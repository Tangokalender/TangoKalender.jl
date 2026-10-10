# Per-site settings: one calendar site per city, each built from its own data repo with a `site.toml` at its root
# (events/, venues.json and the issue forms live there too). Renderers read the settings through `SITE[]`, a
# ScopedValue set by `main`/`write_site` (like `LANG` and `VENUES`), via the accessors below: `site_url()`,
# `repo_url()`, `site_name()`, `site_city()`, … Nothing site-specific is hard-coded in the package.
using TOML
using Base.ScopedValues: ScopedValue, with
"""
    SiteConfig

Settings for one city's site (`site.toml`):
- `slug`: short id (`"oslo"`), `name`: site name in titles and feeds (`"Tangokalender | Oslo"`), `city`: the city
  (default `venue.city`, texts, geocoding).
- `site_url`: where the site is published, without a trailing slash; may have a path
  (`https://tangokalender.github.io/bergen`). Every absolute URL derives from it.
- `repo_url`: the data repo on GitHub; the issue forms (`…/issues/new?template=…`) are there.
- `map_center` (lat, lon) and `map_zoom`: the map view when no event has a position.
- `countrycodes` (and optional `viewbox`, "lon1,lat1,lon2,lat2"): Nominatim search limits for `geocode`.
- `og_image`: link-preview image file (absolute path; `site.toml` gives it relative to itself), `nothing` = the
  package's generic image.
- `texts`: per language (`nb`/`en`/`es`), UI strings that replace the package's `_T` entries.
"""
Base.@kwdef struct SiteConfig
 slug::String
 name::String
 city::String
 site_url::String
 repo_url::String
 map_center::Tuple{Float64,Float64}=(59.9139,10.7522)
 map_zoom::Int=12
 countrycodes::String="no"
 viewbox::Union{Nothing,String}=nothing
 og_image::Union{Nothing,String}=nothing
 texts::Dict{String,Dict{String,String}}=Dict{String,Dict{String,String}}()
end
"""
Used when no `site.toml` is given: a placeholder city, so a forgotten config shows on the page rather than
silently publishing another city's name and URLs.
"""
const DEFAULT_SITE=SiteConfig(slug="eksempel",name="Tangokalender | Eksempelby",city="Eksempelby",
 site_url="https://example.org/tangokalender",repo_url="https://github.com/OWNER/REPO")
"The site being built (set by `_with_site`; `DEFAULT_SITE` outside one)."
const SITE=ScopedValue(DEFAULT_SITE)
"Run `f()` with `site` as the current site."
_with_site(f,site::SiteConfig)=with(f,SITE=>site)
const SITE_FILE="site.toml"
const SITE_SCHEMA_FILE=joinpath(@__DIR__,"..","schema","site.schema.json")
"""
    load_site(file="site.toml") -> SiteConfig

Read a site's settings. Throws `ArgumentError` naming the problem if the file doesn't match
`schema/site.schema.json`.
"""
function load_site(file::AbstractString=SITE_FILE)
 isfile(file) || throw(ArgumentError("no site config $file"))
 t=TOML.parsefile(file)
 issue=JSONSchema.validate(JSONSchema.Schema(JSON.parsefile(SITE_SCHEMA_FILE)),JSON.parse(JSON.json(t)))
 isnothing(issue) || throw(ArgumentError("$file: $(_issue_message(t,issue))"))
 m=get(t,"map",Dict()); g=get(t,"geocode",Dict()); og=get(t,"og_image",nothing)
 SiteConfig(slug=t["slug"],name=t["name"],city=t["city"],site_url=rstrip(t["site_url"],'/'),repo_url=rstrip(t["repo_url"],'/'),
  map_center=Tuple(Float64.(get(m,"center",[59.9139,10.7522]))),map_zoom=get(m,"zoom",12),
  countrycodes=get(g,"countrycodes","no"),viewbox=get(g,"viewbox",nothing),
  og_image=isnothing(og) ? nothing : normpath(joinpath(dirname(abspath(file)),og)),
  texts=Dict{String,Dict{String,String}}(l=>Dict{String,String}(k=>string(v) for (k,v) in d) for (l,d) in get(t,"texts",Dict())))
end
"The site config the CLI uses: `--site=FILE`, else `./site.toml` if it exists, else the current one."
_cli_site(file)=!isempty(file) ? load_site(file) : isfile(SITE_FILE) ? load_site(SITE_FILE) : SITE[]
site_url()=SITE[].site_url
repo_url()=SITE[].repo_url
site_name()=SITE[].name
site_city()=SITE[].city
"Host of the site URL (`tangokalender.github.io`), used in iCalendar UIDs."
site_host()=(m=match(r"^https?://([^/]+)",site_url()); isnothing(m) ? site_url() : String(m[1]))
"Where the page's «Legg til arrangement» link points: the new-event issue form."
submit_form_url()=repo_url()*"/issues/new?template=nytt-arrangement.yml"
"Base of each card's «Rett opp» link: the correction issue form (prefilled by `correction_url`)."
correct_form_url()=repo_url()*"/issues/new?template=rett-arrangement.yml"
"The table issue form: cells pasted from a spreadsheet (see legg-til.html#tabell, src/table.jl)."
table_form_url()=repo_url()*"/issues/new?template=nytt-arrangement-tabell.yml"
"The JSON issue form used with LLM-extracted events (see legg-til.html#ki / llms.txt)."
json_form_url()=repo_url()*"/issues/new?template=nytt-arrangement-json.yml"
