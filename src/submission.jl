# JSON submissions (e.g. extracted by an LLM, see llms.jl) via .github/ISSUE_TEMPLATE/nytt-arrangement-json.yml.
# The submission schema is derived from the stored schema: bot-managed fields removed, times relaxed to Oslo local time.
const SUBMISSION_SCHEMA_URL=SITE_URL*"/schema/tango-event-submission.schema.json"
const BOT_FIELDS=["id","series","source","source_url","published_date","first_seen","last_verified","crawl_timestamp","confidence","video"]
const MAX_SUBMISSION=60
const _LOCALTIME="^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}(:[0-9]{2})?(Z|[+-][0-9]{2}:[0-9]{2})?)?\$"
const TYPE_HELP=Dict("milonga"=>"social dance evening","practica"=>"practice evening","class"=>"class or course",
 "class_and_social"=>"class followed by a milonga","class_and_practica"=>"class followed by a practica","workshop"=>"workshop or seminar",
 "festival"=>"festival or multi-day event with workshops","marathon"=>"multi-day, mostly social dancing","other"=>"anything else")
const MUSIC_HELP=Dict("traditional"=>"traditional / golden-age tango","alternative"=>"alternative or neo tango","live_orchestra"=>"live orchestra")
_typelist()=join(("$k ($(TYPE_HELP[k]))" for k in sort(collect(keys(_TYPES)))),", ")
_musiclist()=join(("$k ($(MUSIC_HELP[k]))" for k in sort(collect(keys(_MUSIC)))),", ")
const _DESCRIPTIONS=Dict(
 "title"=>"Event name as written by the organiser.",
 "type"=>"One of: " ,   # completed in submission_schema()
 "status"=>"\"cancelled\" only if the source says the event is cancelled; otherwise omit.",
 "start"=>"Oslo local start time, \"YYYY-MM-DDTHH:MM\" (no time zone), or \"YYYY-MM-DD\" if no time is given.",
 "end"=>"Oslo local end time in the same format. If it ends after midnight, use the next day's date. null if not stated.",
 "venue"=>"Where the event takes place.",
 "organizer"=>"Organising group or person, as written in the source.",
 "dj"=>"DJ name(s) exactly as written in the source, or null.",
 "teachers"=>"Teachers' names exactly as written in the source; [] if none.",
 "music_style"=>"Only if the source states it. Any of: ",   # completed below
 "price_nok"=>"Regular entry price in whole Norwegian kroner (integer), or null.",
 "student_price_nok"=>"Student/reduced price in whole NOK, or null.",
 "class_price_nok"=>"Price for the class/course part in whole NOK, or null.",
 "description"=>"1–3 short neutral sentences in the source's language (level, entry, dress code). No marketing.",
 "flyer_url"=>"Direct https URL of the event image, only if it appears in the source; otherwise null.",
 "video_url"=>"YouTube or Vimeo link from the source, or null.",
 "link"=>"URL of the event page (e.g. the Facebook event or the organiser's page).")
"""
    submission_schema() -> JSON.Object

JSON Schema (draft-07) for submitted events: a single event or an array of up to $MAX_SUBMISSION.
Derived from `schema/tango-event.schema.json`; published at `SUBMISSION_SCHEMA_URL`.
"""
function submission_schema()
 s=JSON.parsefile(SCHEMA_FILE); defs=s["definitions"]; props=s["properties"]
 for k in BOT_FIELDS; delete!(props,k); end
 defs["localtime"]=JSON.Object{String,Any}("type"=>["string","null"],"pattern"=>_LOCALTIME)
 props["start"]=JSON.Object{String,Any}("type"=>"string","pattern"=>_LOCALTIME)
 props["end"]=JSON.Object{String,Any}("\$ref"=>"#/definitions/localtime")
 props["video_url"]=JSON.Object{String,Any}("\$ref"=>"#/definitions/url")
 props["venue"]["type"]="object"; props["venue"]["required"]=["name","address"]
 for (k,d) in _DESCRIPTIONS
  d=k=="type" ? d*_typelist()*"." : k=="music_style" ? d*_musiclist()*"." : d
  p=props[k]; haskey(p,"\$ref") ? (props[k]=JSON.Object{String,Any}("description"=>d,"allOf"=>[p])) : (p["description"]=d)
 end
 event=JSON.Object{String,Any}("type"=>"object","required"=>["title","type","start","venue","organizer","link"],
  "additionalProperties"=>false,"properties"=>props)
 defs["event"]=event
 JSON.Object{String,Any}("\$schema"=>"http://json-schema.org/draft-07/schema#","\$id"=>SUBMISSION_SCHEMA_URL,
  "title"=>"Tangokalender event submission",
  "description"=>"One event, or an array with one object per date (up to $MAX_SUBMISSION). Times are Oslo local time. Use null for anything not stated in the source.",
  "definitions"=>defs,
  "oneOf"=>[JSON.Object{String,Any}("\$ref"=>"#/definitions/event"),
   JSON.Object{String,Any}("type"=>"array","minItems"=>1,"maxItems"=>MAX_SUBMISSION,"items"=>JSON.Object{String,Any}("\$ref"=>"#/definitions/event"))])
