# One page per event: arrangement/<id>/index.html (linkable, with schema.org JSON-LD and OpenGraph for previews).
_iso_dt(stamp)=(s=_s(stamp); isempty(s) ? nothing : s)
"schema.org Event as JSON-LD (escaped for a <script> block)."
function _event_jsonld(e)
 (vname,vaddr)=_venue(e); cancelled=_s(get(e,"status",nothing))=="cancelled"
 d=JSON.Object{String,Any}("@context"=>"https://schema.org","@type"=>"Event","name"=>_s(e["title"]),"url"=>event_url(e),
  "startDate"=>_s(e["start"]),"eventAttendanceMode"=>"https://schema.org/OfflineEventAttendanceMode",
  "eventStatus"=>"https://schema.org/"*(cancelled ? "EventCancelled" : "EventScheduled"),
  "location"=>JSON.Object{String,Any}("@type"=>"Place","name"=>vname,"address"=>JSON.Object{String,Any}("@type"=>"PostalAddress",
   "streetAddress"=>vaddr,"addressLocality"=>something(_none(_s(get(something(get(e,"venue",nothing),Dict()),"city",nothing))),"Oslo"),"addressCountry"=>"NO")))
 en=_iso_dt(get(e,"end",nothing)); isnothing(en) || (d["endDate"]=en)
 desc=_s(get(e,"description",nothing)); isempty(desc) || (d["description"]=desc)
 org=_s(get(e,"organizer",nothing)); isempty(org) || (d["organizer"]=JSON.Object{String,Any}("@type"=>"Organization","name"=>org))
 img=_http(get(e,"flyer_url",nothing)); isempty(img) || (d["image"]=[img])
 p=get(e,"price_nok",nothing); c=get(e,"class_price_nok",nothing); price=something(p,c,missing)
 ismissing(price) || (d["offers"]=JSON.Object{String,Any}("@type"=>"Offer","price"=>price,"priceCurrency"=>"NOK","url"=>something(_none(_http(get(e,"link",nothing))),event_url(e))))
 replace(JSON.json(d),"<"=>"\\u003c",">"=>"\\u003e","&"=>"\\u0026")   # safe inside <script>
