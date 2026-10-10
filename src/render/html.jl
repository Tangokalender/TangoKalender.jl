_esc(x)=replace(string(something(x,"")),'&'=>"&amp;",'<'=>"&lt;",'>'=>"&gt;",'"'=>"&quot;",'\''=>"&#39;")
_val(e,k,d="")=(v=get(e,k,d); isnothing(v) ? d : v)
_iso(e)=(s=string(_val(e,"start","")); isempty(s) ? "" : first(split(s,'T')))
_sortkey(e)=string(_val(e,"start",""))
"`(DateTime, has_time)` for an ISO `start`/`end` string (offset ignored), or `nothing`."
# Parsed and formatted by hand rather than with Dates' format strings, which `juliac --trim` can't compile.
function _parse_dt(raw)
 m=match(r"^([0-9]{4})-([0-9]{2})-([0-9]{2})(?:T([0-9]{2}):([0-9]{2})(?::([0-9]{2}))?)?(?:Z|[+-][0-9]{2}:[0-9]{2})?$",raw)
 isnothing(m) && return nothing
 n=[isnothing(c) ? 0 : parse(Int,c) for c in m.captures]
 try (DateTime(n[1],n[2],n[3],n[4],n[5],n[6]),occursin('T',raw)) catch; nothing end
end
_hm(dt)=_two(hour(dt))*":"*_two(minute(dt))
"Last day of an event: an end at or before 06:00 the next day still belongs to the evening that started it."
_evening_end(dt,edt,etimed)=etimed && Date(edt)>Date(dt) && Time(edt)<=Time(6) ? Date(edt)-Day(1) : Date(edt)
"`data-end` for the page's date filters: the last day the event runs (start day if no usable end)."
function _end_day(e)
 iso=_iso(e); isempty(iso) && return ""
 p=_parse_dt(string(_val(e,"start",""))); q=_parse_dt(string(_val(e,"end","")))
 (isnothing(p) || isnothing(q)) && return iso
 string(max(_evening_end(p[1],q[1],q[2]),Date(p[1])))
end
_date_label(e)=_date_label(string(_val(e,"start","")),string(_val(e,"end","")))
function _date_label(raw::AbstractString,rawend::AbstractString)
 if !isempty(raw)
  p=_parse_dt(raw)
  d=_ymd(raw); isnothing(p) && return isnothing(d) ? String(raw) : "$(_two(day(d))).$(_two(month(d))).$(year(d))"
  dt,timed=p; startl=timed ? "$(_day(dt)) · $(_hm(dt))" : _day(dt)
  q=_parse_dt(rawend); isnothing(q) && return startl
  edt,etimed=q
  eday=_evening_end(dt,edt,etimed)
  eday<Date(dt) && return startl
  eday==Date(dt) && return timed && etimed ? "$(startl)–$(_hm(edt))" : startl
  return "$(startl) – $(_day(eday))"
 end
 ""
end
_music(e)=[string(m) for m in something(_val(e,"music_style",Any[]),Any[])]
_http(u)=(s=string(something(u,"")); occursin(r"^https?://"i,s) ? s : "")
function _venue(e)
 v=_val(e,"venue",nothing)
 v isa AbstractDict || (v=Dict{String,Any}())
 name=string(_val(v,"name","")); addr=string(_val(v,"address","")); city=string(_val(v,"city",site_city()))
 (isempty(name) ? _t("venue.none") : name, isempty(addr) ? (isempty(city) ? site_city() : city) : addr)
end
function _video(e)
 v=_val(e,"video",nothing); v isa AbstractDict || return ""
 p=string(_val(v,"platform","")); id=string(_val(v,"id",""))
 src= p=="youtube" && occursin(r"^[A-Za-z0-9_-]{11}$",id) ? "https://www.youtube-nocookie.com/embed/$id" :
      p=="vimeo" && occursin(r"^[0-9]+$",id) ? "https://player.vimeo.com/video/$id" : ""
 isempty(src) ? "" : "<div class=\"video\"><iframe src=\"$src\" title=\"Video: $(_esc(_title(e)))\" loading=\"lazy\" referrerpolicy=\"strict-origin-when-cross-origin\" allow=\"fullscreen; picture-in-picture; encrypted-media\" allowfullscreen></iframe></div>"
end
"Prices «150 kr · student 100 kr», or \"\" when none is given (show `_t(\"price.none\")` where needed)."
function _price(e)
 parts=String[]
 for (k,label) in [("price_nok",""),("student_price_nok",_t("price.student")*" "),("class_price_nok",_t("price.class")*" ")]
  v=get(e,k,nothing); !isnothing(v) && push!(parts,"$(label)$(v) kr")
 end
 join(parts," · ")
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
 join(("<symbol id=\"i-$k\" viewBox=\"0 0 24 24\">$v</symbol>" for (k,v) in sort(collect(_ICON_PATHS))),"")*join((_FLAGS[l] for l in LANGS),"")*"</svg>"
"Inline icon referencing the page sprite; `label` becomes screen-reader text («DJ: »)."
function _icon(name,label="")
 haskey(_ICON_PATHS,name) || throw(ArgumentError("unknown icon $name"))
 "<svg class=\"ic\" aria-hidden=\"true\" focusable=\"false\"><use href=\"#i-$name\"/></svg>"*(isempty(label) ? "" : "<span class=\"sr\">$label: </span>")
