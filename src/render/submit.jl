# The single «Legg til arrangement» page (legg-til.html): all ways to submit or correct events, in each language (the GitHub forms themselves are Norwegian).
# Sections: #skjema (issue form), #tabell (cells pasted from a spreadsheet), #ki (prompt for an AI assistant), #rette.
const ADD_PAGE="legg-til.html"
const TEMPLATE_CSV="mal/arrangementer-mal.csv"
const _PAGE_CSS=""".sitefooter{text-align:center;color:var(--muted);padding:20px;font-size:.8rem}.sitefooter a{color:var(--wine);font-weight:700}:root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c;line-height:1.55}.hero{padding:40px 20px 56px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:820px;margin:auto}.hero h1{font:500 clamp(2rem,6vw,3.4rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5;margin:0}.hero a{color:white}main{max-width:820px;margin:-28px auto 0;padding:0 16px 60px}.card{background:white;border:1px solid var(--line);border-radius:18px;padding:22px;margin-bottom:16px;box-shadow:0 5px 18px #2919210b}h2{font:500 1.5rem Georgia;margin:0 0 8px}ol{padding-left:1.3em}li{margin:6px 0}a{color:var(--wine);font-weight:700}.promptbox{position:relative}pre{white-space:pre-wrap;word-break:break-word;background:#f7f2ec;border:1px solid var(--line);border-radius:12px;padding:16px;max-height:340px;overflow:auto;font-size:.82rem}button{border:0;border-radius:999px;background:var(--wine);color:white;font-weight:800;padding:10px 18px;cursor:pointer}button:hover{background:#6f2240}.btnrow{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:10px 0}.btn{display:inline-block;border-radius:999px;padding:10px 18px;background:#f2dce4;color:#76203e;text-decoration:none}small,.muted{color:var(--muted)}.hero nav a{color:#f7dce5;margin-right:14px}.toc{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}.toc a{display:inline-block;padding:8px 14px;border-radius:999px;border:1px solid #ffffff55;color:white;text-decoration:none;font-weight:700}.when{color:var(--muted);font-size:.92rem;margin:-4px 0 10px}.cta{display:inline-block;background:var(--wine);color:white;border-radius:999px;padding:10px 18px;font-weight:800;text-decoration:none;margin:6px 8px 6px 0}.cta.secondary{background:#f2dce4;color:#76203e}table.ex{border-collapse:collapse;font-size:.8rem;margin:10px 0;display:block;overflow-x:auto;white-space:nowrap}table.ex th,table.ex td{border:1px solid var(--line);padding:5px 8px;text-align:left}table.ex th{background:#f2dce4}table.ex tr.def td{background:#fbf3f6}table.ex td.blank{color:#bbb}dl.cols{display:grid;grid-template-columns:150px 1fr;gap:4px 14px;font-size:.9rem}dl.cols dt{font-weight:800}dl.cols dd{margin:0}code{background:#f7f2ec;padding:1px 5px;border-radius:5px}"""
"Spreadsheet columns (Norwegian names, as typed in row 1) with help per language; ` *` marks required columns."
const _COLUMN_HELP=Dict(
 "nb"=>[("Tittel","Navnet på arrangementet. *"),("Type","Én eller flere, skilt med komma: Kurs, Workshop, Milonga, Practica, Festival, Maraton, Utetango, Annet – f.eks. «Kurs, Milonga» eller «Milonga, Utetango». *"),
  ("Dato","Én dato per rad: ÅÅÅÅ-MM-DD eller DD.MM.ÅÅÅÅ. *"),("Starttid / Sluttid","TT:MM. Sluttid etter midnatt er greit (f.eks. 01:00). Starttid *"),
  ("Sted / Adresse","Navn på stedet og gateadresse. *"),("Arrangør","Klubb eller person som arrangerer. *"),("DJ / Lærere","Navn – lærere skilt med komma."),
  ("Pris (kr), Studentpris (kr), Kurspris (kr)","Hele kroner."),("Musikk","Tradisjonell, Alternativ / neo og/eller Levende orkester, skilt med komma."),
  ("Flyer / Video","Lenke til bilde / YouTube eller Vimeo."),("Lenke","Arrangementets nettside eller Facebook-arrangement. *"),
  ("Beskrivelse","Kort tekst."),("Tekstspråk","«Norsk» (standard) eller «English»: språket i Tittel og Beskrivelse."),
  ("Tittel (andre språk) / Beskrivelse (andre språk)","Valgfritt: tittel og beskrivelse på det andre språket (engelsk hvis teksten er norsk)."),
  ("Status","Skriv «Avlyst» på datoer som er avlyst.")],
 "en"=>[("Tittel","Title: the name of the event. *"),("Type","One or more, separated by commas: Class, Workshop, Milonga, Practica, Festival, Marathon, Open-air, Other (or the Norwegian Kurs, Maraton, Utetango, Annet) – e.g. “Class, Milonga”. *"),
  ("Dato","Date, one per row: YYYY-MM-DD, DD.MM.YYYY or DD/MM/YYYY. *"),("Starttid / Sluttid","Start / end time, HH:MM. An end after midnight is fine (e.g. 01:00). Start time *"),
  ("Sted / Adresse","Venue name and street address. *"),("Arrangør","Organiser: the club or person organising. *"),("DJ / Lærere","DJ / teachers – teachers separated by commas."),
  ("Pris (kr), Studentpris (kr), Kurspris (kr)","Price, student price, class price in whole kroner."),("Musikk","Music: Traditional, Alternative / neo and/or Live orchestra, separated by commas."),
  ("Flyer / Video","Link to an image / YouTube or Vimeo."),("Lenke","Link: the event's web page or Facebook event. *"),
  ("Beskrivelse","Description: a short text."),("Tekstspråk","Text language: “English” or “Norsk” (the default) – the language of Tittel and Beskrivelse."),
  ("Tittel (andre språk) / Beskrivelse (andre språk)","Optional: title and description in the other language (Norwegian if your text is English)."),
  ("Status","Write “Avlyst” (or “Cancelled”) on cancelled dates.")],
 "es"=>[("Tittel","Título: el nombre del evento. *"),("Type","Tipo, uno o más separados por comas: Class (clase), Workshop (seminario), Milonga, Practica, Festival, Marathon, Open-air (al aire libre), Other (otro) – p. ej. «Class, Milonga». *"),
  ("Dato","Fecha, una por fila: AAAA-MM-DD, DD.MM.AAAA o DD/MM/AAAA. *"),("Starttid / Sluttid","Hora de inicio / fin, HH:MM. Si termina después de medianoche, está bien (p. ej. 01:00). Inicio *"),
  ("Sted / Adresse","Nombre del lugar y dirección. *"),("Arrangør","Organiza: el club o la persona que organiza. *"),("DJ / Lærere","DJ / profesores, separados por comas."),
  ("Pris (kr), Studentpris (kr), Kurspris (kr)","Precio, precio para estudiantes, precio de la clase, en coronas enteras."),("Musikk","Música: Traditional, Alternative / neo y/o Live orchestra, separados por comas."),
  ("Flyer / Video","Enlace a una imagen / a YouTube o Vimeo."),("Lenke","Enlace: la página del evento o el evento de Facebook. *"),
  ("Beskrivelse","Descripción: un texto corto."),("Tekstspråk","Idioma del texto: «English» o «Norsk» (predeterminado), el idioma de Tittel y Beskrivelse. Por ahora el texto de los eventos va en noruego o inglés."),
  ("Tittel (andre språk) / Beskrivelse (andre språk)","Opcional: título y descripción en el otro idioma."),
  ("Status","Escribí «Avlyst» (o «Cancelled») en las fechas canceladas.")])
