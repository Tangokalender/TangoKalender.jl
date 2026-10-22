# The event form of the interactive editors (TangoTUI on Tachikoma; later perhaps a trimmed tangoedit): which fields an
# editor sees and in what order, their allowed values, and how a field's text maps to and from an `Event`. No terminal
# code here. Values are written through `set_path` (the same conversion as `edit KEY=VALUE`) and checked with `check`.
"""
    FormField

One field of the event form. `key` is a JSON path (`venue.name`) or a form-only key: `date`, `start_time`, `end`,
`video`, `other_title`, `other_description` (the text in the language that isn't `lang`), `es_title`, `es_description`
(`translations.es`). `label` and `help` are
Norwegian, like the issue forms. `kind` is one of `:text`, `:longtext`, `:int`, `:price` (an entry price or «betal det
du kan» still sets `pay_what_you_can` too; the field `pay_what_you_can` is a Ja/Nei `:choice`), `:date`, `:time`, `:end`, `:choice`, `:multi`, `:list`, `:url`, `:video`; `choices` are the allowed `(value, label)` pairs of `:choice`/`:multi`, and
`checks` the `check` keys whose problems belong to the field.
"""
struct FormField
 key::String
 label::String
 kind::Symbol
 choices::Vector{Tuple{String,String}}
 help::String
 checks::Vector{String}
end
FormField(key,label,kind,help;choices=Tuple{String,String}[],checks=[key])=FormField(key,label,kind,choices,help,checks)
"The fields of the event form, in order (the bot fields `first_seen`, `last_verified`, … are set on save)."
function form_fields()
 F=FormField
 [F("title","Tittel",:text,"Arrangementets navn, uten arrangøren (den har eget felt)."),
  F("types","Type",:multi,"Én eller flere: kurs og milonga samme kveld er Kurs + Milonga.";choices=[(t,_TYPES[t]) for t in TYPE_ORDER]),
  F("status","Status",:choice,"Avlyste datoer beholdes og vises som avlyst.";choices=[("scheduled","Planlagt"),("cancelled","Avlyst")]),
  F("date","Dato",:date,"ÅÅÅÅ-MM-DD eller DD.MM.ÅÅÅÅ. Sluttdato og -tid flyttes med.";checks=["start"]),
  F("start_time","Starttid",:time,"TT:MM. Tom for heldagsarrangementer (festivaler).";checks=["start"]),
  F("end","Slutt",:end,"TT:MM (før starttiden = etter midnatt), ÅÅÅÅ-MM-DD for flere dager, eller ÅÅÅÅ-MM-DD TT:MM."),
  F("venue.name","Sted",:text,"Navnet på lokalet."),
  F("venue.address","Adresse",:text,"Gate og nummer, postnummer og sted."),
  F("venue.city","By",:text,""),
  F("organizer","Arrangør",:text,"Gruppen eller personen som arrangerer."),
  F("dj","DJ",:text,""),
  F("teachers","Lærere",:list,"Skilt med komma."),
  F("music_style","Musikk",:multi,"Bare hvis arrangøren sier det.";choices=[(m,_MUSIC[m]) for m in sort(collect(keys(_MUSIC)))]),
  F("price_nok","Pris",:price,"Vanlig inngang, hele kroner. Med «Betal det du kan»: et foreslått beløp, eller tomt.";checks=["price_nok"]),
  F("pay_what_you_can","Betal det du kan",:choice,"Ja: inngangen er frivillig, og «Pris» er et forslag.";choices=[("ja","Ja"),("nei","Nei")],checks=["pay_what_you_can"]),
  F("student_price_nok","Studentpris",:int,"Hele kroner."),
  F("class_price_nok","Kurspris",:int,"Kurs- eller klassedelen. Pris for et helt kurs: skriv det i beskrivelsen."),
  F("description","Beskrivelse",:longtext,"1–3 korte, nøytrale setninger (nivå, inngang, påmelding)."),
  F("lang","Tekstspråk",:choice,"Språket i tittel og beskrivelse.";choices=[("nb","Norsk"),("en","English")]),
  F("other_title","Tittel (andre språk)",:text,"Bare tekst arrangøren selv har på begge språk; aldri egen oversettelse.";checks=["translations"]),
  F("other_description","Beskrivelse (andre språk)",:longtext,"Som over.";checks=["translations"]),
  F("es_title","Tittel (spansk)",:text,"Bare tekst arrangøren selv har på spansk; aldri egen oversettelse.";checks=["translations"]),
  F("es_description","Beskrivelse (spansk)",:longtext,"Som over.";checks=["translations"]),
  F("link","Lenke",:url,"Arrangementets egen side (f.eks. Facebook-arrangementet)."),
  F("flyer_url","Flyer",:url,"Lenke til bildet."),
  F("video","Video",:video,"YouTube- eller Vimeo-lenke.";checks=["video"]),
  F("series","Serie",:text,"Felles id for alle datoene i en serie: små bokstaver, tall og bindestrek."),
  F("source","Kilde",:text,"Hvor opplysningene kom fra (nettside, Facebook …)."),
  F("source_url","Kilde-URL",:url,"")]
