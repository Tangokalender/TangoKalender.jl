# [Events](@id events)

Every event is one JSON file in the data repository, named by its date and id:

```
events/
  2026/10-october/2026-10-14-esa-2026-10-14.json     # <start date>-<id>.json
```

- **Every event has a date.** A repeating activity (a weekly milonga, a course) is one file per date, all with the
  same `series` id, so the DJ, price or venue can differ from week to week.
- **Cancelled dates stay:** set `"status": "cancelled"` instead of deleting the file. The site shows them struck
  through with «Avlyst».
- **Times** are Norwegian local time with the offset: `2026-10-14T20:00:00+02:00` in summer time, `+01:00` in
  winter. A date without a time (`"2026-11-20"`) is fine for festivals.
- **Privacy:** only information that is already public. Names of DJs and teachers only with their consent; never
  phone numbers or e-mail addresses.

The schema, `schema/tango-event.schema.json`, is published on every site (e.g.
<https://tango.oslo.no/schema/tango-event.schema.json>). Add it as `"$schema"` in a file to get
completion in your editor. `tangokalender validate events` checks every file, unique ids and file locations, and warns about two events of
one series with the same start (usually one date entered twice).

## Fields

Generated from the schema; only `id`, `title`, `types` and `start` are required.

```@example
using TangoKalender, JSON, Markdown
s=JSON.parsefile(TangoKalender.SCHEMA_FILE); defs=s["definitions"]; req=Set(s["required"])
function kind(p)
 r=get(p,"\$ref",get(get(p,"allOf",[Dict()])[1],"\$ref",nothing))
 isnothing(r) || return Dict("datetime"=>"date or date-time","nok"=>"whole kroner","text"=>"text","url"=>"http(s) URL","day"=>"date")[split(r,'/')[end]]
 haskey(p,"enum") && return join(("`$(x)`" for x in p["enum"] if !isnothing(x)),", ")
 t=get(p,"type",""); t isa Vector ? join(filter(!=("null"),t),"/") : string(t)
end
notes=Dict("id"=>"Lower-case letters, digits and dashes; part of the file name and the event's web address. Never change it.",
 "title"=>"As the organiser writes it.","start"=>"`2026-10-14T20:00:00+02:00`, or a date for all-day events.",
 "end"=>"Same format. After midnight: the next day's date.","venue"=>"`{\"name\", \"address\", \"city\"}`; `null` when not announced.",
 "organizer"=>"Group or person that organises it.","dj"=>"Only with consent.","teachers"=>"List of names; only with consent.",
 "price_nok"=>"Entry price.","student_price_nok"=>"Reduced price.","class_price_nok"=>"Class or course price (for a whole course: on every date).",
 "description"=>"1–3 short, neutral sentences.","flyer_url"=>"Direct link to the image; used in link previews.",
 "video"=>"`{\"platform\": \"youtube\" or \"vimeo\", \"id\"}`.","link"=>"The official event page.",
 "source"=>"Where the information came from (set by the bot).","source_url"=>"Link to that source.",
 "published_date"=>"When the source published it.","first_seen"=>"Added to the calendar (set by the bot).",
 "last_verified"=>"Last checked against the source.","crawl_timestamp"=>"When it was read (set by the bot).",
 "confidence"=>"0–1: how sure the extraction was.","music_style"=>"See the table below.","translations"=>"Title and description in other languages: `{\"en\": {\"title\", \"description\"}}`.")
note(k,p)=replace(isempty(get(p,"description","")) ? get(notes,k,"") : p["description"],"|"=>"\\|","\n"=>" ")
rows=["| `$k` | $(k in req ? "yes" : "") | $(kind(p)) | $(note(k,p)) |" for (k,p) in s["properties"] if k!="\$schema"]
Markdown.parse("| Field | Required | Value | Notes |\n|:--|:--|:--|:--|\n"*join(rows,"\n"))
```

## Types and music styles

`types` lists one or more of the values below, in the order shown on the site; a class followed by a milonga is
`["class", "milonga"]`, an open-air milonga `["milonga", "outdoor"]`.

```@example
using TangoKalender, Markdown
TK=TangoKalender
Markdown.parse("| `types` | Norwegian | English |\n|:--|:--|:--|\n"*join(("| `$t` | $(TK._TYPES[t]) | $(TK._TYPES_I18N["en"][t]) |" for t in TK.TYPE_ORDER),"\n")*
 "\n\n| `music_style` | Norwegian | English |\n|:--|:--|:--|\n"*join(("| `$m` | $(TK._MUSIC[m]) | $(TK._MUSIC_I18N["en"][m]) |" for m in sort(collect(keys(TK._MUSIC)))),"\n"))
```