"Norwegian form labels explained for English and Spanish visitors (the GitHub forms are in Norwegian)."
const _GLOSSARY=Dict(
 "en"=>[("Tekstspråk","Text language: choose English if you write the title and description in English"),("Tittel","Title"),
  ("Type","Kurs = class, Workshop, Milonga, Practica, Festival, Maraton = marathon, Utetango = open-air, Annet = other"),
  ("Dato","Date (YYYY-MM-DD)"),("Starttid / Sluttid","Start / end time"),("Gjentas","Repeats: Nei = no, Ukentlig = weekly"),
  ("Gjentas til / Unntatt datoer","Repeats until / except on these dates"),("Sted / Adresse","Venue / address"),("Arrangør","Organiser"),
  ("Lærere","Teachers"),("Pris / Studentpris / Kurspris (kr)","Price / student price / class price in kroner"),
  ("Musikk","Music: Tradisjonell = traditional, Alternativ / neo, Levende orkester = live orchestra"),("Lenke","Link to the event page"),
  ("Beskrivelse","Description"),("Tittel / Beskrivelse (andre språk)","Optional title / description in the other language"),
  ("Samtykke","Consent: the people named have agreed to be listed")],
 "es"=>[("Tekstspråk","Idioma del texto: elegí English si escribís el título y la descripción en inglés"),("Tittel","Título"),
  ("Type","Kurs = clase, Workshop = seminario, Milonga, Practica, Festival, Maraton = maratón, Utetango = al aire libre, Annet = otro"),
  ("Dato","Fecha (AAAA-MM-DD)"),("Starttid / Sluttid","Hora de inicio / fin"),("Gjentas","Se repite: Nei = no, Ukentlig = todas las semanas"),
  ("Gjentas til / Unntatt datoer","Se repite hasta / excepto estas fechas"),("Sted / Adresse","Lugar / dirección"),("Arrangør","Organiza"),
  ("Lærere","Profesores"),("Pris / Studentpris / Kurspris (kr)","Precio / estudiantes / clase, en coronas"),
  ("Musikk","Música: Tradisjonell = tradicional, Alternativ / neo, Levende orkester = orquesta en vivo"),("Lenke","Enlace a la página del evento"),
  ("Beskrivelse","Descripción"),("Tittel / Beskrivelse (andre språk)","Título / descripción opcional en el otro idioma"),
  ("Samtykke","Consentimiento: las personas mencionadas aceptaron figurar")])