end
"One chip per type, in TYPE_ORDER («Kurs» «Milonga»); `cls` adds a class (e.g. for small chips)."
_type_chips(e)=join(("<span class=\"chip$(t=="outdoor" ? " outdoor" : "")\">$(_esc(_type_label(t)))</span>" for t in _types(e))," ")
"CSS class for the colour of a week-view cell: the first type other than `outdoor`."
_type_class(e)=(ts=filter(!=("outdoor"),_types(e)); "t-"*(isempty(ts) ? "other" : first(ts))*("outdoor" in _types(e) ? " outdoor" : ""))
function _card(e; correct_url=correct_form_url(), links=false)
 corr=isempty(_http(correct_url)) || isempty(string(_val(e,"id",""))) || isempty(string(_val(e,"start",""))) ? "" :
  "<a class=\"correct\" href=\"$(_esc(correction_url(e;base=_http(correct_url))))\" target=\"_blank\" rel=\"noopener\" aria-label=\"$(_esc(_t("correct.aria",_title(e))))\">$(_t("correct"))</a>"
 title=_esc(_title(e)); date=_esc(_date_label(e)); iso=_esc(_iso(e)); (vname,vaddr)=_venue(e); venue=_esc(vname); addr=_esc(vaddr); org=_esc(_val(e,"organizer","")); dj=_esc(_val(e,"dj","")); (dtext,dl)=_text(e,"description"); desc=isempty(dtext) ? "" : "<span$(_langattr(dl))>$(_esc(dtext))</span>$(_langnote(dl))"; source=_esc(_val(e,"source",_t("source"))); url=_esc(_val(e,"source_url","")); pub=_esc(_val(e,"published_date",_t("notgiven"))); cancelled=_val(e,"status","")=="cancelled"; series=_esc(_val(e,"series","")); music=_music(e); flyer=_esc(_http(_val(e,"flyer_url",""))); info=_esc(_http(_val(e,"link","")))
 link=isempty(url) ? "<span>$source</span>" : "<a href=\"$url\" target=\"_blank\" rel=\"noopener\">$source ↗</a>"
 djhtml=isempty(dj) ? "" : "<div title=\"DJ\">$(_icon("dj","DJ"))$dj</div>"; orghtml=isempty(org) ? "" : "<div title=\"$(_t("organizer"))\">$(_icon("org",_t("organizer")))$org</div>"
 musichtml=isempty(music) ? "" : "<div class=\"music\">"*_icon("music",_t("music"))*join(("<span class=\"chip music-chip\">$(_esc(_music_label(m)))</span>" for m in music),"")*"</div>"
 media=(isempty(flyer) ? "" : "<img class=\"flyer\" src=\"$flyer\" alt=\"Flyer: $title\" loading=\"lazy\">")*_video(e)
 mediahtml=isempty(media) ? "" : "<div class=\"media\">$media</div>"
 infohtml=isempty(info) ? "" : "<a href=\"$info\" target=\"_blank\" rel=\"noopener\">$(_t("moreinfo"))</a>"
 price=_price(e); isempty(price) && (price=_t("price.none"))
 """<article class="event ev$(cancelled ? " cancelled" : "")" $(_data_attrs(e))><aside>$date</aside><section><header><span>$(cancelled ? "<span class=\"chip avlyst\">$(_t("cancelled"))</span> " : "")$(_type_chips(e))</span><span class="price">$(_icon("price",_t("price")))$(_esc(price))</span></header><h2>$(_title_html(e,links))</h2><div class="meta"><div title="$(_t("venue"))">$(_icon("pin",_t("venue")))<b>$venue</b><br><small>$addr</small></div>$djhtml$orghtml</div>$musichtml<p>$desc</p>$mediahtml<footer><span>$(_t("published")): $pub</span><span class="links">$infohtml$link$corr</span></footer></section></article>"""