end
_path(k::AbstractString)=String.(split(k,'.'))
_other_lang(e::Event)=something(e.lang,"nb")=="en" ? "nb" : "en"
"`(h, m)` from «20:15», «20.15», «2015», «915», «20» or «kl. 20:15» (`TIME_RE`); 24:00 only with `allow24`; `nothing` if invalid."
function _form_hm(s::AbstractString; allow24::Bool=false)
 m=match(TIME_RE,s); isnothing(m) && return nothing
 h=parse(Int,something(m[1])); mi=isnothing(m[2]) ? 0 : parse(Int,something(m[2]))
 (0<=h<=23 && 0<=mi<=59) || (allow24 && h==24 && mi==0) ? (h,mi) : nothing
end
_hm_of(stamp)=(m=match(r"T([0-9]{2}):([0-9]{2})",something(stamp,"")); isnothing(m) ? nothing : (parse(Int,something(m[1])),parse(Int,something(m[2]))))
_stamp_at(d::Date,h::Int,mi::Int)="$(_ymd_str(d))T$(_two(h)):$(_two(mi)):00$(_oslo_offset(d,h))"
_hm_text(t)="$(_two(t[1])):$(_two(t[2]))"
"""
    field_text(e, f) -> String

The field's current value as the text an editor sees and edits ("" when unset). Lists are comma-separated, choices
show their labels, and `end` is just «TT:MM» when it ends the same evening (by the next morning).
"""
function field_text(e::Event, f::FormField)
 k=f.key
 k=="date" && return first(e.start,10)
 k=="start_time" && (t=_hm_of(e.start); return isnothing(t) ? "" : _hm_text(t))
 k=="end" && return _end_text(e)
 f.kind==:price && return isnothing(e.price_nok) ? "" : string(e.price_nok)
 k=="video" && return isnothing(e.video) ? "" : e.video.platform=="vimeo" ? "https://vimeo.com/$(e.video.id)" : "https://youtu.be/$(e.video.id)"
 f.kind in (:choice,:multi) && return join((l for (v,l) in f.choices if v in field_values(e,f)),", ")
 _text_at(e,k=="other_title" ? "translations.$(_other_lang(e)).title" : k=="other_description" ? "translations.$(_other_lang(e)).description" :
  k=="es_title" ? "translations.es.title" : k=="es_description" ? "translations.es.description" : k)
end
function _text_at(e::Event, k::String)
 v=JSON.parse(path_json(e,_path(k)))
 isnothing(v) ? "" : v isa AbstractVector ? join(string.(v),", ") : v isa Real ? string(v) : String(v)
end
function _end_text(e::Event)
 en=e.end_; isnothing(en) && return ""
 d0=_ymd(e.start); d1=_ymd(en); t0=_hm_of(e.start); t1=_hm_of(en)
 isnothing(t1) && return first(en,10)
 !isnothing(t0) && !isnothing(d0) && (d1==d0 || (d1==d0+Day(1) && t1<=t0)) && return _hm_text(t1)
 "$(first(en,10)) $(_hm_text(t1))"
