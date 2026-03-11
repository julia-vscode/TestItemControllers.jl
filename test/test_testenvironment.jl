@testitem "TestEnvironment equality" begin
    using TestItemControllers: TestEnvironment

    env1 = TestEnvironment(
        "file:///project",
        "file:///package",
        "MyPkg",
        "julia",
        String[],
        missing,
        "Run",
        Dict{String,Union{String,Nothing}}()
    )
    env2 = TestEnvironment(
        "file:///project",
        "file:///package",
        "MyPkg",
        "julia",
        String[],
        missing,
        "Run",
        Dict{String,Union{String,Nothing}}()
    )

    @test env1 == env2
    @test isequal(env1, env2)
end

@testitem "TestEnvironment inequality" begin
    using TestItemControllers: TestEnvironment

    env1 = TestEnvironment(
        "file:///project",
        "file:///package",
        "MyPkg",
        "julia",
        String[],
        missing,
        "Run",
        Dict{String,Union{String,Nothing}}()
    )
    env_diff_mode = TestEnvironment(
        "file:///project",
        "file:///package",
        "MyPkg",
        "julia",
        String[],
        missing,
        "Coverage",
        Dict{String,Union{String,Nothing}}()
    )
    env_diff_pkg = TestEnvironment(
        "file:///project",
        "file:///other",
        "OtherPkg",
        "julia",
        String[],
        missing,
        "Run",
        Dict{String,Union{String,Nothing}}()
    )

    @test env1 != env_diff_mode
    @test env1 != env_diff_pkg
    @test !isequal(env1, env_diff_mode)
end

@testitem "TestEnvironment hashing" begin
    using TestItemControllers: TestEnvironment

    env1 = TestEnvironment(nothing, "file:///pkg", "Pkg", "julia", String[], missing, "Run", Dict{String,Union{String,Nothing}}())
    env2 = TestEnvironment(nothing, "file:///pkg", "Pkg", "julia", String[], missing, "Run", Dict{String,Union{String,Nothing}}())
    env3 = TestEnvironment(nothing, "file:///pkg", "Pkg", "julia", String[], missing, "Coverage", Dict{String,Union{String,Nothing}}())

    @test hash(env1) == hash(env2)
    @test hash(env1) != hash(env3)
end

@testitem "TestEnvironment as Dict key" begin
    using TestItemControllers: TestEnvironment

    env1 = TestEnvironment(nothing, "file:///pkg", "Pkg", "julia", String[], missing, "Run", Dict{String,Union{String,Nothing}}())
    env2 = TestEnvironment(nothing, "file:///pkg", "Pkg", "julia", String[], missing, "Run", Dict{String,Union{String,Nothing}}())

    d = Dict{TestEnvironment,Int}()
    d[env1] = 42
    @test d[env2] == 42
    @test length(d) == 1
end