end
const _SUBMISSION_EVENT=Ref{Any}(nothing)
"(schema dict, compiled Schema) for one submitted event – validated item by item, for precise error paths."
function _submission_event_schema()
 isnothing(_SUBMISSION_EVENT[]) || return _SUBMISSION_EVENT[]
 s=submission_schema(); ev=JSON.Object{String,Any}("definitions"=>s["definitions"]); merge!(ev,s["definitions"]["event"])
 _SUBMISSION_EVENT[]=(ev,JSONSchema.Schema(ev))
end
"The JSON value inside `text`: code fences and surrounding prose are ignored."
function _extract_json(text)
 t=strip(text); m=match(r"```[a-zA-Z]*\s*(.*?)```"s,t); isnothing(m) || (t=strip(m[1]))
 i=findfirst(c->c in "{[",t); isnothing(i) && return nothing
 j=findlast(==(t[i]=='{' ? '}' : ']'),t); isnothing(j) ? t[i:end] : t[i:j]   # unclosed: let the parser report it
end
"Norwegian message for a submission-schema issue at item `i`."
function _submission_message(i,x,issue)
 p=lstrip(replace(string(issue.path),r"\[(\d+)\]"=>s->s,r"\[([^\]]*[^\]\d][^\]]*|[^\]\d])\]"=>s".\1"),'.')
 at="«"*join(filter(!isempty,[isnothing(i) ? "" : "[$i]",p]),".")*"»"; at=="«»" && (at="«(arrangementet)»")
 v=JSON.json(issue.x); r=issue.reason
 r=="additionalProperties" && x isa AbstractDict && isempty(issue.path) &&
  return "$at: ukjente felt: $(join(sort([k for k in keys(x) if !haskey(_submission_event_schema()[1]["properties"],k)]),", ")). Se $SUBMISSION_SCHEMA_URL"
 r=="required" && return "$at mangler påkrevd felt: $(join([k for k in issue.val if !(issue.x isa AbstractDict && haskey(issue.x,k))],", "))."
 r=="enum" && return "$at: $v er ikke en gyldig verdi. Lovlige verdier: $(join(filter(!isnothing,issue.val),", "))."
 r=="type" && return "$at: forventet $(issue.val isa AbstractVector ? join(issue.val," eller ") : issue.val), fikk $v."
 r=="pattern" && return "$at: $v har feil format."
 "$at: $v er ugyldig ($r)."
end
"(Date, \"HH:MM\" or nothing) from a submitted local time; offsets are ignored (times are Oslo local time)."
function _local(raw)
 m=match(r"^(\d{4}-\d{2}-\d{2})(?:T(\d{2}:\d{2}))?",_s(raw)); isnothing(m) && return nothing
 d=tryparse(Date,m[1]); isnothing(d) && return nothing
 t=isnothing(m[2]) ? nothing : _time(m[2];allow24=true); (d,t)
