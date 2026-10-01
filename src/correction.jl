# Correction form (.github/ISSUE_TEMPLATE/rett-arrangement.yml): prefilled «Rett opp» links and applying submitted changes.
# Semantics: a blank field means "unchanged", `-` clears an optional field.
const CORRECTION_FIELDS=["Arrangement-ID","Gjelder","Status","Tittel","Type","Dato","Starttid","Sluttid","Sted","Adresse","Arrangør",
 "DJ","Lærere","Pris (kr)","Studentpris (kr)","Kurspris (kr)","Musikk","Flyer","Video","Lenke","Beskrivelse","Kommentar","Samtykke"]
# form field id (URL prefill key) => form label, for the fields prefilled with the event's current value
const CORRECTION_IDS=["arrangement_id"=>"Arrangement-ID","tittel"=>"Tittel","dato"=>"Dato","starttid"=>"Starttid","sluttid"=>"Sluttid",
 "sted"=>"Sted","adresse"=>"Adresse","arrangor"=>"Arrangør","dj"=>"DJ","laerere"=>"Lærere","pris"=>"Pris (kr)",
 "studentpris"=>"Studentpris (kr)","kurspris"=>"Kurspris (kr)","flyer"=>"Flyer","video"=>"Video","lenke"=>"Lenke","beskrivelse"=>"Beskrivelse"]
const REQUIRED_LABELS=Set(["Tittel","Dato","Starttid","Sted","Adresse","Arrangør","Lenke"])
const SERIES_SCOPE="Denne og alle senere datoer i serien"
const MAX_URL=6000
_s(x)=isnothing(x) ? "" : string(x)
_hhmm(stamp)=(s=_s(stamp); occursin('T',s) ? s[12:16] : "")
function _video_url(v)
 v isa AbstractDict || return ""
 p=_s(get(v,"platform",nothing)); id=_s(get(v,"id",nothing))
 p=="youtube" ? "https://youtu.be/$id" : p=="vimeo" ? "https://vimeo.com/$id" : ""
end
"An event's current values in correction-form syntax, keyed by form field id (also the URL prefill keys)."
function correction_fields(e)
 v=get(e,"venue",nothing); v isa AbstractDict || (v=Dict{String,Any}())
 Dict{String,String}("arrangement_id"=>_s(e["id"]),"tittel"=>_s(get(e,"title",nothing)),"dato"=>first(_s(get(e,"start",nothing)),10),
  "starttid"=>_hhmm(get(e,"start",nothing)),"sluttid"=>_hhmm(get(e,"end",nothing)),"sted"=>_s(get(v,"name",nothing)),
  "adresse"=>_s(get(v,"address",nothing)),"arrangor"=>_s(get(e,"organizer",nothing)),"dj"=>_s(get(e,"dj",nothing)),
  "laerere"=>join(something(get(e,"teachers",nothing),Any[]),", "),"pris"=>_s(get(e,"price_nok",nothing)),
  "studentpris"=>_s(get(e,"student_price_nok",nothing)),"kurspris"=>_s(get(e,"class_price_nok",nothing)),
  "flyer"=>_s(get(e,"flyer_url",nothing)),"video"=>_video_url(get(e,"video",nothing)),"lenke"=>_s(get(e,"link",nothing)),
  "beskrivelse"=>_s(get(e,"description",nothing)))
end
"Percent-encode `s` as UTF-8 for a URL query value (RFC 3986 unreserved characters kept)."
_urlenc(s)=join((c<0x80 && (isletter(Char(c)) || isdigit(Char(c)) || Char(c) in "-_.~")) ? string(Char(c)) : "%"*uppercase(string(c;base=16,pad=2)) for c in codeunits(s))
"«Rett opp» link: the correction form prefilled with `e`'s current values (description dropped if the URL gets too long)."
function correction_url(e; base=CORRECT_URL)
 f=correction_fields(e); d=Date(first(_s(e["start"]),10))
 params=["title"=>"Rettelse: $(f["tittel"]) ($(day(d)). $(_MO[month(d)]))";[k=>f[k] for (k,_) in CORRECTION_IDS if !isempty(f[k])]]
 url(ps)=base*join(("&$(k)=$(_urlenc(v))" for (k,v) in ps))
 u=url(params); length(u)>MAX_URL ? url(filter(p->first(p)!="beskrivelse",params)) : u
end
"Display values for the before/after table."
function _display(e)
 f=correction_fields(e)
 merge(Dict(lbl=>f[id] for (id,lbl) in CORRECTION_IDS if id!="arrangement_id"),
  Dict("Type"=>_type_label(_s(get(e,"type","other"))),"Musikk"=>join(_music_label.(string.(something(get(e,"music_style",nothing),Any[]))),", "),
   "Status"=>_s(get(e,"status",nothing))=="cancelled" ? "Avlyst" : "Gjennomføres"))
