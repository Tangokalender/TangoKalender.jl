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
_codeblock(id,code)="<div class=\"codebox\"><pre id=\"$id\"><code>$(_esc(code))</code></pre><button type=\"button\" class=\"copybtn\" data-copy=\"$id\">$(_t("embed.copy"))</button></div>"
_strings!("embed.copy"=>("Kopier koden","Copy the code","Copiar el código"),"embed.copied"=>("Kopiert ✓","Copied ✓","Copiado ✓"))
"Per-language text of bygg-inn.html."
function _embed_text()
 webcal="webcal://$(replace(_lang_url("kalender.ics"),r"^https?://"=>""))"
 Dict(
 "nb"=>(title="Bygg inn kalenderen",intro="Vis tangokalenderen på klubbens eller arrangørens nettside. Alt er gratis, og innholdet oppdateres automatisk.",
  toc=["Dagens program","Ukens program","Liste med filtre","WordPress m.fl.","Abonner og data"],
  seetoday="Se dagens tango i $(site_city())",seeweek="Se ukens tango i $(site_city())",imgalt="Dagens tango i $(site_city())",todayfb="Dagens tango i $(site_city())",weekfb="Ukens tango i $(site_city())",
  today="""<h2>Dagens program (bilde med lenker)</h2><p class="when">Et bilde i samme stil som kalenderen. Tittelen lenker til kalenderen, hvert arrangement til sin egen side. Bildet inneholder programmet for åtte dager og viser selv riktig dag fra midnatt (norsk tid) når det bygges inn med <code>&lt;object&gt;</code>.</p>""",
  img="""<p><b>Viktig:</b> bruk <code>&lt;object&gt;</code> som over – da virker lenkene. Med <code>&lt;img&gt;</code> vises bildet, men lenkene inni virker ikke. Tillater nettstedet bare bilder, kan du legge bildet i en lenke til kalenderen – da viser bildet dagen det sist ble oppdatert (normalt like etter midnatt):</p>""",
  week="""<h2>Ukens program</h2><p class="when">Mandag til søndag denne uken i kalenderens ukevisning. Tittelen lenker til ukevisningen.</p>""",
  weeknote="Bildet skaleres til bredden på siden; på smale skjermer blir skriften liten – bruk gjerne dagens program eller listen under på mobil.",
  list="""<h2>Liste med filtre (iframe)</h2><p class="when">Kommende arrangementer som en liste – oppdateres fortløpende. Velg gjerne bare deres egne arrangementer.</p>""",
  all="Alle",org="Arrangør inneholder",orgph="f.eks. Tangoskolen",period="Periode",allup="Alle kommende",d7="Neste 7 dager",d30="Neste 30 dager",height="Høyde (px)",preview="Forhåndsvisning",
  langlabel="Språk",langnote="Bildene og listen finnes på norsk, engelsk og spansk – velg språk her, så endres koden over og under.",
  platforms="""<h2>Slik gjør du det i …</h2><ul>
<li><b>WordPress:</b> legg til blokken «Egendefinert HTML» og lim inn koden.</li>
<li><b>Squarespace:</b> legg til en «Code»-blokk og lim inn koden.</li>
<li><b>Wix:</b> «Legg til» → «Bygg inn kode» → «Bygg inn HTML», og lim inn koden.</li>
<li><b>Facebook og Instagram</b> kan ikke bygge inn kode – del heller lenken til kalenderen eller et arrangement.</li></ul>""",
  feeds="""<h2>Abonner og data</h2><ul>
<li><b>Kalender-app:</b> abonner på <code>$webcal</code> i Google, Apple eller Outlook – nye arrangementer dukker opp av seg selv.</li>
<li><b>RSS:</b> <a href="rss.xml">rss.xml</a> – mange nettsider (f.eks. WordPress) har en RSS-blokk som kan vise de siste arrangementene.</li>
<li><b>For utviklere:</b> <a href="$(_root_rel())events.json">events.json</a> (kommende arrangementer, <a href="$(_root_rel())schema/tango-event.schema.json">format</a>) og <a href="$(_root_rel())llms.txt">llms.txt</a>.</li></ul>
<p>Lenk gjerne tilbake til <a href="./">kalenderen</a> – og hjelp oss å holde den oppdatert: <a href="$ADD_PAGE">legg inn eller rett opp arrangementer</a>.</p>"""),
 "en"=>(title="Embed the calendar",intro="Show the tango calendar on your club's or organiser's website. It is free, and the content updates automatically.",
  toc=["Today's programme","This week's programme","List with filters","WordPress etc.","Subscribe and data"],
  seetoday="See today's tango in $(site_city())",seeweek="See this week's tango in $(site_city())",imgalt="Today's tango in $(site_city())",todayfb="Today's tango in $(site_city())",weekfb="This week's tango in $(site_city())",
  today="""<h2>Today's programme (image with links)</h2><p class="when">An image in the same style as the calendar. The title links to the calendar, each event to its own page. The image holds the programme for eight days and shows the right day from midnight ($(site_city()) time) by itself when embedded with <code>&lt;object&gt;</code>.</p>""",
  img="""<p><b>Important:</b> use <code>&lt;object&gt;</code> as above – then the links work. With <code>&lt;img&gt;</code> the image is shown but the links inside it do not work. If your site only allows images, wrap the image in a link to the calendar – it then shows the day it was last updated (normally just after midnight):</p>""",
  week="""<h2>This week's programme</h2><p class="when">Monday to Sunday this week, as in the calendar's week view. The title links to the week view.</p>""",
  weeknote="The image scales to the width of the page; on narrow screens the text gets small – on mobile, today's programme or the list below may work better.",
  list="""<h2>List with filters (iframe)</h2><p class="when">Upcoming events as a list – always up to date. You can show only your own events.</p>""",
  all="All",org="Organiser contains",orgph="e.g. Tangoskolen",period="Period",allup="All upcoming",d7="Next 7 days",d30="Next 30 days",height="Height (px)",preview="Preview",
  langlabel="Language",langnote="The images and the list are available in Norwegian, English and Spanish – choose the language here and the code above and below changes.",
  platforms="""<h2>How to do it in …</h2><ul>
<li><b>WordPress:</b> add a “Custom HTML” block and paste the code.</li>
<li><b>Squarespace:</b> add a “Code” block and paste the code.</li>
<li><b>Wix:</b> “Add” → “Embed Code” → “Embed HTML”, and paste the code.</li>
<li><b>Facebook and Instagram</b> cannot embed code – share the link to the calendar or an event instead.</li></ul>""",
  feeds="""<h2>Subscribe and data</h2><ul>
<li><b>Calendar app:</b> subscribe to <code>$webcal</code> in Google, Apple or Outlook – new events appear by themselves.</li>
<li><b>RSS:</b> <a href="rss.xml">rss.xml</a> – many websites (e.g. WordPress) have an RSS block that can show the latest events.</li>
<li><b>For developers:</b> <a href="$(_root_rel())events.json">events.json</a> (upcoming events, <a href="$(_root_rel())schema/tango-event.schema.json">format</a>) and <a href="$(_root_rel())llms.txt">llms.txt</a>.</li></ul>
<p>Please link back to <a href="./">the calendar</a> – and help us keep it up to date: <a href="$ADD_PAGE">add or correct events</a>.</p>"""),
 "es"=>(title="Insertar el calendario",intro="Mostrá el calendario de tango en el sitio web de tu club u organización. Es gratis y el contenido se actualiza solo.",
  toc=["Programa de hoy","Programa de la semana","Lista con filtros","WordPress y otros","Suscripción y datos"],
  seetoday="Ver el tango de hoy en $(site_city())",seeweek="Ver el tango de esta semana en $(site_city())",imgalt="Tango de hoy en $(site_city())",todayfb="Tango de hoy en $(site_city())",weekfb="Tango de esta semana en $(site_city())",
  today="""<h2>Programa de hoy (imagen con enlaces)</h2><p class="when">Una imagen con el mismo estilo que el calendario. El título lleva al calendario y cada evento a su propia página. La imagen trae el programa de ocho días y muestra sola el día correcto desde la medianoche (hora de $(site_city())) cuando se inserta con <code>&lt;object&gt;</code>.</p>""",
  img="""<p><b>Importante:</b> usá <code>&lt;object&gt;</code> como arriba: así funcionan los enlaces. Con <code>&lt;img&gt;</code> se ve la imagen, pero los enlaces no funcionan. Si tu sitio solo permite imágenes, poné la imagen dentro de un enlace al calendario; en ese caso muestra el día de la última actualización (normalmente justo después de medianoche):</p>""",
  week="""<h2>Programa de la semana</h2><p class="when">De lunes a domingo de esta semana, como en la vista semanal del calendario. El título lleva a la vista semanal.</p>""",
  weeknote="La imagen se adapta al ancho de la página; en pantallas angostas la letra queda chica: en el celular quizá convenga el programa de hoy o la lista de abajo.",
  list="""<h2>Lista con filtros (iframe)</h2><p class="when">Los próximos eventos como lista, siempre actualizada. Podés mostrar solo tus propios eventos.</p>""",
  all="Todos",org="Organización contiene",orgph="p. ej. Tangoskolen",period="Período",allup="Todos los próximos",d7="Próximos 7 días",d30="Próximos 30 días",height="Alto (px)",preview="Vista previa",
  langlabel="Idioma",langnote="Las imágenes y la lista están en noruego, inglés y español: elegí el idioma acá y el código de arriba y de abajo cambia.",
  platforms="""<h2>Cómo hacerlo en …</h2><ul>
<li><b>WordPress:</b> agregá un bloque «HTML personalizado» y pegá el código.</li>
<li><b>Squarespace:</b> agregá un bloque «Código» y pegá el código.</li>
<li><b>Wix:</b> «Agregar» → «Insertar código» → «Insertar HTML», y pegá el código.</li>
<li><b>Facebook e Instagram</b> no permiten insertar código: compartí el enlace al calendario o a un evento.</li></ul>""",
  feeds="""<h2>Suscripción y datos</h2><ul>
<li><b>Aplicación de calendario:</b> suscribite a <code>$webcal</code> en Google, Apple u Outlook; los eventos nuevos aparecen solos.</li>
<li><b>RSS:</b> <a href="rss.xml">rss.xml</a>: muchos sitios (p. ej. WordPress) tienen un bloque RSS que muestra los últimos eventos.</li>
<li><b>Para desarrolladores:</b> <a href="$(_root_rel())events.json">events.json</a> (próximos eventos, <a href="$(_root_rel())schema/tango-event.schema.json">formato</a>) y <a href="$(_root_rel())llms.txt">llms.txt</a>.</li></ul>
<p>Si podés, enlazá de vuelta al <a href="./">calendario</a>, y ayudanos a mantenerlo al día: <a href="$ADD_PAGE">cargá o corregí eventos</a>.</p>"""))
end
"Relative path from a page at a language root to the site root (language-neutral files: events.json, schemas, llms.txt)."
_root_rel()=_lang()=="nb" ? "" : "../"
"""
    bygg_inn_html(; lang="nb") -> String

The embedding guide: live previews, copyable code (in a chosen language), the iframe builder, platform notes, feeds.
"""
bygg_inn_html(; lang="nb", kwargs...)=_with_lang(()->_bygg_inn_html(;kwargs...),lang)
function _bygg_inn_html(; title=nothing)
 B="{BASE}"   # replaced by the chosen language's root URL (server-side for the page language, in the browser on change)
 t=B*EMBED_TODAY; w=B*EMBED_WEEK; l=B*EMBED_LIST
 a=_embed_text()[_lang()]; title=something(title,a.title)
 obj_today="""<object type="image/svg+xml" data="$t" style="width:100%;max-width:600px">
  <a href="$B">$(a.seetoday)</a>
</object>"""
 obj_week="""<object type="image/svg+xml" data="$w" style="width:100%;max-width:980px">
  <a href="$(B)uke.html">$(a.seeweek)</a>
</object>"""
 img_today="""<a href="$B"><img src="$t" alt="$(a.imgalt) – $(site_name())" style="width:100%;max-width:600px"></a>"""
 ifr="""<iframe src="$l" title="$(site_name())" style="width:100%;height:600px;border:0" loading="lazy"></iframe>"""
 base=_lang_url("")
 code(id,c)=replace(replace(_codeblock(id,c),B=>base),"<code>"=>"<code data-tpl=\"$(_esc(c))\">")
 typeopts=join(("<option value=\"$t_\">$(_esc(_type_label(t_)))</option>" for t_ in TYPE_ORDER),"")
 langopts=join(("<option value=\"$(_lang_url("",x))\"$(x==_lang() ? " selected" : "")>$(LANG_CODE[x]) – $(LANG_NAME[x])</option>" for x in LANGS),"")
 toc=join(("<a href=\"#$id\">$(_esc(x))</a>" for (id,x) in zip(["idag","uke","liste","plattform","abonner"],a.toc)),"")
 """<!doctype html><html lang="$(_lang())"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(site_name()))</title>$(_plain_head(EMBED_PAGE))$(_og_head(title="$title – $(site_name())",desc=_t("site.description"),url=_lang_url(EMBED_PAGE)))<style>
$_PAGE_CSS$_LANG_CSS.codebox{position:relative;margin:10px 0}.codebox pre{margin:0;padding-right:120px}.copybtn{position:absolute;top:8px;right:8px;border:0;border-radius:999px;background:var(--wine);color:white;font-weight:800;padding:6px 12px;cursor:pointer;font-size:.8rem}.preview{border:1px dashed var(--line);border-radius:12px;padding:10px;background:#fff;overflow:auto}.preview object{display:block;width:100%}.builder{display:flex;flex-wrap:wrap;gap:10px;align-items:end;margin:8px 0}.builder label{display:block;font-size:.72rem;text-transform:uppercase;color:var(--muted);font-weight:800}.builder select,.builder input{padding:8px;border:1px solid var(--line);border-radius:8px}
</style></head><body>$_SPRITE<div class="hero"><div class="wrap">$(_plain_top(EMBED_PAGE))<h1>$(_esc(title))</h1><p>$(a.intro)</p>
<nav class="toc" aria-label="$(_esc(a.title))">$toc</nav></div></div><main>
<section class="card"><div class="builder"><div><label for="b-lang">$(a.langlabel)</label><select id="b-lang">$langopts</select></div></div><p class="muted">$(a.langnote)</p></section>
<section class="card" id="idag">$(a.today)
<div class="preview"><object type="image/svg+xml" data="$EMBED_TODAY" style="max-width:600px"><a href="./">$(a.todayfb)</a></object></div>
$(code("c-today",obj_today))
$(a.img)
$(code("c-img",img_today))</section>
<section class="card" id="uke">$(a.week)
<div class="preview"><object type="image/svg+xml" data="$EMBED_WEEK" style="max-width:980px"><a href="uke.html">$(a.weekfb)</a></object></div>
$(code("c-week",obj_week))<p class="muted">$(a.weeknote)</p></section>
<section class="card" id="liste">$(a.list)
<div class="builder"><div><label for="b-type">$(_t("type"))</label><select id="b-type"><option value="">$(a.all)</option>$typeopts</select></div>
<div><label for="b-arr">$(a.org)</label><input id="b-arr" placeholder="$(a.orgph)"></div>
<div><label for="b-when">$(a.period)</label><select id="b-when"><option value="">$(a.allup)</option><option value="week">$(a.d7)</option><option value="month">$(a.d30)</option></select></div>
<div><label for="b-h">$(a.height)</label><input id="b-h" type="number" value="600" min="200" step="50" style="width:90px"></div></div>
$(code("c-ifr",ifr))
<div class="preview"><iframe id="ifr-preview" src="$EMBED_LIST" title="$(a.preview)" style="width:100%;height:420px;border:0"></iframe></div></section>
<section class="card" id="plattform">$(a.platforms)</section>
<section class="card" id="abonner">$(a.feeds)</section>
</main><div class="sitefooter"><a href="./">$(_t("calendar"))</a> · <a href="$ABOUT_PAGE">$(_t("about"))</a> · <a href="$ADD_PAGE">$(_t("add"))</a></div><script>
(function(){var CP='$(_t("embed.copy"))',OK='$(_t("embed.copied"))';document.querySelectorAll('.copybtn').forEach(function(b){b.addEventListener('click',function(){var p=document.getElementById(b.getAttribute('data-copy')),t=p.textContent;function sel(){var r=document.createRange();r.selectNodeContents(p);var g=getSelection();g.removeAllRanges();g.addRange(r)}if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(function(){b.textContent=OK;setTimeout(function(){b.textContent=CP},2500)},sel)}else sel()})});
var lg=document.getElementById('b-lang'),ty=document.getElementById('b-type'),ar=document.getElementById('b-arr'),wh=document.getElementById('b-when'),hh=document.getElementById('b-h'),pv=document.getElementById('ifr-preview');
function upd(){var B=lg.value,p=[];if(ty.value)p.push('type='+encodeURIComponent(ty.value));if(ar.value.trim())p.push('arr='+encodeURIComponent(ar.value.trim()));if(wh.value)p.push('when='+wh.value);var q=p.length?'?'+p.join('&'):'';
document.querySelectorAll('code[data-tpl]').forEach(function(c){var s=c.getAttribute('data-tpl').split('{BASE}').join(B);if(c.parentNode.id==='c-ifr')s=s.replace('$EMBED_LIST"','$EMBED_LIST'+q+'"').replace('height:600px','height:'+(parseInt(hh.value)||600)+'px');c.textContent=s});pv.src='$EMBED_LIST'+q}
[lg,ty,ar,wh,hh].forEach(function(x){x.addEventListener('input',upd);x.addEventListener('change',upd)})})();
</script></body></html>"""
end