end
_none(x)=x isa AbstractString && isempty(strip(x)) ? nothing : x
"""
    events_from_json(text; issue_url=nothing, today=Dates.today()) -> (events, errors)

Parse a JSON submission (one event or an array), validate it against the submission schema, and build stored
v2 events: Oslo offsets recomputed, ids/series/metadata set by the bot. Errors are Norwegian.
"""
function events_from_json(text::AbstractString; issue_url=nothing, today::Date=Dates.today())
 errs=String[]; err(m)=push!(errs,m); fail()=(JSON.Object{String,Any}[],errs)
 raw=_extract_json(text); isnothing(raw) && (err("Fant ingen JSON i feltet. Lim inn svaret fra KI-assistenten (det som starter med { eller [)."); return fail())
 data=try JSON.parse(raw) catch e; err("JSON-en kan ikke leses: $(first(split(sprint(showerror,e),'\n')))"); return fail() end
 items=data isa AbstractVector ? collect(data) : [data]; multi=data isa AbstractVector
 for x in items; x isa AbstractDict && foreach(k->delete!(x,k),BOT_FIELDS); end   # the bot sets these itself
 isempty(items) && (err("Lista er tom."); return fail())
 length(items)>MAX_SUBMISSION && (err("Høyst $MAX_SUBMISSION arrangementer per innsending (fikk $(length(items)))."); return fail())
 sch=_submission_event_schema()[2]
 for (k,x) in enumerate(items)
  issue=JSONSchema.validate(sch,x); isnothing(issue) || err(_submission_message(multi ? k-1 : nothing,x,issue))
 end
 isempty(errs) || return fail()
 slugs=[_slug(_s(x["title"])) for x in items]; counts=Dict(s=>count(==(s),slugs) for s in slugs)
 events=JSON.Object{String,Any}[]; seen=Set{String}()
 for (k,x) in enumerate(items)
  at=multi ? "[$(k-1)] " : ""
  st=_local(x["start"]); isnothing(st) && (err("$(at)«start» er ikke en gyldig dato."); continue)
  d,t=st; d<today && err("$(at)«start» ($d) har allerede vært.")
  en=_local(get(x,"end",nothing))
  stamp_end=if isnothing(en) nothing
   elseif isnothing(en[2]) string(en[1])
   elseif !isnothing(t) && en[1]==d _end_stamp(d,t,en[2])     # same-day end before the start = after midnight
   else _stamp(en[1],en[2]) end
  id="$(slugs[k])-$(Dates.format(d,"yyyy-mm-dd"))"; id in seen && (err("$(at)samme arrangement og dato finnes to ganger ($id)."); continue); push!(seen,id)
  v=x["venue"]
  for (f,n) in ("name"=>"venue.name","address"=>"venue.address"); isnothing(_none(get(v,f,nothing))) && err("$(at)«$n» må fylles ut."); end
  vurl=_none(get(x,"video_url",nothing)); video=isnothing(vurl) ? nothing : _video_from_url(vurl)
  !isnothing(vurl) && isnothing(video) && err("$(at)«video_url» må være en lenke til YouTube eller Vimeo.")
  e=JSON.Object{String,Any}("id"=>id,"title"=>strip(_s(x["title"])),"type"=>x["type"],"status"=>something(_none(get(x,"status",nothing)),"scheduled"),
   "series"=>counts[slugs[k]]>1 ? slugs[k] : nothing,"start"=>_stamp(d,t),"end"=>stamp_end,
   "venue"=>JSON.Object{String,Any}("name"=>_none(get(v,"name",nothing)),"address"=>_none(get(v,"address",nothing)),"city"=>something(_none(get(v,"city",nothing)),"Oslo")),
   "organizer"=>_none(x["organizer"]),"dj"=>_none(get(x,"dj",nothing)),"teachers"=>collect(something(get(x,"teachers",nothing),Any[])),
   "price_nok"=>get(x,"price_nok",nothing),"student_price_nok"=>get(x,"student_price_nok",nothing),"class_price_nok"=>get(x,"class_price_nok",nothing),
   "description"=>_none(get(x,"description",nothing)),"music_style"=>collect(something(get(x,"music_style",nothing),Any[])),
   "flyer_url"=>_none(get(x,"flyer_url",nothing)),"video"=>video,"link"=>x["link"],
   "source"=>"Innsendt via KI-skjema","source_url"=>isnothing(issue_url) ? nothing : string(issue_url),"published_date"=>string(today),
   "first_seen"=>string(today),"last_verified"=>string(today),"crawl_timestamp"=>nothing,"confidence"=>1.0)
  for m in validate_event(e); err("$(at)$m"); end
  push!(events,e)
 end
 isempty(errs) ? (sort!(events,by=e->e["start"]),errs) : fail()
end
