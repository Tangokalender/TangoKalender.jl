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
"Last day of an event: an end at or before 06:00 the next day still belongs to the evening that started it."
_evening_end(dt,edt,etimed)=etimed && Date(edt)>Date(dt) && Time(edt)<=Time(6) ? Date(edt)-Day(1) : Date(edt)
"`data-end` for the page's date filters: the last day the event runs (start day if no usable end)."
function _end_day(e)
 iso=_iso(e); isempty(iso) && return "9999-12-31"
 p=_parse_dt(string(_val(e,"start",""))); q=_parse_dt(string(_val(e,"end","")))
 (isnothing(p) || isnothing(q)) && return iso
 string(max(_evening_end(p[1],q[1],q[2]),Date(p[1])))
end
function _date_label(e)
 raw=string(_val(e,"start",""))
 if !isempty(raw)
  p=_parse_dt(raw)
  isnothing(p) && return (try Dates.format(Date(raw),"dd.mm.yyyy") catch; raw end)
  dt,timed=p; startl=timed ? "$(_day(dt)) · $(_hm(dt))" : _day(dt)
  q=_parse_dt(string(_val(e,"end",""))); isnothing(q) && return startl
  edt,etimed=q
  eday=_evening_end(dt,edt,etimed)
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
# Small monochrome line icons (tango-argentin.fr style). One hidden <svg> sprite per page; rows reference it with
# <use>. Icons are decorative (aria-hidden); `_icon(name,label)` adds a visually hidden text label for screen readers.
const _ICON_PATHS=Dict(
 "pin"=>"<path d=\"M12 21s-6.5-5.8-6.5-10.5a6.5 6.5 0 0 1 13 0C18.5 15.2 12 21 12 21z\"/><circle cx=\"12\" cy=\"10.5\" r=\"2.3\"/>",
 "price"=>"<path d=\"M4 7.5h16v3a1.8 1.8 0 0 0 0 3.6v3H4v-3a1.8 1.8 0 0 0 0-3.6z\"/><path d=\"M14.5 8v1.5M14.5 11.3v1.4M14.5 14.5V16\"/>",
 "dj"=>"<path d=\"M4.5 15v-2.5a7.5 7.5 0 0 1 15 0V15\"/><rect x=\"3.5\" y=\"14\" width=\"4\" height=\"6\" rx=\"1.5\"/><rect x=\"16.5\" y=\"14\" width=\"4\" height=\"6\" rx=\"1.5\"/>",
 "teachers"=>"<circle cx=\"9\" cy=\"8\" r=\"3\"/><path d=\"M3.5 19.5a5.5 5.5 0 0 1 11 0\"/><circle cx=\"17\" cy=\"9\" r=\"2.3\"/><path d=\"M15.8 14.3a4.3 4.3 0 0 1 4.9 4.4\"/>",
 "org"=>"<path d=\"M5.5 21V4\"/><path d=\"M5.5 4.5h11l-2 3.75 2 3.75h-11\"/>",
 "clock"=>"<circle cx=\"12\" cy=\"12\" r=\"8.5\"/><path d=\"M12 7.5V12l3 2\"/>",
 "music"=>"<path d=\"M9 17.5V5.5l10-2v12\"/><circle cx=\"6.7\" cy=\"17.5\" r=\"2.3\"/><circle cx=\"16.7\" cy=\"15.5\" r=\"2.3\"/>",
 "calendar"=>"<rect x=\"4\" y=\"5.5\" width=\"16\" height=\"14.5\" rx=\"2\"/><path d=\"M4 10h16M9 3.5v4M15 3.5v4\"/>")
const _SPRITE="<svg width=\"0\" height=\"0\" style=\"position:absolute\" aria-hidden=\"true\" focusable=\"false\">"*
 join(("<symbol id=\"i-$k\" viewBox=\"0 0 24 24\">$v</symbol>" for (k,v) in sort(collect(_ICON_PATHS))),"")*"</svg>"
"Inline icon referencing the page sprite; `label` becomes screen-reader text («DJ: »)."
function _icon(name,label="")
 haskey(_ICON_PATHS,name) || throw(ArgumentError("unknown icon $name"))
 "<svg class=\"ic\" aria-hidden=\"true\" focusable=\"false\"><use href=\"#i-$name\"/></svg>"*(isempty(label) ? "" : "<span class=\"sr\">$label: </span>")
