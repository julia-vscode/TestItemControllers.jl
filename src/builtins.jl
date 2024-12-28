# This file is generated by `generate_builtins.jl`. Do not edit by hand.

function getargs(args, frame)
    nargs = length(args)-1  # skip f
    callargs = resize!(frame.framedata.callargs, nargs)
    for i = 1:nargs
        callargs[i] = @lookup(frame, args[i+1])
    end
    return callargs
end

const kwinvoke = Core.kwfunc(Core.invoke)

function maybe_recurse_expanded_builtin(frame, new_expr)
    f = new_expr.args[1]
    if isa(f, Core.Builtin) || isa(f, Core.IntrinsicFunction)
        return maybe_evaluate_builtin(frame, new_expr, true)
    else
        return new_expr
    end
end

"""
    ret = maybe_evaluate_builtin(frame, call_expr, expand::Bool)

If `call_expr` is to a builtin function, evaluate it, returning the result inside a `Some` wrapper.
Otherwise, return `call_expr`.

If `expand` is true, `Core._apply_iterate` calls will be resolved as a call to the applied function.
"""
function maybe_evaluate_builtin(frame, call_expr, expand::Bool)
    args = call_expr.args
    nargs = length(args) - 1
    fex = args[1]
    if isa(fex, QuoteNode)
        f = fex.value
    else
        f = @lookup(frame, fex)
    end

    if @static isdefined(Core, :OpaqueClosure) && f isa Core.OpaqueClosure
        if expand
            if !Core.Compiler.uncompressed_ir(f.source).inferred
                return Expr(:call, f, args[2:end]...)
            else
                @debug "not interpreting opaque closure $f since it contains inferred code"
            end
        end
        return Some{Any}(f(args...))
    end
    if !(isa(f, Core.Builtin) || isa(f, Core.IntrinsicFunction))
        return call_expr
    end
    # By having each call appearing statically in the "switch" block below,
    # each gets call-site optimized.
    if f === <:
        if nargs == 2
            return Some{Any}(<:(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(<:(getargs(args, frame)...))
        end
    elseif f === ===
        if nargs == 2
            return Some{Any}(===(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(===(getargs(args, frame)...))
        end
    elseif f === Core._abstracttype
        return Some{Any}(Core._abstracttype(getargs(args, frame)...))
    elseif f === Core._apply_iterate
        argswrapped = getargs(args, frame)
        if !expand
            return Some{Any}(Core._apply_iterate(argswrapped...))
        end
        aw1 = argswrapped[1]::Function
        @assert aw1 === Core.iterate || aw1 === Core.Compiler.iterate || aw1 === Base.iterate "cannot handle `_apply_iterate` with non iterate as first argument, got $(aw1), $(typeof(aw1))"
        new_expr = Expr(:call, argswrapped[2])
        popfirst!(argswrapped) # pop the iterate
        popfirst!(argswrapped) # pop the function
        argsflat = append_any(argswrapped...)
        for x in argsflat
            push!(new_expr.args, QuoteNode(x))
        end
        return maybe_recurse_expanded_builtin(frame, new_expr)
    elseif f === Core._apply_pure
        return Some{Any}(Core._apply_pure(getargs(args, frame)...))
    elseif f === Core._call_in_world
        return Some{Any}(Core._call_in_world(getargs(args, frame)...))
    elseif @static isdefined(Core, :_call_in_world_total) && f === Core._call_in_world_total
        return Some{Any}(Core._call_in_world_total(getargs(args, frame)...))
    elseif f === Core._call_latest
        args = getargs(args, frame)
        if !expand
            return Some{Any}(Core._call_latest(args...))
        end
        new_expr = Expr(:call, args[1])
        popfirst!(args)
        for x in args
            push!(new_expr.args, QuoteNode(x))
        end
        return maybe_recurse_expanded_builtin(frame, new_expr)
    elseif @static isdefined(Core, :_compute_sparams) && f === Core._compute_sparams
        return Some{Any}(Core._compute_sparams(getargs(args, frame)...))
    elseif f === Core._equiv_typedef
        return Some{Any}(Core._equiv_typedef(getargs(args, frame)...))
    elseif f === Core._expr
        return Some{Any}(Core._expr(getargs(args, frame)...))
    elseif f === Core._primitivetype
        return Some{Any}(Core._primitivetype(getargs(args, frame)...))
    elseif f === Core._setsuper!
        return Some{Any}(Core._setsuper!(getargs(args, frame)...))
    elseif f === Core._structtype
        return Some{Any}(Core._structtype(getargs(args, frame)...))
    elseif @static isdefined(Core, :_svec_ref) && f === Core._svec_ref
        return Some{Any}(Core._svec_ref(getargs(args, frame)...))
    elseif f === Core._typebody!
        return Some{Any}(Core._typebody!(getargs(args, frame)...))
    elseif f === Core._typevar
        if nargs == 3
            return Some{Any}(Core._typevar(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(Core._typevar(getargs(args, frame)...))
        end
    elseif f === Core.apply_type
        return Some{Any}(Core.apply_type(getargs(args, frame)...))
    elseif @static isdefined(Core, :compilerbarrier) && f === Core.compilerbarrier
        if nargs == 2
            return Some{Any}(Core.compilerbarrier(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(Core.compilerbarrier(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :current_scope) && f === Core.current_scope
        if nargs == 0
            currscope = Core.current_scope()
            for scope in frame.framedata.current_scopes
                currscope = Scope(currscope, scope.values...)
            end
            return Some{Any}(currscope)
        else
            return Some{Any}(Core.current_scope(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :donotdelete) && f === Core.donotdelete
        return Some{Any}(Core.donotdelete(getargs(args, frame)...))
    elseif @static isdefined(Core, :finalizer) && f === Core.finalizer
        if nargs == 2
            return Some{Any}(Core.finalizer(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.finalizer(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.finalizer(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(Core.finalizer(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :get_binding_type) && f === Core.get_binding_type
        if nargs == 2
            return Some{Any}(Core.get_binding_type(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(Core.get_binding_type(getargs(args, frame)...))
        end
    elseif f === Core.ifelse
        if nargs == 3
            return Some{Any}(Core.ifelse(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(Core.ifelse(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryref_isassigned) && f === Core.memoryref_isassigned
        if nargs == 3
            return Some{Any}(Core.memoryref_isassigned(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(Core.memoryref_isassigned(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefget) && f === Core.memoryrefget
        if nargs == 3
            return Some{Any}(Core.memoryrefget(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(Core.memoryrefget(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefmodify!) && f === Core.memoryrefmodify!
        if nargs == 5
            return Some{Any}(Core.memoryrefmodify!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.memoryrefmodify!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefnew) && f === Core.memoryrefnew
        if nargs == 1
            return Some{Any}(Core.memoryrefnew(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.memoryrefnew(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.memoryrefnew(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.memoryrefnew(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.memoryrefnew(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.memoryrefnew(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefoffset) && f === Core.memoryrefoffset
        if nargs == 1
            return Some{Any}(Core.memoryrefoffset(@lookup(frame, args[2])))
        else
            return Some{Any}(Core.memoryrefoffset(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefreplace!) && f === Core.memoryrefreplace!
        if nargs == 6
            return Some{Any}(Core.memoryrefreplace!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6]), @lookup(frame, args[7])))
        else
            return Some{Any}(Core.memoryrefreplace!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefset!) && f === Core.memoryrefset!
        if nargs == 4
            return Some{Any}(Core.memoryrefset!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(Core.memoryrefset!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefsetonce!) && f === Core.memoryrefsetonce!
        if nargs == 5
            return Some{Any}(Core.memoryrefsetonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.memoryrefsetonce!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :memoryrefswap!) && f === Core.memoryrefswap!
        if nargs == 4
            return Some{Any}(Core.memoryrefswap!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(Core.memoryrefswap!(getargs(args, frame)...))
        end
    elseif f === Core.sizeof
        if nargs == 1
            return Some{Any}(Core.sizeof(@lookup(frame, args[2])))
        else
            return Some{Any}(Core.sizeof(getargs(args, frame)...))
        end
    elseif f === Core.svec
        return Some{Any}(Core.svec(getargs(args, frame)...))
    elseif @static isdefined(Core, :throw_methoderror) && f === Core.throw_methoderror
        return Some{Any}(Core.throw_methoderror(getargs(args, frame)...))
    elseif f === applicable
        return Some{Any}(applicable(getargs(args, frame)...))
    elseif f === fieldtype
        if nargs == 2
            return Some{Any}(fieldtype(@lookup(frame, args[2]), @lookup(frame, args[3]))::Type)
        elseif nargs == 3
            return Some{Any}(fieldtype(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]))::Type)
        else
            return Some{Any}(fieldtype(getargs(args, frame)...)::Type)
        end
    elseif f === getfield
        if nargs == 2
            return Some{Any}(getfield(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(getfield(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(getfield(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(getfield(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :getglobal) && f === getglobal
        if nargs == 2
            return Some{Any}(getglobal(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(getglobal(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(getglobal(getargs(args, frame)...))
        end
    elseif f === invoke
        if !expand
            argswrapped = getargs(args, frame)
            return Some{Any}(invoke(argswrapped...))
        end
        # This uses the original arguments to avoid looking them up twice
        # See #442
        return Expr(:call, invoke, args[2:end]...)
    elseif f === isa
        if nargs == 2
            return Some{Any}(isa(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(isa(getargs(args, frame)...))
        end
    elseif f === isdefined
        if nargs == 2
            return Some{Any}(isdefined(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(isdefined(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(isdefined(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :modifyfield!) && f === modifyfield!
        if nargs == 4
            return Some{Any}(modifyfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(modifyfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(modifyfield!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :modifyglobal!) && f === modifyglobal!
        if nargs == 4
            return Some{Any}(modifyglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(modifyglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(modifyglobal!(getargs(args, frame)...))
        end
    elseif f === nfields
        if nargs == 1
            return Some{Any}(nfields(@lookup(frame, args[2])))
        else
            return Some{Any}(nfields(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :replacefield!) && f === replacefield!
        if nargs == 4
            return Some{Any}(replacefield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(replacefield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        elseif nargs == 6
            return Some{Any}(replacefield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6]), @lookup(frame, args[7])))
        else
            return Some{Any}(replacefield!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :replaceglobal!) && f === replaceglobal!
        if nargs == 4
            return Some{Any}(replaceglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(replaceglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        elseif nargs == 6
            return Some{Any}(replaceglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6]), @lookup(frame, args[7])))
        else
            return Some{Any}(replaceglobal!(getargs(args, frame)...))
        end
    elseif f === setfield!
        if nargs == 3
            return Some{Any}(setfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(setfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(setfield!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :setfieldonce!) && f === setfieldonce!
        if nargs == 3
            return Some{Any}(setfieldonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(setfieldonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(setfieldonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(setfieldonce!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :setglobal!) && f === setglobal!
        if nargs == 3
            return Some{Any}(setglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(setglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(setglobal!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :setglobalonce!) && f === setglobalonce!
        if nargs == 3
            return Some{Any}(setglobalonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(setglobalonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(setglobalonce!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(setglobalonce!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :swapfield!) && f === swapfield!
        if nargs == 3
            return Some{Any}(swapfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(swapfield!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(swapfield!(getargs(args, frame)...))
        end
    elseif @static isdefined(Core, :swapglobal!) && f === swapglobal!
        if nargs == 3
            return Some{Any}(swapglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(swapglobal!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        else
            return Some{Any}(swapglobal!(getargs(args, frame)...))
        end
    elseif f === throw
        if nargs == 1
            return Some{Any}(throw(@lookup(frame, args[2])))
        else
            return Some{Any}(throw(getargs(args, frame)...))
        end
    elseif f === tuple
        return Some{Any}(ntupleany(i->@lookup(frame, args[i+1]), length(args)-1))
    elseif f === typeassert
        if nargs == 2
            return Some{Any}(typeassert(@lookup(frame, args[2]), @lookup(frame, args[3])))
        else
            return Some{Any}(typeassert(getargs(args, frame)...))
        end
    elseif f === typeof
        if nargs == 1
            return Some{Any}(typeof(@lookup(frame, args[2])))
        else
            return Some{Any}(typeof(getargs(args, frame)...))
        end
    # Intrinsics
    elseif f === Base.cglobal
        if nargs == 1
            call_expr = copy(call_expr)
            args2 = args[2]
            call_expr.args[2] = isa(args2, QuoteNode) ? args2 : @lookup(frame, args2)
            return Some{Any}(Core.eval(moduleof(frame), call_expr))
        elseif nargs == 2
            call_expr = copy(call_expr)
            args2 = args[2]
            call_expr.args[2] = isa(args2, QuoteNode) ? args2 : @lookup(frame, args2)
            call_expr.args[3] = @lookup(frame, args[3])
            return Some{Any}(Core.eval(moduleof(frame), call_expr))
        end
    elseif @static (isdefined(Core, :arrayref) && Core.arrayref isa Core.Builtin) && f === Core.arrayref
        if nargs == 1
            return Some{Any}(Core.arrayref(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.arrayref(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.arrayref(getargs(args, frame)...))
        end
    elseif @static (isdefined(Core, :arrayset) && Core.arrayset isa Core.Builtin) && f === Core.arrayset
        if nargs == 1
            return Some{Any}(Core.arrayset(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        elseif nargs == 6
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6]), @lookup(frame, args[7])))
        else
            return Some{Any}(Core.arrayset(getargs(args, frame)...))
        end
    elseif @static (isdefined(Core, :arrayset) && Core.arrayset isa Core.Builtin) && f === Core.arrayset
        if nargs == 1
            return Some{Any}(Core.arrayset(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        elseif nargs == 6
            return Some{Any}(Core.arrayset(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6]), @lookup(frame, args[7])))
        else
            return Some{Any}(Core.arrayset(getargs(args, frame)...))
        end
    elseif @static (isdefined(Core, :const_arrayref) && Core.const_arrayref isa Core.Builtin) && f === Core.const_arrayref
        if nargs == 1
            return Some{Any}(Core.const_arrayref(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.const_arrayref(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.const_arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.const_arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.const_arrayref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.const_arrayref(getargs(args, frame)...))
        end
    elseif @static (isdefined(Core, :memoryref) && Core.memoryref isa Core.Builtin) && f === Core.memoryref
        if nargs == 1
            return Some{Any}(Core.memoryref(@lookup(frame, args[2])))
        elseif nargs == 2
            return Some{Any}(Core.memoryref(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.memoryref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        elseif nargs == 4
            return Some{Any}(Core.memoryref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5])))
        elseif nargs == 5
            return Some{Any}(Core.memoryref(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4]), @lookup(frame, args[5]), @lookup(frame, args[6])))
        else
            return Some{Any}(Core.memoryref(getargs(args, frame)...))
        end
    elseif @static (isdefined(Core, :set_binding_type!) && Core.set_binding_type! isa Core.Builtin) && f === Core.set_binding_type!
        if nargs == 2
            return Some{Any}(Core.set_binding_type!(@lookup(frame, args[2]), @lookup(frame, args[3])))
        elseif nargs == 3
            return Some{Any}(Core.set_binding_type!(@lookup(frame, args[2]), @lookup(frame, args[3]), @lookup(frame, args[4])))
        else
            return Some{Any}(Core.set_binding_type!(getargs(args, frame)...))
        end
    elseif f === Core.Intrinsics.llvmcall
        return Some{Any}(Core.Intrinsics.llvmcall(getargs(args, frame)...))
    end
    if isa(f, Core.IntrinsicFunction)
        cargs = getargs(args, frame)
        @static if isdefined(Core.Intrinsics, :have_fma)
            if f === Core.Intrinsics.have_fma && length(cargs) == 1
                cargs1 = cargs[1]
                if cargs1 == Float64
                    return Some{Any}(FMA_FLOAT64[])
                elseif cargs1 == Float32
                    return Some{Any}(FMA_FLOAT32[])
                elseif cargs1 == Float16
                    return Some{Any}(FMA_FLOAT16[])
                end
            end
        end
        if f === Core.Intrinsics.muladd_float && length(cargs) == 3
            a, b, c = cargs
            Ta, Tb, Tc = typeof(a), typeof(b), typeof(c)
            if !(Ta == Tb == Tc)
                error("muladd_float: types of a, b, and c must match")
            end
            if Ta == Float64 && FMA_FLOAT64[]
                f = Core.Intrinsics.fma_float
            elseif Ta == Float32 && FMA_FLOAT32[]
                f = Core.Intrinsics.fma_float
            elseif Ta == Float16 && FMA_FLOAT16[]
                f = Core.Intrinsics.fma_float
            end
        end
        return Some{Any}(ccall(:jl_f_intrinsic_call, Any, (Any, Ptr{Any}, UInt32), f, cargs, length(cargs)))
    end
    if isa(f, typeof(kwinvoke))
        return Some{Any}(kwinvoke(getargs(args, frame)...))
    end
    return call_expr
end
