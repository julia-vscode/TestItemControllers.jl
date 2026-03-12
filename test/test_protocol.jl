@testitem "TestMessage round-trip" begin
    using TestItemControllers: TestItemControllerProtocol, JSON

    msg = TestItemControllerProtocol.TestMessage(
        message = "Test failed",
        expectedOutput = "1",
        actualOutput = "2",
        uri = "file:///test.jl",
        line = 10,
        column = 5
    )

    json_str = JSON.json(msg)
    parsed = JSON.parse(json_str)
    msg2 = TestItemControllerProtocol.TestMessage(parsed)

    @test msg2.message == "Test failed"
    @test msg2.expectedOutput == "1"
    @test msg2.actualOutput == "2"
    @test msg2.uri == "file:///test.jl"
    @test msg2.line == 10
    @test msg2.column == 5
end

@testitem "TestMessage with missing fields" begin
    using TestItemControllers: TestItemControllerProtocol, JSON

    msg = TestItemControllerProtocol.TestMessage(
        message = "Error occurred",
        expectedOutput = missing,
        actualOutput = missing,
        uri = missing,
        line = missing,
        column = missing
    )

    json_str = JSON.json(msg)
    parsed = JSON.parse(json_str)
    msg2 = TestItemControllerProtocol.TestMessage(parsed)

    @test msg2.message == "Error occurred"
    @test ismissing(msg2.expectedOutput)
    @test ismissing(msg2.actualOutput)
end

@testitem "TestItemDetail round-trip" begin
    using TestItemControllers: TestItemControllerProtocol, JSON

    item = TestItemControllerProtocol.TestItemDetail(
        id = "item-1",
        uri = "file:///test.jl",
        label = "my test",
        packageName = "MyPkg",
        packageUri = "file:///mypkg",
        projectUri = missing,
        envContentHash = "abc123",
        useDefaultUsings = true,
        testSetups = ["Setup1"],
        line = 1,
        column = 1,
        code = "@test true",
        codeLine = 2,
        codeColumn = 5
    )

    json_str = JSON.json(item)
    parsed = JSON.parse(json_str)
    item2 = TestItemControllerProtocol.TestItemDetail(parsed)

    @test item2.id == "item-1"
    @test item2.label == "my test"
    @test item2.packageName == "MyPkg"
    @test ismissing(item2.projectUri)
    @test item2.useDefaultUsings == true
    @test item2.testSetups == ["Setup1"]
    @test item2.code == "@test true"
end

@testitem "FileCoverage round-trip" begin
    using TestItemControllers: TestItemControllerProtocol, JSON

    fc = TestItemControllerProtocol.FileCoverage(
        uri = "file:///src/myfile.jl",
        coverage = [1, 0, nothing, 3, nothing]
    )

    json_str = JSON.json(fc)
    parsed = JSON.parse(json_str)
    fc2 = TestItemControllerProtocol.FileCoverage(parsed)

    @test fc2.uri == "file:///src/myfile.jl"
    @test fc2.coverage == [1, 0, nothing, 3, nothing]
end

@testitem "CreateTestRunParams round-trip" begin
    using TestItemControllers: TestItemControllerProtocol, JSON

    params = TestItemControllerProtocol.CreateTestRunParams(
        testRunId = "run-1",
        testProfiles = [
            TestItemControllerProtocol.TestProfile(
                id = "prof-1",
                label = "Default",
                juliaCmd = "julia",
                juliaArgs = String[],
                juliaNumThreads = missing,
                juliaEnv = Dict{String,Union{String,Nothing}}(),
                maxProcessCount = 1,
                mode = "Run",
                coverageRootUris = missing
            )
        ],
        testItems = TestItemControllerProtocol.TestItemDetail[],
        testSetups = TestItemControllerProtocol.TestSetupDetail[]
    )

    json_str = JSON.json(params)
    parsed = JSON.parse(json_str)
    params2 = TestItemControllerProtocol.CreateTestRunParams(parsed)

    @test params2.testRunId == "run-1"
    @test length(params2.testProfiles) == 1
    @test params2.testProfiles[1].mode == "Run"
end
