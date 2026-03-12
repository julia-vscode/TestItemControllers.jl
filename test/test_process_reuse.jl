@testitem "Test process reused across runs" setup=[TestHelpers] begin
    using TestItemControllers: TestItemController, execute_testrun, shutdown
    import UUIDs

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    passing_items = filter(i -> i.label == "add works", discovered.items)
    @test length(passing_items) == 1

    controller = TestItemController(log_level=:Debug)
    profile = TestHelpers.make_test_profile()

    process_created_ids = String[]
    process_created_lock = ReentrantLock()

    controller_task = @async try
        run(
            controller,
            (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> lock(process_created_lock) do
                push!(process_created_ids, id)
            end,
            id -> nothing,
            (id, status) -> nothing,
            (id, output) -> nothing
        )
    catch err
        @error "Controller error" exception=(err, catch_backtrace())
    end

    events1 = NamedTuple[]
    events1_lock = ReentrantLock()

    # First test run
    execute_testrun(
        controller,
        string(UUIDs.uuid4()),
        [profile],
        passing_items,
        discovered.setups,
        (run_id, item_id) -> nothing,
        (run_id, item_id, duration) -> lock(events1_lock) do; push!(events1, (event=:passed,)); end,
        (run_id, item_id, messages, duration) -> nothing,
        (run_id, item_id, messages, duration) -> nothing,
        (run_id, item_id) -> nothing,
        (run_id, item_id, output) -> nothing,
        (run_id, pipe_name) -> nothing,
        nothing
    )

    @test length(filter(e -> e.event == :passed, events1)) == 1
    first_run_process_count = lock(process_created_lock) do
        length(process_created_ids)
    end
    @test first_run_process_count == 1

    events2 = NamedTuple[]
    events2_lock = ReentrantLock()

    # Second test run — should reuse the existing process
    execute_testrun(
        controller,
        string(UUIDs.uuid4()),
        [profile],
        passing_items,
        discovered.setups,
        (run_id, item_id) -> nothing,
        (run_id, item_id, duration) -> lock(events2_lock) do; push!(events2, (event=:passed,)); end,
        (run_id, item_id, messages, duration) -> nothing,
        (run_id, item_id, messages, duration) -> nothing,
        (run_id, item_id) -> nothing,
        (run_id, item_id, output) -> nothing,
        (run_id, pipe_name) -> nothing,
        nothing
    )

    @test length(filter(e -> e.event == :passed, events2)) == 1

    second_run_process_count = lock(process_created_lock) do
        length(process_created_ids)
    end
    # Process count should still be 1 — the process was reused
    @test second_run_process_count == 1

    shutdown(controller)
    wait(controller_task)
end