end
"The selected values of a `:choice`/`:multi` field."
function field_values(e::Event, f::FormField)
 f.key=="types" && return copy(e.types)
 f.key=="music_style" && return copy(something(e.music_style,String[]))
 f.key=="status" && return [something(e.status,"scheduled")]
 f.key=="lang" && return [something(e.lang,"nb")]
 f.key=="pay_what_you_can" && return [e.pay_what_you_can===true ? "ja" : "nei"]
 String[]
end
"""
    set_field(e, f, text) -> Event
    set_field(e, f, values::Vector{String}) -> Event   # :choice/:multi

`e` with the field set from the editor's text ("" clears it). Throws `ArgumentError` with a Norwegian message for
text that can't be read (a date, time, number or video link). Problems that `check` finds are not thrown: the
editor shows them at the field (`field_problems`), and saving refuses them.
"""
function set_field(e::Event, f::FormField, s::AbstractString)
 s=String(strip(s)); k=f.key; bad(m)=throw(ArgumentError("«$(f.label)»: $m"))
 k=="dj" && (s=first(_strip_dj_prefix(s)))   # the field is already called DJ: «TDJ Ana» → «Ana»
 kind=k in ("title","other_title","es_title","organizer","venue.name","venue.address") ? :title :
  k in ("description","other_description","es_description") ? :text : k in ("dj","teachers") ? :name : :none
 if kind!==:none && !isempty(s)   # the capitals check: all capitals are normalised, creative mixed case refused
  s=first(_caps_normalize(f.label,s;kind))
  m=_caps_problem(f.label,s;kind); isnothing(m) || throw(ArgumentError(m))
 end
 f.kind in (:choice,:multi) && return set_field(e,f,String[v for (v,l) in f.choices if any(x->lowercase(strip(x)) in (lowercase(v),lowercase(l)),split(s,','))])
 if k=="date"
  d=_date(s); isnothing(d) && bad("«$s» er ikke en dato (ÅÅÅÅ-MM-DD).")
  return _move_event(e,d)
 elseif k=="start_time"
  d=_ymd(e.start); isnothing(d) && bad("sett «Dato» først.")
  endtext=_end_text(e)
  if isempty(s)
   e=_put(e,Val(:start),_ymd_str(d))
   return isnothing(_hm_of(e.end_)) ? e : _put(e,Val(:end_),_ymd(something(e.end_,""))==d ? nothing : first(something(e.end_,""),10))
  end
  t=_form_hm(s); isnothing(t) && bad("«$s» er ikke et klokkeslett (TT:MM).")
  e=_put(e,Val(:start),_stamp_at(d,t[1],t[2]))
  return isnothing(_form_hm(endtext;allow24=true)) ? e : set_field(e,_field("end"),endtext)   # «ends 23:00» stays so
 elseif k=="end"
  isempty(s) && return _put(e,Val(:end_),nothing)
  d0=_ymd(e.start); t0=_hm_of(e.start)
  t=_form_hm(s;allow24=true)
  if !isnothing(t)
   (isnothing(d0) || isnothing(t0)) && bad("et klokkeslett alene krever «Dato» og «Starttid»; skriv ellers ÅÅÅÅ-MM-DD TT:MM.")
   d=t==(24,0) || t<=t0 ? d0+Day(1) : d0
   return _put(e,Val(:end_),t==(24,0) ? _stamp_at(d,0,0) : _stamp_at(d,t[1],t[2]))
  end
  m=match(r"^(\S+)(?:\s+(\S+))?$",s); d=isnothing(m) ? nothing : _date(something(m[1]))
  isnothing(d) && bad("«$s»: skriv TT:MM, ÅÅÅÅ-MM-DD eller ÅÅÅÅ-MM-DD TT:MM.")
  isnothing(m[2]) && return _put(e,Val(:end_),_ymd_str(d))
  t=_form_hm(something(m[2])); isnothing(t) && bad("«$(m[2])» er ikke et klokkeslett (TT:MM).")
  return _put(e,Val(:end_),_stamp_at(d,t[1],t[2]))
 elseif k=="video"
  isempty(s) && return set_path(e,["video"],"null")
  v=_video_from_url(s); isnothing(v) && bad("må være en lenke til YouTube eller Vimeo.")
  return set_path(e,["video"],JSON.json(v))
 elseif k in ("other_title","other_description","es_title","es_description")
  l=startswith(k,"es_") ? "es" : _other_lang(e); part=endswith(k,"title") ? "title" : "description"
  e=set_path(e,["translations",l,part],isempty(s) ? "null" : JSON.json(s))
  return _prune_translations(e)
 elseif f.kind==:price
  isempty(s) && return _put(e,Val(:price_nok),nothing)
  v=_parse_price(s); isnothing(v) && bad("«$s» er ikke et helt tall. Er inngangen frivillig, velg «Betal det du kan»: Ja.")
  e=_put(e,Val(:price_nok),v[1])          # a number changes the amount only; «betal det du kan, 100» also sets the flag
  return v[2] ? _put(e,Val(:pay_what_you_can),true) : e
 elseif f.kind==:int
  isempty(s) && return set_path(e,_path(k),"null")
  n=tryparse(Int,replace(s,r"\s|kr\.?$|,-$"=>"")); isnothing(n) && bad("«$s» er ikke et helt tall.")
  return set_path(e,_path(k),string(n))
 elseif f.kind==:list
  return set_path(e,_path(k),JSON.json(String[String(strip(x)) for x in split(s,',') if !isempty(strip(x))]))
 end
 k=="title" && return set_path(e,["title"],JSON.json(s))   # never null; `check` reports an empty title
 set_path(e,_path(k),isempty(s) ? "null" : JSON.json(s))
