# A typed view of one event file, for bulk edits (edit.jl) and terminal cards (render/term.jl). The rest of the package
# works on the parsed JSON objects. Every field type is concrete (optional ones are `Union{Nothing,T}`), and keys are
# matched to fields by `if` chains generated per struct rather than by lenses built from strings, so this code can be
# compiled with `juliac --trim`. Fields follow schema/tango-event.schema.json; `test/runtests.jl` checks that they match.
StructUtils.@kwarg struct Venue
 name::Union{Nothing,String}=nothing
 address::Union{Nothing,String}=nothing
 city::Union{Nothing,String}=nothing
end
StructUtils.@kwarg struct Video
 platform::String="youtube"
 id::String=""
end
StructUtils.@kwarg struct Translation
 title::Union{Nothing,String}=nothing
 description::Union{Nothing,String}=nothing
end
StructUtils.@kwarg struct Translations
 nb::Union{Nothing,Translation}=nothing
 en::Union{Nothing,Translation}=nothing
 es::Union{Nothing,Translation}=nothing
end
# The schema allows a missing language or text, but not a null one.
JSON.omit_null(::Type{Translation})=true
JSON.omit_null(::Type{Translations})=true
"""
    Event

One event as a struct. JSON keys are the field names, except `\$schema` (field `schema`) and `end` (field `end_`).
Read and write files with `read_event`/`write_event`; change fields with `set_path`.
"""
StructUtils.@kwarg struct Event
 schema::Union{Nothing,String}=nothing & (json=(name="\$schema",),)
 id::String=""
 title::String=""
 types::Vector{String}=String[]
 status::Union{Nothing,String}=nothing
 series::Union{Nothing,String}=nothing
 start::String=""
 end_::Union{Nothing,String}=nothing & (json=(name="end",),)
 venue::Union{Nothing,Venue}=nothing
 organizer::Union{Nothing,String}=nothing
 dj::Union{Nothing,String}=nothing
 teachers::Union{Nothing,Vector{String}}=nothing
 music_style::Union{Nothing,Vector{String}}=nothing
 price_nok::Union{Nothing,Int}=nothing
 student_price_nok::Union{Nothing,Int}=nothing
 class_price_nok::Union{Nothing,Int}=nothing
 description::Union{Nothing,String}=nothing
 lang::Union{Nothing,String}=nothing
 translations::Union{Nothing,Translations}=nothing
 flyer_url::Union{Nothing,String}=nothing
 video::Union{Nothing,Video}=nothing
 link::Union{Nothing,String}=nothing
 source::Union{Nothing,String}=nothing
 source_url::Union{Nothing,String}=nothing
 published_date::Union{Nothing,String}=nothing
 first_seen::Union{Nothing,String}=nothing
 last_verified::Union{Nothing,String}=nothing
 crawl_timestamp::Union{Nothing,String}=nothing
 confidence::Union{Nothing,Float64}=nothing
end
const _Record=Union{Event,Venue,Video,Translation,Translations}
_jsonname(f::Symbol)=f===:schema ? "\$schema" : f===:end_ ? "end" : String(f)
"JSON keys of a record type, in field order."
jsonkeys(::Type{T}) where {T<:_Record}=[_jsonname(f) for f in fieldnames(T)]
"""
    _withfield(f, x, key) -> f(value)

Call `f` on the field of `x` named `key` (a JSON key). The generated `if` chain gives each call a concrete field
type. Throws `ArgumentError` for an unknown key.
"""
@generated function _withfield(f, x::T, key::AbstractString) where {T<:_Record}
 body=:(throw(ArgumentError("unknown key \"$key\" (valid: $(join(jsonkeys($T),", ")))")))
 for n in reverse(fieldnames(T))
  body=:(key==$(_jsonname(n)) ? f(getfield(x,$(QuoteNode(n)))) : $body)
 end
 body
end
"""
    _setfield(f, x, key) -> copy of `x`

`x` with the field named `key` replaced by `f(old_value, Val(FieldType))`, through an `Accessors.PropertyLens`.
(`Val`, because a closure isn't specialised on a plain `Type` argument, and a trimmed build needs that.)
"""
@generated function _setfield(f, x::T, key::AbstractString) where {T<:_Record}
 body=:(throw(ArgumentError("unknown key \"$key\" (valid: $(join(jsonkeys($T),", ")))")))
 for (n,FT) in reverse(collect(zip(fieldnames(T),fieldtypes(T))))
  body=:(key==$(_jsonname(n)) ? Accessors.set(x,Accessors.PropertyLens{$(QuoteNode(n))}(),f(getfield(x,$(QuoteNode(n))),Val{$FT}())) : $body)
 end
 body