end
const _CSS=""":root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c}.hero{padding:48px 20px 82px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:1080px;margin:auto}.hero h1{font:500 clamp(2.5rem,7vw,4.8rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5}.hero .submit{display:inline-block;margin-top:10px;padding:10px 18px;border-radius:999px;background:white;color:var(--wine);font-weight:800;text-decoration:none}.hero .submit:hover{background:#f7dce5}.hero .submit.ghost{background:transparent;color:white;border:1px solid #f7dce5;margin-left:6px}.hero .submit.ghost:hover{background:#ffffff1f}.sitefooter a{color:var(--wine);font-weight:700}.filters{position:sticky;top:0;z-index:3;max-width:1080px;margin:-38px auto 24px;padding:14px;display:grid;grid-template-columns:2fr repeat(4,1fr);gap:10px;background:#fffffff2;border:1px solid white;border-radius:18px;box-shadow:0 12px 30px #29192118}.filters label{display:block;font-size:.68rem;text-transform:uppercase;color:var(--muted);font-weight:800;margin-bottom:4px}.filters input,.filters select{width:100%;padding:10px;border:1px solid var(--line);border-radius:10px;background:white}.main{max-width:1080px;margin:auto;padding:0 20px 60px}.summary{display:flex;justify-content:space-between;color:var(--muted);margin-bottom:14px}.summary button{border:0;background:none;color:var(--wine);font-weight:800}.events{display:grid;gap:15px}.event{display:grid;grid-template-columns:180px 1fr;background:white;border:1px solid var(--line);border-radius:18px;overflow:hidden;box-shadow:0 5px 18px #2919210b}.event aside{padding:24px;background:#eee5de;font-weight:800}.event section{padding:22px}.event header,.event footer{display:flex;justify-content:space-between;gap:12px}.chip{padding:5px 10px;border-radius:999px;background:#f2dce4;color:#76203e;text-transform:uppercase;font-size:.7rem;font-weight:850}.price,small,.event footer{color:var(--muted)}h2{font:500 1.7rem Georgia;margin:12px 0}.meta{display:flex;flex-wrap:wrap;gap:15px 28px}.event p{line-height:1.55}.event footer{border-top:1px solid #eee7e1;padding-top:12px;font-size:.78rem}.event footer a{color:var(--wine);font-weight:800;text-decoration:none}.music{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}.music-chip{background:#efe7dd;color:#5b4636}.media{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:12px 0}.flyer{width:100%;border-radius:12px;object-fit:cover}.video{position:relative;aspect-ratio:16/9}.video iframe{position:absolute;inset:0;width:100%;height:100%;border:0;border-radius:12px}.links{display:flex;gap:14px;flex-wrap:wrap}.event footer a.correct{color:var(--muted);font-weight:600}.cancelled h2,.cancelled aside{text-decoration:line-through}.cancelled section>*:not(header){opacity:.6}.avlyst{background:#b3261e;color:white}.hidden{display:none}.empty{display:none;text-align:center;padding:40px}.sitefooter{text-align:center;color:var(--muted);padding:20px;font-size:.8rem}@media(max-width:760px){.filters{position:relative;margin:-42px 14px 20px;grid-template-columns:1fr 1fr}.search{grid-column:1/-1}.event{grid-template-columns:1fr}.event aside{padding:14px 20px}.main{padding:0 14px 40px}}@media(max-width:460px){.filters{grid-template-columns:1fr}.search{grid-column:auto}.event header,.event footer{flex-direction:column}}.tabs{display:flex;gap:6px;margin-top:18px;flex-wrap:wrap}.tabs a{color:#f7dce5;text-decoration:none;font-weight:800;padding:7px 14px;border-radius:999px;border:1px solid #ffffff40}.tabs a.on{background:white;color:var(--wine);border-color:white}.ev h2 a,.ev h3 a{color:inherit;text-decoration:none}.ev h2 a:hover,.ev h3 a:hover{text-decoration:underline}.group{margin-bottom:18px}.dayhead{font:600 1.05rem Georgia;margin:0 0 6px;padding:8px 2px;border-bottom:2px solid var(--wine);color:var(--wine)}.row{display:grid;grid-template-columns:110px 1fr;gap:4px 16px;padding:10px 4px;border-bottom:1px solid var(--line);background:transparent}.row .time{font-weight:800;font-variant-numeric:tabular-nums}.row h3{display:inline;font:600 1.02rem Inter,system-ui,sans-serif;margin:0 8px 0 0}.row .chip{font-size:.6rem;padding:3px 8px;vertical-align:2px}.row .where,.row .facts,.row .lead{color:var(--muted);font-size:.86rem;margin-top:2px}.row .lead{color:#3b3433}.row .dayn{font-size:.72rem;color:var(--muted);margin-left:6px}.row.cancelled h3,.row.cancelled .time{text-decoration:line-through}.group .none{display:none;color:var(--muted);font-size:.86rem;padding:8px 4px}.group.noev .none{display:block}.week.off{display:none}.weekgrid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:8px;align-items:start}.col{background:white;border:1px solid var(--line);border-radius:14px;padding:8px;min-height:120px;margin:0}.col.weekend{background:#fbf8f4}.col.today{border:2px solid var(--wine);box-shadow:0 6px 18px #87294922}.colhead{margin:0 0 6px;padding:2px 2px 6px;border-bottom:1px solid var(--line);font:600 .9rem Inter,system-ui,sans-serif;display:flex;justify-content:space-between;align-items:baseline}.colhead .wd{text-transform:uppercase;font-size:.72rem;letter-spacing:.04em;color:var(--muted);font-weight:800}.col.today .colhead .wd,.col.today .colhead .dm{color:var(--wine)}.col .none{display:none;color:var(--muted);text-align:center;margin:18px 0}.col.noev .none{display:block}.cell{display:block;border-left:3px solid #d9b8c5;border-radius:8px;background:#faf6f2;padding:6px 7px;margin-bottom:6px;font-size:.8rem;line-height:1.3}.chip.outdoor{background:#e3efe0;color:#2f5a2a}.cell.outdoor{background:#f3f8f1}.cell.t-milonga{border-left-color:var(--wine)}.cell.t-practica{border-left-color:#b48a9b}.cell.t-festival,.cell.t-marathon{border-left-color:#5b4636}.cell.t-class,.cell.t-workshop,.cell.t-class_and_social,.cell.t-class_and_practica{border-left-color:#8c7a6b}.cell .time{font-weight:800;font-variant-numeric:tabular-nums}.cell h3{font:700 .86rem Inter,system-ui,sans-serif;margin:2px 0 3px;overflow-wrap:break-word;hyphens:auto}.cell .tags .chip{font-size:.55rem;padding:2px 6px}.cell .where,.cell .facts{color:var(--muted);margin-top:3px;overflow-wrap:break-word;hyphens:auto}.cell .facts .f{display:block}.cell.cancelled h3,.cell.cancelled .time{text-decoration:line-through}.cell .dayn{font-weight:600;color:var(--muted);font-size:.7rem}.weeknav{position:sticky;top:0;z-index:4;background:var(--paper);padding:10px 0}.weeknav .wk{display:flex;gap:12px;align-items:center;font-size:1.05rem}.weeknav button{font-size:1rem;min-width:44px;white-space:nowrap}@media(max-width:560px){.weeknav .wk{font-size:.95rem;gap:8px}}.weeknav button:disabled{opacity:.35;cursor:default}.weektitle{font:500 1.3rem Georgia;margin:18px 0 8px}.js .weektitle{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}.weeknav{display:none}.js .weeknav{display:flex}@media(max-width:760px){.weekgrid{grid-template-columns:repeat(7,minmax(160px,1fr));overflow-x:auto;scroll-snap-type:x mandatory;padding-bottom:8px}.col{scroll-snap-align:start}.weeknav .lbl{display:none}}.weeknav{display:flex;gap:8px;align-items:center;justify-content:space-between;margin:0 0 14px}.weeknav button{border:1px solid var(--line);background:white;border-radius:999px;padding:8px 14px;font-weight:800;color:var(--wine);cursor:pointer}.week>h2{font:500 1.5rem Georgia;margin:6px 0 12px}.feeds a{white-space:nowrap}.hidden{display:none!important}.filters{display:block}.topline{display:flex;gap:10px;align-items:flex-end}.topline .search{flex:1}.ftoggle{display:none;align-items:center;gap:4px;border:1px solid var(--line);background:white;border-radius:10px;padding:10px 14px;font-weight:800;color:var(--wine);cursor:pointer;white-space:nowrap}.ftoggle .chev{transition:transform .15s}.filters.open .ftoggle .chev{transform:rotate(180deg)}.more .frow{margin-top:10px}.frow{display:grid;gap:10px}.pills-row{display:flex;flex-wrap:wrap;gap:6px 26px;margin-top:12px}fieldset.pills{border:0;margin:0;padding:0;display:flex;flex-wrap:wrap;gap:6px;align-items:center}fieldset.pills legend{float:left;margin-right:6px;font-size:.68rem;text-transform:uppercase;color:var(--muted);font-weight:800}.filters label.pill{position:relative;cursor:pointer;display:inline-block;margin:0;text-transform:none;font-size:inherit;font-weight:inherit;color:inherit}.pill input{position:absolute;opacity:0;width:1px;height:1px}.pill span{display:inline-block;padding:6px 12px;border-radius:999px;border:1px solid var(--line);background:white;font-size:.85rem;font-weight:600;color:#3b3433}.pill input:checked+span{background:var(--wine);border-color:var(--wine);color:white}.pill input:focus-visible+span{outline:2px solid var(--wine);outline-offset:2px}.sumbtns{display:flex;gap:14px}.summary button{cursor:pointer}@media(max-width:760px){.frow{grid-template-columns:1fr 1fr!important}.ftoggle{display:inline-flex}.more{display:none}.filters.open .more{display:block}.filters{padding:10px}}.ic{width:1.05em;height:1.05em;vertical-align:-.17em;margin-right:.32em;flex:none;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;opacity:.75}.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);clip-path:inset(50%);white-space:nowrap}.row .facts .f{display:inline-block;margin-right:16px;white-space:nowrap}.music .ic{align-self:center}@media(max-width:560px){.row{grid-template-columns:1fr}.row .time{font-size:.9rem}}"""
"Shared page script: filters on `.ev` rows, per-day group hiding, and week navigation (week view)."
const _JS=raw"""(function(){const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)],rows=$$('.ev'),groups=$$('.group'),q=$('#q'),when=$('#when'),sort=$('#sort'),box=$('#events'),count=$('#count'),empty=$('#empty'),tboxes=$$('input[name=type]'),mboxes=$$('input[name=music]'),tabs=$$('.tabs a'),total=new Set(rows.map(c=>c.dataset.eid)).size,DW=(when&&when.dataset&&when.dataset.default)||'upcoming',WHEN=['upcoming','all','today','week','month','recurring'],SORT=['asc','desc','title'];tabs.forEach(a=>{a.dataset.base=a.getAttribute('href')});const checked=bs=>bs.filter(b=>b.checked).map(b=>b.value);function day(d){return new Date(d.getFullYear(),d.getMonth(),d.getDate())}
const ARR=(new URLSearchParams(location.search).get('arr')||'').trim().toLowerCase();function readURL(){const p=new URLSearchParams(location.search),list=k=>(p.get(k)||'').split(',').map(x=>x.trim()).filter(Boolean);if(q)q.value=p.get('q')||'';const ts=list('type'),ms=list('music');tboxes.forEach(b=>{b.checked=ts.includes(b.value)});mboxes.forEach(b=>{b.checked=ms.includes(b.value)});if(when)when.value=WHEN.includes(p.get('when'))?p.get('when'):DW;if(sort)sort.value=SORT.includes(p.get('sort'))?p.get('sort'):'asc'}
function writeURL(){const p=new URLSearchParams();if(q&&q.value.trim())p.set('q',q.value.trim());const ts=checked(tboxes),ms=checked(mboxes);if(ts.length)p.set('type',ts.join(','));if(ms.length)p.set('music',ms.join(','));if(when&&when.value!==DW)p.set('when',when.value);if(sort&&sort.value!=='asc')p.set('sort',sort.value);if(ARR)p.set('arr',ARR);const s=p.toString().replace(/%2C/gi,','),search=s?'?'+s:'';if(search!==location.search)history.replaceState(null,'',location.origin+location.pathname+search+location.hash);tabs.forEach(a=>{a.setAttribute('href',a.dataset.base+search)})}
function apply(){let now=day(new Date()),limit=new Date(now),w=when?when.value:'any',ts=checked(tboxes),ms=checked(mboxes),words=q?q.value.toLowerCase().split(/\s+/).filter(Boolean):[];if(w==='week')limit.setDate(limit.getDate()+7);if(w==='month')limit.setDate(limit.getDate()+30);let v=[];rows.forEach(c=>{let ser=c.dataset.series!=='',d=new Date(c.dataset.date+'T00:00:00'),en=new Date(c.dataset.end+'T00:00:00'),future=en>=now,oktime=true;if(w==='upcoming')oktime=future;else if(w==='today')oktime=d<=now&&en>=now;else if(w==='week'||w==='month')oktime=en>=now&&d<=limit;else if(w==='recurring')oktime=ser&&future;let ok=oktime&&(!ARR||(c.dataset.org||'').includes(ARR))&&(!ts.length||c.dataset.type.split(' ').some(t=>ts.includes(t)))&&(!ms.length||c.dataset.music.split(' ').some(m=>ms.includes(m)))&&words.every(x=>c.dataset.search.includes(x));c.classList.toggle('hidden',!ok);if(ok)v.push(c)});if(sort&&box){v.sort((a,b)=>sort.value==='title'?a.querySelector('h2').textContent.localeCompare(b.querySelector('h2').textContent,T.locale):(sort.value==='desc'?-1:1)*a.dataset.date.localeCompare(b.dataset.date));v.forEach(c=>box.appendChild(c))}let vis=new Set(v.map(c=>c.dataset.group));groups.forEach(g=>{let has=vis.has(g.dataset.group);g.dataset.keep?g.classList.toggle('noev',!has):g.classList.toggle('hidden',!has)});let n=new Set(v.map(c=>c.dataset.eid)).size;if(count)count.textContent=n+T.of+total+T.events;if(empty)empty.style.display=v.length?'none':'block';writeURL();if(window.onfiltered)window.onfiltered(v)}
if(q)q.addEventListener('input',apply);[when,sort,...tboxes,...mboxes].forEach(x=>x&&x.addEventListener('change',apply));let r=$('#reset');if(r)r.onclick=()=>{if(q)q.value='';tboxes.concat(mboxes).forEach(b=>{b.checked=false});if(when)when.value=DW;if(sort)sort.value='asc';apply();if(typeof countActive==='function')countActive()};let sh=$('#sharefilter');if(sh)sh.onclick=()=>{const u=location.href;if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(u).then(()=>{sh.textContent=T.copied;setTimeout(()=>{sh.textContent=T.copy},2500)});else prompt(T.prompt,u)};let fb=$('#filters'),ft=$('#filtertoggle'),fc=$('#fcount');if(ft&&fb)ft.addEventListener('click',()=>{let o=fb.classList.toggle('open');ft.setAttribute('aria-expanded',o?'true':'false')});function countActive(){let n=checked(tboxes).length+checked(mboxes).length+(when&&when.value!==DW?1:0)+(sort&&sort.value!=='asc'?1:0);if(fc)fc.textContent=n?' ('+n+')':''}[when,sort,...tboxes,...mboxes].forEach(x=>x&&x.addEventListener('change',countActive));window.apply=apply;readURL();apply();countActive();
const weeks=[...document.querySelectorAll('.week')];if(weeks.length){if(document.documentElement)document.documentElement.classList.add('js');function isoWeek(d){let t=new Date(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())),n=t.getUTCDay()||7;t.setUTCDate(t.getUTCDate()+4-n);let y=t.getUTCFullYear(),w=Math.ceil(((t-Date.UTC(y,0,1))/864e5+1)/7);return y+'-W'+String(w).padStart(2,'0')}function current(){let k=isoWeek(new Date()),i=weeks.findIndex(x=>x.dataset.week>=k);return i<0?weeks.length-1:i}let i=current();let pv=$('#prevw'),nx=$('#nextw'),lb=$('#weeklabel'),td=new Date(),tk=td.getFullYear()+'-'+String(td.getMonth()+1).padStart(2,'0')+'-'+String(td.getDate()).padStart(2,'0');[...document.querySelectorAll('.col')].forEach(c=>{if(c.dataset.group===tk)c.classList.add('today')});function show(j,push){i=Math.max(0,Math.min(weeks.length-1,j));weeks.forEach((x,k)=>x.classList.toggle('off',k!==i));if(lb)lb.textContent=weeks[i].dataset.label;if(pv)pv.disabled=i===0;if(nx)nx.disabled=i===weeks.length-1;if(push)history.replaceState(null,'',location.origin+location.pathname+location.search+'#'+weeks[i].id);let t=weeks[i].querySelector&&weeks[i].querySelector('.col.today');if(t&&t.scrollIntoView&&window.innerWidth<760)t.parentNode.scrollLeft=t.offsetLeft-12}function fromHash(){let k=weeks.findIndex(x=>'#'+x.id===location.hash);show(k<0?current():k,false)}$('#prevw').onclick=()=>show(i-1,true);$('#nextw').onclick=()=>show(i+1,true);$('#todayw').onclick=()=>show(current(),true);window.addEventListener('hashchange',fromHash);document.addEventListener('keydown',ev=>{if(/INPUT|SELECT|TEXTAREA/.test((ev.target&&ev.target.tagName)||''))return;if(ev.key==='ArrowLeft')show(i-1,true);if(ev.key==='ArrowRight')show(i+1,true)});window.showWeek=show;fromHash()}})();"""
"View => (file, label key). The file names are the same in every language tree."
const _VIEWS=["compact"=>("index.html","view.compact"),"week"=>("uke.html","view.week"),"map"=>("kart.html","view.map"),"cards"=>("kort.html","view.cards")]
"Strings for the page script (`T` in `_JS`), as a JS object literal."
_js_strings()=JSON.json(Dict("of"=>_t("count.of"),"events"=>_t("count.events"),"copied"=>_t("copied"),"copy"=>_t("copylink"),"prompt"=>_t("copyprompt"),"nomap"=>_t("map.none"),"locale"=>JS_LOCALE[_lang()]))
"The page script with its strings: one <script> block (test/js/filters.js evaluates it as a whole)."
_page_script(extra="")="<script>var T=$(replace(_js_strings(),"</"=>"<\\/"));$_JS$extra</script>"
_href(e)="arrangement/$(_esc(string(_val(e,"id",""))))/"
_haspage(e)=!isempty(string(_val(e,"id",""))) && !isempty(string(_val(e,"start","")))
"Title, linked to the event page when `links` (only the full site has event pages)."
function _title_html(e,links)
 (t,l)=_text(e,"title"); t=_esc(isempty(t) ? _t("untitled") : t); la=_langattr(l)
 links && _haspage(e) ? "<a href=\"$(_href(e))\"$la>$t</a>" : isempty(la) ? t : "<span$la>$t</span>"