end
function _card(e; correct_url=CORRECT_URL, links=false)
 corr=isempty(_http(correct_url)) || isempty(string(_val(e,"id",""))) || isempty(string(_val(e,"start",""))) ? "" :
  "<a class=\"correct\" href=\"$(_esc(correction_url(e;base=_http(correct_url))))\" target=\"_blank\" rel=\"noopener\" aria-label=\"Rett opp: $(_esc(_val(e,"title","")))\">Rett opp ↗</a>"
 title=_esc(_val(e,"title","Uten tittel")); typ=lowercase(string(_val(e,"type","other"))); date=_esc(_date_label(e)); iso=_esc(_iso(e)); (vname,vaddr)=_venue(e); venue=_esc(vname); addr=_esc(vaddr); org=_esc(_val(e,"organizer","")); dj=_esc(_val(e,"dj","")); desc=_esc(_val(e,"description","")); source=_esc(_val(e,"source","Kilde")); url=_esc(_val(e,"source_url","")); pub=_esc(_val(e,"published_date","Ikke oppgitt")); cancelled=_val(e,"status","")=="cancelled"; series=_esc(_val(e,"series","")); search=lowercase(join([title,venue,addr,org,dj,desc,cancelled ? "avlyst" : ""]," ")); d=isempty(iso) ? "9999-12-31" : iso; music=_music(e); flyer=_esc(_http(_val(e,"flyer_url",""))); info=_esc(_http(_val(e,"link","")))
 link=isempty(url) ? "<span>$source</span>" : "<a href=\"$url\" target=\"_blank\" rel=\"noopener\">$source ↗</a>"
 djhtml=isempty(dj) ? "" : "<div title=\"DJ\">$(_icon("dj","DJ"))$dj</div>"; orghtml=isempty(org) ? "" : "<div title=\"Arrangør\">$(_icon("org","Arrangør"))$org</div>"
 musichtml=isempty(music) ? "" : "<div class=\"music\">"*_icon("music","Musikk")*join(("<span class=\"chip music-chip\">$(_esc(_music_label(m)))</span>" for m in music),"")*"</div>"
 media=(isempty(flyer) ? "" : "<img class=\"flyer\" src=\"$flyer\" alt=\"Flyer: $title\" loading=\"lazy\">")*_video(e)
 mediahtml=isempty(media) ? "" : "<div class=\"media\">$media</div>"
 infohtml=isempty(info) ? "" : "<a href=\"$info\" target=\"_blank\" rel=\"noopener\">Mer info ↗</a>"
 """<article class="event ev$(cancelled ? " cancelled" : "")" $(_data_attrs(e))><aside>$date</aside><section><header><span>$(cancelled ? "<span class=\"chip avlyst\">Avlyst</span> " : "")<span class="chip">$(_esc(_type_label(typ)))</span></span><span class="price">$(_icon("price","Pris"))$(_esc(_price(e)))</span></header><h2>$(_title_html(e,links))</h2><div class="meta"><div title="Sted">$(_icon("pin","Sted"))<b>$venue</b><br><small>$addr</small></div>$djhtml$orghtml</div>$musichtml<p>$desc</p>$mediahtml<footer><span>Publisert: $pub</span><span class="links">$infohtml$link$corr</span></footer></section></article>"""
