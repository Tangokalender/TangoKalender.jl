# Architecture

The package reads a city's data (`site.toml`, `events/`, `venues.json`) and writes a static site: self-contained
HTML pages (inline CSS and JS), feeds and embeds. Julia string interpolation builds the markup; there are no templates.

## Data flow

```
events/**/*.json ─ load_events ─▶ Vector of JSON.Object ─▶ renderers ─▶ write_site ─▶ _site/
issue body ─ parse_issue_form ─▶ events_from_form / _table / _json / apply_correction ─▶ event files
events/**/*.json ─ read_event ─▶ Event (struct) ─ set_path ─▶ write_event   (bulk edits)
```

Events are plain dictionaries (`JSON.Object`, which keeps the key order) everywhere except the bulk edit, which uses
the typed [`Event`](@ref) struct.

## Context in scoped values

Three `ScopedValue`s carry the context, so helpers need no extra arguments:

| Value | Set by | Holds |
|:--|:--|:--|
| `SITE` | `main`, [`write_site`](@ref) (`_with_site`) | The [`TangoKalender.SiteConfig`](@ref): name, city, URLs, map, texts. |
| `LANG` | each public renderer's `lang=` (`_with_lang`) | `"nb"`, `"en"` or `"es"`. |
| `VENUES` | `write_site(…; venues=)`, the CLI | The geocoding cache, so builds never use the network. |

Nothing site-specific is hard-coded: use `site_url()`, `repo_url()`, `site_name()`, `site_city()` and the form-URL
functions. A test fails on a hard-coded site URL.

## The site

- **Views** (`src/render/html.jl`): `index.html` (compact list), `uke.html` (week), `kart.html` (map),
  `kort.html` (cards). One page script filters the rows; the filter state lives in the URL.
- **Event pages** (`src/render/event.jl`): `arrangement/<id>/` with JSON-LD, link previews and a map.
- **Feeds and embeds:** `kalender.ics` and per-event `.ics` (`src/ics.jl`), `rss.xml`, `events.json`, the SVG images
  that pick the current day themselves (`src/render/svg.jl`), and an iframe list (`src/render/embed.jl`).
- **Languages** (`src/i18n.jl`): Norwegian at `/`, English at `/en/`, Spanish at `/es/`, with the same file names.
  Every UI string is in `_T` in all three languages; a test fails on a missing one.
- **Submission pages** (`src/render/submit.jl`, `src/llms.jl`): «Legg til», the AI prompt and `llms.txt`.

## Intake

The issue forms' labels are the parser's keys, so the canonical forms live in `templates/ISSUE_TEMPLATE/` and data
repositories get rendered copies. [`parse_issue_form`](@ref TangoKalender.parse_issue_form) splits a form; the plain form, the spreadsheet
([`events_from_table`](@ref TangoKalender.events_from_table)) and the JSON route ([`events_from_json`](@ref TangoKalender.events_from_json)) all end in the same event rules,
and corrections go through [`apply_correction`](@ref TangoKalender.apply_correction). Times are always recomputed as Norwegian local time.

## Bulk edits and trimming

`src/eventstruct.jl`, `src/edit.jl`, `src/repeat.jl` and `src/render/term.jl` implement `tangokalender edit` and `repeat` on the [`Event`](@ref)
struct. That code is written so `juliac --trim` can compile it into the stand-alone `tangoedit`:
- keys reach fields through generated `if` chains instead of lenses built from strings;
- field types are passed as `Val`, and nested keys use one function per level instead of recursion;
- dates are parsed by hand;
- terminal output goes through [`TangoKalender.ansi_text`](@ref) instead of StyledStrings.

Keep it that way and run `bin/build_tangoedit.sh` after changing that path.