end
"Common `data-` attributes for a filterable row/card; `day` overrides the date for per-day rows of multi-day events."
function _data_attrs(e; day=nothing, group=nothing)
 (vname,vaddr)=_venue(e); cancelled=_val(e,"status","")=="cancelled"
 search=lowercase(join([_alltext(e,"title"),vname,vaddr,_val(e,"organizer",""),_val(e,"dj",""),_alltext(e,"description"),cancelled ? _t("cancelled") : ""]," "))
 d=isnothing(day) ? _iso(e) : string(day); en=isnothing(day) ? _end_day(e) : string(day)
 g=isnothing(group) ? "" : " data-group=\"$(_esc(group))\""
 c=venue_coords(e)   # map position (kart.html): only precise or manual coordinates, see src/geo.jl
 isnothing(c) || isempty(d) || (g*=" data-lat=\"$(round(c[1];digits=6))\" data-lon=\"$(round(c[2];digits=6))\" data-venue=\"$(_esc(vname))\" data-dl=\"$(_esc(_day(Date(d))))\"")
 "data-eid=\"$(_esc(_val(e,"id",_val(e,"title",""))))\" data-type=\"$(_esc(join(_types(e)," ")))\" data-date=\"$d\" data-end=\"$en\" data-series=\"$(_esc(_val(e,"series","")))\" data-search=\"$(_esc(search))\" data-music=\"$(_esc(join(_music(e)," ")))\" data-org=\"$(_esc(lowercase(string(_val(e,"organizer","")))))\"$g"