end
const REPO_URL="https://github.com/Tangokalender/TangoKalender.jl"
"Where the page's «Legg til arrangement» link points: the new-event issue form."
const SUBMIT_URL=REPO_URL*"/issues/new?template=nytt-arrangement.yml"
"Base of each card's «Rett opp» link: the correction issue form (prefilled by `correction_url`)."
const CORRECT_URL=REPO_URL*"/issues/new?template=rett-arrangement.yml"
"The JSON issue form used with LLM-extracted events (see for-ki.html / llms.txt)."
const JSON_FORM_URL=REPO_URL*"/issues/new?template=nytt-arrangement-json.yml"
"Published site (GitHub Pages); also where the schemas are served."
const SITE_URL="https://tangokalender.github.io/TangoKalender.jl"
const _CSS=""":root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c}.hero{padding:48px 20px 82px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:1080px;margin:auto}.hero h1{font:500 clamp(2.5rem,7vw,4.8rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5}.hero .submit{display:inline-block;margin-top:10px;padding:10px 18px;border-radius:999px;background:white;color:var(--wine);font-weight:800;text-decoration:none}.hero .submit:hover{background:#f7dce5}.hero .submit.ghost{background:transparent;color:white;border:1px solid #f7dce5;margin-left:6px}.hero .submit.ghost:hover{background:#ffffff1f}.sitefooter a{color:var(--wine);font-weight:700}.filters{position:sticky;top:0;z-index:3;max-width:1080px;margin:-38px auto 24px;padding:14px;display:grid;grid-template-columns:2fr repeat(4,1fr);gap:10px;background:#fffffff2;border:1px solid white;border-radius:18px;box-shadow:0 12px 30px #29192118}.filters label{display:block;font-size:.68rem;text-transform:uppercase;color:var(--muted);font-weight:800;margin-bottom:4px}.filters input,.filters select{width:100%;padding:10px;border:1px solid var(--line);border-radius:10px;background:white}.main{max-width:1080px;margin:auto;padding:0 20px 60px}.summary{display:flex;justify-content:space-between;color:var(--muted);margin-bottom:14px}.summary button{border:0;background:none;color:var(--wine);font-weight:800}.events{display:grid;gap:15px}.event{display:grid;grid-template-columns:180px 1fr;background:white;border:1px solid var(--line);border-radius:18px;overflow:hidden;box-shadow:0 5px 18px #2919210b}.event aside{padding:24px;background:#eee5de;font-weight:800}.event section{padding:22px}.event header,.event footer{display:flex;justify-content:space-between;gap:12px}.chip{padding:5px 10px;border-radius:999px;background:#f2dce4;color:#76203e;text-transform:uppercase;font-size:.7rem;font-weight:850}.price,small,.event footer{color:var(--muted)}h2{font:500 1.7rem Georgia;margin:12px 0}.meta{display:flex;flex-wrap:wrap;gap:15px 28px}.event p{line-height:1.55}.event footer{border-top:1px solid #eee7e1;padding-top:12px;font-size:.78rem}.event footer a{color:var(--wine);font-weight:800;text-decoration:none}.music{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}.music-chip{background:#efe7dd;color:#5b4636}.media{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:12px 0}.flyer{width:100%;border-radius:12px;object-fit:cover}.video{position:relative;aspect-ratio:16/9}.video iframe{position:absolute;inset:0;width:100%;height:100%;border:0;border-radius:12px}.links{display:flex;gap:14px;flex-wrap:wrap}.event footer a.correct{color:var(--muted);font-weight:600}.cancelled h2,.cancelled aside{text-decoration:line-through}.cancelled section>*:not(header){opacity:.6}.avlyst{background:#b3261e;color:white}.hidden{display:none}.empty{display:none;text-align:center;padding:40px}.sitefooter{text-align:center;color:var(--muted);padding:20px;font-size:.8rem}@media(max-width:760px){.filters{position:relative;margin:-42px 14px 20px;grid-template-columns:1fr 1fr}.search{grid-column:1/-1}.event{grid-template-columns:1fr}.event aside{padding:14px 20px}.main{padding:0 14px 40px}}@media(max-width:460px){.filters{grid-template-columns:1fr}.search{grid-column:auto}.event header,.event footer{flex-direction:column}}.tabs{display:flex;gap:6px;margin-top:18px;flex-wrap:wrap}.tabs a{color:#f7dce5;text-decoration:none;font-weight:800;padding:7px 14px;border-radius:999px;border:1px solid #ffffff40}.tabs a.on{background:white;color:var(--wine);border-color:white}.ev h2 a,.ev h3 a{color:inherit;text-decoration:none}.ev h2 a:hover,.ev h3 a:hover{text-decoration:underline}.group{margin-bottom:18px}.dayhead{font:600 1.05rem Georgia;margin:0 0 6px;padding:8px 2px;border-bottom:2px solid var(--wine);color:var(--wine)}.row{display:grid;grid-template-columns:110px 1fr;gap:4px 16px;padding:10px 4px;border-bottom:1px solid var(--line);background:transparent}.row .time{font-weight:800;font-variant-numeric:tabular-nums}.row h3{display:inline;font:600 1.02rem Inter,system-ui,sans-serif;margin:0 8px 0 0}.row .chip{font-size:.6rem;padding:3px 8px;vertical-align:2px}.row .where,.row .facts,.row .lead{color:var(--muted);font-size:.86rem;margin-top:2px}.row .lead{color:#3b3433}.row .dayn{font-size:.72rem;color:var(--muted);margin-left:6px}.row.cancelled h3,.row.cancelled .time{text-decoration:line-through}.group .none{display:none;color:var(--muted);font-size:.86rem;padding:8px 4px}.group.empty .none{display:block}.week.off{display:none}.weeknav{display:flex;gap:8px;align-items:center;justify-content:space-between;margin:0 0 14px}.weeknav button{border:1px solid var(--line);background:white;border-radius:999px;padding:8px 14px;font-weight:800;color:var(--wine);cursor:pointer}.week>h2{font:500 1.5rem Georgia;margin:6px 0 12px}.feeds a{white-space:nowrap}.ic{width:1.05em;height:1.05em;vertical-align:-.17em;margin-right:.32em;flex:none;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;opacity:.75}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);clip-path:inset(50%);white-space:nowrap}.row .facts .f{display:inline-block;margin-right:16px;white-space:nowrap}.music .ic{align-self:center}@media(max-width:560px){.row{grid-template-columns:1fr}.row .time{font-size:.9rem}}"""
"Shared page script: filters on `.ev` rows, per-day group hiding, and week navigation (week view)."
const _JS=raw"""(function(){const $=s=>document.querySelector(s),rows=[...document.querySelectorAll('.ev')],groups=[...document.querySelectorAll('.group')],q=$('#q'),type=$('#type'),music=$('#music'),when=$('#when'),sort=$('#sort'),box=$('#events'),count=$('#count'),empty=$('#empty'),total=new Set(rows.map(c=>c.dataset.eid)).size;function day(d){return new Date(d.getFullYear(),d.getMonth(),d.getDate())}function apply(){let now=day(new Date()),limit=new Date(now),w=when?when.value:'any';if(w==='week')limit.setDate(limit.getDate()+7);if(w==='month')limit.setDate(limit.getDate()+30);let v=[];rows.forEach(c=>{let rec=c.dataset.date==='9999-12-31',ser=rec||c.dataset.series!=='',d=rec?null:new Date(c.dataset.date+'T00:00:00'),en=rec?null:new Date(c.dataset.end+'T00:00:00'),future=rec||en>=now,oktime=true;if(w==='upcoming')oktime=future;else if(w==='today')oktime=!rec&&d<=now&&en>=now;else if(w==='week'||w==='month')oktime=!rec&&en>=now&&d<=limit;else if(w==='recurring')oktime=ser&&future;let ok=(!type||!type.value||c.dataset.type===type.value)&&(!music||!music.value||c.dataset.music.split(' ').includes(music.value))&&(!q||!q.value||c.dataset.search.includes(q.value.toLowerCase()))&&oktime;c.classList.toggle('hidden',!ok);if(ok)v.push(c)});if(sort&&box){v.sort((a,b)=>sort.value==='title'?a.querySelector('h2').textContent.localeCompare(b.querySelector('h2').textContent,'nb'):(sort.value==='desc'?-1:1)*a.dataset.date.localeCompare(b.dataset.date));v.forEach(c=>box.appendChild(c))}let vis=new Set(v.map(c=>c.dataset.group));groups.forEach(g=>{let has=vis.has(g.dataset.group);g.dataset.keep?g.classList.toggle('empty',!has):g.classList.toggle('hidden',!has)});let n=new Set(v.map(c=>c.dataset.eid)).size;if(count)count.textContent=n+' av '+total+' arrangementer';if(empty)empty.style.display=v.length?'none':'block'}[q,type,music,when,sort].forEach(x=>x&&x.addEventListener(x===q?'input':'change',apply));let r=$('#reset');if(r)r.onclick=()=>{if(q)q.value='';if(type)type.value='';if(music)music.value='';if(when)when.value='upcoming';if(sort)sort.value='asc';apply()};window.apply=apply;apply();
const weeks=[...document.querySelectorAll('.week')];if(weeks.length){function isoWeek(d){let t=new Date(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())),n=t.getUTCDay()||7;t.setUTCDate(t.getUTCDate()+4-n);let y=t.getUTCFullYear(),w=Math.ceil(((t-Date.UTC(y,0,1))/864e5+1)/7);return y+'-W'+String(w).padStart(2,'0')}function current(){let k=isoWeek(new Date()),i=weeks.findIndex(x=>x.dataset.week>=k);return i<0?weeks.length-1:i}let i=current();function show(j,push){i=Math.max(0,Math.min(weeks.length-1,j));weeks.forEach((x,k)=>x.classList.toggle('off',k!==i));if(push)history.replaceState(null,'','#'+weeks[i].id)}function fromHash(){let k=weeks.findIndex(x=>'#'+x.id===location.hash);show(k<0?current():k,false)}$('#prevw').onclick=()=>show(i-1,true);$('#nextw').onclick=()=>show(i+1,true);$('#todayw').onclick=()=>show(current(),true);window.addEventListener('hashchange',fromHash);window.showWeek=show;fromHash()}})();"""
const _VIEWS=["compact"=>("index.html","Liste"),"week"=>("uke.html","Uke"),"cards"=>("kort.html","Kort")]
_href(e)="arrangement/$(_esc(string(_val(e,"id",""))))/"
_haspage(e)=!isempty(string(_val(e,"id",""))) && !isempty(string(_val(e,"start","")))
"Title, linked to the event page when `links` (only the full site has event pages)."
_title_html(e,links)=(t=_esc(_val(e,"title","Uten tittel")); links && _haspage(e) ? "<a href=\"$(_href(e))\">$t</a>" : t)
"Common `data-` attributes for a filterable row/card; `day` overrides the date for per-day rows of multi-day events."
function _data_attrs(e; day=nothing, group=nothing)
 typ=lowercase(string(_val(e,"type","other"))); (vname,vaddr)=_venue(e); cancelled=_val(e,"status","")=="cancelled"
 search=lowercase(join([_val(e,"title",""),vname,vaddr,_val(e,"organizer",""),_val(e,"dj",""),_val(e,"description",""),cancelled ? "avlyst" : ""]," "))
 iso=_iso(e); d=isnothing(day) ? (isempty(iso) ? "9999-12-31" : iso) : string(day); en=isnothing(day) ? _end_day(e) : string(day)
 g=isnothing(group) ? "" : " data-group=\"$(_esc(group))\""
 "data-eid=\"$(_esc(_val(e,"id",_val(e,"title",""))))\" data-type=\"$(_esc(typ))\" data-date=\"$d\" data-end=\"$en\" data-series=\"$(_esc(_val(e,"series","")))\" data-search=\"$(_esc(search))\" data-music=\"$(_esc(join(_music(e)," ")))\"$g"
