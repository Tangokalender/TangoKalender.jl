# «Om kalenderen» (om.html): what the calendar is and how to support it. Same look as legg-til.html (_PAGE_CSS).
const ABOUT_PAGE="om.html"
"""
    om_html() -> String

The about page: the calendar is a community effort; thanks to volunteers and organisers; how to support it.
"""
function om_html(; title="Om kalenderen")
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – $(_esc(SITE_NAME))</title><link rel="canonical" href="$SITE_URL/$ABOUT_PAGE"><meta name="description" content="Tangokalenderen for Oslo er et felles prosjekt for tangomiljøet. Slik kan du bidra."><style>
$_PAGE_CSS.thanks{font:500 1.25rem Georgia;color:var(--wine);margin:0}.wink{font-size:1.05rem}
</style></head><body><div class="hero"><div class="wrap"><small><a href="./">← Til kalenderen</a></small><h1>$(_esc(title))</h1><p>$(_esc(SITE_NAME)) samler milongaer, practicaer, kurs og festivaler for argentinsk tango i Oslo på ett sted.</p></div></div><main>
<section class="card"><h2>Et felles prosjekt</h2>
<p>Kalenderen er et dugnadsprosjekt for og av tangomiljøet i Oslo. Den eies ikke av noen klubb eller arrangør – den er til for alle som danser, arrangerer eller bare er nysgjerrige på tango.</p>
<p>Alt innhold kommer fra miljøet selv: arrangører og dansere legger inn arrangementer, retter opp feil og melder fra om avlysninger. Hver innsending blir sett over før den publiseres.</p></section>
<section class="card"><h2>Tusen takk</h2>
<p class="thanks">Til alle frivillige og arrangører i Oslos tangomiljø: dere er grunnen til at det finnes noe å sette i kalenderen.</p>
<p>Milongaer, practicaer, kurs og festivaler blir ikke til av seg selv. Bak hver kveld står folk som bærer høyttalere, rydder gulv, setter sammen musikk, underviser, holder styr på økonomien og passer på at alle føler seg velkomne. Hjelpen og innsatsen deres settes stor pris på.</p></section>
<section class="card"><h2>Slik støtter du kalenderen</h2>
<ol><li><b>Bruk den.</b> Sjekk kalenderen når du lurer på hvor du kan danse – i dag, denne uken eller neste måned.</li>
<li><b>Del arrangementer.</b> Hvert arrangement har sin egen side du kan dele, og filtrene ligger i lenken – del gjerne «alle milongaer denne måneden» med en venn. Du kan også abonnere på hele kalenderen i din egen kalender-app.</li>
<li><b>Hjelp til med å holde den oppdatert.</b> Ser du et arrangement som mangler, en feil tid eller en avlysning? Det tar et par minutter å <a href="$ADD_PAGE">legge inn eller rette opp</a>. Jo flere som hjelper til, jo mer kan alle stole på kalenderen.</li></ol>
<p class="wink">Og vil noen vise sin takknemlighet ved å spandere en drink på den som står bak kalenderen på neste milonga, er det neppe noen som klager … 😉</p></section>
<section class="card"><h2>Hvordan det fungerer</h2>
<p>Kalenderen er en statisk nettside uten reklame, sporing eller innlogging for besøkende. Arrangementene ligger som åpne data, og alt – kode, data og endringshistorikk – er åpent på <a href="$(_esc(REPO_URL))" target="_blank" rel="noopener">GitHub</a>. For å sende inn trenger du en gratis GitHub-konto; en robot sjekker innsendingen og en redaktør godkjenner den.</p>
<p class="muted">Kontroller alltid detaljer hos arrangøren. Har du spørsmål eller forslag, <a href="$(_esc(REPO_URL))/issues" target="_blank" rel="noopener">skriv en sak på GitHub</a>.</p>
<p><a class="cta" href="./">Til kalenderen</a><a class="cta secondary" href="$ADD_PAGE">Legg til arrangement</a></p></section>
</main><div class="sitefooter"><a href="./">Kalenderen</a> · <a href="$ADD_PAGE">Legg til arrangement</a> · <a href="kalender.ics">Abonner (.ics)</a> · <a href="rss.xml">RSS</a></div></body></html>"""
end
