# RSS 2.0 feed of upcoming events, newest additions first.
const RSS_MAX=100
const _RFC822_D=["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
const _RFC822_M=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
"Escape for XML text/attributes; drops control characters XML 1.0 does not allow."
_xml(s)=replace(replace(string(s),r"[\x00-\x08\x0B\x0C\x0E-\x1F]"=>""),'&'=>"&amp;",'<'=>"&lt;",'>'=>"&gt;",'"'=>"&quot;",'\''=>"&apos;")
"RFC 822 date at 00:00 Oslo time on `d`, e.g. `Fri, 02 Oct 2026 00:00:00 +0200`."
_rfc822(d::Date)="$(_RFC822_D[dayofweek(d)]), $(lpad(day(d),2,'0')) $(_RFC822_M[month(d)]) $(year(d)) 00:00:00 $(replace(oslo_offset(d,"00:00"),":"=>""))"
_short_label(e)=(d=Date(_iso(e)); "$(_wd3(d)) $(_dm(d))")
"""
    rss_xml(events; today, title=site_name(), lang="nb") -> String

Upcoming events (end day ≥ `today`), most recently added (`first_seen`) first, at most $RSS_MAX, in language `lang`.
"""
rss_xml(events; lang="nb", kwargs...)=_with_lang(()->_rss_xml(events;kwargs...),lang)
function _rss_xml(events; today::Date=Dates.today(), title=site_name())
 seen(e)=something(tryparse(Date,_s(get(e,"first_seen",nothing))),Date(_iso(e)))
 ev=[e for e in events if _haspage(e) && Date(_end_day(e))>=today]
 sort!(ev,by=e->(-Dates.value(seen(e)),_sortkey(e)))
 items=String[]
 for e in first(ev,RSS_MAX)
  (vname,vaddr)=_venue(e); cancelled=_s(get(e,"status",nothing))=="cancelled"
  parts=["<p><b>$(_esc(_date_label(e)))</b>$(cancelled ? " – <b>$(_t("cancelled.caps"))</b>" : "")</p>","<p>$(_esc(vname)), $(_esc(vaddr))</p>"]
  p=_price(e); isempty(p) || push!(parts,"<p>$(_esc(p))</p>")
  dj=_s(get(e,"dj",nothing)); isempty(dj) || push!(parts,"<p>DJ: $(_esc(dj))</p>")
  d=first(_text(e,"description")); isempty(d) || push!(parts,"<p>$(_esc(d))</p>")
  push!(items,"""<item><title>$(_xml((cancelled ? _t("cancelled.caps")*": " : "")*_short_label(e)*" · "*_title(e)))</title><link>$(_xml(event_url(e)))</link><guid isPermaLink="true">$(_xml(event_url(e)))</guid><pubDate>$(_rfc822(seen(e)))</pubDate>$(join(("<category>$(_xml(_type_label(t)))</category>" for t in _types(e)),""))<description>$(_xml(join(parts,"")))</description></item>""")
 end
 """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>$(_xml(title))</title><link>$(_lang_url(""))</link><description>$(_xml(_t("site.description")))</description><language>$(_lang())</language><atom:link href="$(_lang_url("rss.xml"))" rel="self" type="application/rss+xml"/><lastBuildDate>$(_rfc822(today))</lastBuildDate>
$(join(items,"\n"))
</channel></rss>
"""
end
