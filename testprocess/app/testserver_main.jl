@info "Starting the Julia Test Server"

import Pkg
version_specific_env_path = joinpath(@__DIR__, "../environments", "v$(VERSION.major).$(VERSION.minor)")
if isdir(version_specific_env_path)
    Pkg.activate(version_specific_env_path, io=devnull)
else
    Pkg.activate(joinpath(@__DIR__, "../environments", "fallback"), io=devnull)
end

let
    has_error_handler = false

    try

        if length(ARGS) > 2
            include(ARGS[3])
            has_error_handler = true
        end

        using TestItemServer

        TestItemServer.serve(
            ARGS[1],
            ARGS[2],
            has_error_handler ? (err, bt) -> global_err_handler(err, bt, Base.ARGS[4], "Test Process") : nothing)
    catch err
        bt = catch_backtrace()
        if has_error_handler
            global_err_handler(err, bt, Base.ARGS[4], "Test Process")
        else
            Base.display_error(err, bt)
        end
    end
end