"Per-language text of legg-til.html (a function: it interpolates URLs and the example table)."
function _add_text()
 f=_esc(submit_form_url()); tf=_esc(table_form_url()); jf=_esc(json_form_url())
 Dict(
 "nb"=>(title="Legg til arrangement",
  intro="Alle kan legge inn arrangementer. En robot sjekker innsendingen og lager et forslag som en redaktør ser over før det publiseres – du får svar som en kommentar på GitHub.",
  toc=["Ett arrangement","Flere datoer (regneark)","Med KI","Rette opp / avlyse"],
  form="""<h2>Ett arrangement – eller en enkel ukentlig serie</h2><p class="when">Når: én milonga, en workshop, eller noe som gjentas likt hver uke.</p>
<p>Fyll ut skjemaet. For faste kvelder velger du «Gjentas: Ukentlig» og siste dato; hver dato blir et eget arrangement som senere kan endres eller avlyses for seg.</p>
<p>Tittel og beskrivelse kan skrives på norsk eller engelsk («Tekstspråk»). Har du teksten på begge språk, kan du legge den andre inn i de valgfrie feltene nederst – men ett språk er nok.</p>
<a class="cta" href="$f" target="_blank" rel="noopener">Åpne skjemaet ↗</a>""",
  table="""<h2>Flere datoer med variasjoner – fra regneark</h2><p class="when">Når: en serie der f.eks. DJ eller pris varierer, eller mange datoer på én gang.</p>
<ol><li><b>Første rad</b> er kolonnenavnene, <b>andre rad</b> har alt som er felles (tittel, sted, tider, pris …).</li>
<li>På <b>de neste radene</b> fyller du bare inn det som er annerledes – typisk <b>Dato</b> og <b>DJ</b>. Tom celle = som andre rad. Skriv <code>-</code> for å fjerne en opplysning, og «Avlyst» i <b>Status</b> for avlyste datoer.</li>
<li>Merk alle cellene (også kolonnenavnene), kopier (Ctrl+C / ⌘C) og lim inn i skjemaet «Nytt arrangement (fra tabell)». Fungerer fra Excel, Google Regneark og Numbers.</li></ol>""",
  tablebtn="Åpne tabell-skjemaet ↗",template="Last ned mal (CSV for Excel)",columns="Kolonner",
  colnote="Kolonnene kan stå i hvilken som helst rekkefølge, og du trenger bare de du bruker.",required="påkrevd",
  ki="""<h2>Med KI – fra en Facebook-side eller nettside</h2><p class="when">Når: arrangementet er allerede beskrevet et sted, og du vil slippe å skrive det inn selv.</p><ol>
<li><b>Kopier ledeteksten</b> under.</li>
<li>Åpne KI-assistenten (Copilot, Gemini, ChatGPT …), lim inn ledeteksten og <b>legg til arrangementsteksten</b> rett etter – kopier teksten fra arrangementssiden, eller legg ved et skjermbilde. KI-assistenter kan som regel ikke logge inn på Facebook selv.</li>
<li><b>Les over svaret.</b> KI kan ta feil – sjekk særlig dato, klokkeslett, sted og pris.</li>
<li>Lim inn hele svaret i skjemaet «Nytt arrangement (JSON fra KI)».</li></ol>""",
  copy="Kopier ledeteksten",kibtn="Åpne KI-skjemaet ↗",
  kinote="Faste kvelder blir én oppføring per dato – skriv gjerne til KI-assistenten hvilke datoer det gjelder, f.eks. «hver onsdag fra 7. oktober til 9. desember, ikke 18. november».",
  fix="""<h2>Rette opp eller avlyse</h2><p>Hvert arrangement har en lenke «Rett opp ↗». Skjemaet viser hva som står der nå; fyll bare inn det som skal endres, velg om endringen gjelder bare denne datoen eller også alle senere i serien, og send inn. Avlysninger meldes med «Status: Avlyst» – arrangementet blir stående som «Avlyst» i kalenderen.</p>""",
  privacy="""<h2>Personvern</h2><p>Bruk bare opplysninger som allerede er offentlige. Navn på DJ-er og lærere skal bare være med hvis de har godtatt det – du bekrefter dette i skjemaet. Ikke lim inn private meldinger eller personopplysninger i en KI-assistent.</p>""",
  dev="Du trenger en (gratis) GitHub-konto for å sende inn. For utviklere og KI-agenter:",subschema="innsendingsskjema (JSON Schema)",stored="lagret format",
  glossary="",copied="Kopiert ✓",selected="Merket – trykk Ctrl+C / ⌘C"),
 "en"=>(title="Add an event",
  intro="Anyone can add events. A bot checks each submission and prepares a proposal that an editor reviews before it is published – you get a reply as a comment on GitHub.",
  toc=["One event","Several dates (spreadsheet)","With AI","Correct / cancel"],
  form="""<h2>One event – or a simple weekly series</h2><p class="when">For: a single milonga, a workshop, or something that repeats the same way every week.</p>
<p>Fill in the form. For regular evenings choose «Gjentas: Ukentlig» (repeats weekly) and the last date; each date becomes an event of its own that can later be changed or cancelled separately.</p>
<p><b>The form is in Norwegian</b>, but you can write the title and description in English – just choose «Tekstspråk: English». If you have the text in both languages, add the other one in the optional fields at the bottom; one language is enough.</p>
<a class="cta" href="$f" target="_blank" rel="noopener">Open the form ↗</a>""",
  table="""<h2>Several dates with variations – from a spreadsheet</h2><p class="when">For: a series where e.g. the DJ or price varies, or many dates at once.</p>
<ol><li>The <b>first row</b> holds the column names (in Norwegian, see below), the <b>second row</b> everything the dates have in common (title, venue, times, price …).</li>
<li>On the <b>following rows</b>, fill in only what is different – typically <b>Dato</b> (date) and <b>DJ</b>. An empty cell = same as row two. Write <code>-</code> to remove a value, and «Avlyst» in <b>Status</b> for cancelled dates.</li>
<li>Select all the cells (including the column names), copy (Ctrl+C / ⌘C) and paste them into the form «Nytt arrangement (fra tabell)». Works from Excel, Google Sheets and Numbers.</li></ol>""",
  tablebtn="Open the spreadsheet form ↗",template="Download the template (CSV for Excel)",columns="Columns",
  colnote="The columns can be in any order, and you only need the ones you use.",required="required",
  ki="""<h2>With AI – from a Facebook page or website</h2><p class="when">For: the event is already described somewhere and you would rather not type it in yourself.</p><ol>
<li><b>Copy the prompt</b> below.</li>
<li>Open your AI assistant (Copilot, Gemini, ChatGPT …), paste the prompt and <b>add the event text</b> right after it – copy the text from the event page, or attach a screenshot. AI assistants usually cannot log in to Facebook themselves.</li>
<li><b>Read through the answer.</b> AI can get things wrong – check the date, times, venue and price in particular.</li>
<li>Paste the whole answer into the form «Nytt arrangement (JSON fra KI)».</li></ol>""",
  copy="Copy the prompt",kibtn="Open the AI form ↗",
  kinote="Regular evenings become one entry per date – tell the assistant which dates apply, e.g. “every Wednesday from 7 October to 9 December, except 18 November”.",
  fix="""<h2>Correct or cancel</h2><p>Every event has a link «Suggest a correction ↗». The form (in Norwegian) shows what is listed now; fill in only what should change, choose whether the change applies to this date only or to all later dates in the series too, and submit. Cancellations are reported with «Status: Avlyst» – the event stays in the calendar marked as cancelled.</p>""",
  privacy="""<h2>Privacy</h2><p>Only use information that is already public. Names of DJs and teachers should only be included if they have agreed to it – you confirm this in the form. Don't paste private messages or personal data into an AI assistant.</p>""",
  dev="You need a (free) GitHub account to submit. For developers and AI agents:",subschema="submission schema (JSON Schema)",stored="stored format",
  glossary="The form fields in English",copied="Copied ✓",selected="Selected – press Ctrl+C / ⌘C"),
 "es"=>(title="Sumá un evento",
  intro="Cualquiera puede cargar eventos. Un bot revisa cada envío y prepara una propuesta que alguien del equipo editorial revisa antes de publicarla; te respondemos con un comentario en GitHub.",
  toc=["Un evento","Varias fechas (planilla)","Con IA","Corregir / cancelar"],
  form="""<h2>Un evento, o una serie semanal sencilla</h2><p class="when">Para: una milonga, un seminario o algo que se repite igual todas las semanas.</p>
<p>Completá el formulario. Para las noches fijas elegí «Gjentas: Ukentlig» (se repite cada semana) y la última fecha; cada fecha queda como un evento propio que después se puede cambiar o cancelar por separado.</p>
<p><b>El formulario está en noruego.</b> El título y la descripción se pueden escribir en noruego o en inglés («Tekstspråk»); por ahora no en español. Si tenés el texto en los dos idiomas, cargá el otro en los campos opcionales del final; con un idioma alcanza.</p>
<a class="cta" href="$f" target="_blank" rel="noopener">Abrir el formulario ↗</a>""",
  table="""<h2>Varias fechas con variaciones, desde una planilla</h2><p class="when">Para: una serie en la que cambian, por ejemplo, el DJ o el precio, o muchas fechas de una vez.</p>
<ol><li>La <b>primera fila</b> tiene los nombres de las columnas (en noruego, ver abajo); la <b>segunda fila</b>, todo lo que las fechas tienen en común (título, lugar, horarios, precio …).</li>
<li>En las <b>filas siguientes</b> completá solo lo que cambia, normalmente <b>Dato</b> (fecha) y <b>DJ</b>. Celda vacía = igual que la segunda fila. Escribí <code>-</code> para borrar un dato y «Avlyst» en <b>Status</b> para las fechas canceladas.</li>
<li>Seleccioná todas las celdas (también los nombres de las columnas), copiá (Ctrl+C / ⌘C) y pegá en el formulario «Nytt arrangement (fra tabell)». Funciona con Excel, Hojas de cálculo de Google y Numbers.</li></ol>""",
  tablebtn="Abrir el formulario de planilla ↗",template="Descargar la plantilla (CSV para Excel)",columns="Columnas",
  colnote="Las columnas pueden ir en cualquier orden y solo hacen falta las que uses.",required="obligatorio",
  ki="""<h2>Con IA, desde una página de Facebook o un sitio web</h2><p class="when">Para: el evento ya está descrito en algún lado y preferís no escribirlo de nuevo.</p><ol>
<li><b>Copiá las instrucciones</b> de abajo.</li>
<li>Abrí tu asistente de IA (Copilot, Gemini, ChatGPT …), pegá las instrucciones y <b>agregá el texto del evento</b> justo después: copiá el texto de la página del evento o adjuntá una captura de pantalla. Los asistentes de IA normalmente no pueden entrar a Facebook por su cuenta.</li>
<li><b>Revisá la respuesta.</b> La IA se puede equivocar: fijate sobre todo en la fecha, los horarios, el lugar y el precio.</li>
<li>Pegá la respuesta completa en el formulario «Nytt arrangement (JSON fra KI)».</li></ol>""",
  copy="Copiar las instrucciones",kibtn="Abrir el formulario de IA ↗",
  kinote="Las noches fijas quedan como una entrada por fecha: decile al asistente qué fechas son, p. ej. «todos los miércoles del 7 de octubre al 9 de diciembre, menos el 18 de noviembre».",
  fix="""<h2>Corregir o cancelar</h2><p>Cada evento tiene un enlace «Proponer una corrección ↗». El formulario (en noruego) muestra lo que figura ahora; completá solo lo que hay que cambiar, elegí si el cambio vale solo para esa fecha o también para todas las siguientes de la serie, y envialo. Las cancelaciones se avisan con «Status: Avlyst»: el evento sigue en el calendario marcado como cancelado.</p>""",
  privacy="""<h2>Privacidad</h2><p>Usá solo información que ya sea pública. Los nombres de DJ y profesores solo pueden figurar si dieron su consentimiento; lo confirmás en el formulario. No pegues mensajes privados ni datos personales en un asistente de IA.</p>""",
  dev="Para enviar necesitás una cuenta (gratuita) de GitHub. Para desarrolladores y agentes de IA:",subschema="esquema de envío (JSON Schema)",stored="formato guardado",
  glossary="Los campos del formulario en español",copied="Copiado ✓",selected="Seleccionado: apretá Ctrl+C / ⌘C"))
