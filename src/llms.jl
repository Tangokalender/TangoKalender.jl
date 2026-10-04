# Instructions for LLM assistants: /llms.txt (for the model); the human-facing part lives on legg-til.html#ki (src/render/submit.jl).
# The rules are written once (llm_rules) and reused in both; the worked example is checked by the tests.
const LLMS_URL=SITE_URL*"/llms.txt"
const AI_PAGE="for-ki.html"   # old address, now a redirect to legg-til.html#ki
const EXAMPLE_INPUT="""Milonga del Fiordo 🎶 Fredag 12. mars kl. 21–01.30 på Kulturhuset Fjord, Storgata 9, Oslo.
DJ: Gjeste-DJ. Inngang 150 kr, studenter 100 kr. Tradisjonell tango hele kvelden.
Arr: Tangoforeningen Fjord. https://www.facebook.com/events/000000000000000"""
const EXAMPLE_OUTPUT="""{
  "title": "Milonga del Fiordo",
  "types": ["milonga"],
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
- Required in every object: "title", "types", "start", "venue" (with "name" and "address"), "organizer" and "link". Everything else may be null or left out.
- "organizer" is the group or person the source names as organiser. If none is named, use the page or profile that published the event (on Facebook: the event host). Ask the user if you cannot tell.
- One JSON object per date. If the event repeats (e.g. "every Wednesday until 9 December"), output an array with one object per date and leave out dates the source says are cancelled. If no end date is given, include the next 4 dates.
- "start" and "end" are Oslo local time: "YYYY-MM-DDTHH:MM", without a time zone. Use "YYYY-MM-DD" when no time is given (e.g. festivals). If the event ends after midnight, "end" has the next day's date. If the year is not stated, use the next upcoming occurrence of that date.
- "types" is a list with one or more of: $(_typelist()). Use several when the event combines them, e.g. ["class", "milonga"], or ["milonga", "outdoor"] for an open-air milonga.
- "music_style" (only if the source states it) is a list of: $(_musiclist()).
- Prices are whole Norwegian kroner as integers: "price_nok" (regular entry), "student_price_nok", "class_price_nok" (the class or course part). If a price covers a whole course or several dates (e.g. 910 kr for a 6-session course), put it in "class_price_nok" on each date, leave "price_nok" null, and say what it covers in "description" (e.g. "Pris for hele kurset.").
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
- [Instructions for people, in Norwegian]($SITE_URL/$ADD_PAGE#ki)
"""
"""
    write_site(dir, events; today=Dates.today(), kwargs...) -> files

Write the whole static site: the three views (index.html = compact list, uke.html, kort.html), one page and one
.ics per event (arrangement/<id>/index.html, arrangement/<id>.ics), kalender.ics, rss.xml, legg-til.html (+ the old
for-ki.html as a redirect and the spreadsheet template),
llms.txt and both schemas. `kwargs` go to `render_events_html`.
"""
function write_site(dir::AbstractString, events; today::Date=Dates.today(), kwargs...)
 mkpath(joinpath(dir,"schema")); mkpath(joinpath(dir,"arrangement")); files=String[]
 w(rel,content)=(f=joinpath(dir,rel); mkpath(dirname(f)); write(f,content); push!(files,f))
 ev=collect(events)
 for (view,(file,_)) in _VIEWS; w(file,render_events_html(ev;view,site=true,today,kwargs...)); end
 cu=get(Dict(kwargs),:correct_url,CORRECT_URL)
 for e in ev
  _haspage(e) || continue
  w(joinpath("arrangement",string(e["id"]),"index.html"),render_event_page(e,ev;today,correct_url=cu))
  w(joinpath("arrangement","$(e["id"]).ics"),event_ics(e;today))
 end
 w("kalender.ics",calendar_ics([e for e in ev if _haspage(e) && Date(_end_day(e))>=today-Day(30)];today))
 w("rss.xml",rss_xml(ev;today))
 w(ADD_PAGE,legg_til_html()); w(ABOUT_PAGE,om_html()); w(AI_PAGE,for_ki_redirect_html()); w("llms.txt",llms_txt())
 w(TEMPLATE_CSV,table_template_csv())
 cp(SCHEMA_FILE,joinpath(dir,"schema","tango-event.schema.json");force=true); push!(files,joinpath(dir,"schema","tango-event.schema.json"))
 w(joinpath("schema","tango-event-submission.schema.json"),sprint(io->(JSON.print(io,submission_schema(),2); write(io,'\n'))))
 touch(joinpath(dir,".nojekyll")); files
end
