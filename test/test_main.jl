@testitem "TestItemController run and shutdown" begin
    tic = TestItemController(log_level=:Debug)

    finished = Channel(1)

    @async try
        run(tic)

        put!(finished, true)
    catch err
        Base.display_error(err, catch_backtrace())
    end

    shutdown(tic)

    @test fetch(finished)
end
