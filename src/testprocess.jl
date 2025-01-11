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
    TestItemServerProtocol.append_output_notification_type => (params, msg_channel) -> put!(
        msg_channel,
        (
            event = :append_output,
            testitem_id = params.testItemId,
            output = params.output
        )
    )
end

function create_testprocess(
        controller_msg_channel::Channel,
        env::TestEnvironment,
        is_precompile_process::Bool,
        test_env_content_hash::Union{Nothing,Int},
        error_handler_file,
        crash_reporting_pipename)

    testprocess_id = string(UUIDs.uuid4())
    msg_channel = Channel(Inf)

    @async try
        # These are not nothing while a testrun is going on
        testrun_channel = nothing
        test_setups = nothing
        coverage_root_uris = nothing

        # These are nothing if no Julia process is up and running
        jl_process = nothing
        endpoint = nothing

        debug_pipe_name = JSONRPC.generate_pipe_name()

        precompile_done = false

        while true
            msg = take!(msg_channel)
            # @info "Test process new message" msg

            if msg.event == :start_testrun
                testrun_channel = msg.testrun_channel
                test_setups =msg.test_setups
                coverage_root_uris = msg.coverage_root_uris
            elseif msg.event == :revise
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
                        put!(msg_channel, (;event=:testprocess_activated))
                    else
                        put!(msg_channel, (;event=:restart))
                    end
                catch err
                    Base.display_error(err, catch_backtrace())
                end
            elseif msg.event == :restart
                @info "Revise could not handle changes or test env was changed, restarting process"
                kill(jl_process)
                jl_process = nothing
                endpoint = nothing
                put!(msg_channel, (;event = :start))
            elseif msg.event == :start
                put!(controller_msg_channel, (event=:test_process_status_changed, id=testprocess_id, status="Launching"))
                @async try
                    start(testprocess_id, msg_channel, env, debug_pipe_name, error_handler_file, crash_reporting_pipename)
                catch err
                    Base.display_error(err, catch_backtrace())
                end
            elseif msg.event == :end_testrun
                testrun_channel = nothing
                test_setups = nothing
                coverage_root_uris = nothing
            elseif msg.event == :testprocess_launched
                if env.mode == "Debug"
                    put!(testrun_channel, (source=:testprocess, msg=(;event=:attach_debugger, debug_pipe_name=debug_pipe_name)))
                end
                jl_process = msg.jl_process
                endpoint = msg.endpoint
                if is_precompile_process || precompile_done
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

                        put!(testrun_channel, (source=:testprocess, msg=(;event=:precompile_done, env=env)))
                        put!(msg_channel, (;event=:testprocess_activated))
                    catch err
                        Base.display_error(err, catch_backtrace())
                    end
                end
            elseif msg.event == :precompile_by_other_proc_done
                precompile_done = true
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
                        Base.display_error(err, catch_backtrace())
                    end
                end
            elseif msg.event == :testprocess_activated
                @async try
                    JSONRPC.send(
                        endpoint,
                        TestItemServerProtocol.configure_testrun_request_type,
                        TestItemServerProtocol.ConfigureTestRunRequestParams(
                            mode = env.mode,
                            coverageRootUris = something(coverage_root_uris,missing),
                            testSetups = test_setups
                        )
                    )

                    put!(msg_channel, (;event=:testprocess_testsetups_loaded))
                catch err
                    Base.display_error(err, catch_backtrace())
                end
            elseif msg.event == :testprocess_testsetups_loaded
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
            elseif msg.event == :run_testitems
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
                                    packageName = i.packageName,
                                    packageUri = i.packageUri,
                                    useDefaultUsings = i.useDefaultUsings,
                                    testSetups = i.testSetups,
                                    line = i.codeLine,
                                    column = i.codeColumn,
                                    code = i.code,
                                ) for i in msg.testitems
                            ],
                        )
                    )
                catch err
                    Base.display_error(err, catch_backtrace())
                end
            elseif msg.event == :steal
                @async try
                    JSONRPC.send(
                            endpoint,
                            TestItemServerProtocol.testserver_steal_testitems_request_type,
                            TestItemServerProtocol.StealTestItemsRequestParams(
                                testItemIds = msg.testitem_ids
                            )
                        )
                catch err
                    Base.display_error(err, catch_backtrace())
                end
            elseif msg.event == :testitem_started
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
            elseif msg.event in (:testitem_passed, :testitem_failed, :testitem_errored, :testitem_skipped_stolen)
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
            end
        end
    catch err
        Base.display_error(err, catch_backtrace())
    end

    return testprocess_id, msg_channel
end

function start(testprocess_id, testprocess_msg_channel, env::TestEnvironment, debug_pipe_name, error_handler_file, crash_reporting_pipename)
    pipe_name = JSONRPC.generate_pipe_name()
    server = Sockets.listen(pipe_name)

    testserver_script = joinpath(@__DIR__, "../testprocess/app/testserver_main.jl")

    pipe_out = IOBuffer()

    coverage_arg = env.mode == "Coverage" ? "--code-coverage=user" : "--code-coverage=none"

# //             if(package_uri && false) {
# //                 jlArgs.push(`--code-coverage=@${vscode.Uri.parse(package_uri).fsPath}`)
# //             }
# //             else {

    jlArgs = copy(env.juliaArgs)

    if env.juliaNumThreads == "auto"
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

    if env.juliaNumThreads!="auto" && env.juliaNumThreads!=""
        jlEnv["JULIA_NUM_THREADS"] = env.juliaNumThreads
    end

    error_handler_file = error_handler_file === nothing ? [] : [error_handler_file]
    crash_reporting_pipename = crash_reporting_pipename === nothing ? [] : [crash_reporting_pipename]

    jl_process = open(
        pipeline(
            Cmd(`$(env.juliaCmd) $(env.juliaArgs) --check-bounds=yes --startup-file=no --history-file=no --depwarn=no $coverage_arg $testserver_script $pipe_name $(debug_pipe_name) $(error_handler_file...) $(crash_reporting_pipename...)`, detach=false, env=jlEnv),
            # stdout = pipe_out,
            # stderr = pipe_out
        )
    )

    @async try
        while true
            s = String(take!(pipe_out))

            put!(
                controller_msg_channel,
                (
                    event = :testprocess_output,
                    id = testrun_id,
                    output = s
                )
            )
            sleep(0.5)
        end
    catch err
        bt = catch_backtrace()
        if controller.err_handler !== nothing
            controller.err_handler(err, bt)
        else
            Base.display_error(err, bt)
        end
    end

    socket = Sockets.accept(server)

    endpoint = JSONRPC.JSONRPCEndpoint(socket, socket)

    run(endpoint)

    put!(testprocess_msg_channel, (event=:testprocess_launched, jl_process=jl_process, endpoint=endpoint))

    while true
        msg = JSONRPC.get_next_message(endpoint)
        # @info "Processing msg from test process" msg

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