end
"Days an event appears on in the list/week views (each day of a multi-day event)."
function _days(e)
 iso=_iso(e); isempty(iso) && return Date[]
 d0=Date(iso); d1=Date(_end_day(e)); d1<d0 || d1>d0+Day(30) ? [d0] : collect(d0:Day(1):d1)
end
"True when `e` started on an earlier day than `d` (later days of a multi-day event)."
_ongoing(e,d)=(p=_parse_dt(string(_val(e,"start",""))); !isnothing(p) && Date(p[1])!=d)
"Time column for the list/week rows: `21:00–01:30`, `fra 17:00`, `hele dagen` or `pågår`."
function _time_cell(e,d)
 p=_parse_dt(string(_val(e,"start",""))); isnothing(p) && return _t("allday")
 dt,timed=p; Date(dt)==d || return _t("ongoing")
 timed || return _t("allday")
 q=_parse_dt(string(_val(e,"end","")))
 isnothing(q) || !q[2] || _evening_end(dt,q[1],q[2])!=Date(dt) ? (length(_days(e))>1 ? _t("from",_hm(dt)) : _hm(dt)) : "$(_hm(dt))–$(_hm(q[1]))"
end
_first_sentence(s)=(t=strip(string(s)); m=match(r"^(.{20,180}?[.!?])(\s|$)",t); isnothing(m) ? (length(t)>180 ? first(t,177)*"…" : t) : m[1])
"One dense row (compact list and week view) for event `e` on day `d`."
function _row(e,d; links=true, lead=false)
 days=_days(e); n=length(days); k=findfirst(==(d),days); cancelled=_val(e,"status","")=="cancelled"
 (vname,vaddr)=_venue(e)
 facts=String[]; fact(ic,label,v)=push!(facts,"<span class=\"f\" title=\"$label\">$(_icon(ic,label))$(_esc(v))</span>")
 p=_price(e); isempty(p) || fact("price",_t("price"),p)
 dj=string(_val(e,"dj","")); isempty(dj) || fact("dj","DJ",dj)
 t=join(something(_val(e,"teachers",Any[]),Any[]),", "); isempty(t) || fact("teachers",_t("teachers"),t)
 desc=first(_text(e,"description")); leadhtml=lead && !isempty(desc) ? "<div class=\"lead\">$(_esc(_first_sentence(desc)))</div>" : ""
 """<article class="row ev$(cancelled ? " cancelled" : "")" $(_data_attrs(e; day=d, group=string(d)))><div class="time">$(_esc(_time_cell(e,d)))</div><div class="what"><h3>$(_title_html(e,links))</h3>$(_type_chips(e))$(cancelled ? " <span class=\"chip avlyst\">$(_t("cancelled"))</span>" : "")$(n>1 ? "<span class=\"dayn\">$(_t("dayn",k,n))</span>" : "")<div class="where">$(_icon("pin",_t("venue")))$(_esc(vname)) · $(_esc(vaddr))</div>$(isempty(facts) ? "" : "<div class=\"facts\">$(join(facts,""))</div>")$leadhtml</div></article>"""
