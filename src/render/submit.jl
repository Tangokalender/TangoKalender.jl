# The single «Legg til arrangement» page (legg-til.html): all ways to submit or correct events, in Norwegian.
# Sections: #skjema (issue form), #tabell (cells pasted from a spreadsheet), #ki (prompt for an AI assistant), #rette.
const ADD_PAGE="legg-til.html"
const TEMPLATE_CSV="mal/arrangementer-mal.csv"
const _PAGE_CSS=""".sitefooter{text-align:center;color:var(--muted);padding:20px;font-size:.8rem}.sitefooter a{color:var(--wine);font-weight:700}:root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c;line-height:1.55}.hero{padding:40px 20px 56px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:820px;margin:auto}.hero h1{font:500 clamp(2rem,6vw,3.4rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5;margin:0}.hero a{color:white}main{max-width:820px;margin:-28px auto 0;padding:0 16px 60px}.card{background:white;border:1px solid var(--line);border-radius:18px;padding:22px;margin-bottom:16px;box-shadow:0 5px 18px #2919210b}h2{font:500 1.5rem Georgia;margin:0 0 8px}ol{padding-left:1.3em}li{margin:6px 0}a{color:var(--wine);font-weight:700}.promptbox{position:relative}pre{white-space:pre-wrap;word-break:break-word;background:#f7f2ec;border:1px solid var(--line);border-radius:12px;padding:16px;max-height:340px;overflow:auto;font-size:.82rem}button{border:0;border-radius:999px;background:var(--wine);color:white;font-weight:800;padding:10px 18px;cursor:pointer}button:hover{background:#6f2240}.btnrow{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:10px 0}.btn{display:inline-block;border-radius:999px;padding:10px 18px;background:#f2dce4;color:#76203e;text-decoration:none}small,.muted{color:var(--muted)}.hero nav a{color:#f7dce5;margin-right:14px}.toc{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}.toc a{display:inline-block;padding:8px 14px;border-radius:999px;border:1px solid #ffffff55;color:white;text-decoration:none;font-weight:700}.when{color:var(--muted);font-size:.92rem;margin:-4px 0 10px}.cta{display:inline-block;background:var(--wine);color:white;border-radius:999px;padding:10px 18px;font-weight:800;text-decoration:none;margin:6px 8px 6px 0}.cta.secondary{background:#f2dce4;color:#76203e}table.ex{border-collapse:collapse;font-size:.8rem;margin:10px 0;display:block;overflow-x:auto;white-space:nowrap}table.ex th,table.ex td{border:1px solid var(--line);padding:5px 8px;text-align:left}table.ex th{background:#f2dce4}table.ex tr.def td{background:#fbf3f6}table.ex td.blank{color:#bbb}dl.cols{display:grid;grid-template-columns:150px 1fr;gap:4px 14px;font-size:.9rem}dl.cols dt{font-weight:800}dl.cols dd{margin:0}code{background:#f7f2ec;padding:1px 5px;border-radius:5px}"""
const _COPY_JS=raw"""(function(){var b=document.getElementById('copy'),p=document.getElementById('prompt'),s=document.getElementById('copied');function sel(){var r=document.createRange();r.selectNodeContents(p);var g=window.getSelection();g.removeAllRanges();g.addRange(r)}b.addEventListener('click',function(){var t=p.textContent;if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(function(){s.textContent='Kopiert ✓'},function(){sel();s.textContent='Merket – trykk Ctrl+C / ⌘C'})}else{sel();s.textContent='Merket – trykk Ctrl+C / ⌘C'}setTimeout(function(){s.textContent=''},4000)})})();"""
const _COLUMN_HELP=[("Tittel","Navnet på arrangementet. *"),("Type","Én eller flere, skilt med komma: Kurs, Workshop, Milonga, Practica, Festival, Maraton, Utetango, Annet – f.eks. «Kurs, Milonga» eller «Milonga, Utetango». *"),
 ("Dato","Én dato per rad: ÅÅÅÅ-MM-DD eller DD.MM.ÅÅÅÅ. *"),("Starttid / Sluttid","TT:MM. Sluttid etter midnatt er greit (f.eks. 01:00). Starttid *"),
 ("Sted / Adresse","Navn på stedet og gateadresse. *"),("Arrangør","Klubb eller person som arrangerer. *"),("DJ / Lærere","Navn – lærere skilt med komma."),
 ("Pris (kr), Studentpris (kr), Kurspris (kr)","Hele kroner."),("Musikk","Tradisjonell, Alternativ / neo og/eller Levende orkester, skilt med komma."),
 ("Flyer / Video","Lenke til bilde / YouTube eller Vimeo."),("Lenke","Arrangementets nettside eller Facebook-arrangement. *"),
 ("Beskrivelse","Kort tekst."),("Status","Skriv «Avlyst» på datoer som er avlyst.")]
