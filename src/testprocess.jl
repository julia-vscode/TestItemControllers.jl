# This is the dispatch handler for messages from the test processes. It directly passes
# those messages into the main message channel for the test process
JSONRPC.@message_dispatcher dispatch_testprocess_msg begin
    TestItemServerProtocol.started_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :testitem_started,
            testitem_id = params.testItemId,
        )
    )
    TestItemServerProtocol.passed_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :testitem_passed,
            testitem_id = params.testItemId,
            duration = params.duration,
            coverage = params.coverage
        )
    )
    TestItemServerProtocol.failed_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :testitem_failed,
            testitem_id = params.testItemId,
            messages = params.messages,
            duration = params.duration,
        )
    )
    TestItemServerProtocol.errored_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :testitem_errored,
            testitem_id = params.testItemId,
            messages = params.messages,
            duration = params.duration,
        )
    )
    TestItemServerProtocol.skipped_stolen_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :testitem_skipped_stolen,
            testitem_id = params.testItemId
        )
    )
end

function create_testprocess(
        controller_msg_channel::Channel,
        env::TestEnvironment,
        is_precompile_process::Bool,
        test_env_content_hash::Union{Nothing,String},
        error_handler_file,
        crash_reporting_pipename)

    testprocess_id = string(UUIDs.uuid4())
    msg_channel = Channel(Inf)

    Base.ScopedValues.@with logging_node => "tp_$(testprocess_id[1:5])" @async try
        # These are not nothing while a testrun is going on
        testrun_channel = nothing
        testrun_token = nothing
        test_setups = nothing
        coverage_root_uris = nothing
        log_level = :Info

        # These are nothing if no Julia process is up and running
        jl_process = nothing
        endpoint = nothing

        debug_pipe_name = JSONRPC.generate_pipe_name()

        precompile_done = false

        cs = CancellationTokens.CancellationTokenSource()

        julia_proc_cs = nothing

        queued_tests_n = 0
        finished_testitems = Set{String}()
        testitems_to_run_when_ready = nothing
        testrun_watcher_registration = nothing

        state = :created
        function set_state!(new_state::Symbol; reason=nothing)
            old_state = state
            state = new_state
            @debug "Test process state transition" testprocess_id from=old_state to=new_state reason queued_tests_n finished=length(finished_testitems)
            return state
        end

        while true
            msg = take!(msg_channel)
            @debug "Msg $(msg.event)" msg queued_tests_n length(finished_testitems)

            # Absorber: in :cancelled state, ignore all messages except lifecycle events.
            # This safely drains stale messages from killed async operations.
            if state == :cancelled && msg.event ∉ (:end_testrun, :terminate, :shutdown)
                if msg.event == :testprocess_launched
                    # Kill the stale process that connected after cancellation
                    try kill(msg.jl_process) catch end
                end
                @debug "Ignoring message in cancelled state" testprocess_id event=msg.event
                continue
            end

            if msg.event == :shutdown
                @debug "Sending shutdown request to active endpoint" testprocess_id state has_endpoint=endpoint !== nothing
                CancellationTokens.cancel(cs)
                @async try
                    JSONRPC.send(
                        endpoint,
                        TestItemServerProtocol.testserver_shutdown_request_type,
                        nothing
                    )
                catch err
                    @error "Error sending shutdown request" testprocess_id state exception=(err, catch_backtrace())
                end
            elseif msg.event == :terminate
                @info "Terminating test process"
                if jl_process !== nothing
                    try CancellationTokens.cancel(julia_proc_cs) catch end
                    try kill(jl_process) catch end
                    jl_process = nothing
                    endpoint = nothing
                    julia_proc_cs = nothing
                end
                if testrun_channel !== nothing && isopen(testrun_channel)
                    put!(testrun_channel, (source=:testprocess, msg=(event=:test_process_terminated, id=testprocess_id)))
                end
                put!(controller_msg_channel, (event=:test_process_terminated, id=testprocess_id))
                break
            elseif msg.event == :start_testrun
                state in (:created, :idle) || error("Invalid state transition from $state.")
                set_state!(:testrun_idle; reason=:start_testrun)

                testrun_channel = msg.testrun_channel
                testrun_token = msg.token
                test_setups = msg.test_setups
                coverage_root_uris = msg.coverage_root_uris
                log_level = msg.log_level

                @debug "Registered test run on process" testprocess_id has_token=testrun_token !== nothing setup_count=length(test_setups) coverage_root_uris_count=coverage_root_uris === nothing ? 0 : length(coverage_root_uris)

                testrun_watcher_registration = CancellationTokens.register(testrun_token) do
                    @debug "Process cancellation watcher fired" testprocess_id
                    try put!(msg_channel, (;event=:cancel_test_run)) catch end
                end
            elseif msg.event == :cancel_test_run
                if state == :idle
                    # Already idle, nothing to cancel (async watcher fired after :end_testrun)
                    continue
                end

                @debug "Cancelling test run on process" testprocess_id state

                if jl_process !== nothing && endpoint !== nothing
                    # Attempt graceful shutdown first
                    local saved_endpoint = endpoint
                    local saved_process = jl_process
                    @async try
                        @debug "Attempting graceful shutdown of Julia process" testprocess_id
                        shutdown_timeout = CancellationTokens.CancellationTokenSource(2.0)
                        shutdown_done = Channel{Bool}(1)
                        @async try
                            try
                                JSONRPC.send(
                                    saved_endpoint,
                                    TestItemServerProtocol.testserver_shutdown_request_type,
                                    nothing
                                )
                                put!(shutdown_done, true)
                            catch
                                put!(shutdown_done, false)
                            end
                        catch err
                            @error "Error in shutdown sender" testprocess_id exception=(err, catch_backtrace())
                        end
                        shutdown_timeout_reg = CancellationTokens.register(CancellationTokens.get_token(shutdown_timeout)) do
                            try put!(shutdown_done, false) catch end
                        end
                        graceful = take!(shutdown_done)
                        close(shutdown_timeout_reg)
                        if !graceful && process_running(saved_process)
                            kill(saved_process)
                        end
                    catch err
                        try kill(saved_process) catch end
                    end
                elseif jl_process !== nothing
                    try kill(jl_process) catch end
                end

                if julia_proc_cs !== nothing
                    try CancellationTokens.cancel(julia_proc_cs) catch end
                end
                jl_process = nothing
                endpoint = nothing
                julia_proc_cs = nothing

                queued_tests_n = 0
                empty!(finished_testitems)
                testitems_to_run_when_ready = nothing

                if testrun_watcher_registration !== nothing
                    try close(testrun_watcher_registration) catch end
                    testrun_watcher_registration = nothing
                end

                set_state!(:cancelled; reason=:cancel_test_run)
            elseif msg.event == :revise
                state == :testrun_idle || error("Invalid state transition")

                if endpoint === nothing
                    # Process was killed during cancellation but not yet restarted —
                    # skip revise and go straight to restart path.
                    set_state!(:testrun_killed_after_revise_fail; reason=:revise_without_endpoint)
                    @debug "Skipping revise because endpoint is gone" testprocess_id
                    put!(msg_channel, (;event = :start))
                    continue
                end

                set_state!(:testrun_revising; reason=:revise)

                put!(controller_msg_channel, (event=:test_process_status_changed, id=testprocess_id, status="Revising"))

                @async try
                    needs_restart = false

                    if msg.test_env_content_hash != test_env_content_hash
                        needs_restart = true
                    else
                        res = JSONRPC.send(endpoint, TestItemServerProtocol.testserver_revise_request_type, nothing)

                        if res=="success"
                            needs_restart = false
                        elseif res == "failed"
                            needs_restart = true
                        else
                            error("")
                        end
                    end

                    if !needs_restart
                        @debug "Revise completed without restart" testprocess_id
                        put!(msg_channel, (;event=:testprocess_activated))
                    else
                        @debug "Revise requested restart" testprocess_id
                        put!(msg_channel, (;event=:restart))
                    end
                catch err
                    @error "Error during revise" testprocess_id state exception=(err, catch_backtrace())
                    try put!(msg_channel, (;event=:restart)) catch end
                end
            elseif msg.event == :restart
                state == :testrun_revising || error("Invalid state transition")
                set_state!(:testrun_killed_after_revise_fail; reason=:restart)

                @debug "Revise could not handle changes or test env was changed, restarting process"
                if julia_proc_cs !== nothing
                    CancellationTokens.cancel(julia_proc_cs)
                end
                if jl_process !== nothing
                    kill(jl_process)
                end
                jl_process = nothing
                endpoint = nothing
                julia_proc_cs = nothing
                put!(msg_channel, (;event = :start))
            elseif msg.event == :start
                if state == :idle
                    # Stale :start from a cancelled test run that already ended — ignore
                    @debug "Ignoring stale start request" testprocess_id
                    continue
                end
                state in (:testrun_idle, :testrun_killed_after_revise_fail) || error("Invalid state transition")
                set_state!(:testprocess_starting; reason=:start)

                julia_proc_cs === nothing || error("Invalid state for julia_proc_cs")
                julia_proc_cs = if testrun_token !== nothing && !CancellationTokens.is_cancellation_requested(testrun_token)
                    CancellationTokens.CancellationTokenSource(CancellationTokens.get_token(cs), testrun_token)
                else
                    CancellationTokens.CancellationTokenSource(CancellationTokens.get_token(cs))
                end

                @debug "Launching Julia process for test process" testprocess_id linked_to_testrun=testrun_token !== nothing

                put!(controller_msg_channel, (event=:test_process_status_changed, id=testprocess_id, status="Launching"))
                @async try

                    start(testprocess_id, controller_msg_channel, msg_channel, env, debug_pipe_name, error_handler_file, crash_reporting_pipename, CancellationTokens.get_token(julia_proc_cs))
                catch err
                    @error "Error starting test process" testprocess_id state exception=(err, catch_backtrace())
                    try put!(msg_channel, (;event=:process_error)) catch end
                end
            elseif msg.event == :end_testrun
                if state == :idle
                    # Already idle, nothing to do (defensive guard against duplicate :end_testrun)
                    @debug "Ignoring duplicate end_testrun" testprocess_id
                    continue
                end
                if state == :running_tests
                    @error "This should not happen" queued_tests_n length(finished_testitems)
                end
                if state == :testprocess_starting
                    # Process is restarting (e.g. after cancellation) — clear testrun
                    # vars but keep state so :testprocess_launched can finish and
                    # transition to :idle via the testrun_channel===nothing path.
                    if testrun_watcher_registration !== nothing
                        try close(testrun_watcher_registration) catch end
                        testrun_watcher_registration = nothing
                    end
                    testrun_channel = nothing
                    testrun_token = nothing
                    test_setups = nothing
                    coverage_root_uris = nothing
                    @debug "Cleared test run metadata while process is still starting" testprocess_id
                    continue
                end
                state in (:testrun_idle, :testrun_killed_after_revise_fail, :cancelled) || error("Invalid state transition from $state")
                set_state!(:idle; reason=:end_testrun)

                # Deregister the cancellation callback so it doesn't fire after testrun ends
                if testrun_watcher_registration !== nothing
                    try close(testrun_watcher_registration) catch end
                    testrun_watcher_registration = nothing
                end

                testrun_channel = nothing
                testrun_token = nothing
                test_setups = nothing
                coverage_root_uris = nothing
            elseif msg.event == :testprocess_launched
                state == :testprocess_starting || error("Invalid state transition.")

                jl_process = msg.jl_process
                endpoint = msg.endpoint
                if testrun_channel===nothing
                    set_state!(:idle; reason=:launched_without_testrun)
                elseif is_precompile_process || precompile_done
                    set_state!(is_precompile_process ? :testrun_precompiling : :testrun_activating; reason=:testprocess_launched)
                    @debug "Activating environment after launch" testprocess_id precompile_process=is_precompile_process precompile_done
                    @async try
                        JSONRPC.send(
                            endpoint,
                            TestItemServerProtocol.testserver_activate_env_request_type,
                            TestItemServerProtocol.ActivateEnvParams(
                                projectUri=something(env.project_uri, missing),
                                packageUri=env.package_uri,
                                packageName=env.package_name
                            )
                        )

                        put!(testrun_channel, (source=:testprocess, msg=(;event=:precompile_done, env=env, testprocess_id=testprocess_id)))
                        put!(msg_channel, (;event=:testprocess_activated))
                    catch err
                        @error "Error activating environment" testprocess_id state exception=(err, catch_backtrace())
                        try put!(msg_channel, (;event=:kill_and_restart)) catch end
                    end
                else
                    set_state!(:testrun_waiting_for_precompile_done; reason=:waiting_for_peer_precompile)
                end
            elseif msg.event == :precompile_by_other_proc_done
                if state == :testrun_waiting_for_precompile_done
                    set_state!(:activating_env; reason=:precompile_by_other_proc_done)

                    precompile_done = true
                    @debug "Peer process completed precompile" testprocess_id
                    if !is_precompile_process && jl_process !== nothing
                        @async try
                            JSONRPC.send(
                                endpoint,
                                TestItemServerProtocol.testserver_activate_env_request_type,
                                TestItemServerProtocol.ActivateEnvParams(
                                    projectUri=something(env.project_uri, missing),
                                    packageUri=env.package_uri,
                                    packageName=env.package_name
                                )
                            )

                            put!(msg_channel, (;event=:testprocess_activated))
                        catch err
                            @error "Error activating env after precompile" testprocess_id state exception=(err, catch_backtrace())
                            try put!(msg_channel, (;event=:kill_and_restart)) catch end
                        end
                    end
                end
            elseif msg.event == :testprocess_activated
                state in (:activating_env, :testrun_activating, :testrun_precompiling, :testrun_revising) || error("Invalid state transition from $state.")
                set_state!(:configuring_test_run; reason=:testprocess_activated)

                if env.mode == "Debug"
                    @debug "Requesting debugger attachment" testprocess_id debug_pipe_name
                    put!(testrun_channel, (source=:testprocess, msg=(;event=:attach_debugger, debug_pipe_name=debug_pipe_name)))
                end

                @debug "Configuring test run on process" testprocess_id mode=env.mode setup_count=length(test_setups)
                @async try
                    JSONRPC.send(
                        endpoint,
                        TestItemServerProtocol.configure_testrun_request_type,
                        TestItemServerProtocol.ConfigureTestRunRequestParams(
                            mode = env.mode,
                            logLevel = string(log_level),
                            coverageRootUris = something(coverage_root_uris,missing),
                            testSetups = test_setups
                        )
                    )

                    put!(msg_channel, (;event=:testprocess_testsetups_loaded))
                catch err
                    @error "Error configuring test run" testprocess_id state exception=(err, catch_backtrace())
                    try put!(msg_channel, (;event=:kill_and_restart)) catch end
                end
            elseif msg.event == :testprocess_testsetups_loaded
                state == :configuring_test_run || error("Invalid state transition from $state.")
                set_state!(:ready_to_run_tests; reason=:testprocess_testsetups_loaded)
                @info "Process is ready to run test items"
                put!(
                    testrun_channel,
                    (
                        source=:testprocess,
                        msg = (
                            event = :ready_to_run_testitems,
                            id = testprocess_id,
                            channel = msg_channel
                        )
                    )
                )

                if testitems_to_run_when_ready!==nothing
                    set_state!(:running_tests; reason=:draining_buffered_testitems)

                    queued_tests_n = length(testitems_to_run_when_ready)
                    empty!(finished_testitems)

                    @debug "Running buffered test items" testprocess_id queued_tests_n

                    put!(controller_msg_channel, (event=:test_process_status_changed, id=testprocess_id, status="Running"))
                    @async try
                        JSONRPC.send(
                            endpoint,
                            TestItemServerProtocol.testserver_run_testitems_batch_request_type,
                            TestItemServerProtocol.RunTestItemsRequestParams(
                                mode = env.mode,
                                coverageRootUris = something(coverage_root_uris, missing),
                                testItems = TestItemServerProtocol.RunTestItem[
                                    TestItemServerProtocol.RunTestItem(
                                        id = i.id,
                                        uri = i.uri,
                                        name = i.label,
                                        packageName = something(i.package_name, missing),
                                        packageUri = something(i.package_uri, missing),
                                        useDefaultUsings = i.option_default_imports,
                                        testSetups = i.test_setups,
                                        line = i.code_line,
                                        column = i.code_column,
                                        code = i.code,
                                    ) for i in testitems_to_run_when_ready
                                ],
                            )
                        )
                        testitems_to_run_when_ready = nothing
                    catch err
                        @error "Error running queued test batch" testprocess_id state exception=(err, catch_backtrace())
                        try put!(msg_channel, (;event=:kill_and_restart)) catch end
                    end
                end
            elseif msg.event == :run_testitems
                if state in (:ready_to_run_tests, :testrun_idle, :running_tests)
                    set_state!(:running_tests; reason=:run_testitems)

                    queued_tests_n = length(msg.testitems)
                    empty!(finished_testitems)

                    @debug "Running assigned test items" testprocess_id queued_tests_n

                    put!(controller_msg_channel, (event=:test_process_status_changed, id=testprocess_id, status="Running"))
                    @async try
                        JSONRPC.send(
                            endpoint,
                            TestItemServerProtocol.testserver_run_testitems_batch_request_type,
                            TestItemServerProtocol.RunTestItemsRequestParams(
                                mode = env.mode,
                                coverageRootUris = something(coverage_root_uris, missing),
                                testItems = TestItemServerProtocol.RunTestItem[
                                    TestItemServerProtocol.RunTestItem(
                                        id = i.id,
                                        uri = i.uri,
                                        name = i.label,
                                        packageName = something(i.package_name, missing),
                                        packageUri = something(i.package_uri, missing),
                                        useDefaultUsings = i.option_default_imports,
                                        testSetups = i.test_setups,
                                        line = i.code_line,
                                        column = i.code_column,
                                        code = i.code,
                                    ) for i in msg.testitems
                                ],
                            )
                        )
                    catch err
                        @error "Error running testitems" testprocess_id state exception=(err, catch_backtrace())
                        try put!(msg_channel, (;event=:kill_and_restart)) catch end
                    end
                elseif state == :testprocess_starting
                    @debug "Buffering test items until process is ready" testprocess_id buffered=length(msg.testitems)
                    testitems_to_run_when_ready = msg.testitems
                else
                    error("Invalid state transition from $state on $testprocess_id.")
                end
            elseif msg.event == :steal
                @debug "Sending steal request to test server" testprocess_id count=length(msg.testitem_ids)
                @async try
                    JSONRPC.send(
                            endpoint,
                            TestItemServerProtocol.testserver_steal_testitems_request_type,
                            TestItemServerProtocol.StealTestItemsRequestParams(
                                testItemIds = msg.testitem_ids
                            )
                        )
                catch err
                    @error "Error stealing testitems" testprocess_id state exception=(err, catch_backtrace())
                end
            elseif msg.event == :testitem_started
                if testrun_channel !== nothing
                    @debug "Forwarding started notification" testprocess_id testitem_id=msg.testitem_id
                    put!(
                        testrun_channel,
                        (
                            source=:testprocess,
                            msg=(
                                event=:started,
                                testitemid=msg.testitem_id
                            )
                        )
                    )
                end
            elseif msg.event in (:testitem_passed, :testitem_failed, :testitem_errored, :testitem_skipped_stolen)
                if state == :testrun_idle && testrun_channel !== nothing
                    # Late result arriving after batch completed (e.g. stolen item confirmation)
                    # Forward to testrun_channel without batch accounting
                    if !(msg.testitem_id in finished_testitems)
                        push!(finished_testitems, msg.testitem_id)
                        @debug "Forwarding late terminal result" testprocess_id event=msg.event testitem_id=msg.testitem_id state
                    else
                        @debug "Ignoring duplicate late terminal result" testprocess_id event=msg.event testitem_id=msg.testitem_id state
                        continue
                    end
                elseif state != :running_tests
                    # Stale result from a killed process after cancellation — ignore
                    @debug "Ignoring stale terminal result" testprocess_id event=msg.event testitem_id=msg.testitem_id state
                    continue
                else
                    if msg.testitem_id in finished_testitems
                        @debug "Ignoring duplicate terminal result from test process" testprocess_id event=msg.event testitem_id=msg.testitem_id
                        # Duplicate result from steal race — skip forwarding
                        continue
                    end

                    push!(finished_testitems, msg.testitem_id)
                    @debug "Forwarding terminal result" testprocess_id event=msg.event testitem_id=msg.testitem_id finished=length(finished_testitems) queued_tests_n

                    if queued_tests_n == length(finished_testitems)
                        set_state!(:testrun_idle; reason=:batch_completed)
                    end
                end

                    if msg.event == :testitem_passed
                        put!(
                            testrun_channel,
                            (
                                source=:testprocess,
                                msg=(
                                    event=:passed,
                                    testitemid=msg.testitem_id,
                                    duration=msg.duration,
                                    coverage=msg.coverage,
                                    test_process_id = testprocess_id
                                )
                            )
                        )
                    elseif msg.event == :testitem_failed
                        put!(
                            testrun_channel,
                            (
                                source=:testprocess,
                                msg=(
                                    event=:failed,
                                    testitemid=msg.testitem_id,
                                    messages=msg.messages,
                                    duration=msg.duration,
                                    test_process_id = testprocess_id
                                )
                            )
                        )
                    elseif msg.event == :testitem_errored
                        put!(
                            testrun_channel,
                            (
                                source=:testprocess,
                                msg=(
                                    event=:errored,
                                    testitemid=msg.testitem_id,
                                    messages=msg.messages,
                                    duration=msg.duration,
                                    test_process_id = testprocess_id
                                )
                            )
                        )
                    elseif msg.event == :testitem_skipped_stolen
                        put!(
                            testrun_channel,
                            (
                                source=:testprocess,
                                msg=(
                                    event=:skipped_stolen,
                                    testitemid=msg.testitem_id,
                                    test_process_id = testprocess_id
                                )
                            )
                        )
                    else
                        error("Unknown message")
                    end
            elseif msg.event == :append_output
                # TODO Remove this and understand the race situation better
                if testrun_channel !== nothing
                    @debug "Forwarding append_output notification" testprocess_id testitem_id=msg.testitem_id ncodeunits=ncodeunits(msg.output)
                    put!(
                        testrun_channel,
                        (
                            source=:testprocess,
                            msg=(
                                event=:append_output,
                                testitemid=msg.testitem_id,
                                # testrunid=params.testRunId,
                                output=msg.output
                            )
                        )
                    )
                end
            elseif msg.event == :kill_and_restart
                if state == :idle
                    # Stale message from a previous async operation — ignore
                    @debug "Ignoring stale kill_and_restart" testprocess_id
                    continue
                end
                @warn "Async operation failed, restarting test process" testprocess_id state
                if jl_process !== nothing
                    try CancellationTokens.cancel(julia_proc_cs) catch end
                    try kill(jl_process) catch end
                    jl_process = nothing
                    endpoint = nothing
                    julia_proc_cs = nothing
                end
                set_state!(:testrun_killed_after_revise_fail; reason=:kill_and_restart)
                put!(msg_channel, (;event=:start))
            elseif msg.event == :process_error
                @error "Test process encountered an unrecoverable error" testprocess_id state
                if jl_process !== nothing
                    try CancellationTokens.cancel(julia_proc_cs) catch end
                    try kill(jl_process) catch end
                    jl_process = nothing
                    endpoint = nothing
                    julia_proc_cs = nothing
                end
                if testrun_channel !== nothing && isopen(testrun_channel)
                    put!(testrun_channel, (source=:testprocess, msg=(event=:test_process_terminated, id=testprocess_id)))
                end
                put!(controller_msg_channel, (event=:test_process_terminated, id=testprocess_id))
                break
            end
        end
    catch err
        @error "Fatal error in test process event loop" testprocess_id exception=(err, catch_backtrace())
        if jl_process !== nothing
            try CancellationTokens.cancel(julia_proc_cs) catch end
            try kill(jl_process) catch end
            jl_process = nothing
            endpoint = nothing
            julia_proc_cs = nothing
        end
        if testrun_channel !== nothing && isopen(testrun_channel)
            put!(testrun_channel, (source=:testprocess, msg=(event=:test_process_terminated, id=testprocess_id)))
        end
        put!(controller_msg_channel, (event=:test_process_terminated, id=testprocess_id))
    end

    return testprocess_id, msg_channel