end
"""
The value `raw` converted to type `T`: read as JSON (`250`, `null`, `["a","b"]`, `"text"`), or, when that does not
give a `T`, taken as plain text if `T` holds text (so `title=250` is the title «250»). `ArgumentError` otherwise.
"""
function _convert(::Val{T}, raw::AbstractString) where {T}
 try return JSON.parse(raw,T)::T catch err; err isa InterruptException && rethrow() end
 raw=="null" && throw(ArgumentError("this key cannot be null"))
 String<:T && return String(raw)::T
 throw(ArgumentError("$(repr(raw)) is not a valid $(_typename(T))"))
end
_typename(::Type{Union{Nothing,T}}) where {T}="$(_typename(T)) or null"
_typename(::Type{String})="text"
_typename(::Type{Int})="whole number"
_typename(::Type{Float64})="number"
_typename(::Type{Vector{String}})="list of texts, e.g. [\"a\",\"b\"]"
_typename(::Type{T}) where {T}="object ($(join(jsonkeys(T),", ")))"
"""
    set_path(x, path, raw) -> copy of `x`

Set the field at `path` (JSON keys, e.g. `["venue","name"]`) to `raw`, read as JSON or else as plain text and
converted to the field's type. A null object on the way is created first (setting `venue.name` on an event without
a venue gives a venue with only a name).
"""
function set_path(x::_Record, path::AbstractVector{<:AbstractString}, raw::AbstractString)
 isempty(path) && throw(ArgumentError("empty key"))
 _set1(x,String[String(p) for p in path],String(raw))
end
# One function per nesting level (Event → Translations → Translation is the deepest) instead of recursion, which
# inference can't follow through the generated `_setfield`, so a trimmed build would fail.
for (f,inner,next) in ((:_set1,:_inner1,:_set2),(:_set2,:_inner2,:_set3),(:_set3,:_inner3,:_too_deep))
 @eval function $f(x::_Record, path::Vector{String}, raw::String)
  length(path)==1 && return _setfield((_,ft)->_convert(ft,raw),x,path[1])
  key=path[1]; rest=path[2:end]
  _setfield((v,ft)->$inner(v,ft,rest,raw,key),x,key)
 end
 @eval $inner(v::_Record,FT,rest::Vector{String},raw::String,key::String)=$next(v,rest,raw)
 @eval $inner(::Nothing,::Val{Union{Nothing,R}},rest::Vector{String},raw::String,key::String) where {R<:_Record}=$next(R(),rest,raw)
 @eval $inner(v,FT,rest::Vector{String},raw::String,key::String)=throw(ArgumentError("\"$key\" is not an object, so \"$key.$(join(rest,"."))\" cannot be set"))
end
_too_deep(x,path::Vector{String},raw::String)=throw(ArgumentError("no key is nested that deep: $(join(path,"."))"))
"The value at `path` as compact JSON (`null` when a parent is null)."
function path_json(x::_Record, path::AbstractVector{<:AbstractString})
 length(path)==1 && return _withfield(JSON.json,x,path[1])
 rest=path[2:end]
 _withfield(v->_inner_json(v,rest,path[1]),x,path[1])
end
_inner_json(v::_Record,rest,key)=path_json(v,rest)
_inner_json(::Nothing,rest,key)="null"
_inner_json(v,rest,key)=throw(ArgumentError("\"$key\" is not an object"))
"""
    read_event(file) -> (event::Event, keys::Vector{String})

One event file as an `Event`, plus its keys in file order (so `write_event` can keep the order and the absent keys).
Throws `ArgumentError` for keys the schema does not know.
"""
read_event(file::AbstractString)=parse_event(read(file,String);file)
function parse_event(text::AbstractString; file="event")
 keys_=String[String(k) for k in keys(JSON.parse(text,JSON.Object{String,Any}))]
 known=jsonkeys(Event); bad=filter(!in(known),keys_)
 isempty(bad) || throw(ArgumentError("$file: unknown key(s) $(join(bad,", "))"))
 (JSON.parse(text,Event),keys_)
end
"""
    write_event(io, e, keys)

Write `e` as `save_events` does (4-space indent, trailing newline): first the keys in `keys` (the order the file
had), then any other field that is not null. A file read with `read_event` and written back unchanged is identical.
"""
function write_event(io::IO, e::Event, keys_::AbstractVector{<:AbstractString}=jsonkeys(Event))
 ks=String[String(k) for k in keys_]
 for k in jsonkeys(Event); k in ks || _withfield(isnothing,e,k) || push!(ks,k); end
 print(io,"{\n")
 for (i,k) in enumerate(ks)
  v=_withfield(x->JSON.json(x,4),e,k)
  print(io,"    ",JSON.json(k),": ",replace(v,"\n"=>"\n    "),i<length(ks) ? ",\n" : "\n")
 end
 print(io,"}\n")