end
"Days an event appears on in the list/week views (each day of a multi-day event)."
function _days(e)
 iso=_iso(e); isempty(iso) && return Date[]
 d0=Date(iso); d1=Date(_end_day(e)); d1<d0 || d1>d0+Day(30) ? [d0] : collect(d0:Day(1):d1)
end
"Time column for the list/week rows: `21:00–01:30`, `fra 17:00`, `hele dagen` or `pågår`."
function _time_cell(e,d)
 p=_parse_dt(string(_val(e,"start",""))); isnothing(p) && return "hele dagen"
 dt,timed=p; Date(dt)==d || return "pågår"
 timed || return "hele dagen"
 q=_parse_dt(string(_val(e,"end","")))
 isnothing(q) || !q[2] || _evening_end(dt,q[1],q[2])!=Date(dt) ? (length(_days(e))>1 ? "fra $(_hm(dt))" : _hm(dt)) : "$(_hm(dt))–$(_hm(q[1]))"
end
_first_sentence(s)=(t=strip(string(s)); m=match(r"^(.{20,180}?[.!?])(\s|$)",t); isnothing(m) ? (length(t)>180 ? first(t,177)*"…" : t) : m[1])
"One dense row (compact list and week view) for event `e` on day `d`."
function _row(e,d; links=true, lead=false)
 days=_days(e); n=length(days); k=findfirst(==(d),days); cancelled=_val(e,"status","")=="cancelled"
 typ=lowercase(string(_val(e,"type","other"))); (vname,vaddr)=_venue(e)
 facts=String[]; fact(ic,label,v)=push!(facts,"<span class=\"f\" title=\"$label\">$(_icon(ic,label))$(_esc(v))</span>")
 p=_price(e); p!="Pris ikke oppgitt" && fact("price","Pris",p)
 dj=string(_val(e,"dj","")); isempty(dj) || fact("dj","DJ",dj)
 t=join(something(_val(e,"teachers",Any[]),Any[]),", "); isempty(t) || fact("teachers","Lærere",t)
 desc=string(_val(e,"description","")); leadhtml=lead && !isempty(desc) ? "<div class=\"lead\">$(_esc(_first_sentence(desc)))</div>" : ""
 """<article class="row ev$(cancelled ? " cancelled" : "")" $(_data_attrs(e; day=d, group=string(d)))><div class="time">$(_esc(_time_cell(e,d)))</div><div class="what"><h3>$(_title_html(e,links))</h3><span class="chip">$(_esc(_type_label(typ)))</span>$(cancelled ? " <span class=\"chip avlyst\">Avlyst</span>" : "")$(n>1 ? "<span class=\"dayn\">dag $k av $n</span>" : "")<div class="where">$(_icon("pin","Sted"))$(_esc(vname)) · $(_esc(vaddr))</div>$(isempty(facts) ? "" : "<div class=\"facts\">$(join(facts,""))</div>")$leadhtml</div></article>"""
