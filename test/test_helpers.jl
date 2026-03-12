@testmodule TestHelpers begin
    using JuliaWorkspaces
    using TestItemControllers: TestProfile, TestItemDetail, TestSetupDetail, TestItemController,
        execute_testrun, shutdown, TestItemControllerProtocol

    const TESTDATA_DIR = normpath(joinpath(@__DIR__, "..", "testdata"))

    function discover_test_items(pkg_path::String)
        jw = workspace_from_folders([pkg_path])
        td_dict = get_test_items(jw)

        items = TestItemDetail[]
        setups = TestSetupDetail[]

        for (file_uri, td) in td_dict
            for ti in td.testitems
                env = get_test_env(jw, ti.uri)
                tf = get_text_file(jw, ti.uri)
                pos = position_at(tf.content, first(ti.range))
                code_pos = position_at(tf.content, first(ti.code_range))

                push!(items, TestItemDetail(
                    ti.id,                                    # id
                    string(ti.uri),                           # uri
                    ti.name,                                  # label
                    env.package_name,                         # package_name
                    env.package_uri === nothing ? nothing : string(env.package_uri),  # package_uri
                    env.project_uri === nothing ? nothing : string(env.project_uri),  # project_uri
                    env.env_content_hash,                     # env_content_hash
                    ti.option_default_imports,                 # option_default_imports
                    String[string(s) for s in ti.option_setup],  # test_setups
                    pos[1],                                    # line
                    pos[2],                                    # column
                    ti.code,                                  # code
                    code_pos[1],                               # code_line
                    code_pos[2]                                # code_column
                ))
            end

            for ts in td.testsetups
                env = get_test_env(jw, ts.uri)
                env.package_uri === nothing && continue
                tf = get_text_file(jw, ts.uri)
                pos = position_at(tf.content, first(ts.range))

                push!(setups, TestSetupDetail(
                    string(env.package_uri),
                    string(ts.name),
                    string(ts.kind),
                    string(ts.uri),
                    pos[1],
                    pos[2],
                    ts.code
                ))
            end
        end

        return (items=items, setups=setups)
    end

    function make_test_profile(; mode="Run", max_procs=1, coverage_root_uris=nothing, log_level=:Debug)
        TestProfile(
            "test-profile-1",
            "Test Profile",
            joinpath(Sys.BINDIR, "julia"),
            String[],
            missing,
            Dict{String,Union{String,Nothing}}(),
            max_procs,
            mode,
            coverage_root_uris,
            log_level
        )
    end

    function run_testrun(items, setups; mode="Run", max_procs=1, timeout=300, coverage_root_uris=nothing, log_level=:Debug)
        controller = TestItemController(log_level=log_level)
        profile = make_test_profile(; mode=mode, max_procs=max_procs, coverage_root_uris=coverage_root_uris, log_level=log_level)
        testrun_id = string(UUIDs.uuid4())

        events = NamedTuple[]
        events_lock = ReentrantLock()
        push_event!(e) = lock(events_lock) do
            push!(events, e)
        end

        process_events = NamedTuple[]
        process_events_lock = ReentrantLock()
        push_process_event!(e) = lock(process_events_lock) do
            push!(process_events, e)
        end

        controller_task = @async try
            run(
                controller,
                (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> push_process_event!((
                    event=:process_created, id=id, package_name=pkg_name
                )),
                id -> push_process_event!((event=:process_terminated, id=id)),
                (id, status) -> push_process_event!((event=:status_changed, id=id, status=status)),
                (id, output) -> nothing  # suppress output
            )
        catch err
            @error "Controller run error" exception=(err, catch_backtrace())
        end

        coverage_result = missing
        testrun_task = @async try
            coverage_result = execute_testrun(
                controller,
                testrun_id,
                [profile],
                items,
                setups,
                # testitem_started
                (run_id, item_id) -> push_event!((event=:started, testrun_id=run_id, testitem_id=item_id)),
                # testitem_passed
                (run_id, item_id, duration) -> push_event!((event=:passed, testrun_id=run_id, testitem_id=item_id, duration=duration)),
                # testitem_failed
                (run_id, item_id, messages, duration) -> push_event!((event=:failed, testrun_id=run_id, testitem_id=item_id, messages=messages, duration=duration)),
                # testitem_errored
                (run_id, item_id, messages, duration) -> push_event!((event=:errored, testrun_id=run_id, testitem_id=item_id, messages=messages, duration=duration)),
                # testitem_skipped
                (run_id, item_id) -> push_event!((event=:skipped, testrun_id=run_id, testitem_id=item_id)),
                # append_output
                (run_id, item_id, output) -> nothing,
                # attach_debugger
                (run_id, pipe_name) -> nothing,
                nothing  # token
            )
        catch err
            @error "Test run error" exception=(err, catch_backtrace())
        end

        # Wait for test run with timeout
        timer = Timer(timeout)
        @async begin
            wait(timer)
            if !istaskdone(testrun_task)
                @warn "Test run timed out after $(timeout)s, shutting down"
                shutdown(controller)
            end
        end

        wait(testrun_task)
        close(timer)

        shutdown(controller)
        wait(controller_task)

        return (events=events, process_events=process_events, coverage=coverage_result)
    end

    import UUIDs
end