end
function set_field(e::Event, f::FormField, vals::Vector{String})
 order=[v for (v,_) in f.choices]
 vs=sort!(unique(filter(in(order),vals)),by=v->findfirst(==(v),order))
 k=f.key
 k=="types" && return _put(e,Val(:types),vs)
 k=="music_style" && return _put(e,Val(:music_style),vs)
 v=isempty(vs) ? nothing : vs[1]
 k=="status" && return _put(e,Val(:status),something(v,"scheduled"))
 k=="lang" && return (v=="en" || !isnothing(e.lang)) ? _put(e,Val(:lang),something(v,"nb")) : e   # Norwegian stays implicit
 k=="pay_what_you_can" && return _put(e,Val(:pay_what_you_can),v=="ja" ? true : nothing)   # left out unless true
 throw(ArgumentError("«$(f.label)» has no choices"))
end
_field(k)=only(filter(f->f.key==k,form_fields()))
"An event without empty translations (the schema allows a missing language or text, not an empty one)."
function _prune_translations(e::Event)
 t=e.translations; isnothing(t) && return e
 for l in ("nb","en","es")
  x=getfield(t,Symbol(l))
  !isnothing(x) && isnothing(x.title) && isnothing(x.description) && (e=set_path(e,["translations",l],"null"); t=e.translations)
 end
 all(l->isnothing(getfield(t,Symbol(l))),(:nb,:en,:es)) ? _put(e,Val(:translations),nothing) : e
end
"`e` moved to day `d`: the start keeps its time, the end keeps its distance in days (offsets recomputed)."
function _move_event(e::Event, d::Date)
 s=something(_ymd(e.start),d); en=e.end_
 en=isnothing(en) ? nothing : _move_stamp(en,d+Day(Dates.value(something(_ymd(en),s)-s)))
 _put(_put(e,Val(:start),_move_stamp(e.start,d)),Val(:end_),en)
end
"The `check` problems that belong to field `f`, without the key prefix."
function field_problems(e::Event, f::FormField; problems=check(e))
 out=String[]
 for p in problems
  i=findfirst(": ",p); isnothing(i) && continue
  k=p[1:prevind(p,first(i))]
  any(c->k==c || startswith(k,c*"."),f.checks) && push!(out,p[nextind(p,last(i)):end])
 end
 out