end
_dd(label,html,icon)=isempty(html) ? "" : "<dt>$(_icon(icon))$label</dt><dd>$html</dd>"
"""
    render_event_page(e, events; today=Dates.today(), correct_url=CORRECT_URL) -> String

Full page for one event; `events` is used to list the other upcoming dates in the same series.
Links are relative to `arrangement/<id>/`.
"""
function render_event_page(e, events; today::Date=Dates.today(), correct_url=CORRECT_URL, generated_at=Dates.format(now(),dateformat"yyyy-mm-dd HH:MM"))
 title=_s(e["title"]); t=_esc(title); (vname,vaddr)=_venue(e); typ=lowercase(_s(get(e,"type","other")))
 cancelled=_s(get(e,"status",nothing))=="cancelled"; past=Date(_end_day(e))<today; url=event_url(e)
 desc=_s(get(e,"description",nothing)); flyer=_esc(_http(get(e,"flyer_url",nothing)))
 ogdesc=_esc(first(isempty(desc) ? "$(_date_label(e)) · $vname" : "$(_date_label(e)) · $vname. $desc",300))
 maplink="<a href=\"https://www.openstreetmap.org/search?query=$(_urlenc("$vaddr, $(something(_none(_s(get(something(get(e,"venue",nothing),Dict()),"city",nothing))),"Oslo"))"))\" target=\"_blank\" rel=\"noopener\">Kart ↗</a>"
 teachers=join(something(get(e,"teachers",nothing),Any[]),", ")
 music=join((_music_label(m) for m in _music(e)),", ")
 p=_price(e)
 info=_esc(_http(get(e,"link",nothing))); src=_esc(_http(get(e,"source_url",nothing)))
 links=String["<a class=\"btn primary\" href=\"../$(_esc(e["id"])).ics\" download>$(_icon("calendar"))Legg i kalender (.ics)</a>"]
 isempty(info) || push!(links,"<a class=\"btn\" href=\"$info\" target=\"_blank\" rel=\"noopener\">Mer info ↗</a>")
 push!(links,"<button class=\"btn\" id=\"share\" type=\"button\" data-url=\"$(_esc(url))\">Del lenke</button>")
 isempty(_http(correct_url)) || push!(links,"<a class=\"btn\" href=\"$(_esc(correction_url(e;base=_http(correct_url))))\" target=\"_blank\" rel=\"noopener\">Rett opp ↗</a>")
 series=_s(get(e,"series",nothing))
 sibs=isempty(series) ? Any[] : sort([x for x in events if _s(get(x,"series",nothing))==series && x["id"]!=e["id"] && _haspage(x) && Date(_end_day(x))>=today],by=_sortkey)
 sibhtml=isempty(sibs) ? "" : "<section class=\"card\"><h2>Flere datoer i denne serien</h2><ul class=\"sibs\">"*
  join(("<li><a href=\"../$(_esc(x["id"]))/\">$(_esc(_date_label(x)))</a>$(_s(get(x,"status",nothing))=="cancelled" ? " <span class=\"chip avlyst\">Avlyst</span>" : "")</li>" for x in first(sibs,20)),"")*"</ul></section>"
 sourceline=isempty(src) ? _esc(_s(get(e,"source",nothing))) : "<a href=\"$src\" target=\"_blank\" rel=\"noopener\">$(_esc(_s(get(e,"source","Kilde"))))</a>"
 details=_dd("Når",_esc(_date_label(e)),"clock")*_dd("Hvor","<b>$(_esc(vname))</b><br>$(_esc(vaddr)) · $maplink","pin")*
  _dd("Arrangør",_esc(_s(get(e,"organizer",nothing))),"org")*_dd("DJ",_esc(_s(get(e,"dj",nothing))),"dj")*_dd("Lærere",_esc(teachers),"teachers")*
  _dd("Pris",p=="Pris ikke oppgitt" ? "" : _esc(p),"price")*_dd("Musikk",_esc(music),"music")
 media=(isempty(flyer) ? "" : "<img class=\"flyer\" src=\"$flyer\" alt=\"Flyer: $t\" loading=\"lazy\">")*_video(e)
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$t – $(_esc(_date_label(e))) – $(_esc(SITE_NAME))</title>
<link rel="canonical" href="$(_esc(url))"><link rel="alternate" type="application/rss+xml" title="$(_esc(SITE_NAME))" href="../../rss.xml">
<meta name="description" content="$ogdesc"><meta property="og:type" content="website"><meta property="og:title" content="$t"><meta property="og:description" content="$ogdesc"><meta property="og:url" content="$(_esc(url))"><meta property="og:locale" content="nb_NO">$(isempty(flyer) ? "" : "<meta property=\"og:image\" content=\"$flyer\">")
<script type="application/ld+json">$(_event_jsonld(e))</script><style>
$_CSS.page{max-width:820px;margin:-40px auto 0;padding:0 16px 50px}.card{background:white;border:1px solid var(--line);border-radius:18px;padding:22px;margin-bottom:16px;box-shadow:0 5px 18px #2919210b}.card h2{font:500 1.35rem Georgia;margin:0 0 10px}dl{display:grid;grid-template-columns:110px 1fr;gap:10px 16px;margin:0}dt{color:var(--muted);font-weight:800;font-size:.8rem;text-transform:uppercase;padding-top:2px}dd{margin:0}.desc{line-height:1.6;white-space:pre-line}.actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:16px}.btn{display:inline-block;border:1px solid var(--line);border-radius:999px;padding:9px 16px;background:white;color:var(--wine);font-weight:800;text-decoration:none;font-size:.9rem;cursor:pointer}.btn.primary{background:var(--wine);border-color:var(--wine);color:white}.hero .back{color:#f7dce5;text-decoration:none;font-weight:700}.hero .when{font-size:1.15rem;color:white;font-weight:700}.notice{background:#fff4e5;border:1px solid #f0d3a8;border-radius:12px;padding:10px 14px;margin-bottom:14px}.sibs{margin:0;padding-left:1.2em}.sibs li{margin:4px 0}.cancelled-title{text-decoration:line-through}@media(max-width:560px){dl{grid-template-columns:1fr}dt{padding-top:8px}}
</style></head><body>$_SPRITE<div class="hero"><div class="wrap"><a class="back" href="../../">← $(_esc(SITE_NAME))</a><h1 class="$(cancelled ? "cancelled-title" : "")">$t</h1><p class="when">$(_esc(_date_label(e)))</p><p><span class="chip">$(_esc(_type_label(typ)))</span>$(cancelled ? " <span class=\"chip avlyst\">Avlyst</span>" : "")</p></div></div><main class="page">
$(cancelled ? "<div class=\"notice\"><b>Avlyst.</b> Arrangementet er avlyst – sjekk med arrangøren.</div>" : past ? "<div class=\"notice\">Dette arrangementet har vært.</div>" : "")
<section class="card"><dl>$details</dl>$(isempty(desc) ? "" : "<p class=\"desc\">$(_esc(desc))</p>")$(isempty(media) ? "" : "<div class=\"media\">$media</div>")<div class="actions">$(join(links,""))</div><p class="muted" style="color:var(--muted);font-size:.8rem;margin:14px 0 0">Kilde: $sourceline · Sist kontrollert $(_esc(_s(get(e,"last_verified",nothing)))) · Kontroller alltid detaljer hos arrangøren.</p></section>
$sibhtml</main><div class="sitefooter">Generert $(_esc(generated_at)) · <a href="../../">Hele kalenderen</a> · <a href="../../kalender.ics">Abonner (.ics)</a> · <a href="../../rss.xml">RSS</a></div><script>
(function(){var b=document.getElementById('share');if(!b)return;b.addEventListener('click',function(){var u=b.getAttribute('data-url');if(navigator.share){navigator.share({title:document.title,url:u}).catch(function(){})}else if(navigator.clipboard){navigator.clipboard.writeText(u).then(function(){b.textContent='Lenke kopiert ✓'})}else{prompt('Kopier lenken:',u)}})})();
</script></body></html>"""
end
