# Instructions for LLM assistants: /llms.txt (for the model) and /for-ki.html (Norwegian, for people).
# The rules are written once (llm_rules) and reused in both; the worked example is checked by the tests.
const LLMS_URL=SITE_URL*"/llms.txt"
const AI_PAGE="for-ki.html"
const EXAMPLE_INPUT="""Milonga del Fiordo 🎶 Fredag 12. mars kl. 21–01.30 på Kulturhuset Fjord, Storgata 9, Oslo.
DJ: Gjeste-DJ. Inngang 150 kr, studenter 100 kr. Tradisjonell tango hele kvelden.
Arr: Tangoforeningen Fjord. https://www.facebook.com/events/000000000000000"""
const EXAMPLE_OUTPUT="""{
  "title": "Milonga del Fiordo",
  "type": "milonga",
  "start": "2027-03-12T21:00",
  "end": "2027-03-13T01:30",
  "venue": {"name": "Kulturhuset Fjord", "address": "Storgata 9, Oslo", "city": "Oslo"},
  "organizer": "Tangoforeningen Fjord",
  "dj": "Gjeste-DJ",
  "teachers": [],
  "music_style": ["traditional"],
  "price_nok": 150,
  "student_price_nok": 100,
  "class_price_nok": null,
  "description": "Milonga med tradisjonell tango hele kvelden.",
  "flyer_url": null,
  "video_url": null,
  "link": "https://www.facebook.com/events/000000000000000"
}"""
"The extraction rules, shared by llms.txt and the copy-ready prompt."
llm_rules()="""- Output ONLY a JSON value that conforms to this JSON Schema, with no explanation around it: $SUBMISSION_SCHEMA_URL
- One JSON object per date. If the event repeats (e.g. "every Wednesday until 9 December"), output an array with one object per date and leave out dates the source says are cancelled. If no end date is given, include the next 4 dates.
- "start" and "end" are Oslo local time: "YYYY-MM-DDTHH:MM", without a time zone. Use "YYYY-MM-DD" when no time is given (e.g. festivals). If the event ends after midnight, "end" has the next day's date. If the year is not stated, use the next upcoming occurrence of that date.
- "type" is one of: $(_typelist()).
- "music_style" (only if the source states it) is a list of: $(_musiclist()).
- Prices are whole Norwegian kroner as integers: "price_nok" (regular entry), "student_price_nok", "class_price_nok" (the class or course part).
- "venue" is {"name", "address", "city"}; "city" is usually "Oslo".
- "link" is the URL of the event page (for example the Facebook event). "flyer_url" and "video_url" (YouTube or Vimeo) only if such links appear in the source.
- "description": 1–3 short, neutral sentences in the language of the source (level, entry, dress code). No marketing language.
- Use null (or [] for lists) for anything the source does not state. Never guess names, prices, times or addresses.
- Write people's names (DJ, teachers, organiser) only as they appear in the public event."""
"Copy-ready prompt for a chat assistant; the person pastes the event text or screenshot after it."
llm_prompt()="""You are helping to submit an event to Tangokalender, a community calendar for Argentine tango in Oslo.
Read the event information I give you below (text, screenshot or link contents) and convert it as follows.

$(llm_rules())

Example. For the input
$EXAMPLE_INPUT
the output is
$EXAMPLE_OUTPUT

Event information:
"""
"Contents of /llms.txt (llmstxt.org convention)."
llms_txt()="""# Tangokalender

> Community calendar for Argentine tango in Oslo, Norway: milongas, practicas, classes and festivals.
> Events are submitted as JSON through a GitHub issue form and reviewed by an editor before they are published.

## Converting an event page to a submission

When a user asks you to add an event to Tangokalender, or gives you an event description (for example copied from Facebook) together with these instructions:

$(llm_rules())

Tell the user to paste your JSON into the form at $JSON_FORM_URL and to check it before submitting.

## Example

Input:

```
$EXAMPLE_INPUT
```

Output:

```json
$EXAMPLE_OUTPUT
```

## Links

- [Calendar]($SITE_URL/)
- [Submission JSON Schema]($SUBMISSION_SCHEMA_URL): what to output
- [Stored event schema]($SITE_URL/schema/tango-event.schema.json): how events are stored after review (ids, series and metadata are set by the bot)
- [JSON submission form]($JSON_FORM_URL)
- [Instructions for people, in Norwegian]($SITE_URL/$AI_PAGE)
"""
"The Norwegian «Bruk KI» help page."
function for_ki_html(; title="Bruk KI til å legge inn arrangementer")
 prompt=_esc(llm_prompt())
 """<!doctype html><html lang="nb"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(_esc(title)) – Oslo Tango</title><style>
:root{--wine:#872b49;--paper:#f5f1eb;--line:#ddd3ca;--muted:#6e6864}*{box-sizing:border-box}body{margin:0;background:var(--paper);font-family:Inter,system-ui,sans-serif;color:#211d1c;line-height:1.55}.hero{padding:40px 20px 56px;color:white;background:linear-gradient(135deg,#26151d,#8b2949)}.wrap{max-width:820px;margin:auto}.hero h1{font:500 clamp(2rem,6vw,3.4rem) Georgia;margin:.1em 0}.hero p{color:#f7dce5;margin:0}.hero a{color:white}main{max-width:820px;margin:-28px auto 0;padding:0 16px 60px}.card{background:white;border:1px solid var(--line);border-radius:18px;padding:22px;margin-bottom:16px;box-shadow:0 5px 18px #2919210b}h2{font:500 1.5rem Georgia;margin:0 0 8px}ol{padding-left:1.3em}li{margin:6px 0}a{color:var(--wine);font-weight:700}.promptbox{position:relative}pre{white-space:pre-wrap;word-break:break-word;background:#f7f2ec;border:1px solid var(--line);border-radius:12px;padding:16px;max-height:340px;overflow:auto;font-size:.82rem}button{border:0;border-radius:999px;background:var(--wine);color:white;font-weight:800;padding:10px 18px;cursor:pointer}button:hover{background:#6f2240}.btnrow{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin:10px 0}.btn{display:inline-block;border-radius:999px;padding:10px 18px;background:#f2dce4;color:#76203e;text-decoration:none}small,.muted{color:var(--muted)}
</style></head><body><div class="hero"><div class="wrap"><small><a href="./">← Til kalenderen</a></small><h1>$(_esc(title))</h1><p>Har du arrangementet på Facebook eller en nettside? La en KI-assistent (Copilot, Gemini, ChatGPT …) lage utfyllingen for deg.</p></div></div><main>
<section class="card"><h2>Slik gjør du</h2><ol>
<li><b>Kopier ledeteksten</b> under.</li>
<li>Åpne KI-assistenten, lim inn ledeteksten og <b>legg til arrangementsteksten</b> rett etter – kopier teksten fra arrangementssiden, eller legg ved et skjermbilde. KI-assistenter kan som regel ikke logge inn på Facebook selv.</li>
<li><b>Les over svaret.</b> KI kan ta feil – sjekk særlig dato, klokkeslett, sted og pris.</li>
<li>Lim inn hele svaret i skjemaet <a href="$(_esc(JSON_FORM_URL))" target="_blank" rel="noopener">«Nytt arrangement (JSON fra KI)»</a> og send inn. En robot sjekker det og lager et forslag som en redaktør ser over.</li>
</ol></section>
<section class="card"><h2>Ledetekst</h2><div class="btnrow"><button id="copy" type="button">Kopier ledeteksten</button><span id="copied" class="muted" aria-live="polite"></span></div><div class="promptbox"><pre id="prompt">$prompt</pre></div></section>
<section class="card"><h2>Gjentatte arrangementer</h2><p>Faste kvelder (f.eks. hver onsdag) blir én oppføring per dato. Skriv gjerne til KI-assistenten hvilke datoer det gjelder, for eksempel «hver onsdag fra 7. oktober til 9. desember, ikke 18. november».</p></section>
<section class="card"><h2>Personvern</h2><p>Bruk bare opplysninger som allerede er offentlige. Navn på DJ-er og lærere skal bare være med hvis de har godtatt det – du bekrefter dette i skjemaet. Ikke lim inn private meldinger eller personopplysninger i KI-assistenten.</p></section>
<section class="card"><h2>For utviklere og KI-agenter</h2><p class="muted">Instruksjonene på engelsk: <a href="llms.txt">llms.txt</a> · Skjema for innsending: <a href="schema/tango-event-submission.schema.json">tango-event-submission.schema.json</a> · Lagret format: <a href="schema/tango-event.schema.json">tango-event.schema.json</a></p></section>
</main><script>
(function(){var b=document.getElementById('copy'),p=document.getElementById('prompt'),s=document.getElementById('copied');function sel(){var r=document.createRange();r.selectNodeContents(p);var g=window.getSelection();g.removeAllRanges();g.addRange(r)}b.addEventListener('click',function(){var t=p.textContent;if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t).then(function(){s.textContent='Kopiert ✓'},function(){sel();s.textContent='Merket – trykk Ctrl+C / ⌘C'})}else{sel();s.textContent='Merket – trykk Ctrl+C / ⌘C'}setTimeout(function(){s.textContent=''},4000)})})();
</script></body></html>"""
end
"""
    write_site(dir; kwargs...) -> files

Write the whole static site: index.html (from `events`), for-ki.html, llms.txt and both schemas.
"""
function write_site(dir::AbstractString, events; kwargs...)
 mkpath(joinpath(dir,"schema"))
 files=[joinpath(dir,f) for f in ("index.html",AI_PAGE,"llms.txt",joinpath("schema","tango-event.schema.json"),joinpath("schema","tango-event-submission.schema.json"))]
 write(files[1],render_events_html(events;kwargs...)); write(files[2],for_ki_html()); write(files[3],llms_txt())
 cp(SCHEMA_FILE,files[4];force=true); open(io->(JSON.print(io,submission_schema(),2); write(io,'\n')),files[5],"w")
 touch(joinpath(dir,".nojekyll")); files
end
