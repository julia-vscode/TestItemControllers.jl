include("../../../packages/TestEnv/src/TestEnv.jl")
include("../../../packages/URIParser/src/URIParser.jl")
include("../../../packages/JSON/src/JSON.jl")
if VERSION >= v"1.6.0"
    include("../../../packages/OrderedCollections/src/OrderedCollections.jl")
else
    include("../../../packages-old/v1.5/OrderedCollections/src/OrderedCollections.jl")
end
include("../../../packages/CodeTracking/src/CodeTracking.jl")
include("../../../packages/CoverageTools/src/CoverageTools.jl")
include("../../../packages/IOCapture/src/IOCapture.jl")
include("../../../packages/CancellationTokens/src/CancellationTokens.jl")

module JSONRPC
import ..CancellationTokens
import ..JSON
import UUIDs
include("../../../packages/JSONRPC/src/packagedef.jl")
end

module JuliaInterpreter
    using ..CodeTracking

    @static if VERSION >= v"1.10.0"
        include("../../../packages/JuliaInterpreter/src/packagedef.jl")
    elseif VERSION >= v"1.6.0"
        include("../../../packages-old/v1.9/JuliaInterpreter/src/packagedef.jl")
    else
        include("../../../packages-old/v1.5/JuliaInterpreter/src/packagedef.jl")
    end
end

module LoweredCodeUtils
    using ..JuliaInterpreter
    using ..JuliaInterpreter: SSAValue, SlotNumber, Frame
    using ..JuliaInterpreter: @lookup, moduleof, pc_expr, step_expr!, is_global_ref, is_quotenode_egal, whichtt,
        next_until!, finish_and_return!, get_return, nstatements, codelocation, linetable,
        is_return, lookup_return

    @static if VERSION >= v"1.10.0"
        include("../../../packages/LoweredCodeUtils/src/packagedef.jl")
    elseif VERSION >= v"1.6.0"
        include("../../../packages-old/v1.9/LoweredCodeUtils/src/packagedef.jl")
    else
        include("../../../packages-old/v1.5/LoweredCodeUtils/src/packagedef.jl")
    end
end

module Revise
    using ..OrderedCollections
    using ..LoweredCodeUtils
    using ..CodeTracking
    using ..JuliaInterpreter
    using ..CodeTracking: PkgFiles, basedir, srcfiles, line_is_decl, basepath
    using ..JuliaInterpreter: whichtt, is_doc_expr, step_expr!, finish_and_return!, get_return,
        @lookup, moduleof, scopeof, pc_expr, is_quotenode_egal,
        linetable, codelocs, LineTypes, isassign, isidentical
    using ..LoweredCodeUtils: next_or_nothing!, trackedheads, callee_matches

    @static if VERSION >= v"1.10.0"
        include("../../../packages/Revise/src/packagedef.jl")
    elseif VERSION >= v"1.6.0"
        include("../../../packages-old/v1.9/Revise/src/packagedef.jl")
    else
        include("../../../packages-old/v1.5/Revise/src/packagedef.jl")
    end
end

module DebugAdapter
    import Pkg
    import ..JuliaInterpreter
    import ..JSON

    include("../../../packages/DebugAdapter/src/packagedef.jl")
end