end
const _COPY_JS=raw"""(function(){var b=document.getElementById('copy'),p=document.getElementById('prompt'),s=document.getElementById('copied');function sel(){var r=document.createRange();r.selectNodeContents(p);var g=window.getSelection();g.removeAllRanges();g.addRange(r)}b.addEventListener('click',function(){var t=p.textContent;if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(function(){s.textContent=b.getAttribute('data-copied')},function(){sel();s.textContent=b.getAttribute('data-selected')})}else{sel();s.textContent=b.getAttribute('data-selected')}setTimeout(function(){s.textContent=''},4000)})})();"""
"""
    legg_til_html(; lang="nb") -> String

The «Legg til arrangement» page: one place for every way to submit (form, spreadsheet, AI assistant) and to correct
events. The GitHub forms are Norwegian; the English and Spanish pages explain their fields.
"""
legg_til_html(; lang="nb", kwargs...)=_with_lang(()->_legg_til_html(;kwargs...),lang)
function _legg_til_html(; title=nothing)
 a=_add_text()[_lang()]; title=something(title,a.title)
 prompt=_esc(llm_prompt()); tf=_esc(table_form_url()); jf=_esc(json_form_url())
 cols=join(("<dt>$(_esc(c))</dt><dd>$(_esc(replace(h," *"=>"")))$(endswith(h," *") ? " <b>($(a.required))</b>" : "")</dd>" for (c,h) in _COLUMN_HELP[_lang()]),"")
 gl=haskey(_GLOSSARY,_lang()) ? "<details><summary>$(a.glossary)</summary><dl class=\"cols\">"*join(("<dt>$(_esc(c))</dt><dd>$(_esc(h))</dd>" for (c,h) in _GLOSSARY[_lang()]),"")*"</dl></details>" : ""
 ex="""<table class="ex"><tr><th>Tittel</th><th>Type</th><th>Dato</th><th>Starttid</th><th>Sluttid</th><th>Sted</th><th>Adresse</th><th>Arrangør</th><th>DJ</th><th>Pris (kr)</th><th>Lenke</th><th>Status</th></tr>
<tr class="def"><td>Fredagsmilonga</td><td>Milonga</td><td>16.10.2026</td><td>20:00</td><td>00:30</td><td>Salen</td><td>Storgata 1, $(site_city())</td><td>Tangoklubben</td><td>DJ A</td><td>150</td><td>https://…</td><td class="blank">–</td></tr>
<tr><td class="blank"></td><td class="blank"></td><td>23.10.2026</td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td>DJ B</td><td class="blank"></td><td class="blank"></td><td class="blank"></td></tr>
<tr><td class="blank"></td><td class="blank"></td><td>30.10.2026</td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td>Avlyst</td></tr></table>"""
 toc=join(("<a href=\"#$id\">$(_esc(l))</a>" for (id,l) in zip(["skjema","tabell","ki","rette"],a.toc)),"")
 # the template and schemas are language-neutral and live at the site root
 root=_lang()=="nb" ? "" : "../"
 """<!doctype html><html lang="$(_lang())"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(site_name()))</title>$(_plain_head(ADD_PAGE))$(_og_head(title="$title – $(site_name())",desc=_t("site.description"),url=_lang_url(ADD_PAGE)))<style>
$_PAGE_CSS$_LANG_CSS
</style></head><body>$_SPRITE<div class="hero"><div class="wrap">$(_plain_top(ADD_PAGE))<h1>$(_esc(title))</h1><p>$(a.intro)</p>
<nav class="toc" aria-label="$(_esc(a.toc[1]))">$toc</nav></div></div><main>
<section class="card" id="skjema">$(a.form)$gl</section>
<section class="card" id="tabell">$(a.table)
$ex
<a class="cta" href="$tf" target="_blank" rel="noopener">$(a.tablebtn)</a><a class="cta secondary" href="$root$(_esc(TEMPLATE_CSV))" download>$(a.template)</a>
<details><summary>$(a.columns)</summary><dl class="cols">$cols</dl><p class="muted">$(a.colnote)</p></details></section>
<section class="card" id="ki">$(a.ki)
<div class="btnrow"><button id="copy" type="button" data-copied="$(a.copied)" data-selected="$(a.selected)">$(a.copy)</button><span id="copied" class="muted" aria-live="polite"></span></div><div class="promptbox"><pre id="prompt">$prompt</pre></div>
<a class="cta" href="$jf" target="_blank" rel="noopener">$(a.kibtn)</a>
<p class="muted">$(a.kinote)</p></section>
<section class="card" id="rette">$(a.fix)</section>
<section class="card">$(a.privacy)
<p class="muted">$(a.dev) <a href="$(root)llms.txt">llms.txt</a> · <a href="$(root)schema/tango-event-submission.schema.json">$(a.subschema)</a> · <a href="$(root)schema/tango-event.schema.json">$(a.stored)</a></p></section>
</main><div class="sitefooter"><a href="./">$(_t("calendar"))</a> · <a href="$ABOUT_PAGE">$(_t("about"))</a> · <a href="kalender.ics">$(_t("subscribe.short"))</a> · <a href="rss.xml">RSS</a></div><script>
$_COPY_JS
</script></body></html>"""
end
"The old «Bruk KI» address: redirects to the KI section of legg-til.html."
for_ki_redirect_html()="""<!doctype html><html lang="nb"><head><meta charset="utf-8"><title>Flyttet – $(_esc(site_name()))</title><link rel="canonical" href="$(site_url())/$ADD_PAGE#ki"><meta http-equiv="refresh" content="0; url=$ADD_PAGE#ki"><meta name="robots" content="noindex"></head><body><p>Siden er flyttet: <a href="$ADD_PAGE#ki">Legg til arrangement – med KI</a>.</p></body></html>"""