end
const _MONTHS_LONG=["januar","februar","mars","april","mai","juni","juli","august","september","oktober","november","desember"]
_longday(d)="$(_WD[dayofweek(d)]) $(day(d)). $(_MONTHS_LONG[month(d)])"
_byday(ev)=(m=Dict{Date,Vector{Any}}(); for e in ev, d in _days(e); push!(get!(m,d,Any[]),e); end; m)
_dayrows(m,d;kw...)=join((_row(e,d;kw...) for e in sort(m[d],by=_sortkey)),"")
function _compact_view(ev; links=true)
 m=_byday(ev)
 join(("<section class=\"group\" data-group=\"$d\"><h2 class=\"dayhead\">$(_esc(_longday(d)))</h2>$(_dayrows(m,d;links))</section>" for d in sort(collect(keys(m)))),"\n")
end
"ISO week key `2026-W41` and the Monday of that week."
_isoweek(d)=(y=year(d+Day(4-dayofweek(d))); w=week(d); "$y-W$(lpad(w,2,'0'))")
function _week_view(ev; links=true)
 m=_byday(ev); isempty(m) && return ""
 mon(d)=d-Day(dayofweek(d)-1); first_=mon(minimum(keys(m))); last_=mon(maximum(keys(m)))
 secs=String[]
 for w in first_:Week(1):last_
  key=_isoweek(w); sun=w+Day(6)
  range_=month(w)==month(sun) ? "$(day(w)).–$(day(sun)). $(_MO[month(sun)])" : "$(day(w)). $(_MO[month(w)]) – $(day(sun)). $(_MO[month(sun)])"
  days=join(("<div class=\"group\" data-keep=\"1\" data-group=\"$d\"><h3 class=\"dayhead\">$(_esc(_longday(d)))</h3>$(haskey(m,d) ? _dayrows(m,d;links,lead=true) : "")<p class=\"none\">Ingen arrangementer</p></div>" for d in w:Day(1):sun),"")
  push!(secs,"<section class=\"week\" id=\"uke-$(replace(key,"-W"=>"-"))\" data-week=\"$key\"><h2>Uke $(week(w)) · $range_</h2>$days</section>")
 end
 "<div class=\"weeknav\"><button id=\"prevw\" type=\"button\">‹ Forrige uke</button><button id=\"todayw\" type=\"button\">Denne uken</button><button id=\"nextw\" type=\"button\">Neste uke ›</button></div>"*join(secs,"\n")
