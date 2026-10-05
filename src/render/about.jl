# «Om kalenderen» (om.html): what the calendar is and how to support it. Same look as legg-til.html (_PAGE_CSS).
const ABOUT_PAGE="om.html"
"Head links (canonical, hreflang, language script) for a plain page `rel` at a language root."
_plain_head(rel)=_alternates(rel)*_lang_js(rel)
"Top bar of a plain page's hero: back link and the language switcher."
_plain_top(rel)="<div class=\"topbar\"><small><a href=\"./\">$(_t("back"))</a></small>$(_langnav(rel))</div>"
"Per-language text of the about page (a function: it links pages defined in later files)."
_about()=Dict(
 "nb"=>(title="Om kalenderen",meta="Tangokalenderen for Oslo er et felles prosjekt for tangomiljøet. Slik kan du bidra.",
  intro="$(SITE_NAME) samler milongaer, practicaer, kurs og festivaler for argentinsk tango i Oslo på ett sted.",
  body="""<section class="card"><h2>Et felles prosjekt</h2>
<p>Kalenderen er et dugnadsprosjekt for og av tangomiljøet i Oslo. Den eies ikke av noen klubb eller arrangør – den er til for alle som danser, arrangerer eller bare er nysgjerrige på tango.</p>
<p>Alt innhold kommer fra miljøet selv: arrangører og dansere legger inn arrangementer, retter opp feil og melder fra om avlysninger. Hver innsending blir sett over før den publiseres.</p></section>
<section class="card"><h2>Tusen takk</h2>
<p class="thanks">Til alle frivillige og arrangører i Oslos tangomiljø: dere er grunnen til at det finnes noe å sette i kalenderen.</p>
<p>Milongaer, practicaer, kurs og festivaler blir ikke til av seg selv. Bak hver kveld står folk som bærer høyttalere, rydder gulv, setter sammen musikk, underviser, holder styr på økonomien og passer på at alle føler seg velkomne. Hjelpen og innsatsen deres settes stor pris på.</p></section>
<section class="card"><h2>Slik støtter du kalenderen</h2>
<ol><li><b>Bruk den.</b> Sjekk kalenderen når du lurer på hvor du kan danse – i dag, denne uken eller neste måned.</li>
<li><b>Del arrangementer.</b> Hvert arrangement har sin egen side du kan dele, og filtrene ligger i lenken – del gjerne «alle milongaer denne måneden» med en venn. Du kan også abonnere på hele kalenderen i din egen kalender-app.</li>
<li><b>Hjelp til med å holde den oppdatert.</b> Ser du et arrangement som mangler, en feil tid eller en avlysning? Det tar et par minutter å <a href="$ADD_PAGE">legge inn eller rette opp</a>. Jo flere som hjelper til, jo mer kan alle stole på kalenderen.</li>
<li><b>Vis kalenderen på nettsiden din.</b> Klubber og arrangører kan <a href="$EMBED_PAGE">bygge inn</a> dagens eller ukens program, eller en liste med bare sine egne arrangementer.</li></ol>
<p class="wink">Og vil noen vise sin takknemlighet ved å spandere en drink på den som står bak kalenderen på neste milonga, er det neppe noen som klager … 😉</p></section>
<section class="card"><h2>Hvordan det fungerer</h2>
<p>Kalenderen er en statisk nettside uten reklame, sporing eller innlogging for besøkende. Kartene hentes fra OpenStreetMap, som da ser at nettleseren din ber om kartbilder. Arrangementene ligger som åpne data, og alt – kode, data og endringshistorikk – er åpent på <a href="$(_esc(REPO_URL))" target="_blank" rel="noopener">GitHub</a>. For å sende inn trenger du en gratis GitHub-konto; en robot sjekker innsendingen og en redaktør godkjenner den.</p>
<p>Siden finnes på norsk, engelsk og spansk. Den velger språk etter nettleseren din første gang; velger du selv (NO, EN, ES øverst), husker nettleseren valget – det lagres bare hos deg.</p>
<p class="muted">Kontroller alltid detaljer hos arrangøren. Har du spørsmål eller forslag, <a href="$(_esc(REPO_URL))/issues" target="_blank" rel="noopener">skriv en sak på GitHub</a>.</p>"""),
 "en"=>(title="About the calendar",meta="The Oslo tango calendar is a shared project of the tango community. Here is how you can help.",
  intro="$(SITE_NAME) brings together milongas, practicas, classes and festivals for Argentine tango in Oslo in one place.",
  body="""<section class="card"><h2>A community project</h2>
<p>The calendar is a volunteer project by and for the tango community in Oslo. It is not owned by any club or organiser – it is there for everyone who dances, organises or is simply curious about tango.</p>
<p>All the content comes from the community itself: organisers and dancers add events, correct mistakes and report cancellations. Every submission is reviewed before it is published.</p></section>
<section class="card"><h2>Thank you</h2>
<p class="thanks">To all the volunteers and organisers in Oslo's tango community: you are the reason there is anything to put in the calendar.</p>
<p>Milongas, practicas, classes and festivals don't happen by themselves. Behind every evening there are people who carry speakers, clear the floor, put the music together, teach, keep the accounts and make sure everyone feels welcome. Your help and effort are greatly appreciated.</p></section>
<section class="card"><h2>How to support the calendar</h2>
<ol><li><b>Use it.</b> Check the calendar whenever you wonder where to dance – today, this week or next month.</li>
<li><b>Share events.</b> Every event has its own page you can share, and the filters are kept in the link – share “all milongas this month” with a friend. You can also subscribe to the whole calendar in your own calendar app.</li>
<li><b>Help keep it up to date.</b> Spotted a missing event, a wrong time or a cancellation? It takes a couple of minutes to <a href="$ADD_PAGE">add or correct it</a>. The more people who help, the more everyone can rely on the calendar.</li>
<li><b>Show the calendar on your website.</b> Clubs and organisers can <a href="$EMBED_PAGE">embed</a> today's or this week's programme, or a list of just their own events.</li></ol>
<p class="wink">And if anyone wants to show their appreciation by buying the person behind the calendar a drink at the next milonga, surely no one will complain … 😉</p></section>
<section class="card"><h2>How it works</h2>
<p>The calendar is a static website with no adverts, tracking or log-in for visitors. Maps are loaded from OpenStreetMap, which therefore sees your browser requesting map images. The events are open data, and everything – code, data and the history of changes – is open on <a href="$(_esc(REPO_URL))" target="_blank" rel="noopener">GitHub</a>. To submit you need a free GitHub account; a bot checks each submission and an editor approves it.</p>
<p>The site is available in Norwegian, English and Spanish. The first time, it follows your browser's language; if you choose one yourself (NO, EN, ES at the top), your browser remembers the choice – it is only stored on your device.</p>
<p class="muted">Always check the details with the organiser. Questions or suggestions? <a href="$(_esc(REPO_URL))/issues" target="_blank" rel="noopener">Open an issue on GitHub</a>.</p>"""),
 "es"=>(title="Sobre el calendario",meta="El calendario de tango de Oslo es un proyecto compartido de la comunidad tanguera. Así podés colaborar.",
  intro="$(SITE_NAME) reúne milongas, prácticas, clases y festivales de tango argentino en Oslo en un solo lugar.",
  body="""<section class="card"><h2>Un proyecto de la comunidad</h2>
<p>El calendario es un proyecto voluntario hecho por y para la comunidad tanguera de Oslo. No pertenece a ningún club ni a ninguna organización: es para todos los que bailan, organizan o simplemente sienten curiosidad por el tango.</p>
<p>Todo el contenido viene de la propia comunidad: organizadores y bailarines cargan eventos, corrigen errores y avisan de cancelaciones. Cada envío se revisa antes de publicarse.</p></section>
<section class="card"><h2>¡Muchas gracias!</h2>
<p class="thanks">A todos los voluntarios y organizadores de la comunidad tanguera de Oslo: gracias a ustedes hay algo para poner en el calendario.</p>
<p>Las milongas, prácticas, clases y festivales no se hacen solos. Detrás de cada noche hay gente que carga parlantes, prepara la pista, arma la música, enseña, lleva las cuentas y se ocupa de que todos se sientan bienvenidos. Su ayuda y su esfuerzo se valoran muchísimo.</p></section>
<section class="card"><h2>Cómo apoyar el calendario</h2>
<ol><li><b>Usalo.</b> Mirá el calendario cada vez que te preguntes dónde bailar: hoy, esta semana o el mes que viene.</li>
<li><b>Compartí eventos.</b> Cada evento tiene su propia página para compartir, y los filtros quedan en el enlace: mandale a un amigo «todas las milongas de este mes». También podés suscribirte al calendario completo desde tu aplicación de calendario.</li>
<li><b>Ayudá a mantenerlo al día.</b> ¿Falta un evento, hay un horario equivocado o una cancelación? Lleva un par de minutos <a href="$ADD_PAGE">cargarlo o corregirlo</a>. Cuanta más gente ayude, más podemos confiar todos en el calendario.</li>
<li><b>Mostrá el calendario en tu sitio web.</b> Clubes y organizadores pueden <a href="$EMBED_PAGE">insertar</a> el programa de hoy o de la semana, o una lista solo con sus propios eventos.</li></ol>
<p class="wink">Y si alguien quiere mostrar su agradecimiento invitándole un trago a quien está detrás del calendario en la próxima milonga, seguro que nadie se va a quejar … 😉</p></section>
<section class="card"><h2>Cómo funciona</h2>
<p>El calendario es un sitio web estático, sin publicidad, sin seguimiento y sin registro para quienes lo visitan. Los mapas se cargan desde OpenStreetMap, que por eso ve que tu navegador pide imágenes del mapa. Los eventos son datos abiertos, y todo –código, datos e historial de cambios– está abierto en <a href="$(_esc(REPO_URL))" target="_blank" rel="noopener">GitHub</a>. Para enviar eventos necesitás una cuenta gratuita de GitHub; un bot revisa el envío y una persona del equipo editorial lo aprueba.</p>
<p>El sitio está en noruego, inglés y español. La primera vez usa el idioma de tu navegador; si elegís uno vos (NO, EN, ES arriba), el navegador lo recuerda: la elección se guarda solo en tu dispositivo.</p>
<p class="muted">Confirmá siempre los detalles con quien organiza. ¿Preguntas o sugerencias? <a href="$(_esc(REPO_URL))/issues" target="_blank" rel="noopener">Abrí un issue en GitHub</a>.</p>"""))
_strings!("about.tocal"=>("Til kalenderen","To the calendar","Ir al calendario"))
"""
    om_html(; lang="nb") -> String

The about page: the calendar is a community effort; thanks to volunteers and organisers; how to support it.
"""
om_html(; lang="nb", kwargs...)=_with_lang(()->_om_html(;kwargs...),lang)
function _om_html(; title=nothing)
 a=_about()[_lang()]; title=something(title,a.title)
 """<!doctype html><html lang="$(_lang())"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(SITE_NAME))</title>$(_plain_head(ABOUT_PAGE))<meta name="description" content="$(_esc(a.meta))"><style>
$_PAGE_CSS$_LANG_CSS.thanks{font:500 1.25rem Georgia;color:var(--wine);margin:0}.wink{font-size:1.05rem}
</style></head><body>$_SPRITE<div class="hero"><div class="wrap">$(_plain_top(ABOUT_PAGE))<h1>$(_esc(title))</h1><p>$(_esc(a.intro))</p></div></div><main>
$(a.body)
<p><a class="cta" href="./">$(_t("about.tocal"))</a><a class="cta secondary" href="$ADD_PAGE">$(_t("add"))</a></p></section>
</main><div class="sitefooter"><a href="./">$(_t("calendar"))</a> · <a href="$ADD_PAGE">$(_t("add"))</a> · <a href="kalender.ics">$(_t("subscribe.short"))</a> · <a href="rss.xml">RSS</a></div></body></html>"""
end