end

function start(testprocess_id, controller_msg_channel, testprocess_msg_channel, env::TestEnvironment, debug_pipe_name, error_handler_file, crash_reporting_pipename, token)
    pipe_name = JSONRPC.generate_pipe_name()
    server = Sockets.listen(pipe_name)

    # Close the server socket if cancellation fires, unblocking Sockets.accept
    server_cancel_reg = CancellationTokens.register(token) do
        try close(server) catch end
    end

    testserver_script = joinpath(@__DIR__, "../testprocess/app/testserver_main.jl")

    pipe_out = Pipe()

    coverage_arg = env.mode == "Coverage" ? "--code-coverage=user" : "--code-coverage=none"

# //             if(package_uri && false) {
# //                 jlArgs.push(`--code-coverage=@${vscode.Uri.parse(package_uri).fsPath}`)
# //             }
# //             else {

    jlArgs = copy(env.juliaArgs)

    if env.juliaNumThreads!==missing && env.juliaNumThreads == "auto"
        push!(jlArgs, "--threads=auto")
    end

    jlEnv = copy(ENV)

    for (k,v) in pairs(env.env)
        if v!==nothing
            jlEnv[k] = v
        elseif haskey(jlEnv, k)
            delete!(jlEnv, k)
        end
    end

    if env.juliaNumThreads!==missing && env.juliaNumThreads!="auto" && env.juliaNumThreads!=""
        jlEnv["JULIA_NUM_THREADS"] = env.juliaNumThreads
    end

    error_handler_file = error_handler_file === nothing ? [] : [error_handler_file]
    crash_reporting_pipename = crash_reporting_pipename === nothing ? [] : [crash_reporting_pipename]

    @info "Launching Julia test server process"
    jl_process = open(
        pipeline(
            Cmd(`$(env.juliaCmd) $(env.juliaArgs) --check-bounds=yes --startup-file=no --history-file=no --depwarn=no $coverage_arg $testserver_script $pipe_name $(debug_pipe_name) $(error_handler_file...) $(crash_reporting_pipename...)`, detach=false, env=jlEnv),
            stdout = pipe_out,
            stderr = pipe_out
        )
    )

    @async try
        begin_marker = "\x1f3805a0ad41b54562a46add40be31ca27"
        end_marker = "\x1f4031af828c3d406ca42e25628bb0aa77"
        buffer = ""
        current_output_testitem_id = nothing
        while !eof(pipe_out)
            data = readavailable(pipe_out)
            data_as_string = String(data)

            buffer *= data_as_string

            output_for_test_proc = IOBuffer()
            output_for_test_items = Pair{Union{Nothing,String},IOBuffer}[]

            i = 1
            while i<=length(buffer)
                might_be_begin_marker = false
                might_be_end_marker = false

                if current_output_testitem_id === nothing
                    j = 1
                    might_be_begin_marker = true
                    while i + j - 1<=length(buffer) && j <= length(begin_marker)
                        if buffer[i + j - 1] != begin_marker[j] || nextind(buffer, i + j - 1) != i + j
                            might_be_begin_marker = false
                            break
                        end
                        j += 1
                    end
                    is_begin_marker = might_be_begin_marker && length(buffer) - i + 1 >= length(begin_marker)

                    if is_begin_marker
                        ti_id_end_index = findfirst("\"", SubString(buffer, i))
                        if ti_id_end_index === nothing
                            break
                        else
                            current_output_testitem_id = SubString(buffer, i + length(begin_marker), i + ti_id_end_index.start - 2)
                            i = nextind(buffer, i + ti_id_end_index.start - 1)
                        end
                    elseif might_be_begin_marker
                        break
                    end
                else
                    j = 1
                    might_be_end_marker = true
                    while i + j - 1<=length(buffer) && j <= length(end_marker)
                        if buffer[i + j - 1] != end_marker[j] || nextind(buffer, i + j - 1) != i + j
                            might_be_end_marker = false
                            break
                        end
                        j += 1
                    end
                    is_end_marker = might_be_end_marker && length(buffer) - i + 1 >= length(end_marker)

                    if is_end_marker
                        current_output_testitem_id = nothing
                        i = i + length(end_marker)
                    elseif might_be_end_marker
                        break
                    end
                end

                if !might_be_begin_marker && !might_be_end_marker
                    print(output_for_test_proc, buffer[i])

                    if length(output_for_test_items) == 0 || output_for_test_items[end].first != current_output_testitem_id
                        push!(output_for_test_items, current_output_testitem_id => IOBuffer())
                    end

                    output_for_ti = output_for_test_items[end].second
                    if !CancellationTokens.is_cancellation_requested(token)
                        print(output_for_ti, buffer[i])
                    end

                    i = nextind(buffer, i)
                end
            end

            buffer = buffer[i:end]

            output_for_test_proc_as_string = String(take!(output_for_test_proc))

            if length(output_for_test_proc_as_string) > 0
                @debug "Forwarding process output chunk" testprocess_id ncodeunits=ncodeunits(output_for_test_proc_as_string)
                put!(
                    controller_msg_channel,
                    (
                        event = :testprocess_output,
                        id = testprocess_id,
                        output = output_for_test_proc_as_string
                    )
                )
            end

            for (k,v) in output_for_test_items
                output_for_ti_as_string = String(take!(v))

                if length(output_for_ti_as_string) > 0
                    @debug "Forwarding test item output chunk" testprocess_id testitem_id=something(k, missing) ncodeunits=ncodeunits(output_for_ti_as_string)
                    put!(
                        testprocess_msg_channel,
                        (
                            event = :append_output,
                            testitem_id = something(k, missing),
                            output = replace(output_for_ti_as_string, "\n"=>"\r\n")
                        )
                    )
                end
            end
        end
    catch err
        @error "Error reading test process output" testprocess_id exception=(err, catch_backtrace())
    end

    @info "Waiting for connection from test process"
    local socket
    try
        socket = Sockets.accept(server)
    catch err
        close(server_cancel_reg)
        rethrow(err)
    end
    close(server_cancel_reg)
    @info "Connection established"

    endpoint = JSONRPC.JSONRPCEndpoint(socket, socket)

    run(endpoint)

    @debug "Notifying state machine that process launched" testprocess_id
    put!(testprocess_msg_channel, (event=:testprocess_launched, jl_process=jl_process, endpoint=endpoint))

    while true
        msg = try
            JSONRPC.get_next_message(endpoint)
        catch err
            if CancellationTokens.is_cancellation_requested(token)
                break
            else
                rethrow(err)
            end
        end
        @debug "Dispatching message from test server" testprocess_id method=msg.method

        dispatch_testprocess_msg(endpoint, msg, testprocess_msg_channel)
    end

    # @async try
    #     while true
    #         msg = take!(tp.channel_to_sub)

    #         if msg.source==:controller
    #             if msg.msg.command == :activate
    #                 JSONRPC.send(
    #                     tp.endpoint,
    #                     TestItemServerProtocol.testserver_start_test_run_request_type,
    #                     [tp.test_run_id]
    #                 )




    #                 put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:test_process_status_changed, id=tp.id, status="Idle")))

    #                 put!(tp.activated, true)

    #             elseif msg.msg.command == :cancel
    #                 tp.killed = true
    #                 @info "Now canceling $(tp.id)"
    #                 put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:test_process_status_changed, id=tp.id, status="Canceling")))
    #                 @info "Canceling process $(tp.id)"
    #                 kill(tp.jl_process)

    #                 put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:test_process_terminated, id=tp.id)))
    #                 break
    #             elseif msg.msg.command == :terminate
    #                 tp.killed = true
    #                 @info "Now terminating $(tp.id)"
    #                 put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:test_process_status_changed, id=tp.id, status="Terminating")))
    #                 kill(tp.jl_process)

    #                 if tp.test_run_id!==nothing
    #                     for ti in tp.testitems_to_run
    #                         put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:failed, testitemid=ti.id, testrunid=tp.test_run_id, messages=[TestItemServerProtocol.TestMessage("Test process was terminated.", TestItemServerProtocol.Location(ti.uri, TestItemServerProtocol.Position(ti.line-1, ti.column-1)))])))
    #                     end
    #                 end

    #                 put!(tp.controller_msg_channel, (source=:testprocess, msg=(event=:test_process_terminated, id=tp.id)))
    #                 break
    #             elseif msg.msg.command == :run

    #             else
    #                 error("")
    #             end
    #         else
    #             error("")
    #         end
    #     end
    # catch err
    #     bt = catch_backtrace()
    #     if controller.err_handler !== nothing
    #         controller.err_handler(err, bt)
    #     else
    #         Base.display_error(err, bt)
    #     end
    # end
end
