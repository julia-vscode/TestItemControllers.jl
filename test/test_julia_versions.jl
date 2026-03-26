@testitem "Run tests on Julia 1.0" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.0"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.1" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.1"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.2" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.2"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.3" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.3"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.4" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.4"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.5" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.5"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.6" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.6"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.7" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.7"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.8" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.8"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.9" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.9"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.10" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.10"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.11" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.11"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end

@testitem "Run tests on Julia 1.12" tags=[:comprehensive_platform] setup=[TestHelpers] begin
    using TestItemControllers: JSON

    version = "1.12"
    config = try
        JSON.parse(read(`juliaup api getconfig1`, String))
    catch e
        error("Failed to query juliaup. Is juliaup installed? Error: $e")
    end
    installed_channels = Set{String}()
    push!(installed_channels, config["DefaultChannel"]["Name"])
    for ch in get(config, "OtherChannels", [])
        push!(installed_channels, ch["Name"])
    end
    version in installed_channels || error("Julia $version is not installed. Install it with: juliaup add $version")

    pkg_path = joinpath(TestHelpers.TESTDATA_DIR, "BasicPackage")
    discovered = TestHelpers.discover_test_items(pkg_path)

    target_labels = ("add works", "greet works", "failing test", "erroring test")
    items = filter(i -> i.label in target_labels, discovered.items)
    @test length(items) == 4

    result = TestHelpers.run_testrun(items, discovered.setups; julia_cmd="julia", julia_args=["+$version"], timeout=600)

    passed_events = filter(e -> e.event == :passed, result.events)
    failed_events = filter(e -> e.event == :failed, result.events)
    errored_events = filter(e -> e.event == :errored, result.events)
    skipped_events = filter(e -> e.event == :skipped, result.events)

    @test length(passed_events) == 2
    @test length(failed_events) == 1
    @test length(failed_events[1].messages) >= 1
    @test length(errored_events) == 1
    @test length(errored_events[1].messages) >= 1
    @test occursin("intentional error", errored_events[1].messages[1].message)
    @test length(skipped_events) == 0
end
