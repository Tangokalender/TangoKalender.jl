_esc(x)=replace(string(something(x,"")),'&'=>"&amp;",'<'=>"&lt;",'>'=>"&gt;",'"'=>"&quot;",'\''=>"&#39;")
_val(e,k,d="")=(v=get(e,k,d); isnothing(v) ? d : v)
_iso(e)=(s=string(_val(e,"start","")); isempty(s) ? "" : first(split(s,'T')))
_sortkey(e)=(s=string(_val(e,"start","")); isempty(s) ? "9999-12-31" : s)
const _WD=["mandag","tirsdag","onsdag","torsdag","fredag","lørdag","søndag"]
const _MO=["jan","feb","mar","apr","mai","jun","jul","aug","sep","okt","nov","des"]
"`(DateTime, has_time)` for an ISO `start`/`end` string (offset ignored), or `nothing`."
function _parse_dt(raw)
 isempty(raw) && return nothing
 try (DateTime(replace(first(split(raw,['+','Z'])),'T'=>' '),dateformat"yyyy-mm-dd HH:MM:SS"),occursin('T',raw)) catch; nothing end
end
_day(d)="$(_WD[dayofweek(d)]) $(day(d)). $(_MO[month(d)])"
_hm(dt)=Dates.format(dt,"HH:MM")
function _date_label(e)
 raw=string(_val(e,"start",""))
 if !isempty(raw)
  p=_parse_dt(raw)
  isnothing(p) && return (try Dates.format(Date(raw),"dd.mm.yyyy") catch; raw end)
  dt,timed=p; startl=timed ? "$(_day(dt)) · $(_hm(dt))" : _day(dt)
  q=_parse_dt(string(_val(e,"end",""))); isnothing(q) && return startl
  edt,etimed=q
  # an end at or before 06:00 the next day still belongs to the evening that started it
  eday=etimed && Date(edt)>Date(dt) && Time(edt)<=Time(6) ? Date(edt)-Day(1) : Date(edt)
  eday<Date(dt) && return startl
  eday==Date(dt) && return timed && etimed ? "$(startl)–$(_hm(edt))" : startl
  return "$(startl) – $(_day(eday))"
 end
 weekday=get(_WEEKDAYS,string(_val(e,"weekday","")),string(_val(e,"weekday",""))); st=string(_val(e,"start_time","")); en=string(_val(e,"end_time",""))
 repeat_text=_val(e,"recurrence","")=="weekly" ? "Ukentlig " : ""
 times=isempty(st) ? "" : isempty(en) ? st : "$(st)–$(en)"
 strip("$(repeat_text)$(weekday) · $(times)",[' ','·'])
end
_music(e)=[string(m) for m in something(_val(e,"music_style",Any[]),Any[])]
_http(u)=(s=string(something(u,"")); occursin(r"^https?://"i,s) ? s : "")
function _venue(e)
 v=_val(e,"venue",nothing)
 v isa AbstractDict || (v=Dict("name"=>v,"address"=>_val(e,"address",nothing),"city"=>_val(e,"city",nothing)))
 name=string(_val(v,"name","Sted ikke oppgitt")); addr=string(_val(v,"address","")); city=string(_val(v,"city","Oslo"))
 (isempty(name) ? "Sted ikke oppgitt" : name, isempty(addr) ? (isempty(city) ? "Oslo" : city) : addr)
end
function _video(e)
 v=_val(e,"video",nothing); v isa AbstractDict || return ""
 p=string(_val(v,"platform","")); id=string(_val(v,"id",""))
 src= p=="youtube" && occursin(r"^[A-Za-z0-9_-]{11}$",id) ? "https://www.youtube-nocookie.com/embed/$id" :
      p=="vimeo" && occursin(r"^[0-9]+$",id) ? "https://player.vimeo.com/video/$id" : ""
 isempty(src) ? "" : "<div class=\"video\"><iframe src=\"$src\" title=\"Video: $(_esc(_val(e,"title","")))\" loading=\"lazy\" allow=\"fullscreen; picture-in-picture\" allowfullscreen></iframe></div>"