end
"""
    new_event(; today=today(), city=site_city()) -> Event

A blank event for the form: today's date, status scheduled, the site's city, `first_seen`/`last_verified` today and
confidence 1 (an editor typed it).
"""
new_event(; today::Date=Dates.today(), city::AbstractString=site_city())=
 Event(title="",types=String[],status="scheduled",start=_ymd_str(today),venue=Venue(city=String(city)),teachers=String[],
       music_style=String[],first_seen=_ymd_str(today),last_verified=_ymd_str(today),confidence=1.0)
"The keys a new event file is written with: every field but `\$schema`, in schema order."
new_event_keys()=filter(!=("\$schema"),jsonkeys(Event))
"The id of a new event: `<series or slug of the title>-YYYY-MM-DD`, as the issue forms make it."
form_id(e::Event)="$(something(e.series,_slug(e.title)))-$(first(e.start,10))"
"""
    save_form_event(file, e, keys; root="events", today=today(), tree_check=validate_event_tree, others=[]) -> (file, errors)

Write the edited event `e` (`file === nothing` for a new one, which gets `form_id`) with `last_verified` today, after
`check`. Moves the file when the date or id changed; refuses to overwrite another event; rolls back when
`tree_check(root)` finds problems. `others` are more edited events as `(file, event, keys)` (the later dates of a
series, `copy_fields`), written in the same go: all or nothing. Returns the new file (or `nothing`) and the problems.
"""
function save_form_event(file::Union{Nothing,AbstractString}, e::Event, keys_::Vector{String}; root::AbstractString="events",
                         today::Date=Dates.today(), tree_check::C=validate_event_tree,
                         others::Vector{Tuple{String,Event,Vector{String}}}=Tuple{String,Event,Vector{String}}[]) where {C}
 isnothing(file) && (e=_put(e,Val(:id),form_id(e)))
 stamp(x)=_put(x,Val(:last_verified),_ymd_str(today))
 e=stamp(e); others=[(f,stamp(x),ks) for (f,x,ks) in others]
 errs=check(e)
 for (_,x,_) in others; append!(errs,("$(x.id): $m" for m in check(x))); end
 isempty(errs) || return (nothing,errs)
 new=event_path(e;root)
 ups=Tuple{Union{Nothing,String},String,String}[(file,new,event_text(e,keys_))]
 for (f,x,ks) in others; push!(ups,(f,event_path(x;root),event_text(x,ks))); end
 written,errs=_write_files!(ups,root;taken=p->"$p finnes allerede (samme id og dato)",check=tree_check)
 isempty(errs) ? (new,String[]) : (nothing,errs)
end
"""
    changed_fields(before, after; fields=form_fields()) -> Vector{FormField}

The fields an editor changed. «Dato» is never among them: a date isn't copied to other dates.
"""
changed_fields(before::Event, after::Event; fields=form_fields())=
 [f for f in fields if f.key!="date" && _fieldvalue(before,f)!=_fieldvalue(after,f)]
_fieldvalue(e::Event,f::FormField)=f.kind in (:choice,:multi) ? join(field_values(e,f),",") : field_text(e,f)
"""
    later_in_series(file, e; root="events") -> [(file, event, keys)]

The other events of `e`'s series from `e`'s date on, by start (what «Rett opp» calls «Denne og alle senere datoer i
serien»; a festival's other events the same day count). Empty when `e` has no series.
"""
function later_in_series(file::Union{Nothing,AbstractString}, e::Event; root::AbstractString="events")
 s=e.series; isnothing(s) && return Tuple{String,Event,Vector{String}}[]
 d=_firstday(e); me=isnothing(file) ? "" : normpath(file)
 [x for x in find_events(["series:$s"];root,from=d) if x[2].series==s && _firstday(x[2])>=d && normpath(x[1])!=me]
end
"""
    copy_fields(target, source, fields) -> Event

`target` with `fields` set to their values in `source`, through `set_field`, so the target keeps its own date: a start
or end time is recomputed for that date (summer/winter time), and an end some days later keeps its distance in days.
"""
function copy_fields(t::Event, src::Event, fields)
 for f in fields
  if f.key=="end" && !isnothing(src.end_) && isnothing(_form_hm(field_text(src,f);allow24=true))   # an end on another day
   n=Dates.value(something(_ymd(src.end_),_firstday(src))-_firstday(src))
   t=_put(t,Val(:end_),_move_stamp(src.end_,_firstday(t)+Day(n)))
  else
   t=f.kind in (:choice,:multi) ? set_field(t,f,field_values(src,f)) : set_field(t,f,field_text(src,f))
  end
 end
 t
