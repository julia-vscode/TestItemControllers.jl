@testitem "TestItemController run and shutdown" begin
    tic = TestItemController()

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