end
_byday(ev)=(m=Dict{Date,Vector{Any}}(); for e in ev, d in _days(e); push!(get!(m,d,Any[]),e); end; m)
_dayrows(m,d;kw...)=join((_row(e,d;kw...) for e in sort(m[d],by=_sortkey)),"")
function _compact_view(ev; links=true)
 m=_byday(ev)
 join(("<section class=\"group\" data-group=\"$d\"><h2 class=\"dayhead\">$(_esc(_longday(d)))</h2>$(_dayrows(m,d;links))</section>" for d in sort(collect(keys(m)))),"\n")
end
"ISO week key `2026-W41` and the Monday of that week."
_isoweek(d)=(y=year(d+Day(4-dayofweek(d))); w=week(d); "$y-W$(lpad(w,2,'0'))")
"One compact event block in a week-grid column (day `d`)."
function _cell(e,d; links=true)
 days=_days(e); n=length(days); k=findfirst(==(d),days); cancelled=_val(e,"status","")=="cancelled"
 (vname,_)=_venue(e)
 facts=String[]; p=_price(e); isempty(p) || push!(facts,"<span class=\"f\" title=\"$(_t("price"))\">$(_icon("price",_t("price")))$(_esc(p))</span>")
 dj=string(_val(e,"dj","")); isempty(dj) || push!(facts,"<span class=\"f\" title=\"DJ\">$(_icon("dj","DJ"))$(_esc(dj))</span>")
 """<article class="cell ev $(_esc(_type_class(e)))$(cancelled ? " cancelled" : "")" $(_data_attrs(e; day=d, group=string(d)))><div class="time">$(_esc(_time_cell(e,d)))$(n>1 ? " <span class=\"dayn\">$k/$n</span>" : "")</div><h3>$(_title_html(e,links))</h3><div class="tags">$(_type_chips(e))$(cancelled ? " <span class=\"chip avlyst\">$(_t("cancelled"))</span>" : "")</div><div class="where">$(_icon("pin",_t("venue")))$(_esc(vname))</div>$(isempty(facts) ? "" : "<div class=\"facts\">$(join(facts,""))</div>")</article>"""