"""
    legg_til_html() -> String

The «Legg til arrangement» page: one place for every way to submit (form, spreadsheet, AI assistant) and to correct events.
"""
function legg_til_html(; title="Legg til arrangement")
 prompt=_esc(llm_prompt()); f=_esc(SUBMIT_URL); tf=_esc(TABLE_FORM_URL); jf=_esc(JSON_FORM_URL)
 cols=join(("<dt>$(_esc(c))</dt><dd>$(_esc(replace(h," *"=>"")))$(endswith(h," *") ? " <b>(påkrevd)</b>" : "")</dd>" for (c,h) in _COLUMN_HELP),"")
 ex="""<table class="ex"><tr><th>Tittel</th><th>Type</th><th>Dato</th><th>Starttid</th><th>Sluttid</th><th>Sted</th><th>Adresse</th><th>Arrangør</th><th>DJ</th><th>Pris (kr)</th><th>Lenke</th><th>Status</th></tr>
<tr class="def"><td>Fredagsmilonga</td><td>Milonga</td><td>16.10.2026</td><td>20:00</td><td>00:30</td><td>Salen</td><td>Storgata 1, Oslo</td><td>Tangoklubben</td><td>DJ A</td><td>150</td><td>https://…</td><td class="blank">–</td></tr>
<tr><td class="blank"></td><td class="blank"></td><td>23.10.2026</td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td>DJ B</td><td class="blank"></td><td class="blank"></td><td class="blank"></td></tr>
<tr><td class="blank"></td><td class="blank"></td><td>30.10.2026</td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td class="blank"></td><td>Avlyst</td></tr></table>"""
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(SITE_NAME))</title><link rel="canonical" href="$SITE_URL/$ADD_PAGE"><style>
$_PAGE_CSS
</style></head><body><div class="hero"><div class="wrap"><small><a href="./">← Til kalenderen</a></small><h1>$(_esc(title))</h1><p>Alle kan legge inn arrangementer. En robot sjekker innsendingen og lager et forslag som en redaktør ser over før det publiseres – du får svar som en kommentar på GitHub.</p>
<nav class="toc" aria-label="Velg måte"><a href="#skjema">Ett arrangement</a><a href="#tabell">Flere datoer (regneark)</a><a href="#ki">Med KI</a><a href="#rette">Rette opp / avlyse</a></nav></div></div><main>
<section class="card" id="skjema"><h2>Ett arrangement – eller en enkel ukentlig serie</h2><p class="when">Når: én milonga, en workshop, eller noe som gjentas likt hver uke.</p>
<p>Fyll ut skjemaet. For faste kvelder velger du «Gjentas: Ukentlig» og siste dato; hver dato blir et eget arrangement som senere kan endres eller avlyses for seg.</p>
<a class="cta" href="$f" target="_blank" rel="noopener">Åpne skjemaet ↗</a></section>
<section class="card" id="tabell"><h2>Flere datoer med variasjoner – fra regneark</h2><p class="when">Når: en serie der f.eks. DJ eller pris varierer, eller mange datoer på én gang.</p>
<ol><li><b>Første rad</b> er kolonnenavnene, <b>andre rad</b> har alt som er felles (tittel, sted, tider, pris …).</li>
<li>På <b>de neste radene</b> fyller du bare inn det som er annerledes – typisk <b>Dato</b> og <b>DJ</b>. Tom celle = som andre rad. Skriv <code>-</code> for å fjerne en opplysning, og «Avlyst» i <b>Status</b> for avlyste datoer.</li>
<li>Merk alle cellene (også kolonnenavnene), kopier (Ctrl+C / ⌘C) og lim inn i skjemaet «Nytt arrangement (fra tabell)». Fungerer fra Excel, Google Regneark og Numbers.</li></ol>
$ex
<a class="cta" href="$tf" target="_blank" rel="noopener">Åpne tabell-skjemaet ↗</a><a class="cta secondary" href="$(_esc(TEMPLATE_CSV))" download>Last ned mal (CSV for Excel)</a>
<details><summary>Kolonner</summary><dl class="cols">$cols</dl><p class="muted">Kolonnene kan stå i hvilken som helst rekkefølge, og du trenger bare de du bruker.</p></details></section>
<section class="card" id="ki"><h2>Med KI – fra en Facebook-side eller nettside</h2><p class="when">Når: arrangementet er allerede beskrevet et sted, og du vil slippe å skrive det inn selv.</p><ol>
<li><b>Kopier ledeteksten</b> under.</li>
<li>Åpne KI-assistenten (Copilot, Gemini, ChatGPT …), lim inn ledeteksten og <b>legg til arrangementsteksten</b> rett etter – kopier teksten fra arrangementssiden, eller legg ved et skjermbilde. KI-assistenter kan som regel ikke logge inn på Facebook selv.</li>
<li><b>Les over svaret.</b> KI kan ta feil – sjekk særlig dato, klokkeslett, sted og pris.</li>
<li>Lim inn hele svaret i skjemaet «Nytt arrangement (JSON fra KI)».</li></ol>
<div class="btnrow"><button id="copy" type="button">Kopier ledeteksten</button><span id="copied" class="muted" aria-live="polite"></span></div><div class="promptbox"><pre id="prompt">$prompt</pre></div>
<a class="cta" href="$jf" target="_blank" rel="noopener">Åpne KI-skjemaet ↗</a>
<p class="muted">Faste kvelder blir én oppføring per dato – skriv gjerne til KI-assistenten hvilke datoer det gjelder, f.eks. «hver onsdag fra 7. oktober til 9. desember, ikke 18. november».</p></section>
<section class="card" id="rette"><h2>Rette opp eller avlyse</h2><p>Hvert arrangement har en lenke «Rett opp ↗». Skjemaet viser hva som står der nå; fyll bare inn det som skal endres, velg om endringen gjelder bare denne datoen eller også alle senere i serien, og send inn. Avlysninger meldes med «Status: Avlyst» – arrangementet blir stående som «Avlyst» i kalenderen.</p></section>
<section class="card"><h2>Personvern</h2><p>Bruk bare opplysninger som allerede er offentlige. Navn på DJ-er og lærere skal bare være med hvis de har godtatt det – du bekrefter dette i skjemaet. Ikke lim inn private meldinger eller personopplysninger i en KI-assistent.</p>
<p class="muted">Du trenger en (gratis) GitHub-konto for å sende inn. For utviklere og KI-agenter: <a href="llms.txt">llms.txt</a> · <a href="schema/tango-event-submission.schema.json">innsendingsskjema (JSON Schema)</a> · <a href="schema/tango-event.schema.json">lagret format</a></p></section>
</main><div class="sitefooter"><a href="./">Kalenderen</a> · <a href="$ABOUT_PAGE">Om kalenderen</a> · <a href="kalender.ics">Abonner (.ics)</a> · <a href="rss.xml">RSS</a></div><script>
$_COPY_JS
</script></body></html>"""
end
"The old «Bruk KI» address: redirects to the KI section of legg-til.html."
for_ki_redirect_html()="""<!doctype html><html lang="nb"><head><meta charset="utf-8"><title>Flyttet – $(_esc(SITE_NAME))</title><link rel="canonical" href="$SITE_URL/$ADD_PAGE#ki"><meta http-equiv="refresh" content="0; url=$ADD_PAGE#ki"><meta name="robots" content="noindex"></head><body><p>Siden er flyttet: <a href="$ADD_PAGE#ki">Legg til arrangement – med KI</a>.</p></body></html>"""
