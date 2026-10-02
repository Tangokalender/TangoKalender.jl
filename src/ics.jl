# iCalendar (RFC 5545): one .ics per event and the subscribable kalender.ics.
# Times are written in UTC (converted from the stored offset), so no VTIMEZONE block is needed.
const ICS_DOMAIN="tangokalender.github.io"
event_url(e)="$SITE_URL/arrangement/$(e["id"])/"
"Escape a TEXT value (backslash, semicolon, comma, newline)."
_icstext(s)=replace(string(s),'\\'=>"\\\\",';'=>"\\;",','=>"\\,","\r\n"=>"\\n",'\n'=>"\\n",'\r'=>"\\n")
"Fold a content line at 75 octets (continuation lines start with a space), never splitting a UTF-8 character."
function _fold(line)
 out=IOBuffer(); n=0; limit=75
 for c in line
  b=ncodeunits(string(c))
  if n+b>limit
   write(out,"\r\n "); n=1; limit=75
  end
  write(out,c); n+=b
 end
 String(take!(out))
end
"UTC timestamp `yyyymmddTHHMMSSZ` for a stored `YYYY-MM-DDTHH:MM:SS±HH:MM` (or `Z`)."
function _utc(stamp)
 m=match(r"^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(Z|([+-])(\d{2}):(\d{2}))$",string(stamp)); isnothing(m) && return nothing
 dt=DateTime("$(m[1])T$(m[2])")
 if m[3]!="Z"
  off=Hour(parse(Int,m[5]))+Minute(parse(Int,m[6])); dt=m[4]=="+" ? dt-off : dt+off
 end
 Dates.format(dt,"yyyymmdd\\THHMMSS\\Z")
end
_icsdate(d::Date)=Dates.format(d,"yyyymmdd")
"VEVENT lines for one event (without the surrounding VCALENDAR)."
function event_ics_lines(e; today::Date=Dates.today())
 s=_s(e["start"]); en=_s(get(e,"end",nothing)); (vname,vaddr)=_venue(e)
 L=["BEGIN:VEVENT","UID:$(e["id"])@$ICS_DOMAIN"]
 stamp=something(tryparse(Date,_s(get(e,"last_verified",nothing))),today); push!(L,"DTSTAMP:$(_icsdate(stamp))T000000Z")
 if occursin('T',s)
  push!(L,"DTSTART:$(_utc(s))")
  u=occursin('T',en) ? _utc(en) : nothing; isnothing(u) || push!(L,"DTEND:$u")
 else
  d=Date(first(s,10)); push!(L,"DTSTART;VALUE=DATE:$(_icsdate(d))")
  last_=isempty(en) ? d : Date(first(en,10)); push!(L,"DTEND;VALUE=DATE:$(_icsdate(max(last_,d)+Day(1)))")   # exclusive
 end
 push!(L,"SUMMARY:"*_icstext(_val(e,"title","Tango")))
 push!(L,"LOCATION:"*_icstext(join(filter(!isempty,[vname,vaddr]),", ")))
 desc=String[]; d_=_s(get(e,"description",nothing)); isempty(d_) || push!(desc,d_)
 p=_price(e); p=="Pris ikke oppgitt" || push!(desc,"Pris: $p")
 for (k,l) in ("dj"=>"DJ","organizer"=>"Arrangør"); v=_s(get(e,k,nothing)); isempty(v) || push!(desc,"$l: $v"); end
 t=join(something(get(e,"teachers",nothing),Any[]),", "); isempty(t) || push!(desc,"Lærere: $t")
 l=_http(get(e,"link",nothing)); isempty(l) || push!(desc,"Mer info: $l")
 push!(desc,event_url(e))
 push!(L,"DESCRIPTION:"*_icstext(join(desc,"\n")))
 push!(L,"URL:"*event_url(e))
 push!(L,"CATEGORIES:"*_icstext(_type_label(lowercase(_s(get(e,"type","other"))))))
 push!(L,"STATUS:"*(_s(get(e,"status",nothing))=="cancelled" ? "CANCELLED" : "CONFIRMED"))
 push!(L,"END:VEVENT")
 L
end
"""
    calendar_ics(events; name=SITE_NAME, today) -> String

A complete VCALENDAR (CRLF line endings, folded lines) with one VEVENT per event that has an id and a start.
"""
function calendar_ics(events; name=SITE_NAME, today::Date=Dates.today())
 L=["BEGIN:VCALENDAR","VERSION:2.0","PRODID:-//Tangokalender//TangoKalender.jl//NO","CALSCALE:GREGORIAN","METHOD:PUBLISH",
  "X-WR-CALNAME:"*_icstext(name),"X-WR-TIMEZONE:Europe/Oslo","X-WR-CALDESC:"*_icstext("Argentinsk tango i Oslo – $SITE_URL/"),
  "REFRESH-INTERVAL;VALUE=DURATION:PT12H","X-PUBLISHED-TTL:PT12H"]
 for e in sort([e for e in events if _haspage(e)],by=_sortkey); append!(L,event_ics_lines(e;today)); end
 push!(L,"END:VCALENDAR")
 join((_fold(l) for l in L),"\r\n")*"\r\n"
end
"The single-event calendar file linked as «Legg i kalender»."
event_ics(e; today::Date=Dates.today())=calendar_ics([e]; name=string(_val(e,"title","Tango")), today)
