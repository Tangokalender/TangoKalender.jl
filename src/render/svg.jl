# Embeddable SVG schedules for other websites: embed/i-dag.svg (today) and embed/uke.svg (this week).
# «Today» is the build date (Pages rebuilds nightly with TZ=Europe/Oslo). Links only work when the SVG is embedded with
# <object>/<iframe> or inline – not <img> – and use target="_top" so they open in the whole window (see bygg-inn.html).
const SVG_FONT="system-ui,-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
const _CHIP_COLOURS=Dict("outdoor"=>("#e3efe0","#2f5a2a"),"avlyst"=>("#b3261e","#ffffff"))
const _TYPE_EDGE=Dict("milonga"=>"#872b49","practica"=>"#b48a9b","festival"=>"#5b4636","marathon"=>"#5b4636",
 "class"=>"#8c7a6b","workshop"=>"#8c7a6b","outdoor"=>"#5f8f55","other"=>"#d9b8c5")
"""
    _wrap(text, maxchars, maxlines) -> Vector{String}

Word-wrap `text` into at most `maxlines` lines of about `maxchars` characters (SVG text does not wrap by itself);
the last line gets an ellipsis if text is left over, and over-long words are cut.
"""
function _wrap(text, maxchars::Int, maxlines::Int)
 words=split(strip(string(text))); lines=String[]; cur=""
 for w in words
  w=length(w)>maxchars ? first(w,maxchars-1)*"…" : String(w)
  if isempty(cur); cur=w
  elseif length(cur)+1+length(w)<=maxchars; cur*=" "*w
  else
   push!(lines,cur); cur=w
   if length(lines)==maxlines
    l=lines[end]; lines[end]=(length(l)>=maxchars ? first(l,maxchars-1) : l)*"…"; return lines
   end
  end
 end
 isempty(cur) || push!(lines,cur)
 if length(lines)>maxlines
  lines=lines[1:maxlines]; l=lines[end]; lines[end]=(length(l)>=maxchars ? first(l,maxchars-1) : l)*"…"
 end
 lines
end
_svg_link(href,inner;label="")="<a href=\"$(_xml(href))\" xlink:href=\"$(_xml(href))\" target=\"_top\">$(isempty(label) ? "" : "<title>$(_xml(label))</title>")$inner</a>"
_svg_text(x,y,s;size=13,weight=400,fill="#211d1c",extra="")="<text x=\"$x\" y=\"$y\" font-size=\"$size\" font-weight=\"$weight\" fill=\"$fill\"$extra>$(_xml(s))</text>"
"Small rounded chip; returns (svg, width). Width is estimated from the label length."
function _svg_chip(x,y,label;bg="#f2dce4",fg="#76203e")
 w=round(Int,length(label)*7.0+14)   # uppercase 9px bold with letter-spacing
 ("<rect x=\"$x\" y=\"$(y-10)\" width=\"$w\" height=\"14\" rx=\"7\" fill=\"$bg\"/><text x=\"$(x+7)\" y=\"$y\" font-size=\"9\" font-weight=\"800\" fill=\"$fg\" letter-spacing=\".4\">$(_xml(uppercase(label)))</text>",w)
end
_svg_defs()="<defs><linearGradient id=\"hero\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"#26151d\"/><stop offset=\"1\" stop-color=\"#8b2949\"/></linearGradient>"*
 "<symbol id=\"i-pin\" viewBox=\"0 0 24 24\">$(_ICON_PATHS["pin"])</symbol></defs>"
_svg_header(w,h,title,sub,href)=_svg_link(href,"<rect width=\"$w\" height=\"$h\" fill=\"url(#hero)\"/>"*_svg_text(20,h÷2+2,title;size=24,fill="#ffffff",extra=" font-family=\"Georgia,serif\"")*
 _svg_text(20,h÷2+22,sub;size=13,fill="#f7dce5");label="Åpne $(SITE_NAME)")
