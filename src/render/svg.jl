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
_svg_header(w,h,title,sub,href)=
 "<defs><linearGradient id=\"hero\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"#26151d\"/><stop offset=\"1\" stop-color=\"#8b2949\"/></linearGradient>"*
 "<symbol id=\"i-pin\" viewBox=\"0 0 24 24\">$(_ICON_PATHS["pin"])</symbol></defs>"*
 _svg_link(href,"<rect width=\"$w\" height=\"$h\" fill=\"url(#hero)\"/>"*_svg_text(20,h÷2+2,title;size=24,fill="#ffffff",extra=" font-family=\"Georgia,serif\"")*
  _svg_text(20,h÷2+22,sub;size=13,fill="#f7dce5");label="Åpne $(SITE_NAME)")
_svg_pin(x,y)="<use href=\"#i-pin\" xlink:href=\"#i-pin\" x=\"$x\" y=\"$(y-10)\" width=\"12\" height=\"12\" fill=\"none\" stroke=\"#6e6864\" stroke-width=\"2\"/>"
_svg_open(w,h,title,desc)="<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 $w $h\" width=\"$w\" height=\"$h\" font-family=\"$SVG_FONT\" role=\"img\" aria-labelledby=\"t d\"><title id=\"t\">$(_xml(title))</title><desc id=\"d\">$(_xml(desc))</desc><rect width=\"$w\" height=\"$h\" fill=\"#f5f1eb\"/>"
_on(e,d)=d in _days(e)
_eventhref(e)=event_url(e)
"""
    today_svg(events; today=Dates.today()) -> String

Today's schedule as a 600px-wide SVG in the list design; the header links to the calendar, each title to its event page.
"""
function today_svg(events; today::Date=Dates.today(), generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"))
 W=600; HEAD=86; ev=sort([e for e in events if _haspage(e) && _on(e,today)],by=e->_time_cell(e,today)=="pågår" ? "" : _sortkey(e))
 parts=String[]; y=HEAD+14
 if isempty(ev)
  push!(parts,_svg_link(SITE_URL*"/",_svg_text(20,y+24,"Ingen arrangementer i dag – se hele kalenderen →";size=14,fill="#872b49",weight=700);label="Se hele kalenderen"))
  y+=48
 end
 for e in ev
  cancelled=_s(get(e,"status",nothing))=="cancelled"; (vname,vaddr)=_venue(e)
  tl=_wrap(_s(e["title"]),52,2); y0=y
  push!(parts,_svg_text(20,y+16,_time_cell(e,today);size=13,weight=800,extra=cancelled ? " text-decoration=\"line-through\"" : ""))
  title=join((_svg_text(130,y+16+(k-1)*19,l;size=15,weight=700,fill="#211d1c",extra=cancelled ? " text-decoration=\"line-through\"" : "") for (k,l) in enumerate(tl)),"")
  push!(parts,_svg_link(_eventhref(e),title;label=_s(e["title"])*" – "*_date_label(e)))
  y+=16+19*(length(tl)-1)+20; x=130
  for t in _types(e)
   bg,fg=get(_CHIP_COLOURS,t,("#f2dce4","#76203e")); s,w=_svg_chip(x,y,_type_label(t);bg,fg); push!(parts,s); x+=w+5
  end
  if cancelled; s,w=_svg_chip(x,y,"Avlyst";bg=_CHIP_COLOURS["avlyst"][1],fg=_CHIP_COLOURS["avlyst"][2]); push!(parts,s); x+=w+5; end
  push!(parts,_svg_pin(x+2,y+1)); push!(parts,_svg_text(x+17,y,first(_wrap("$vname · $vaddr",max(10,round(Int,(W-x-30)/6.6)),1));size=11.5,fill="#6e6864"))
  y+=14; push!(parts,"<line x1=\"20\" y1=\"$(y)\" x2=\"$(W-20)\" y2=\"$(y)\" stroke=\"#ddd3ca\"/>"); y+=12
 end
 H=y+30
 push!(parts,_svg_link(SITE_URL*"/",_svg_text(20,H-12,"$(replace(SITE_URL,r"^https?://"=>"")) · oppdatert $generated_at";size=10.5,fill="#6e6864");label="Åpne kalenderen"))
 sub="I dag · $(_WD[dayofweek(today)]) $(day(today)). $(_MONTHS_LONG[month(today)])"
 _svg_open(W,H,"$(SITE_NAME) – $sub","Tangoarrangementer i Oslo i dag: $(length(ev)).")*_svg_header(W,HEAD,SITE_NAME,sub,SITE_URL*"/")*join(parts,"")*"</svg>"
end
"""
    week_svg(events; today=Dates.today()) -> String

This week's schedule (Monday–Sunday of `today`'s ISO week) as a 980px-wide 7-column SVG like the week view.
"""
function week_svg(events; today::Date=Dates.today(), generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"))
 W=980; HEAD=78; PAD=16; GAP=6; CW=(W-2PAD-6GAP)÷7
 mon=today-Day(dayofweek(today)-1); sun=mon+Day(6); key=_isoweek(mon)
 range_=month(mon)==month(sun) ? "$(day(mon)).–$(day(sun)). $(_MO[month(sun)])" : "$(day(mon)). $(_MO[month(mon)]) – $(day(sun)). $(_MO[month(sun)])"
 sub="Uke $(week(mon)) · $range_"; href="$SITE_URL/uke.html#uke-$(replace(key,"-W"=>"-"))"
 cols=String[]; colh=Int[]; top=HEAD+12
 for (i,d) in enumerate(mon:Day(1):sun)
  x=PAD+(i-1)*(CW+GAP); parts=String[]; y=top+30
  ev=sort([e for e in events if _haspage(e) && _on(e,d)],by=e->_time_cell(e,d)=="pågår" ? "" : _sortkey(e))
  isempty(ev) && (push!(parts,_svg_text(x+CW÷2,y+20,"–";size=14,fill="#6e6864",extra=" text-anchor=\"middle\"")); y+=34)
  for e in ev
   cancelled=_s(get(e,"status",nothing))=="cancelled"; (vname,_)=_venue(e); ts=filter(!=("outdoor"),_types(e))
   edge=_TYPE_EDGE[isempty(ts) ? "other" : first(ts)]; bg="outdoor" in _types(e) ? "#f3f8f1" : "#faf6f2"
   tl=_wrap(_s(e["title"]),15,3); vl=first(_wrap(vname,19,1)); h=16+15*length(tl)+16; y0=y
   strike=cancelled ? " text-decoration=\"line-through\"" : ""
   inner="<rect x=\"$(x+6)\" y=\"$y\" width=\"$(CW-12)\" height=\"$h\" rx=\"6\" fill=\"$bg\"/><rect x=\"$(x+6)\" y=\"$y\" width=\"3\" height=\"$h\" fill=\"$edge\"/>"*
    _svg_text(x+14,y+14,_time_cell(e,d)*(cancelled ? " · avlyst" : "");size=10.5,weight=800,extra=strike)*
    join((_svg_text(x+14,y+29+(k-1)*15,l;size=11.5,weight=700,extra=strike) for (k,l) in enumerate(tl)),"")*
    _svg_text(x+14,y+29+15*length(tl)+1,vl;size=10,fill="#6e6864")
   push!(parts,_svg_link(_eventhref(e),inner;label=_s(e["title"])*" – "*_date_label(e)))
   y+=h+6
  end
  istoday=d==today; wkend=dayofweek(d)>=6
  head="<text x=\"$(x+10)\" y=\"$(top+19)\" font-size=\"10\" font-weight=\"800\" fill=\"$(istoday ? "#872b49" : "#6e6864")\" letter-spacing=\".5\">$(uppercase(_WD3[dayofweek(d)]))</text>"*
   "<text x=\"$(x+CW-10)\" y=\"$(top+19)\" font-size=\"12\" font-weight=\"700\" fill=\"$(istoday ? "#872b49" : "#211d1c")\" text-anchor=\"end\">$(day(d)). $(_MO[month(d)])</text>"*
   "<line x1=\"$(x+8)\" y1=\"$(top+26)\" x2=\"$(x+CW-8)\" y2=\"$(top+26)\" stroke=\"#ddd3ca\"/>"
  push!(colh,y-top+4)
  # clip each column so nothing can spill into the next one (font widths vary between systems)
  push!(cols,"<clipPath id=\"col$i\"><rect x=\"$x\" y=\"$top\" width=\"$CW\" height=\"COLH\" rx=\"10\"/></clipPath><g data-day=\"$d\">COLRECT_$(i)<g clip-path=\"url(#col$i)\">$head$(join(parts,""))</g></g>")
  cols[end]=replace(cols[end],"COLRECT_$(i)"=>"<rect x=\"$x\" y=\"$top\" width=\"$CW\" height=\"COLH\" rx=\"10\" fill=\"$(wkend ? "#fbf8f4" : "#ffffff")\" stroke=\"$(istoday ? "#872b49" : "#ddd3ca")\" stroke-width=\"$(istoday ? 2 : 1)\"/>")
 end
 ch=maximum(colh); H=top+ch+34
 body=join((replace(c,"COLH"=>string(ch)) for c in cols),"")
 foot=_svg_link(href,_svg_text(PAD,H-12,"$(replace(SITE_URL,r"^https?://"=>"")) · oppdatert $generated_at";size=10.5,fill="#6e6864");label="Åpne ukevisningen")
 _svg_open(W,H,"$(SITE_NAME) – $sub","Tangoarrangementer i Oslo denne uken.")*_svg_header(W,HEAD,SITE_NAME,sub,href)*body*foot*"</svg>"
end
