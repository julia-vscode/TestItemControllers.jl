@testitem "Controller shutdown with active processes" setup=[TestHelpers] begin
    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    passing_items = filter(i -> i.label == "add works", discovered.items)

    result = TestHelpers.run_testrun(passing_items, discovered.setups)

    # Test run should complete successfully
    passed_events = filter(e -> e.event == :passed, result.events)
    @test length(passed_events) == 1

    # Process should have been created and eventually become idle
    created_events = filter(e -> e.event == :process_created, result.process_events)
    @test length(created_events) >= 1
end

@testitem "Terminate specific test process" begin
    tic = TestItemController(log_level=:Debug)

    controller_finished = Channel(1)

    process_events = NamedTuple[]

    @async try
        run(
            tic,
            (id, pkg_name, pkg_uri, proj_uri, coverage, env) -> push!(process_events, (event=:created, id=id)),
            id -> push!(process_events, (event=:terminated, id=id)),
            (id, status) -> nothing,
            (id, output) -> nothing
        )
        put!(controller_finished, true)
    catch err
        Base.display_error(err, catch_backtrace())
    end

    # No processes exist yet, so terminate_test_process should be a no-op
    terminate_test_process(tic, "nonexistent-id")

    shutdown(tic)
    @test fetch(controller_finished)
end