_svg_pin(x,y)="<use href=\"#i-pin\" xlink:href=\"#i-pin\" x=\"$x\" y=\"$(y-10)\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"#6e6864\" stroke-width=\"2\"/>"
_svg_open(w,h,title,desc)="<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 $w $h\" width=\"$w\" height=\"$h\" font-family=\"$SVG_FONT\" role=\"img\" aria-labelledby=\"t d\"><title id=\"t\">$(_xml(title))</title><desc id=\"d\">$(_xml(desc))</desc><rect width=\"$w\" height=\"$h\" fill=\"#f5f1eb\"/>"
_on(e,d)=d in _days(e)
_eventhref(e)=event_url(e)
_footer_text(generated_at)="$(replace(SITE_URL,r"^https?://"=>"")) · oppdatert $generated_at"
"""
Script inside the SVG: show the `<g data-date>` group for today's date **in Oslo** (or the Monday of this week when
`mode="week"`), so an image embedded with <object>/<iframe> is right from midnight regardless of when Pages rebuilt it.
In <img> scripts do not run, and the group for the build date (visible by default) is shown.
"""
_svg_dayscript(mode)="<script><![CDATA[(function(){try{var t=new Intl.DateTimeFormat('sv-SE',{timeZone:'Europe/Oslo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());"*
 "if('$mode'==='week'){var d=new Date(t+'T00:00:00Z');d.setUTCDate(d.getUTCDate()-((d.getUTCDay()+6)%7));t=d.toISOString().slice(0,10)}"*
 "var g=document.querySelectorAll('g[data-date]'),hit=null,i;for(i=0;i<g.length;i++)if(g[i].getAttribute('data-date')===t)hit=g[i];"*
 "if(!hit&&g.length>1&&t>g[g.length-2].getAttribute('data-date'))hit=document.querySelector('g[data-date=stale]');"*
 "if(hit)for(i=0;i<g.length;i++)g[i].setAttribute('display',g[i]===hit?'inline':'none')}catch(e){}})();]]></script>"
"Shown (by the script) when today is past the last day in the image, i.e. the nightly rebuild has stopped: never an old program."
_svg_stale(W,H,HEAD,href)="<g data-date=\"stale\" display=\"none\">"*_svg_header(W,HEAD,SITE_NAME,"Programmet er ikke oppdatert",href)*
 _svg_link(href,_svg_text(20,HEAD+40,"Se det oppdaterte programmet i kalenderen →";size=14,fill="#872b49",weight=700);label="Åpne kalenderen")*"</g>"
"Body of one day for the today image: (svg, height)."
function _today_day(events,d,W,HEAD)
 ev=sort([e for e in events if _haspage(e) && _on(e,d)],by=e->_time_cell(e,d)=="pågår" ? "" : _sortkey(e))
 parts=String[]; y=HEAD+14
 if isempty(ev)
  push!(parts,_svg_link(SITE_URL*"/",_svg_text(20,y+24,"Ingen arrangementer i dag – se hele kalenderen →";size=14,fill="#872b49",weight=700);label="Se hele kalenderen"))
  y+=48
 end
 for e in ev
  cancelled=_s(get(e,"status",nothing))=="cancelled"; (vname,vaddr)=_venue(e); tl=_wrap(_s(e["title"]),52,2)
  strike=cancelled ? " text-decoration=\"line-through\"" : ""
  push!(parts,_svg_text(20,y+16,_time_cell(e,d);size=13,weight=800,extra=strike))
  push!(parts,_svg_link(_eventhref(e),join((_svg_text(130,y+16+(k-1)*19,l;size=15,weight=700,extra=strike) for (k,l) in enumerate(tl)),"");label=_s(e["title"])*" – "*_date_label(e)))
  y+=16+19*(length(tl)-1)+20; x=130
  for t in _types(e)
   bg,fg=get(_CHIP_COLOURS,t,("#f2dce4","#76203e")); c,w=_svg_chip(x,y,_type_label(t);bg,fg); push!(parts,c); x+=w+5
  end
  if cancelled; c,w=_svg_chip(x,y,"Avlyst";bg=_CHIP_COLOURS["avlyst"][1],fg=_CHIP_COLOURS["avlyst"][2]); push!(parts,c); x+=w+5; end
  push!(parts,_svg_pin(x+2,y+1)); push!(parts,_svg_text(x+17,y,first(_wrap("$vname · $vaddr",max(10,round(Int,(W-x-30)/6.6)),1));size=11.5,fill="#6e6864"))
  y+=14; push!(parts,"<line x1=\"20\" y1=\"$y\" x2=\"$(W-20)\" y2=\"$y\" stroke=\"#ddd3ca\"/>"); y+=12
 end
 (join(parts,""),y,length(ev))