end
"""
Week calendar: one `<section class="week">` per ISO week (from the first to the last event), each a 7-column grid
(Monday–Sunday). The script shows one week at a time with ‹ ›, «I dag», arrow keys and `#uke-YYYY-WW`.
"""
function _week_view(ev; links=true, today::Date=Dates.today())
 m=_byday(ev); isempty(m) && return ""
 mon(d)=d-Day(dayofweek(d)-1); last_=mon(maximum(keys(m)))
 first_=min(max(mon(minimum(keys(m))),mon(today)-Week(4)),last_)   # skip old weeks: from 4 weeks before the build date
 secs=String[]
 for w in first_:Week(1):last_
  key=_isoweek(w); sun=w+Day(6)
  label=_weeklabel(w)
  cols=join(("<div class=\"group col$(dayofweek(d)>=6 ? " weekend" : "")\" data-keep=\"1\" data-group=\"$d\"><h3 class=\"colhead\" title=\"$(_esc(_longday(d)))\"><span class=\"wd\">$(_wd3(d))</span> <span class=\"dm\">$(_dm(d))</span></h3>$(haskey(m,d) ? join((_cell(e,d;links) for e in sort(m[d],by=_sortkey)),"") : "")<p class=\"none\">–</p></div>" for d in w:Day(1):sun),"")
  push!(secs,"<section class=\"week\" id=\"uke-$(replace(key,"-W"=>"-"))\" data-week=\"$key\" data-label=\"$(_esc(label))\" aria-label=\"$(_esc(label))\"><h2 class=\"weektitle\">$(_esc(label))</h2><div class=\"weekgrid\">$cols</div></section>")
 end
 "<div class=\"weeknav\"><button id=\"prevw\" type=\"button\" aria-label=\"$(_t("week.prev"))\">‹<span class=\"lbl\"> $(_t("week.prev.short"))</span></button><div class=\"wk\"><strong id=\"weeklabel\" aria-live=\"polite\"></strong><button id=\"todayw\" type=\"button\">$(_t("week.today"))</button></div><button id=\"nextw\" type=\"button\" aria-label=\"$(_t("week.next"))\"><span class=\"lbl\">$(_t("week.next.short")) </span>›</button></div>"*join(secs,"\n")
end
function _filterbar(ev; when=true, sort=true, default_when="upcoming")
 types=filter(t->any(t in _types(e) for e in ev),TYPE_ORDER); musics=sort!(unique(m for e in ev for m in _music(e)))
 pill(name,v,l)="<label class=\"pill\"><input type=\"checkbox\" name=\"$name\" value=\"$(_esc(v))\"><span>$(_esc(l))</span></label>"
 tpills=join((pill("type",t,_type_label(t)) for t in types),""); mpills=join((pill("music",m,_music_label(m)) for m in musics),"")
 opts(keys,pre,sel)=join(("<option value=\"$k\"$(k==sel ? " selected" : "")>$(_t(pre*k))</option>" for k in keys),"")
 whenhtml=when ? "<div><label for=\"when\">$(_t("when"))</label><select id=\"when\" data-default=\"$default_when\">$(opts(["upcoming","all","today","week","month","recurring"],"when.",default_when))</select></div>" : ""
 sorthtml=sort ? "<div><label for=\"sort\">$(_t("sort"))</label><select id=\"sort\">$(opts(["asc","desc","title"],"sort.","asc"))</select></div>" : ""
 cols=when+sort
 # Search is always visible; on phones the rest folds into «Filter» (shows the number of active filters)
 "<div class=\"filters\" id=\"filters\"><div class=\"topline\"><div class=\"search\"><label for=\"q\">$(_t("search"))</label><input id=\"q\" type=\"search\" placeholder=\"$(_t("search.placeholder"))\" title=\"$(_t("search.title"))\" autocomplete=\"off\"></div>"*
 "<button id=\"filtertoggle\" class=\"ftoggle\" type=\"button\" aria-expanded=\"false\" aria-controls=\"morefilters\">$(_t("filter"))<span id=\"fcount\"></span> <span class=\"chev\" aria-hidden=\"true\">▾</span></button></div>"*
 "<div class=\"more\" id=\"morefilters\">$(cols>0 ? "<div class=\"frow\" style=\"grid-template-columns:repeat($cols,minmax(160px,260px))\">$whenhtml$sorthtml</div>" : "")"*
 "<div class=\"frow pills-row\"><fieldset class=\"pills\"><legend>$(_t("type"))</legend>$tpills</fieldset>$(isempty(musics) ? "" : "<fieldset class=\"pills\"><legend>$(_t("music"))</legend>$mpills</fieldset>")</div></div></div>"