end
function _filterbar(ev; when=true, sort=true)
 types=sort!(unique(lowercase(string(_val(e,"type","other"))) for e in ev)); musics=sort!(unique(m for e in ev for m in _music(e)))
 opts=join(("<option value=\"$(_esc(t))\">$(_esc(_type_label(t)))</option>" for t in types),""); mopts=join(("<option value=\"$(_esc(m))\">$(_esc(_music_label(m)))</option>" for m in musics),"")
 whenhtml=when ? "<div><label>Tidspunkt</label><select id=\"when\"><option value=\"upcoming\" selected>Kommende</option><option value=\"all\">Alle (også tidligere)</option><option value=\"today\">I dag</option><option value=\"week\">Neste 7 dager</option><option value=\"month\">Neste 30 dager</option><option value=\"recurring\">Faste aktiviteter</option></select></div>" : ""
 sorthtml=sort ? "<div><label>Sortering</label><select id=\"sort\"><option value=\"asc\">Tidligste først</option><option value=\"desc\">Seneste først</option><option value=\"title\">Alfabetisk</option></select></div>" : ""
 cols=2+when+sort
 "<div class=\"filters\" style=\"grid-template-columns:2fr repeat($cols,1fr)\"><div class=\"search\"><label>Søk</label><input id=\"q\" placeholder=\"Sted, DJ, arrangør …\"></div><div><label>Type</label><select id=\"type\"><option value=\"\">Alle typer</option>$opts</select></div><div><label>Musikk</label><select id=\"music\"><option value=\"\">All musikk</option>$mopts</select></div>$whenhtml$sorthtml</div>"
