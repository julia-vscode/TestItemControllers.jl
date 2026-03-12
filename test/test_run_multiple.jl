@testitem "Run multiple test items" setup=[TestHelpers] begin
    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    # Use all 4 test items: 2 passing, 1 failing, 1 erroring
    @test length(discovered.items) >= 4

    result = TestHelpers.run_testrun(discovered.items, discovered.setups)

    started_events = filter(e -> e.event == :started, result.events)
    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)

    # Every item should have a started event
    @test length(started_events) == length(discovered.items)

    # 2 passing ("add works", "greet works"), 1 failing, 1 erroring
    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(errored_events) == 1

    # Total events for items should match
    total_completed = length(passed_events) + length(failed_events) + length(errored_events)
    @test total_completed == length(discovered.items)
end