end
event_text(e::Event, keys_=jsonkeys(Event))=sprint(write_event,e,keys_)
"Plain-JSON form of `e` (an ordered `JSON.Object`), for the Dict-based functions (`validate_event`, renderers)."
event_dict(e::Event, keys_=jsonkeys(Event))=JSON.parse(event_text(e,keys_))
"`n` as two digits («07»); `lpad` can't be trimmed."
_two(n::Integer)=n<10 ? "0$n" : string(n)
"`s` padded with spaces to `n` columns (`rpad` by text width can't be trimmed)."
_pad(s::AbstractString,n::Integer)=(io=IOBuffer(); print(io,s); for _ in textwidth(s)+1:n; print(io,' '); end; String(take!(io)))
"The date at the start of `s` (`YYYY-MM-DD…`), or `nothing`. Parsed by hand, since Dates' string parsing can't be trimmed."
function _ymd(s::AbstractString)
 m=match(r"^([0-9]{4})-([0-9]{2})-([0-9]{2})",s); isnothing(m) && return nothing
 y=parse(Int,something(m[1])); mo=parse(Int,something(m[2])); d=parse(Int,something(m[3]))
 1<=mo<=12 && 1<=d<=daysinmonth(y,mo) ? Date(y,mo,d) : nothing
end
const _ID=r"^[a-z0-9][a-z0-9-]*$"
const _STAMP=r"^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2}))?$"
const _DAY=r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
"""
    check(e::Event) -> problems

The schema rules for one event, checked on the struct (no JSONSchema, so it compiles trimmed). The app also runs the
full `validate_event_tree`.
"""
function check(e::Event)
 p=String[]; bad(k,v,what)=push!(p,"$k: $(JSON.json(v)) $what")
 occursin(_ID,e.id) || bad("id",e.id,"must be lowercase letters, digits and dashes")
 isempty(e.title) && bad("title",e.title,"must not be empty")
 isempty(e.types) && bad("types",e.types,"needs at least one type")
 for t in e.types; t in TYPE_ORDER || bad("types",t,"is not one of $(join(TYPE_ORDER,", "))"); end
 allunique(e.types) || bad("types",e.types,"has duplicates")
 e.status in (nothing,"scheduled","cancelled") || bad("status",e.status,"must be scheduled, cancelled or null")
 isnothing(e.series) || occursin(_ID,e.series) || bad("series",e.series,"must be lowercase letters, digits and dashes")
 occursin(_STAMP,e.start) && !isnothing(_ymd(e.start)) || bad("start",e.start,"must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS+01:00")
 for (k,v) in (("end",e.end_),("crawl_timestamp",e.crawl_timestamp))
  isnothing(v) || occursin(_STAMP,v) || bad(k,v,"must be YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS+01:00")
 end
 for (k,v) in (("published_date",e.published_date),("first_seen",e.first_seen),("last_verified",e.last_verified))
  isnothing(v) || occursin(_DAY,v) || bad(k,v,"must be YYYY-MM-DD")
 end
 for (k,v) in (("flyer_url",e.flyer_url),("link",e.link),("source_url",e.source_url))
  isnothing(v) || occursin(r"^https?://",v) || bad(k,v,"must start with http:// or https://")
 end
 for (k,v) in (("price_nok",e.price_nok),("student_price_nok",e.student_price_nok),("class_price_nok",e.class_price_nok))
  isnothing(v) || v>=0 || bad(k,v,"must not be negative")
 end
 e.lang in (nothing,"nb","en") || bad("lang",e.lang,"must be nb, en or null")
 if !isnothing(e.music_style)
  for m in e.music_style; haskey(_MUSIC,m) || bad("music_style",m,"is not one of $(join(sort(collect(keys(_MUSIC))),", "))"); end
  allunique(e.music_style) || bad("music_style",e.music_style,"has duplicates")
 end
 if !isnothing(e.translations)
  for (l,t) in (("nb",e.translations.nb),("en",e.translations.en),("es",e.translations.es))
   isnothing(t) || !(isnothing(t.title) && isnothing(t.description)) || push!(p,"translations.$l: needs a title or a description")
  end
 end
 v=e.video
 if !isnothing(v)
  v.platform in ("youtube","vimeo") || bad("video.platform",v.platform,"must be youtube or vimeo")
  v.platform=="youtube" && !occursin(r"^[A-Za-z0-9_-]{11}$",v.id) && bad("video.id",v.id,"is not a YouTube id")
 end
 isnothing(e.confidence) || 0<=e.confidence<=1 || bad("confidence",e.confidence,"must be between 0 and 1")
 p
end