end
"""
    render_events_html(events; view="cards", site=false, …) -> String

One calendar page. `view` is `"cards"`, `"compact"` (dense list grouped by day) or `"week"` (one week at a time).
`site=true` (used by `write_site`) adds the view tabs, links to event pages and the feed links.
"""
function render_events_html(events; view="cards",site=false,title=SITE_NAME,subtitle="Milongaer, practicaer, kurs og festivaler",generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"),submit_url=SUBMIT_URL,correct_url=CORRECT_URL,ai_url="for-ki.html")
 view in first.(_VIEWS) || throw(ArgumentError("unknown view $view"))
 submit=_esc(_http(submit_url))
 hero_submit=isempty(submit) ? "" : "<a class=\"submit\" href=\"$submit\" target=\"_blank\" rel=\"noopener\">+ Legg til arrangement</a>"
 footer_submit=isempty(submit) ? "" : " · <a href=\"$submit\" target=\"_blank\" rel=\"noopener\">Legg til arrangement</a>"
 ai=_esc(occursin(r"^(https?://|[A-Za-z0-9._-]+\.html$)",string(ai_url)) ? string(ai_url) : "")   # absolute URL or a relative page
 isempty(ai) || (hero_submit*=" <a class=\"submit ghost\" href=\"$ai\">Bruk KI</a>"; footer_submit*=" · <a href=\"$ai\">Bruk KI til å legge inn</a>")
 tabs=site ? "<nav class=\"tabs\" aria-label=\"Visning\">"*join(("<a href=\"$f\"$(v==view ? " class=\"on\" aria-current=\"page\"" : "")>$l</a>" for (v,(f,l)) in _VIEWS),"")*"</nav>" : ""
 feeds=site ? " · <span class=\"feeds\"><a href=\"webcal://$(replace(SITE_URL,r"^https?://"=>""))/kalender.ics\">Abonner på kalenderen</a> · <a href=\"kalender.ics\">.ics</a> · <a href=\"rss.xml\">RSS</a></span>" : ""
 headlinks=site ? "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"$(_esc(SITE_NAME))\" href=\"rss.xml\"><link rel=\"canonical\" href=\"$SITE_URL/$(Dict(_VIEWS)[view][1]=="index.html" ? "" : Dict(_VIEWS)[view][1])\">" : ""
 ev=sort(collect(events),by=_sortkey)
 body=if view=="cards"
  _filterbar(ev)*"<main class=\"main\"><div class=\"summary\"><span id=\"count\"></span><button id=\"reset\">Nullstill</button></div><div class=\"events\" id=\"events\">$(join((_card(e;correct_url,links=site) for e in ev),"\n"))</div><div class=\"empty\" id=\"empty\">Ingen treff</div></main>"
 elseif view=="compact"
  _filterbar(ev;sort=false)*"<main class=\"main\"><div class=\"summary\"><span id=\"count\"></span><button id=\"reset\">Nullstill</button></div><div id=\"list\">$(_compact_view(ev;links=site))</div><div class=\"empty\" id=\"empty\">Ingen treff</div></main>"
 else
  _filterbar(ev;when=false,sort=false)*"<main class=\"main\"><div class=\"summary\"><span id=\"count\"></span><button id=\"reset\">Nullstill</button></div>$(_week_view(ev;links=site))</main>"
 end
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title))</title>$headlinks<style>
$_CSS
</style></head><body>$_SPRITE<div class="hero"><div class="wrap"><small>ARGENTINSK TANGO I OSLO</small><h1>$(_esc(title))</h1><p>$(_esc(subtitle))</p>$hero_submit$tabs</div></div>$body<div class="sitefooter">Generert $(_esc(generated_at)) · Kontroller alltid detaljer hos arrangøren.$footer_submit$feeds</div><script>$_JS</script></body></html>"""
end
function render_events_file(input::AbstractString,output::AbstractString="index.html";kwargs...)
 html=render_events_html(load_events(input);kwargs...); mkpath(dirname(abspath(output))); write(output,html); output
end
