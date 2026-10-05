# «Bygg inn kalenderen» (bygg-inn.html): how organisers and others put the calendar on their own website, plus
# events.json for developers. The SVGs come from src/render/svg.jl; the iframe list is render_events_html(embed=true).
const EMBED_PAGE="bygg-inn.html"
const EMBED_TODAY="embed/i-dag.svg"
const EMBED_WEEK="embed/uke.svg"
const EMBED_LIST="embed/liste.html"
"""
    events_json(events; today=Dates.today()) -> String

Upcoming events (end day ≥ `today`) in the stored format, sorted by start – a simple feed for developers.
"""
events_json(events; today::Date=Dates.today())=sprint(io->(JSON.print(io,sort([e for e in events if _haspage(e) && Date(_end_day(e))>=today],by=_sortkey),2); write(io,'\n')))
_codeblock(id,code)="<div class=\"codebox\"><pre id=\"$id\"><code>$(_esc(code))</code></pre><button type=\"button\" class=\"copybtn\" data-copy=\"$id\">Kopier koden</button></div>"
function bygg_inn_html(; title="Bygg inn kalenderen")
 t=SITE_URL*"/"*EMBED_TODAY; w=SITE_URL*"/"*EMBED_WEEK; l=SITE_URL*"/"*EMBED_LIST
 obj_today="""<object type="image/svg+xml" data="$t" style="width:100%;max-width:600px">
  <a href="$SITE_URL/">Se dagens tango i Oslo</a>
</object>"""
 obj_week="""<object type="image/svg+xml" data="$w" style="width:100%;max-width:980px">
  <a href="$SITE_URL/uke.html">Se ukens tango i Oslo</a>
</object>"""
 img_today="""<a href="$SITE_URL/"><img src="$t" alt="Dagens tango i Oslo – $(SITE_NAME)" style="width:100%;max-width:600px"></a>"""
 ifr="""<iframe src="$l" title="$(SITE_NAME)" style="width:100%;height:600px;border:0" loading="lazy"></iframe>"""
 typeopts=join(("<option value=\"$t_\">$(_esc(_type_label(t_)))</option>" for t_ in TYPE_ORDER),"")
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(SITE_NAME))</title><link rel="canonical" href="$SITE_URL/$EMBED_PAGE"><style>
$_PAGE_CSS.codebox{position:relative;margin:10px 0}.codebox pre{margin:0;padding-right:120px}.copybtn{position:absolute;top:8px;right:8px;border:0;border-radius:999px;background:var(--wine);color:white;font-weight:800;padding:6px 12px;cursor:pointer;font-size:.8rem}.preview{border:1px dashed var(--line);border-radius:12px;padding:10px;background:#fff;overflow:auto}.preview object{display:block;width:100%}.builder{display:flex;flex-wrap:wrap;gap:10px;align-items:end;margin:8px 0}.builder label{display:block;font-size:.72rem;text-transform:uppercase;color:var(--muted);font-weight:800}.builder select,.builder input{padding:8px;border:1px solid var(--line);border-radius:8px}
</style></head><body><div class="hero"><div class="wrap"><small><a href="./">← Til kalenderen</a></small><h1>$(_esc(title))</h1><p>Vis tangokalenderen på klubbens eller arrangørens nettside. Alt er gratis, og innholdet oppdateres automatisk.</p>
<nav class="toc" aria-label="Velg"><a href="#idag">Dagens program</a><a href="#uke">Ukens program</a><a href="#liste">Liste med filtre</a><a href="#plattform">WordPress m.fl.</a><a href="#abonner">Abonner og data</a></nav></div></div><main>
<section class="card" id="idag"><h2>Dagens program (bilde med lenker)</h2><p class="when">Et bilde i samme stil som kalenderen. Tittelen lenker til kalenderen, hvert arrangement til sin egen side. Oppdateres hver natt.</p>
<div class="preview"><object type="image/svg+xml" data="$EMBED_TODAY" style="max-width:600px"><a href="./">Dagens tango i Oslo</a></object></div>
$(_codeblock("c-today",obj_today))
<p><b>Viktig:</b> bruk <code>&lt;object&gt;</code> som over – da virker lenkene. Med <code>&lt;img&gt;</code> vises bildet, men lenkene inni virker ikke. Tillater nettstedet bare bilder, kan du legge bildet i en lenke til kalenderen:</p>
$(_codeblock("c-img",img_today))</section>
<section class="card" id="uke"><h2>Ukens program</h2><p class="when">Mandag til søndag denne uken i kalenderens ukevisning. Tittelen lenker til ukevisningen.</p>
<div class="preview"><object type="image/svg+xml" data="$EMBED_WEEK" style="max-width:980px"><a href="uke.html">Ukens tango i Oslo</a></object></div>
$(_codeblock("c-week",obj_week))<p class="muted">Bildet skaleres til bredden på siden; på smale skjermer blir skriften liten – bruk gjerne dagens program eller listen under på mobil.</p></section>
<section class="card" id="liste"><h2>Liste med filtre (iframe)</h2><p class="when">Kommende arrangementer som en liste – oppdateres fortløpende. Velg gjerne bare deres egne arrangementer.</p>
<div class="builder"><div><label for="b-type">Type</label><select id="b-type"><option value="">Alle</option>$typeopts</select></div>
<div><label for="b-arr">Arrangør inneholder</label><input id="b-arr" placeholder="f.eks. Tangoskolen"></div>
<div><label for="b-when">Periode</label><select id="b-when"><option value="">Alle kommende</option><option value="week">Neste 7 dager</option><option value="month">Neste 30 dager</option></select></div>
<div><label for="b-h">Høyde (px)</label><input id="b-h" type="number" value="600" min="200" step="50" style="width:90px"></div></div>
$(_codeblock("c-ifr",ifr))
<div class="preview"><iframe id="ifr-preview" src="$EMBED_LIST" title="Forhåndsvisning" style="width:100%;height:420px;border:0"></iframe></div></section>
<section class="card" id="plattform"><h2>Slik gjør du det i …</h2><ul>
<li><b>WordPress:</b> legg til blokken «Egendefinert HTML» og lim inn koden.</li>
<li><b>Squarespace:</b> legg til en «Code»-blokk og lim inn koden.</li>
<li><b>Wix:</b> «Legg til» → «Bygg inn kode» → «Bygg inn HTML», og lim inn koden.</li>
<li><b>Facebook og Instagram</b> kan ikke bygge inn kode – del heller lenken til kalenderen eller et arrangement.</li></ul></section>
<section class="card" id="abonner"><h2>Abonner og data</h2><ul>
<li><b>Kalender-app:</b> abonner på <code>webcal://$(replace(SITE_URL,r"^https?://"=>""))/kalender.ics</code> i Google, Apple eller Outlook – nye arrangementer dukker opp av seg selv.</li>
<li><b>RSS:</b> <a href="rss.xml">rss.xml</a> – mange nettsider (f.eks. WordPress) har en RSS-blokk som kan vise de siste arrangementene.</li>
<li><b>For utviklere:</b> <a href="events.json">events.json</a> (kommende arrangementer, <a href="schema/tango-event.schema.json">format</a>) og <a href="llms.txt">llms.txt</a>.</li></ul>
<p>Lenk gjerne tilbake til <a href="./">kalenderen</a> – og hjelp oss å holde den oppdatert: <a href="$ADD_PAGE">legg inn eller rett opp arrangementer</a>.</p></section>
</main><div class="sitefooter"><a href="./">Kalenderen</a> · <a href="$ABOUT_PAGE">Om kalenderen</a> · <a href="$ADD_PAGE">Legg til arrangement</a></div><script>
(function(){document.querySelectorAll('.copybtn').forEach(function(b){b.addEventListener('click',function(){var p=document.getElementById(b.getAttribute('data-copy')),t=p.textContent;function sel(){var r=document.createRange();r.selectNodeContents(p);var g=getSelection();g.removeAllRanges();g.addRange(r)}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(function(){b.textContent='Kopiert ✓';setTimeout(function(){b.textContent='Kopier koden'},2500)},sel)}else sel()})});
var L='$l',ty=document.getElementById('b-type'),ar=document.getElementById('b-arr'),wh=document.getElementById('b-when'),hh=document.getElementById('b-h'),code=document.querySelector('#c-ifr code'),pv=document.getElementById('ifr-preview');
function upd(){var p=[];if(ty.value)p.push('type='+encodeURIComponent(ty.value));if(ar.value.trim())p.push('arr='+encodeURIComponent(ar.value.trim()));if(wh.value)p.push('when='+wh.value);var u=L+(p.length?'?'+p.join('&'):'');code.textContent='<iframe src="'+u+'" title="$(_esc(SITE_NAME))" style="width:100%;height:'+(parseInt(hh.value)||600)+'px;border:0" loading="lazy"></iframe>';pv.src='$EMBED_LIST'+(p.length?'?'+p.join('&'):'')}
[ty,ar,wh,hh].forEach(function(x){x.addEventListener('input',upd);x.addEventListener('change',upd)})})();
</script></body></html>"""
end