end
"""
    later_in_selection(file, e, files; root="events") -> [(file, event, keys)]

The events among `files` (an editor's search result) from `e`'s date on, other than `file` itself, by start.
"""
function later_in_selection(file::Union{Nothing,AbstractString}, e::Event, files; root::AbstractString="events")
 want=Set(normpath.(files)); d=_firstday(e); me=isnothing(file) ? "" : normpath(file)
 isempty(want) && return Tuple{String,Event,Vector{String}}[]
 [x for x in find_events(String[];root,from=d) if normpath(x[1]) in want && normpath(x[1])!=me && _firstday(x[2])>=d]
end
_org(e::Event)=lowercase(join(split(something(e.organizer,""))," "))
"""
    split_by_organizer(e, events) -> (same, other)

The guardrail for changing several events at once: only events with `e`'s organiser (ignoring case and spacing; an
event without one only matches others without one) may be changed. `other` are the ones left out.
"""
split_by_organizer(e::Event, xs)=(filter(x->_org(x[2])==_org(e),xs),filter(x->_org(x[2])!=_org(e),xs))
"Whether `x` has the same value as `e` in field `f` (used to warn before overwriting a date's own value)."
same_field(x::Event,e::Event,f::FormField)=_fieldvalue(x,f)==_fieldvalue(e,f)
"""
    series_differences(e, later; fields=form_fields()) -> [(field, n, shared)]

The fields in which the events `later` (`(file, event, keys)`, e.g. `later_in_series`) differ from `e`, in form order
(never the date): `n` of them differ, and `shared` is the one value they all have when they agree, else `nothing`.
A field where every later date still has one other value is the typical trace of a correction made for one date
only, when it was meant for the whole series.
"""
function series_differences(e::Event, later; fields::Vector{FormField}=form_fields())
 out=Tuple{FormField,Int,Union{Nothing,String}}[]
 isempty(later) && return out
 for f in fields
  f.key=="date" && continue
  n=count(x->!same_field(x[2],e,f),later); n==0 && continue
  vals=unique(_fieldvalue(x[2],f) for x in later)
  push!(out,(f,n,length(vals)==1 && n==length(later) ? field_text(later[1][2],f) : nothing))
 end
 out
end
"""
    event_search_text(e) -> String

What the editors' event list searches, in lower case: like the web page's search box (title in every language,
venue and address, organiser, DJ, description, «avlyst») plus what editors know events by: teachers, types, id,
series, the date and the weekday («lørdag 24. oktober», `2026-10-24`).
"""
function event_search_text(e::Event)
 parts=String[e.id,e.title,something(e.series,""),e.start,something(e.organizer,""),something(e.dj,""),
  join(something(e.teachers,String[])," "),something(e.description,""),_searchtext(e.venue),join(e.types," "),join(_type_label.(e.types)," ")]
 d=_ymd(e.start); isnothing(d) || push!(parts,_longday(d))
 t=e.translations
 if !isnothing(t)
  for x in (t.nb,t.en,t.es); isnothing(x) || append!(parts,(something(x.title,""),something(x.description,""))); end
 end
 e.status=="cancelled" && push!(parts,"avlyst cancelled")
 lowercase(join(parts," "))
end
"""
    search_matches(e, query; text=event_search_text(e)) -> Bool

Whether `e` matches every word of `query` (ignoring case): a plain word anywhere in `event_search_text`, a
`key:text` word in that key only, as `tangoedit`'s search terms (`type:class`, `venue:sentralen`, `series:otra`).
An empty query matches everything.
"""
function search_matches(e::Event, query::AbstractString; text::AbstractString=event_search_text(e))
 for w in split(lowercase(query))
  t=SearchTerm(w)
  (isnothing(t.key) ? occursin(t.text,text) : matches(e,t)) || return false
 end
 true
end