end
"""
    render_events_html(events; view="cards", site=false, lang="nb", …) -> String

One calendar page. `view` is `"cards"`, `"compact"` (dense list grouped by day), `"week"` (one week at a time) or `"map"` (map of the
venues above the compact list; positions from the venue cache, see `write_site(…; venues)`).
`site=true` (used by `write_site`) adds the view tabs, links to event pages, the feed links and the language switcher.
`lang` is "nb", "en" or "es" (see src/i18n.jl).
"""
render_events_html(events; lang="nb", kwargs...)=_with_lang(()->_render_events_html(events; kwargs...),lang)
function _render_events_html(events; view="cards",site=false,title=site_name(),subtitle=nothing,generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"),submit_url=nothing,correct_url=correct_form_url(),embed::Bool=false,today::Date=Dates.today())
 view in first.(_VIEWS) || throw(ArgumentError("unknown view $view"))
 subtitle=something(subtitle,_t("site.subtitle"))
 # one «Legg til arrangement» link: the combined page on the site, the issue form directly for a standalone page
 su=string(something(submit_url, site ? ADD_PAGE : submit_form_url()))
 submit=_esc(occursin(r"^(https?://|[A-Za-z0-9._-]+\.html(#[a-z-]+)?$)",su) ? su : "")   # absolute URL or a relative page
 ext=startswith(su,"http") ? " target=\"_blank\" rel=\"noopener\"" : ""
 hero_submit=isempty(submit) ? "" : "<a class=\"submit\" href=\"$submit\"$ext>+ $(_t("add"))</a>"
 footer_submit=isempty(submit) ? "" : " · <a href=\"$submit\"$ext>$(_t("add"))</a>"
 tabs=site ? "<nav class=\"tabs\" aria-label=\"$(_t("nav.views"))\">"*join(("<a href=\"$f\"$(v==view ? " class=\"on\" aria-current=\"page\"" : "")>$(_t(l))</a>" for (v,(f,l)) in _VIEWS),"")*"</nav>" : ""
 feeds=site ? " · <a href=\"$ABOUT_PAGE\">$(_t("about"))</a> · <a href=\"$EMBED_PAGE\">$(_t("embed"))</a> · <span class=\"feeds\"><a href=\"webcal://$(replace(_lang_url("kalender.ics"),r"^https?://"=>""))\">$(_t("subscribe"))</a> · <a href=\"kalender.ics\">.ics</a> · <a href=\"rss.xml\">RSS</a></span>" : ""
 file=Dict(_VIEWS)[view][1]; rel=file=="index.html" ? "" : file
 headlinks=site ? "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"$(_esc(site_name()))\" href=\"rss.xml\">$(_alternates(rel))$(_lang_js(rel))<meta name=\"description\" content=\"$(_esc(_t("site.description")))\">$(_og_head(;title,desc=_t("site.description"),url=_lang_url(rel)))" : ""
 langnav=site ? _langnav(rel) : ""
 ev=sort(collect(events),by=_sortkey)
 summary="<div class=\"summary\"><span id=\"count\"></span><span class=\"sumbtns\"><button id=\"sharefilter\" type=\"button\">$(_t("copylink"))</button><button id=\"reset\" type=\"button\">$(_t("reset"))</button></span></div>"
 nomatch="<div class=\"empty\" id=\"empty\">$(_t("nomatch"))</div>"
 body=if view=="cards"
  _filterbar(ev)*"<main class=\"main\">$summary<div class=\"events\" id=\"events\">$(join((_card(e;correct_url,links=site) for e in ev),"\n"))</div>$nomatch</main>"
 elseif view=="compact"
  _filterbar(ev;sort=false)*"<main class=\"main\">$summary<div id=\"list\">$(_compact_view(ev;links=site))</div>$nomatch</main>"
 elseif view=="map"
  _filterbar(ev;sort=false,default_when="week")*"<main class=\"main\">$summary<div id=\"map\" class=\"map\" role=\"region\" aria-label=\"$(_t("map.view.aria"))\"></div><p id=\"nomap\" aria-live=\"polite\"></p><div id=\"list\">$(_compact_view(ev;links=site))</div>$nomatch</main>"
 else
  _filterbar(ev;when=false,sort=false)*"<main class=\"main\">$summary$(_week_view(ev;links=site,today))</main>"
 end
 ismap=view=="map"
 if embed   # for <iframe> on other sites: just the list; URL filters (?type=, ?q=, ?when=, ?arr=) still apply
  return """<!doctype html><html lang="$(_lang())"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title))</title><base href="$(_lang_url(""))" target="_top"><meta name="robots" content="noindex"><style>
$_CSS$_LANG_CSS.embedhead{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:10px 14px;background:linear-gradient(135deg,#26151d,#8b2949)}.embedhead a{color:white;text-decoration:none;font:500 1.15rem Georgia}.embedhead small{color:#f7dce5}.embed .filters,.embed .summary{display:none}.embed .main{padding:6px 12px 10px}.embedfoot{text-align:center;font-size:.78rem;padding:8px}.embedfoot a{color:var(--wine);font-weight:700}
</style></head><body class="embed">$_SPRITE<div class="embedhead"><a href="./">$(_esc(title))</a><small>$(_t("embed.upcoming"))</small></div>$body<div class="embedfoot"><a href="./">$(_t("embed.all"))</a></div>$(_page_script())</body></html>"""
 end
 """<!doctype html><html lang="$(_lang())"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title))</title>$headlinks$(ismap ? LEAFLET_HEAD : "")<style>
$_CSS$_LANG_CSS$(ismap ? _MAP_CSS : "")
</style></head><body>$_SPRITE<div class="hero"><div class="wrap"><div class="topbar"><small>$(_t("site.tagline"))</small>$langnav</div><h1>$(_esc(title))</h1><p>$(_esc(subtitle))</p>$hero_submit$tabs</div></div>$body<div class="sitefooter">$(_t("generated")) $(_esc(generated_at)) · $(_t("check"))$footer_submit$feeds</div>$(_page_script(ismap ? _map_js() : ""))</body></html>"""
end
function render_events_file(input::AbstractString,output::AbstractString="index.html";kwargs...)
 html=render_events_html(load_events(input);kwargs...); mkpath(dirname(abspath(output))); write(output,html); output
end
