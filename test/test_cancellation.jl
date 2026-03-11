@testitem "Cancel running test run" setup=[TestHelpers] begin
    using TestItemControllers: TestItemController, TestProfile, TestItemDetail, TestSetupDetail,
        execute_testrun, shutdown, CancellationTokens
    import UUIDs

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    controller = TestItemController(log_level=:Debug)
    profile = TestHelpers.make_test_profile()
    testrun_id = string(UUIDs.uuid4())

    events = NamedTuple[]
    events_lock = ReentrantLock()

    cs = CancellationTokens.CancellationTokenSource()
    token = CancellationTokens.get_token(cs)

    controller_task = @async try
        run(controller, nothing, nothing, nothing, nothing)
    catch err
        @error "Controller error" exception=(err, catch_backtrace())
    end

    testrun_task = @async try
        execute_testrun(
            controller,
            testrun_id,
            [profile],
            discovered.items,
            discovered.setups,
            (run_id, item_id) -> lock(events_lock) do; push!(events, (event=:started, testitem_id=item_id)); end,
            (run_id, item_id, duration) -> lock(events_lock) do; push!(events, (event=:passed, testitem_id=item_id)); end,
            (run_id, item_id, messages, duration) -> lock(events_lock) do; push!(events, (event=:failed, testitem_id=item_id)); end,
            (run_id, item_id, messages, duration) -> lock(events_lock) do; push!(events, (event=:errored, testitem_id=item_id)); end,
            (run_id, item_id) -> lock(events_lock) do; push!(events, (event=:skipped, testitem_id=item_id)); end,
            (run_id, item_id, output) -> nothing,
            (run_id, pipe_name) -> nothing,
            token
        )
    catch err
        @error "Test run error" exception=(err, catch_backtrace())
    end

    # Cancel immediately
    CancellationTokens.cancel(cs)

    # Wait for testrun to complete
    wait(testrun_task)

    shutdown(controller)
    wait(controller_task)

    # After cancellation, items should be skipped or already completed
    completed = filter(e -> e.event in (:passed, :failed, :errored, :skipped), events)
    @test length(completed) == length(discovered.items)
end
