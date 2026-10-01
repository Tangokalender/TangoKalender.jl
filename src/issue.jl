# Issue form (.github/ISSUE_TEMPLATE/nytt-arrangement.yml) → v2 events. The body is untrusted input: parse it as data only.
const FORM_FIELDS=["Tittel","Type","Dato","Starttid","Sluttid","Gjentas","Gjentas til","Unntatt datoer","Sted","Adresse","Arrangør",
 "DJ","Lærere","Pris (kr)","Studentpris (kr)","Kurspris (kr)","Musikk","Flyer","Video","Lenke","Beskrivelse","Samtykke"]
const MAX_WEEKS=53
"Split an issue-form body into `heading => value`. GitHub's `_No response_` becomes an empty string."
function parse_issue_form(body::AbstractString)
 out=Dict{String,String}()
 for part in split(replace(body,"\r\n"=>"\n"),r"^### "m)[2:end]
  head,rest=occursin('\n',part) ? split(part,'\n';limit=2) : (part,"")
  v=strip(rest); out[strip(head)]= v=="_No response_" ? "" : v
 end
 out
end
_checked(v)=[strip(m[1]) for m in eachmatch(r"^\s*- \[[xX]\]\s*(.+?)\s*$"m,v)]
function _slug(s)
 s=lowercase(replace(s,"æ"=>"ae","Æ"=>"ae","ø"=>"o","Ø"=>"o","å"=>"a","Å"=>"a"))
 s=strip(replace(Base.Unicode.normalize(s;stripmark=true),r"[^a-z0-9]+"=>"-"),'-')
 s=String(rstrip(first(s,50),'-')); isempty(s) ? "arrangement" : s
end
_date(s)=(m=match(r"^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*$",s); isnothing(m) ? nothing : tryparse(Date,"$(m[1])-$(lpad(m[2],2,'0'))-$(lpad(m[3],2,'0'))"))
function _time(s;allow24=false)
 m=match(r"^\s*(\d{1,2})[:.](\d{2})\s*$",s); isnothing(m) && return nothing
 h,mi=parse(Int,m[1]),parse(Int,m[2]); t="$(lpad(h,2,'0')):$(m[2])"
 (h<24 && mi<60) || (allow24 && t=="24:00") ? t : nothing
end
_parse_int(s)=tryparse(Int,replace(strip(s),r"(?i)\s*(kr|nok|,-)\s*$"=>"",r"\s"=>""))
"First image URL in a drag-and-drop textarea (markdown or <img>), or a bare http(s) URL."
function _image_url(s)
 for r in (r"!\[[^\]]*\]\((https?://[^)\s]+)\)", r"<img[^>]*\bsrc=\"(https?://[^\"]+)\"", r"^\s*(https?://\S+)\s*$")
  m=match(r,s); isnothing(m) || return String(m[1])
 end
 nothing
end
function _video_from_url(s)
 m=match(r"(?:youtube(?:-nocookie)?\.com/(?:watch\?(?:[^#\s]*&)?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})",s)
 isnothing(m) || return JSON.Object{String,Any}("platform"=>"youtube","id"=>String(m[1]))
 m=match(r"vimeo\.com/(?:video/)?([0-9]+)",s)
 isnothing(m) ? nothing : JSON.Object{String,Any}("platform"=>"vimeo","id"=>String(m[1]))
end
_lookup(d,label)=(k=findfirst(==(label),d); isnothing(k) ? nothing : k)
const PRICE_FIELDS=["price_nok"=>"Pris (kr)","student_price_nok"=>"Studentpris (kr)","class_price_nok"=>"Kurspris (kr)"]
"""
    _parse_field(label, s) -> (value, error)

Parse one non-empty form field into its event value. `error` is a Norwegian message or `nothing`.
Fields without special syntax are returned as text. Shared by new-event and correction forms.
"""
function _parse_field(label::AbstractString,s::AbstractString)
 bad(m)=(nothing,m)
 if label=="Type"
  t=_lookup(_TYPES,s); isnothing(t) ? bad("Ukjent «Type»: $s.") : (t,nothing)
 elseif label in ("Dato","Gjentas til")
  d=_date(s); isnothing(d) ? bad("«$label» må være på formen ÅÅÅÅ-MM-DD (fikk «$s»).") : (d,nothing)
 elseif label in ("Starttid","Sluttid")
  t=_time(s;allow24=label=="Sluttid"); isnothing(t) ? bad("«$label» må være på formen TT:MM (fikk «$s»).") : (t,nothing)
 elseif label=="Lenke"
  occursin(r"^https?://\S+$",s) ? (s,nothing) : bad("«Lenke» må være en nettadresse som begynner med https://.")
 elseif label in last.(PRICE_FIELDS)
  v=_parse_int(s); isnothing(v) || v<0 ? bad("«$label» må være et helt tall (fikk «$s»).") : (v,nothing)
 elseif label=="Flyer"
  u=_image_url(s); isnothing(u) ? bad("Fant ingen bildelenke i «Flyer». Dra og slipp bildet i feltet, eller lim inn en https-lenke.") : (u,nothing)
 elseif label=="Video"
  v=_video_from_url(s); isnothing(v) ? bad("«Video» må være en lenke til YouTube eller Vimeo.") : (v,nothing)
 elseif label=="Lærere"
  (Any[String(strip(t)) for t in split(s,',') if !isempty(strip(t))],nothing)
 elseif label=="Musikk"
  music=Any[]
  for l in _checked(s)
   m=_lookup(_MUSIC,l); isnothing(m) && return bad("Ukjent «Musikk»: $l."); push!(music,m)
  end
  (music,nothing)
 else
  (s,nothing)
 end
