mutable struct JSONRPCTestItemController{ERR_HANDLER<:Function}
    err_handler::Union{Nothing,ERR_HANDLER}
    endpoint::JSONRPC.JSONRPCEndpoint
    controller::TestItemController

    function JSONRPCTestItemController(
        pipe_in,
        pipe_out,
        err_handler::ERR_HANDLER;
        error_handler_file=nothing,
        crash_reporting_pipename=nothing) where {ERR_HANDLER<:Union{Function,Nothing}}

        endpoint = JSONRPC.JSONRPCEndpoint(pipe_in, pipe_out, err_handler)

        return new{ERR_HANDLER}(
            err_handler,
            endpoint,
            TestItemController(err_handler; error_handler_file=error_handler_file, crash_reporting_pipename=crash_reporting_pipename)
        )
    end
end

function create_testrun_request(params::TestItemControllerProtocol.CreateTestRunParams, jr_controller::JSONRPCTestItemController, token)
    @debug "Received create_testrun request" testrun_id=params.testRunId profile_count=length(params.testProfiles) testitem_count=length(params.testItems) testsetup_count=length(params.testSetups)
    ret =  execute_testrun(
        jr_controller.controller,
        params.testRunId,
        [
            TestProfile(
                i.id,
                i.label,
                i.juliaCmd,
                i.juliaArgs,
                i.juliaNumThreads,
                i.juliaEnv,
                i.maxProcessCount,
                i.mode,
                coalesce(i.coverageRootUris,nothing),
                jr_controller.controller.log_level
            ) for i in params.testProfiles
        ],
        [
            TestItemDetail(
                i.id,
                i.uri,
                i.label,
                coalesce(i.packageName, nothing),
                coalesce(i.packageUri, nothing),
                coalesce(i.projectUri, nothing),
                coalesce(i.envContentHash, nothing),
                i.useDefaultUsings,
                i.testSetups,
                i.line,
                i.column,
                i.code,
                i.codeLine,
                i.codeColumn
            )
            for i in params.testItems
        ],
        [
            TestSetupDetail(
                coalesce(i.packageUri, nothing),
                i.name,
                i.kind,
                i.uri,
                i.line,
                i.column,
                i.code
            ) for i in params.testSetups
        ],
        # testitem_started_callback,
        (testrun_id, testitem_id) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeTestItemStarted,
            TestItemControllerProtocol.TestItemStartedParams(
                testRunId=testrun_id,
                testItemId=testitem_id
            )
        ),
        # testitem_passed_callback
        (testrun_id, testitem_id, duration) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeTestItemPassed,
            TestItemControllerProtocol.TestItemPassedParams(
                testRunId=testrun_id,
                testItemId=testitem_id,
                duration=duration
            )
        ),
        # testitem_failed_callback
        (testrun_id, testitem_id, messages, duration) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeTestItemFailed,
            TestItemControllerProtocol.TestItemFailedParams(
                    testRunId=testrun_id,
                    testItemId=testitem_id,
                    messages = messages,
                    duration=duration
            )
        ),
        # testitem_errored_callback
        (testrun_id, testitem_id, messages, duration) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeTestItemErrored,
            TestItemControllerProtocol.TestItemErroredParams(
                    testRunId=testrun_id,
                    testItemId=testitem_id,
                    messages = messages,
                    duration=duration
            )
        ),
        # testitem_skipped_callback
        (testrun_id, testitem_id) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeTestItemSkipped,
            (testRunId=testrun_id, testItemId=testitem_id)
        ),
        # append_output_callback
        (testrun_id, testitem_id, output) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notficiationTypeAppendOutput,
            TestItemControllerProtocol.AppendOutputParams(
                testRunId=testrun_id,
                testItemId=testitem_id,
                output=output
            )
        ),
        # attach_debugger_callback
        (testrun_id, debug_pipename) -> JSONRPC.send(
            jr_controller.endpoint,
            TestItemControllerProtocol.notificationTypeLaunchDebugger,
            (;
                debugPipeName = debug_pipename,
                testRunId = testrun_id
            )
        ),
        token
    )

    @debug "Finished create_testrun request" testrun_id=params.testRunId coverage_files=ismissing(ret) ? missing : length(ret)
    return TestItemControllerProtocol.CreateTestRunResponse("success", ret)
end

function terminate_test_process_request(params::TestItemControllerProtocol.TerminateTestProcessParams, json_controller::JSONRPCTestItemController, token)
    @debug "Received terminate_test_process request" id=params.testProcessId
    terminate_test_process(json_controller.controller, params.testProcessId)
end

JSONRPC.@message_dispatcher dispatch_msg begin
    TestItemControllerProtocol.create_testrun_request_type => create_testrun_request
    TestItemControllerProtocol.terminate_test_process_request_type => terminate_test_process_request
end

function Base.run(jr_controller::JSONRPCTestItemController)
    @debug "Starting JSON-RPC controller endpoint"
    run(jr_controller.endpoint)

    @async try
        while true
            msg = JSONRPC.get_next_message(jr_controller.endpoint)
            @debug "Received JSON-RPC message" method=msg.method

            @async try
                @debug "Dispatching JSON-RPC message asynchronously" method=msg.method
                dispatch_msg(jr_controller.endpoint, msg, jr_controller)
            catch err
                bt = catch_backtrace()
                if jr_controller.err_handler !== nothing
                    jr_controller.err_handler(err, bt)
                else
                    @error "Error dispatching message" exception=(err, bt)
                end
            end
        end
    catch err
        bt = catch_backtrace()
        if jr_controller.err_handler !== nothing
            jr_controller.err_handler(err, bt)
        else
            @error "Error in JSONRPC message loop" exception=(err, bt)
        end
    end

    run(
        jr_controller.controller,
        (id, package_name, package_uri, project_uri, coverage, env) -> begin
            @debug "Forwarding test process created notification" id package_name coverage
            JSONRPC.send(
                jr_controller.endpoint,
                TestItemControllerProtocol.notificationTypeTestProcessCreated,
                TestItemControllerProtocol.TestProcessCreatedParams(
                    id = id,
                    packageName = package_name,
                    packageUri = something(package_uri, missing),
                    projectUri = something(project_uri, missing),
                    coverage = coverage,
                    env = env
                )
            )
        end,
        id -> begin
            @debug "Forwarding test process terminated notification" id
            JSONRPC.send(
                jr_controller.endpoint,
                TestItemControllerProtocol.notificationTypeTestProcessTerminated,
                (;id = id)
            )
        end,
        (id, status) -> begin
            @debug "Forwarding test process status notification" id status
            JSONRPC.send(
                jr_controller.endpoint,
                TestItemControllerProtocol.notificationTypeTestProcessStatusChanged,
                TestItemControllerProtocol.TestProcessStatusChangedParams(id = id, status = status)
            )
        end,
        (id, output) -> begin
            @debug "Forwarding test process output notification" id ncodeunits=ncodeunits(output)
            JSONRPC.send(
                jr_controller.endpoint,
                TestItemControllerProtocol.notificationTypeTestProcessOutput,
                TestItemControllerProtocol.TestProcessOutputParams(id = id, output = output)
            )
        end
    )
end