end
function _price(e)
 parts=String[]
 for (k,label) in [("price_nok",""),("student_price_nok","student "),("class_price_nok","kurs ")]
  v=get(e,k,nothing); !isnothing(v) && push!(parts,"$(label)$(v) kr")
 end
 isempty(parts) ? "Pris ikke oppgitt" : join(parts," · ")
end
function _card(e; correct_url=CORRECT_URL)
 corr=isempty(_http(correct_url)) || isempty(string(_val(e,"id",""))) || isempty(string(_val(e,"start",""))) ? "" :
  "<a class=\"correct\" href=\"$(_esc(correction_url(e;base=_http(correct_url))))\" target=\"_blank\" rel=\"noopener\" aria-label=\"Rett opp: $(_esc(_val(e,"title","")))\">Rett opp ↗</a>"
 title=_esc(_val(e,"title","Uten tittel")); typ=lowercase(string(_val(e,"type","other"))); date=_esc(_date_label(e)); iso=_esc(_iso(e)); (vname,vaddr)=_venue(e); venue=_esc(vname); addr=_esc(vaddr); org=_esc(_val(e,"organizer","")); dj=_esc(_val(e,"dj","")); desc=_esc(_val(e,"description","")); source=_esc(_val(e,"source","Kilde")); url=_esc(_val(e,"source_url","")); pub=_esc(_val(e,"published_date","Ikke oppgitt")); cancelled=_val(e,"status","")=="cancelled"; series=_esc(_val(e,"series","")); search=lowercase(join([title,venue,addr,org,dj,desc,cancelled ? "avlyst" : ""]," ")); d=isempty(iso) ? "9999-12-31" : iso; music=_music(e); flyer=_esc(_http(_val(e,"flyer_url",""))); info=_esc(_http(_val(e,"link","")))
 link=isempty(url) ? "<span>$source</span>" : "<a href=\"$url\" target=\"_blank\" rel=\"noopener\">$source ↗</a>"
 djhtml=isempty(dj) ? "" : "<div><b>DJ:</b> $dj</div>"; orghtml=isempty(org) ? "" : "<div><b>Arrangør:</b> $org</div>"
 musichtml=isempty(music) ? "" : "<div class=\"music\">"*join(("<span class=\"chip music-chip\">$(_esc(_music_label(m)))</span>" for m in music),"")*"</div>"
 media=(isempty(flyer) ? "" : "<img class=\"flyer\" src=\"$flyer\" alt=\"Flyer: $title\" loading=\"lazy\">")*_video(e)
 mediahtml=isempty(media) ? "" : "<div class=\"media\">$media</div>"
 infohtml=isempty(info) ? "" : "<a href=\"$info\" target=\"_blank\" rel=\"noopener\">Mer info ↗</a>"
 """<article class="event$(cancelled ? " cancelled" : "")" data-type="$(_esc(typ))" data-date="$d" data-series="$series" data-search="$(_esc(search))" data-music="$(_esc(join(music," ")))"><aside>$date</aside><section><header><span>$(cancelled ? "<span class=\"chip avlyst\">Avlyst</span> " : "")<span class="chip">$(_esc(_type_label(typ)))</span></span><span class="price">$(_esc(_price(e)))</span></header><h2>$title</h2><div class="meta"><div><b>$venue</b><br><small>$addr</small></div>$djhtml$orghtml</div>$musichtml<p>$desc</p>$mediahtml<footer><span>Publisert: $pub</span><span class="links">$infohtml$link$corr</span></footer></section></article>"""