end
"""
    today_svg(events; today=Dates.today(), days=8) -> String

Today's schedule as a 600px-wide SVG in the list design. Contains `days` day groups (`today` and the following days);
the embedded script shows the one for the current Oslo date, so the image stays right between rebuilds.
"""
function today_svg(events; today::Date=Dates.today(), days::Int=8, generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"))
 W=600; HEAD=86
 groups=[(d,_today_day(events,d,W,HEAD)...) for d in today:Day(1):today+Day(days-1)]
 H=maximum(g[3] for g in groups)+30     # same height for every day: the embed box never needs to resize
 out=String[]
 for (d,body,_,n) in groups
  sub="I dag · $(_WD[dayofweek(d)]) $(day(d)). $(_MONTHS_LONG[month(d)])"
  push!(out,"<g data-date=\"$d\" display=\"$(d==today ? "inline" : "none")\">"*_svg_header(W,HEAD,SITE_NAME,sub,SITE_URL*"/")*body*
   _svg_link(SITE_URL*"/",_svg_text(20,H-12,_footer_text(generated_at);size=10.5,fill="#6e6864");label="Åpne kalenderen")*"</g>")
 end
 _svg_open(W,H,"$(SITE_NAME) – dagens program","Tangoarrangementer i Oslo i dag.")*_svg_defs()*join(out,"")*_svg_stale(W,H,HEAD,SITE_URL*"/")*_svg_dayscript("day")*"</svg>"
end
"Body of one week (Monday `mon`) for the week image: (svg, column height). `k` makes clip-path ids unique."
function _week_body(events,mon,today,W,HEAD,PAD,GAP,CW,k)
 cols=String[]; colh=Int[]; top=HEAD+12
 for (i,d) in enumerate(mon:Day(1):mon+Day(6))
  x=PAD+(i-1)*(CW+GAP); parts=String[]; y=top+30
  ev=sort([e for e in events if _haspage(e) && _on(e,d)],by=e->_time_cell(e,d)=="pågår" ? "" : _sortkey(e))
  isempty(ev) && (push!(parts,_svg_text(x+CW÷2,y+20,"–";size=14,fill="#6e6864",extra=" text-anchor=\"middle\"")); y+=34)
  for e in ev
   cancelled=_s(get(e,"status",nothing))=="cancelled"; (vname,_)=_venue(e); ts=filter(!=("outdoor"),_types(e))
   edge=_TYPE_EDGE[isempty(ts) ? "other" : first(ts)]; bg="outdoor" in _types(e) ? "#f3f8f1" : "#faf6f2"
   tl=_wrap(_s(e["title"]),15,3); vl=first(_wrap(vname,19,1)); h=16+15*length(tl)+16
   strike=cancelled ? " text-decoration=\"line-through\"" : ""
   inner="<rect x=\"$(x+6)\" y=\"$y\" width=\"$(CW-12)\" height=\"$h\" rx=\"6\" fill=\"$bg\"/><rect x=\"$(x+6)\" y=\"$y\" width=\"3\" height=\"$h\" fill=\"$edge\"/>"*
    _svg_text(x+14,y+14,_time_cell(e,d)*(cancelled ? " · avlyst" : "");size=10.5,weight=800,extra=strike)*
    join((_svg_text(x+14,y+29+(j-1)*15,l;size=11.5,weight=700,extra=strike) for (j,l) in enumerate(tl)),"")*
    _svg_text(x+14,y+29+15*length(tl)+1,vl;size=10,fill="#6e6864")
   push!(parts,_svg_link(_eventhref(e),inner;label=_s(e["title"])*" – "*_date_label(e)))
   y+=h+6
  end
  istoday=d==today; wkend=dayofweek(d)>=6; cid="w$(k)c$i"
  head="<text x=\"$(x+10)\" y=\"$(top+19)\" font-size=\"10\" font-weight=\"800\" fill=\"$(istoday ? "#872b49" : "#6e6864")\" letter-spacing=\".5\">$(uppercase(_WD3[dayofweek(d)]))</text>"*
   "<text x=\"$(x+CW-10)\" y=\"$(top+19)\" font-size=\"12\" font-weight=\"700\" fill=\"$(istoday ? "#872b49" : "#211d1c")\" text-anchor=\"end\">$(day(d)). $(_MO[month(d)])</text>"*
   "<line x1=\"$(x+8)\" y1=\"$(top+26)\" x2=\"$(x+CW-8)\" y2=\"$(top+26)\" stroke=\"#ddd3ca\"/>"
  push!(colh,y-top+4)
  # clip each column so nothing can spill into the next one (font widths vary between systems)
  push!(cols,"<clipPath id=\"$cid\"><rect x=\"$x\" y=\"$top\" width=\"$CW\" height=\"COLH\" rx=\"10\"/></clipPath><g data-day=\"$d\">"*
   "<rect x=\"$x\" y=\"$top\" width=\"$CW\" height=\"COLH\" rx=\"10\" fill=\"$(wkend ? "#fbf8f4" : "#ffffff")\" stroke=\"$(istoday ? "#872b49" : "#ddd3ca")\" stroke-width=\"$(istoday ? 2 : 1)\"/>"*
   "<g clip-path=\"url(#$cid)\">$head$(join(parts,""))</g></g>")
 end
 (join(cols,""),maximum(colh))
end
"""
    week_svg(events; today=Dates.today(), weeks=2) -> String

This week's schedule (Monday–Sunday) as a 980px-wide 7-column SVG like the week view. Contains `weeks` week groups
(this week and the next); the embedded script shows the current Oslo week, so the image stays right between rebuilds.
"""
function week_svg(events; today::Date=Dates.today(), weeks::Int=2, generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"))
 W=980; HEAD=78; PAD=16; GAP=6; CW=(W-2PAD-6GAP)÷7; top=HEAD+12
 mon0=today-Day(dayofweek(today)-1)
 bodies=[(mon0+Week(k-1),_week_body(events,mon0+Week(k-1),today,W,HEAD,PAD,GAP,CW,k)...) for k in 1:weeks]
 ch=maximum(b[3] for b in bodies); H=top+ch+34
 out=String[]
 for (mon,body,_) in bodies
  sun=mon+Day(6); key=_isoweek(mon)
  range_=month(mon)==month(sun) ? "$(day(mon)).–$(day(sun)). $(_MO[month(sun)])" : "$(day(mon)). $(_MO[month(mon)]) – $(day(sun)). $(_MO[month(sun)])"
  href="$SITE_URL/uke.html#uke-$(replace(key,"-W"=>"-"))"
  push!(out,"<g data-date=\"$mon\" data-week=\"$key\" display=\"$(mon==mon0 ? "inline" : "none")\">"*_svg_header(W,HEAD,SITE_NAME,"Uke $(week(mon)) · $range_",href)*
   replace(body,"COLH"=>string(ch))*_svg_link(href,_svg_text(PAD,H-12,_footer_text(generated_at);size=10.5,fill="#6e6864");label="Åpne ukevisningen")*"</g>")
 end
 _svg_open(W,H,"$(SITE_NAME) – ukens program","Tangoarrangementer i Oslo denne uken.")*_svg_defs()*join(out,"")*_svg_stale(W,H,HEAD,"$SITE_URL/uke.html")*_svg_dayscript("week")*"</svg>"
end
