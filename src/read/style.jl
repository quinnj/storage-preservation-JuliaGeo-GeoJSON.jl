"""
    GeoJSONStyle <: JSON.JSONStyle

Style shared by every GeoJSON `StructUtils.make` and `applyeach` method. `JSON.parse` wraps it
in a `JSON.JSONReadStyle`, so the methods dispatch on the abstract `JSON.JSONStyle`. On the
write side it closes the set of value types: a foreign-member or property value the reader
never stores is an error rather than a dynamic `lower` call, so `write` builds under
`juliac --trim=safe`.
"""
struct GeoJSONStyle <: JSON.JSONStyle end

@noinline _badvalue() = throw(ArgumentError(
    "a foreign member or property value must be null, missing, Bool, Int64, Float64, BigInt, BigFloat, String, Vector{Any}, JSON.Object{String,Any} or Dict{String,Any}, as `read` stores them"))
JSON.applyany(::GeoJSONStyle, f, key, value) = _badvalue()

using JSON: LazyValue, LazyValues, PtrString, JSONTypes,
            getbuf, getpos, gettype, getopts, getlength, getbyte,
            applyobject, applyarray, parsestring
using StructUtils: EarlyReturn

const OBJECT = JSONTypes.OBJECT
const ARRAY = JSONTypes.ARRAY
const NULL = JSONTypes.NULL
const STRING = JSONTypes.STRING
const NUMBER = JSONTypes.NUMBER

@noinline _notobject(what::String) = throw(ArgumentError("expected a JSON object for $what"))
@noinline _notype(what::String) = throw(ArgumentError("$what has no \"type\" member"))
@noinline _wrongtype(expected::String, got::PtrString) =
    throw(ArgumentError("expected \"type\": \"$expected\", got \"$(convert(String, got))\""))

# Materializes one foreign member the way untyped `JSON.parse` would, returning the end
# position so the enclosing `applyobject` never walks the value twice.
function _extra!(st, extras::Extras, k::PtrString, v::LazyValues)
    val, pos = StructUtils.make(st, Any, v)
    out = extras === nothing ? Pair{String,Any}[] : extras
    push!(out, Pair{String,Any}(convert(String, k), val))
    return out, pos
end

# `applyarray` directly rather than `make(st, Vector{F}, v)`: the generic array path also
# compiles JSON's object branch for the array closure, which the trim verifier cannot resolve.
function readarray(st, ::Type{E}, v::LazyValues) where {E}
    out = E[]
    pos = applyarray(v) do _, e
        val, p = StructUtils.make(st, E, e)
        push!(out, val)
        return p
    end
    return out, pos::Int
end