end
const REPO_URL="https://github.com/Tangokalender/TangoKalender.jl"
"Where the page's «Legg til arrangement» link points: the new-event issue form."
const SUBMIT_URL=REPO_URL*"/issues/new?template=nytt-arrangement.yml"
"Base of each card's «Rett opp» link: the correction issue form (prefilled by `correction_url`)."
const CORRECT_URL=REPO_URL*"/issues/new?template=rett-arrangement.yml"
function render_events_html(events; title="Oslo Tango",subtitle="Milongaer, practicaer, kurs og festivaler",generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"),submit_url=SUBMIT_URL,correct_url=CORRECT_URL)
 submit=_esc(_http(submit_url))
 hero_submit=isempty(submit) ? "" : "<a class=\"submit\" href=\"$submit\" target=\"_blank\" rel=\"noopener\">+ Legg til arrangement</a>"
 footer_submit=isempty(submit) ? "" : " · <a href=\"$submit\" target=\"_blank\" rel=\"noopener\">Legg til arrangement</a>"
 ev=sort(collect(events),by=_sortkey); cards=join((_card(e;correct_url) for e in ev),"\n"); types=sort(unique(lowercase(string(_val(e,"type","other"))) for e in ev)); opts=join(("<option value=\"$(_esc(t))\">$(_esc(_type_label(t)))</option>" for t in types),""); musics=sort(unique(m for e in ev for m in _music(e))); mopts=join(("<option value=\"$(_esc(m))\">$(_esc(_music_label(m)))</option>" for m in musics),"")
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title))</title><style>
:root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c}.hero{padding:48px 20px 82px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:1080px;margin:auto}.hero h1{font:500 clamp(2.5rem,7vw,4.8rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5}.hero .submit{display:inline-block;margin-top:10px;padding:10px 18px;border-radius:999px;background:white;color:var(--wine);font-weight:800;text-decoration:none}.hero .submit:hover{background:#f7dce5}.sitefooter a{color:var(--wine);font-weight:700}.filters{position:sticky;top:0;z-index:3;max-width:1080px;margin:-38px auto 24px;padding:14px;display:grid;grid-template-columns:2fr repeat(4,1fr);gap:10px;background:#fffffff2;border:1px solid white;border-radius:18px;box-shadow:0 12px 30px #29192118}.filters label{display:block;font-size:.68rem;text-transform:uppercase;color:var(--muted);font-weight:800;margin-bottom:4px}.filters input,.filters select{width:100%;padding:10px;border:1px solid var(--line);border-radius:10px;background:white}.main{max-width:1080px;margin:auto;padding:0 20px 60px}.summary{display:flex;justify-content:space-between;color:var(--muted);margin-bottom:14px}.summary button{border:0;background:none;color:var(--wine);font-weight:800}.events{display:grid;gap:15px}.event{display:grid;grid-template-columns:180px 1fr;background:white;border:1px solid var(--line);border-radius:18px;overflow:hidden;box-shadow:0 5px 18px #2919210b}.event aside{padding:24px;background:#eee5de;font-weight:800}.event section{padding:22px}.event header,.event footer{display:flex;justify-content:space-between;gap:12px}.chip{padding:5px 10px;border-radius:999px;background:#f2dce4;color:#76203e;text-transform:uppercase;font-size:.7rem;font-weight:850}.price,small,.event footer{color:var(--muted)}h2{font:500 1.7rem Georgia;margin:12px 0}.meta{display:flex;flex-wrap:wrap;gap:15px 28px}.event p{line-height:1.55}.event footer{border-top:1px solid #eee7e1;padding-top:12px;font-size:.78rem}.event footer a{color:var(--wine);font-weight:800;text-decoration:none}.music{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}.music-chip{background:#efe7dd;color:#5b4636}.media{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:12px 0}.flyer{width:100%;border-radius:12px;object-fit:cover}.video{position:relative;aspect-ratio:16/9}.video iframe{position:absolute;inset:0;width:100%;height:100%;border:0;border-radius:12px}.links{display:flex;gap:14px;flex-wrap:wrap}.event footer a.correct{color:var(--muted);font-weight:600}.cancelled h2,.cancelled aside{text-decoration:line-through}.cancelled section>*:not(header){opacity:.6}.avlyst{background:#b3261e;color:white}.hidden{display:none}.empty{display:none;text-align:center;padding:40px}.sitefooter{text-align:center;color:var(--muted);padding:20px;font-size:.8rem}@media(max-width:760px){.filters{position:relative;margin:-42px 14px 20px;grid-template-columns:1fr 1fr}.search{grid-column:1/-1}.event{grid-template-columns:1fr}.event aside{padding:14px 20px}.main{padding:0 14px 40px}}@media(max-width:460px){.filters{grid-template-columns:1fr}.search{grid-column:auto}.event header,.event footer{flex-direction:column}}
</style></head><body><div class="hero"><div class="wrap"><small>ARGENTINSK TANGO I OSLO</small><h1>$(_esc(title))</h1><p>$(_esc(subtitle))</p>$hero_submit</div></div><div class="filters"><div class="search"><label>Søk</label><input id="q" placeholder="Sted, DJ, arrangør …"></div><div><label>Type</label><select id="type"><option value="">Alle typer</option>$opts</select></div><div><label>Musikk</label><select id="music"><option value="">All musikk</option>$mopts</select></div><div><label>Tidspunkt</label><select id="when"><option value="all">Alle</option><option value="today">I dag</option><option value="week">Neste 7 dager</option><option value="month">Neste 30 dager</option><option value="recurring">Faste aktiviteter</option></select></div><div><label>Sortering</label><select id="sort"><option value="asc">Tidligste først</option><option value="desc">Seneste først</option><option value="title">Alfabetisk</option></select></div></div><main class="main"><div class="summary"><span id="count"></span><button id="reset">Nullstill</button></div><div class="events" id="events">$cards</div><div class="empty" id="empty">Ingen treff</div></main><div class="sitefooter">Generert $(_esc(generated_at)) · Kontroller alltid detaljer hos arrangøren.$footer_submit</div><script>
const cards=[...document.querySelectorAll('.event')],q=document.querySelector('#q'),type=document.querySelector('#type'),music=document.querySelector('#music'),when=document.querySelector('#when'),sort=document.querySelector('#sort'),box=document.querySelector('#events'),count=document.querySelector('#count'),empty=document.querySelector('#empty');function day(d){return new Date(d.getFullYear(),d.getMonth(),d.getDate())}function apply(){let now=day(new Date()),limit=new Date(now);if(when.value==='week')limit.setDate(limit.getDate()+7);if(when.value==='month')limit.setDate(limit.getDate()+30);let v=[];cards.forEach(c=>{let rec=c.dataset.date==='9999-12-31',ser=rec||c.dataset.series!=='',d=rec?null:new Date(c.dataset.date+'T00:00:00'),oktime=true;if(when.value==='today')oktime=!rec&&d.getTime()===now.getTime();else if(['week','month'].includes(when.value))oktime=!rec&&d>=now&&d<=limit;else if(when.value==='recurring')oktime=ser;let ok=(!type.value||c.dataset.type===type.value)&&(!music.value||c.dataset.music.split(' ').includes(music.value))&&(!q.value||c.dataset.search.includes(q.value.toLowerCase()))&&oktime;c.classList.toggle('hidden',!ok);if(ok)v.push(c)});v.sort((a,b)=>sort.value==='title'?a.querySelector('h2').textContent.localeCompare(b.querySelector('h2').textContent,'nb'):(sort.value==='desc'?-1:1)*a.dataset.date.localeCompare(b.dataset.date));v.forEach(c=>box.appendChild(c));count.textContent=`\${v.length} av \${cards.length} arrangementer`;empty.style.display=v.length?'none':'block'}[q,type,music,when,sort].forEach(x=>x.addEventListener(x===q?'input':'change',apply));reset.onclick=()=>{q.value='';type.value='';music.value='';when.value='all';sort.value='asc';apply()};apply();</script></body></html>"""
end
function render_events_file(input::AbstractString,output::AbstractString="index.html";kwargs...)
 html=render_events_html(load_events(input);kwargs...); mkpath(dirname(abspath(output))); write(output,html); output
end