end
"""
    apply_correction(fields, root; today=Dates.today()) -> (updates, errors, changed)

`updates` is a vector of `(old_file, new_event)`; `changed` lists `(label, before, after)` for the first target.
Targets the event with «Arrangement-ID», or it and all later dates in its series («$SERIES_SCOPE»).
"""
function apply_correction(f::AbstractDict, root::AbstractString; today::Date=Dates.today())
 errs=String[]; err(m)=push!(errs,m); none=(Tuple{String,JSON.Object{String,Any}}[],errs,Tuple{String,String,String}[])
 get_(k)=String(strip(get(f,k,"")))
 id=get_("Arrangement-ID"); isempty(id) && (err("«Arrangement-ID» mangler – bruk «Rett opp»-lenken på arrangementet."); return none)
 tree=[(file,JSON.parsefile(file)) for file in event_files(root)]
 i=findfirst(((_,e),)->_s(get(e,"id",nothing))==id,tree)
 isnothing(i) && (err("Fant ikke arrangementet «$id». Det kan ha blitt endret eller fjernet."); return none)
 file,orig=tree[i]; cur=correction_fields(orig)
 ch=Dict{String,Any}()   # label => new value (`nothing` clears)
 for (fid,label) in CORRECTION_IDS
  fid=="arrangement_id" && continue
  s=get_(label); (isempty(s) || s==cur[fid]) && continue
  if s=="-"
   label in REQUIRED_LABELS ? err("«$label» kan ikke fjernes.") : !isempty(cur[fid]) && (ch[label]=nothing)
   continue
  end
  v,e=_parse_field(label,s); isnothing(e) ? (ch[label]=v) : err(e)
 end
 t=get_("Type")
 if !isempty(t) && t!="Som før"
  v,e=_parse_field("Type",t); isnothing(e) ? (v!=get(orig,"type",nothing) && (ch["Type"]=v)) : err(e)
 end
 m=get_("Musikk")
 if !isempty(_checked(m))
  v,e=_parse_field("Musikk",m); isnothing(e) ? (v!=collect(something(get(orig,"music_style",nothing),Any[])) && (ch["Musikk"]=v)) : err(e)
 end
 st=Dict("Avlyst"=>"cancelled","Gjennomføres"=>"scheduled")
 status=get(st,get_("Status"),nothing)
 !isnothing(status) && status!=something(get(orig,"status",nothing),"scheduled") && (ch["Status"]=status)
 isempty(_checked(get_("Samtykke"))) && err("«Samtykke» må krysses av.")
 series=get_("Gjelder")==SERIES_SCOPE
 haskey(ch,"Dato") && series && err("«Dato» kan bare endres for én dato om gangen – velg «Bare denne datoen».")
 haskey(ch,"Dato") && ch["Dato"]<today && err("«Dato» ($(ch["Dato"])) har allerede vært.")
 isempty(errs) && isempty(ch) && err("Ingen endringer funnet. Endre feltene som er feil (tomt felt = ingen endring).")
 isempty(errs) || return none
 d0=Date(first(_s(orig["start"]),10)); sid=get(orig,"series",nothing)
 targets=if series
  isnothing(sid) && (err("Arrangementet er ikke del av en serie – velg «Bare denne datoen»."); return none)
  sort([(fl,e) for (fl,e) in tree if get(e,"series",nothing)==sid && Date(first(_s(e["start"]),10))>=d0],by=x->_s(x[2]["start"]))
 else
  [(file,orig)]
 end
 updates=Tuple{String,JSON.Object{String,Any}}[]
 for (fl,e) in targets
  x=JSON.parse(JSON.json(e))   # deep copy, same key order
  apply!(k,v)=haskey(ch,k) && (x[v]=ch[k])
  apply!("Tittel","title"); apply!("Type","type"); apply!("Arrangør","organizer"); apply!("DJ","dj"); apply!("Lenke","link")
  apply!("Beskrivelse","description"); apply!("Flyer","flyer_url"); apply!("Video","video"); apply!("Musikk","music_style")
  apply!("Status","status"); haskey(ch,"Lærere") && (x["teachers"]=something(ch["Lærere"],Any[]))
  for (k,field) in PRICE_FIELDS; apply!(field,k); end
  if haskey(ch,"Sted") || haskey(ch,"Adresse")
   v=get(x,"venue",nothing); v isa AbstractDict || (v=JSON.Object{String,Any}("name"=>nothing,"address"=>nothing,"city"=>"Oslo"))
   haskey(ch,"Sted") && (v["name"]=ch["Sted"]); haskey(ch,"Adresse") && (v["address"]=ch["Adresse"]); x["venue"]=v
  end
  if haskey(ch,"Dato") || haskey(ch,"Starttid") || haskey(ch,"Sluttid")
   olds=Date(first(_s(e["start"]),10)); d=get(ch,"Dato",olds)
   h=_hhmm(e["start"]); s_=get(ch,"Starttid",isempty(h) ? nothing : h)
   en=_s(get(e,"end",nothing)); offset=isempty(en) ? 0 : Dates.value(Date(first(en,10))-olds)
   et=haskey(ch,"Sluttid") ? ch["Sluttid"] : (isempty(_hhmm(en)) ? nothing : _hhmm(en))
   x["start"]=_stamp(d,s_)
   x["end"]=if isnothing(et)
    haskey(ch,"Sluttid") || isempty(en) ? nothing : string(Date(first(en,10))+(d-olds))   # date-only end moves with the date
   elseif offset>=2 || isnothing(s_)
    _stamp(d+Day(offset),et)
   else
    _end_stamp(d,s_,et)
   end
  end
  x["last_verified"]=string(today)
  for msg in validate_event(x); err("$(x["id"]): $msg"); end
  push!(updates,(fl,x))
 end
 isempty(errs) || return none
 a,b=_display(orig),_display(updates[1][2])
 changed=[(lbl,a[lbl],b[lbl]) for lbl in CORRECTION_FIELDS if haskey(a,lbl) && a[lbl]!=b[lbl]]
 (updates,errs,changed)
end
