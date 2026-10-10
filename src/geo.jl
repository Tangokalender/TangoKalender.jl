# Coordinates for maps. Events only store address text; `venues.json` (repo root) caches address → lat/lon, filled by
# `tangokalender geocode` from OpenStreetMap Nominatim (at most one request per second, identifying User-Agent, see
# https://operations.osmfoundation.org/policies/nominatim/). Builds never use the network: they read the cache.
# Only precise matches (a house number, a building or an amenity) or manual entries put an event on a map.
using Base.ScopedValues: ScopedValue
const VENUES_FILE="venues.json"
const VENUES_SCHEMA_FILE=joinpath(@__DIR__,"..","schema","venues.schema.json")
const NOMINATIM_URL="https://nominatim.openstreetmap.org/search"
geo_user_agent()="Tangokalender/1 (+$(repo_url()))"
"The venue cache used while rendering (set by `write_site`/`_with_venues`): normalised address => entry."
const VENUES=ScopedValue(Dict{String,Any}())
"Normalised address key: lower case, no postcode, no city name (the site's), «gt.» → «gate», single spaces."
function _addrkey(addr)
 s=lowercase(strip(string(something(addr,""))))
 city=Regex("\\b"*_regex_escape(lowercase(site_city()))*"\\b")
 s=replace(s,r"\b\d{4}\b"=>" ",city=>" ",r"\bgt\b\.?"=>"gate",r"[\s,]+"=>" ")
 strip(s)
end
"The address an event is geocoded by (`venue.address`, with the city added when missing), or \"\"."
function _geo_address(e)
 v=get(e,"venue",nothing); v isa AbstractDict || return ""
 a=strip(_s(get(v,"address",nothing))); isempty(a) && return ""
 c=strip(_s(get(v,"city",nothing))); c=isempty(c) ? site_city() : c
 occursin(lowercase(c),lowercase(a)) ? a : "$a, $c"
end
"`s` with regex special characters escaped."
_regex_escape(s)=replace(s,r"([\\^$.|?*+()\[\]{}])"=>s"\\\1")
"Read `venues.json` into a lookup dict (empty if the file is missing)."
load_venues(file::AbstractString=VENUES_FILE)=isfile(file) ? Dict{String,Any}(_addrkey(x["address"])=>x for x in JSON.parsefile(file)) : Dict{String,Any}()
"Write the cache sorted by address (stable diffs)."
function save_venues(venues::AbstractDict,file::AbstractString=VENUES_FILE)
 open(file,"w") do io; JSON.print(io,sort(collect(values(venues)),by=x->_addrkey(x["address"])),2); write(io,'\n'); end
 file
end
_with_venues(f,venues)=with(f,VENUES=>venues)
"`(lat, lon)` for an event whose address is in the cache with a precise or manual position, otherwise `nothing`."
function venue_coords(e, venues=VENUES[])
 a=_geo_address(e); isempty(a) && return nothing
 x=get(venues,_addrkey(a),nothing); x isa AbstractDict || return nothing
 (get(x,"source","")=="manual" || get(x,"precision","")=="house") || return nothing
 lat=get(x,"lat",nothing); lon=get(x,"lon",nothing)
 lat isa Real && lon isa Real ? (Float64(lat),Float64(lon)) : nothing
end
"Is a Nominatim result precise enough to put a pin on (a house number, or a building/amenity)?"
_precise(r)=haskey(something(get(r,"address",nothing),Dict()),"house_number") || get(r,"category","") in ("building","amenity") || get(r,"addresstype","") in ("building","amenity")
"Query Nominatim for `q`; the first result as a dict, `nothing` when nothing was found. Throws on network errors."
function _nominatim(q)
 url=NOMINATIM_URL*"?q="*_urlenc(q)*"&countrycodes="*SITE[].countrycodes*(isnothing(SITE[].viewbox) ? "" : "&viewbox="*SITE[].viewbox)*"&format=jsonv2&addressdetails=1&limit=1"
 io=IOBuffer(); Downloads.request(url;output=io,headers=["User-Agent"=>geo_user_agent()],throw=true)
 r=JSON.parse(String(take!(io))); isempty(r) ? nothing : r[1]
end
"""
    geocode!(venues, events; fetch=_nominatim, retry=false, pause=1.0, today=Dates.today()) -> (added, failed)

Look up every event address missing from `venues` (normalised keys). Manual entries are never touched; addresses
stored as not found (`precision: "none"`) are only retried with `retry=true`. Network errors leave the address out,
so it is tried again next time. `pause` seconds between requests keep within Nominatim's usage policy.
"""
function geocode!(venues::AbstractDict, events; fetch=_nominatim, retry::Bool=false, pause::Real=1.0, today::Date=Dates.today())
 added=String[]; failed=String[]; first_=true
 for a in unique(filter(!isempty,[_geo_address(e) for e in events]))
  k=_addrkey(a); old=get(venues,k,nothing)
  old isa AbstractDict && (get(old,"source","")=="manual" || !retry || get(old,"precision","")!="none") && continue
  first_ || sleep(pause); first_=false
  r=try fetch(a) catch err; push!(failed,"$a: $(sprint(showerror,err))"); continue end
  x=JSON.Object{String,Any}("address"=>a,"lat"=>nothing,"lon"=>nothing,"precision"=>"none","source"=>"nominatim","checked"=>string(today))
  if !isnothing(r)
   x["lat"]=round(parse(Float64,string(r["lat"]));digits=6); x["lon"]=round(parse(Float64,string(r["lon"]));digits=6)
   x["precision"]=_precise(r) ? "house" : "street"
   haskey(r,"osm_type") && haskey(r,"osm_id") && (x["osm"]="$(r["osm_type"])/$(r["osm_id"])")
  end
  venues[k]=x; push!(added,a)
 end
 (added,failed)
end
"Problems in `venues.json` (schema and duplicate keys), as `(file, message)` like `validate_event_tree`."
function validate_venues(file::AbstractString=VENUES_FILE)
 isfile(file) || return Tuple{String,String}[]
 data=try JSON.parsefile(file) catch err; return [(file,"kan ikke leses: $(sprint(showerror,err))")] end
 out=Tuple{String,String}[]
 issue=JSONSchema.validate(JSONSchema.Schema(JSON.parsefile(VENUES_SCHEMA_FILE)),JSON.parse(JSON.json(data)))
 isnothing(issue) || push!(out,(file,"$(issue.path): $(issue.reason)"))
 data isa AbstractVector || return out
 keys_=[_addrkey(get(x,"address","")) for x in data if x isa AbstractDict]
 for k in unique(keys_); count(==(k),keys_)>1 && push!(out,(file,"samme adresse flere ganger: «$k»")); end
 out
end
