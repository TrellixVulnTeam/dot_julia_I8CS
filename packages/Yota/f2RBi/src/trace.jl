########################################################################
#                       SETTING THE SCENE                              #
########################################################################

Cassette.@context TraceCtx

# allow assiciation of Int values with TraceCtx
Cassette.metadatatype(::Type{<:TraceCtx}, ::DataType) = Int
Cassette.hastagging(::Type{<:TraceCtx}) = true


const PRIMITIVES = Set([
    *, /, +, -, sin, cos, sum, Base._sum,
    println,
    Base.getproperty, Base.getfield,
    broadcast, Broadcast.materialize, Broadcast.broadcasted])



########################################################################
#                               TRACE                                  #
########################################################################

struct TapeBox
    tape::Tape
    primitives::Set{Any}
end


"""
Trace function execution using provided arguments.
Returns calculated value and a tape.

```
foo(x) = 2.0x + 1.0
val, tape = trace(foo, 4.0)
```
"""
function trace(f, args...; primitives=PRIMITIVES, optimize=true)
    # create tape
    tape = Tape(guess_device(args))
    box = TapeBox(tape, primitives)
    ctx = enabletagging(TraceCtx(metadata=box), f)
    tagged_args = Vector(undef, length(args))
    for (i, x) in enumerate(args)
        id = record!(tape, Input, x)
        tagged_args[i] = tag(x, ctx, i)
    end
    # trace f with tagged arguments
    tagged_val = overdub(ctx, f, tagged_args...)
    val = untag(tagged_val, ctx)
    tape.resultid = metadata(tagged_val, ctx)
    if optimize
        tape = simplify(tape)
    end
    return val, tape
end


function with_free_args_as_constants(ctx::TraceCtx, tape::Tape, args)
    new_args = []
    for x in args
        if istagged(x, ctx)
            push!(new_args, x)
        else
            # x = x isa Function ? device_function(ctx.metadata.tape.device, x) : x
            id = record!(tape, Constant, x)
            x = tag(x, ctx, id)
            push!(new_args, x)
        end
    end
    return new_args
end


function Cassette.overdub(ctx::TraceCtx, f, args...)
    args_str = join([a isa Nothing ? "nothing" : a for a in args], ", ")
    tape = ctx.metadata.tape
    primitives = ctx.metadata.primitives
    # @info "$f($args...)"
    if f in primitives
        args = with_free_args_as_constants(ctx, tape, args)
        arg_ids = [metadata(x, ctx) for x in args]
        arg_ids = Int[id isa Cassette.NoMetaData ? -1 : id for id in arg_ids]
        # execute call
        retval = fallback(ctx, f, [untag(x, ctx) for x in args]...)
        # record to the tape and tag with a newly created ID
        ret_id = record!(tape, Call, retval, f, arg_ids)
        retval = tag(retval, ctx, ret_id)
    elseif canrecurse(ctx, f, args...)
        retval = Cassette.recurse(ctx, f, args...)
    else
        retval = fallback(ctx, f, args...)
    end
    return retval
end