end
"""
    events_from_form(fields; issue_url=nothing, today=Dates.today()) -> (events, errors)

Turn parsed form fields into dated v2 events (one per week for «Gjentas: Ukentlig»).
`errors` are Norwegian messages naming the form fields; `events` is empty when there are errors.
"""
function events_from_form(f::AbstractDict; issue_url=nothing, today::Date=Dates.today())
 errs=String[]; err(m)=push!(errs,m)
 get_(k)=String(strip(get(f,k,"")))
 req(k)=(v=get_(k); isempty(v) && err("«$k» må fylles ut."); v)
 val(k;required=false)=(s=required ? req(k) : get_(k); isempty(s) ? nothing : ((v,e)=_parse_field(k,s); isnothing(e) || err(e); v))
 title=req("Tittel"); typ=val("Type";required=true); date=val("Dato";required=true); st=val("Starttid";required=true)
 venue=req("Sted"); address=req("Adresse"); org=req("Arrangør"); link=val("Lenke";required=true)
 !isnothing(date) && date<today && err("«Dato» ($date) har allerede vært.")
 et=val("Sluttid")
 weekly=get_("Gjentas")=="Ukentlig"; until=nothing; except=Date[]
 if weekly
  until=val("Gjentas til";required=true)
  if !isnothing(until) && !isnothing(date)
   until<date && err("«Gjentas til» ($until) er før «Dato» ($date).")
   until>date+Week(MAX_WEEKS-1) && err("«Gjentas til» kan være høyst ett år etter «Dato».")
  end
  for s in split(get_("Unntatt datoer"),r"[,;\s]+";keepempty=false)
   d=_date(s); isnothing(d) ? err("«Unntatt datoer»: «$s» er ikke en dato (ÅÅÅÅ-MM-DD).") : push!(except,d)
  end
 elseif !isempty(get_("Gjentas til")) || !isempty(get_("Unntatt datoer"))
  err("«Gjentas til»/«Unntatt datoer» brukes bare når «Gjentas» er «Ukentlig».")
 end
 prices=Dict{String,Any}(k=>val(field) for (k,field) in PRICE_FIELDS)
 music=something(val("Musikk"),Any[]); flyer=val("Flyer"); video=val("Video")
 isempty(_checked(get_("Samtykke"))) && err("«Samtykke» må krysses av.")
 isempty(errs) || return (JSON.Object{String,Any}[],errs)
 slug=_slug(title); none(s)=isempty(s) ? nothing : s
 base=JSON.Object{String,Any}("id"=>"$slug-$(Dates.format(date,"yyyy-mm-dd"))","title"=>title,"type"=>typ,"status"=>"scheduled","series"=>weekly ? slug : nothing,
  "start"=>_stamp(date,st),"end"=>isnothing(et) ? nothing : _end_stamp(date,st,et),
  "venue"=>JSON.Object{String,Any}("name"=>venue,"address"=>address,"city"=>"Oslo"),"organizer"=>org,"dj"=>none(get_("DJ")),
  "teachers"=>something(val("Lærere"),Any[]),
  "price_nok"=>prices["price_nok"],"student_price_nok"=>prices["student_price_nok"],"class_price_nok"=>prices["class_price_nok"],
  "description"=>none(get_("Beskrivelse")),"music_style"=>music,"flyer_url"=>flyer,"video"=>video,"link"=>link,
  "source"=>"Innsendt via skjema","source_url"=>isnothing(issue_url) ? nothing : string(issue_url),"published_date"=>string(today),
  "first_seen"=>string(today),"last_verified"=>string(today),"crawl_timestamp"=>nothing,"confidence"=>1.0)
 events=if weekly
  t=JSON.Object{String,Any}(k=>v for (k,v) in base if !(k in ("start","end","status","series")))
  t["id"]=slug; t["weekday"]=WEEKDAYS[dayofweek(date)]; t["start_time"]=st; t["end_time"]=et
  expand_weekly(t; from=date, until=until, except=except, series=slug)
 else
  [base]
 end
 isempty(events) && return (events,["Ingen datoer igjen etter «Unntatt datoer»."])
 for e in events, m in validate_event(e); err("$(e["id"]): $m"); end
 isempty(errs) ? (events,errs) : (JSON.Object{String,Any}[],errs)
end
