@testitem "Coverage collection" setup=[TestHelpers] begin
    # Coverage mode requires Julia >= 1.11
    if VERSION < v"1.11"
        @test_skip "Coverage mode requires Julia 1.11+"
    else
        using TestItemControllers: filepath2uri

        pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
        discovered = TestHelpers.discover_test_items(pkg_path)

        passing_items = filter(i -> i.label == "add works", discovered.items)
        @test length(passing_items) == 1

        coverage_root = filepath2uri(joinpath(pkg_path, "src"))

        result = TestHelpers.run_testrun(
            passing_items, discovered.setups;
            mode="Coverage",
            coverage_root_uris=[coverage_root]
        )

        passed_events = filter(e -> e.event == :passed, result.events)
        @test length(passed_events) == 1

        # Coverage data should be returned
        @test result.coverage !== missing
    end
end
