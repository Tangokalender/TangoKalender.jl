# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A small Julia package that turns Oslo tango events (one JSON file per event under `events/`) into one self-contained static HTML page (inline CSS and JS, no external assets). The page lets visitors search, filter and sort events. The UI text is Norwegian Bokmål (`lang="nb"`), so keep any new UI strings in Norwegian. Data values stay English slugs (schema enums such as `class_and_social`, `Tuesday`); `src/labels.jl` maps them to Norwegian display labels through `_TYPES`, `_MUSIC` and `_WEEKDAYS` (used by the renderer and the issue-form parser). Add any new enum value to the matching dict too. An English version of the page is planned, and these dicts are the place to translate.

## Commands

```bash
# Install dependencies and run the tests
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'

# CLI entry point (TangoKalender.main): build is the default subcommand; paths are relative to the cwd
julia --project=. -m TangoKalender validate [events]                   # exit 1 on problems
julia --project=. -m TangoKalender [build] [events] [public/index.html] [--title=… --subtitle=… --no-validate]
julia --project=. -m TangoKalender site [events] [_site]   # whole site: index.html, for-ki.html, llms.txt, schema/*.json (used by pages.yml)
julia --project=. -m TangoKalender migrate examples/oslo_tango_events_2026-09-30.json events  # one-off v1 → tree
julia --project=. -m TangoKalender from-issue BODY.md [--root=events] [--issue-url=URL] [--report=r.md] [--today=YYYY-MM-DD]

# Install as the `tangokalender` app (Pkg apps, Julia ≥ 1.12). Apps.add(path=) needs a git repo; use develop locally
julia -e 'using Pkg; Pkg.Apps.develop(path=".")'
```

`bin/build_site.jl`, `bin/validate_events.jl` and `bin/migrate_v1.jl` are thin wrappers around `TangoKalender.main`.

`test/runtests.jl` holds plain `@testset`s; it does not use TestItems. `test/fixtures/media/` is a small valid tree that exercises flyer, video and music style. The `julia` MCP server is set up in `/workspace/.mcp.json`. Prefer a persistent session (`julia_create_session` + `julia_eval_code`, with Revise) over repeated `julia` invocations, which recompile every time. `/workspace/dev-oslotango/` is a dev environment that `[sources]`-links this package by path.

## Architecture

- `src/TangoKalender.jl`: the module. It `include`s the files below and exports the public API.
- `src/models.jl`: events are plain dicts (`JSON.Object` when parsed, which keeps key order). There are no structs. `load_events(path)` reads a directory tree via `load_event_tree` or a single v1-style array file. `event_path` gives each event's canonical file location (and throws if there is no `start`), and `save_event_tree` writes to it. `upgrade_event`/`upgrade_events` convert v1 to v2. `expand_weekly` turns a weekly template (`weekday`/`start_time`/`end_time`) into dated events with ids `<series>-YYYY-MM-DD`, and uses `oslo_offset` for the summer/winter time offset (no TimeZones dependency). It is the intended core for a future form or spreadsheet generator.
- `src/cli.jl`: `function (@main)(args)` defines `TangoKalender.main`, which returns an exit code (0 ok, 1 validation failed, 2 usage error). It is reached through `julia -m TangoKalender` and the `[apps] tangokalender` entry in `Project.toml`. `main` is deliberately not exported: `using TangoKalender` from a script would otherwise bring `main` into `Main`, and `@main` would run it when the script finishes.
- `src/issue.jl`: `parse_issue_form` splits a GitHub issue-form body into `### Heading => value`, and `events_from_form` turns that into dated events. Weekly submissions go through `expand_weekly`. It returns `(events, errors)`, with errors in Norwegian that name the form fields. The headings are the `label:`s in `.github/ISSUE_TEMPLATE/nytt-arrangement.yml` and are listed in `FORM_FIELDS`. A test checks that they stay in sync, so rename both together. The type and music options must match the `_TYPES`/`_MUSIC` labels.
- `src/correction.jl`: the «Rett opp» flow.
  - `correction_fields(e)` gives the event's values in form syntax, keyed by the field `id`s in `.github/ISSUE_TEMPLATE/rett-arrangement.yml`. It's used to detect and display changes.
  - `correction_url(e)` prefills **only** `arrangement_id` and the read-only `navaerende` box (`current_summary`). It drops the description if the URL would exceed `MAX_URL`. GitHub resets URL-prefilled fields when the user edits them, so editable fields must never be prefilled.
  - `apply_correction(form, root)` finds the event by «Arrangement-ID», works out which fields changed, and applies them to this date or, with `SERIES_SCOPE`, to all later dates in its `series`. A **blank field means unchanged and `-` clears**, so a lost prefill can never wipe data. Times are recomputed per date, so the clock change stays correct. A date change keeps the `id` and moves the file.
  - `from-issue` treats any form that has «Arrangement-ID» as a correction. It rolls back if validating the tree fails.
  - Avoid GitHub's own query parameters (`title`, `labels`, `type`, …) as field ids; that's why the ID field is `arrangement_id`.
- `src/submission.jl`: JSON submissions, e.g. extracted by an LLM, through `.github/ISSUE_TEMPLATE/nytt-arrangement-json.yml`.
  - `submission_schema()` is **derived** from the stored schema at build time: the `BOT_FIELDS` are removed, `video_url` replaces `video`, and `start`/`end` are relaxed to Oslo local time. It's published at `SUBMISSION_SCHEMA_URL`. Don't hand-edit a copy of it.
  - `events_from_json` strips code fences and prose, drops any bot fields the LLM included, and validates each item for precise Norwegian error paths (`«[1].venue.name»`).
  - It **ignores any submitted offset and recomputes it** with `_stamp`/`_end_stamp`, because all times are Oslo local time. Then it sets `id`/`series`/metadata and runs `validate_event`.
  - `from-issue` routes a form that has a «JSON» heading here.
- `src/llms.jl`: `llm_rules()` is written once and used both in `llms_txt()` (English, for models) and in the copy-ready prompt on `for_ki_html()` (Norwegian page). `EXAMPLE_INPUT`/`EXAMPLE_OUTPUT` are the published worked example, and the tests check that the example converts cleanly. `write_site` writes everything for Pages. The type and music lists come from `_TYPES`/`_MUSIC`, with English help text in `TYPE_HELP`/`MUSIC_HELP`, so add new enum values there too.
- `src/validate.jl`: `validate_event` checks one event against `schema/tango-event.schema.json` with JSONSchema.jl. `validate_event_tree` also flags duplicate ids and files not at their `event_path`.
- `src/render/html.jl`: the calendar views. `render_events_html(events; view="cards"|"compact"|"week", site=false)`: `site=true` (used by `write_site`) adds the view tabs, links to event pages, and the feed links and canonical URL. The views share `_CSS`, `_filterbar` and one raw-string script `_JS`.
  - The script filters every `.ev` row and hides `.group` day sections without visible rows; with `data-keep` (week view) it marks them `noev` instead.
  - **The filter state is in the URL**: `?q=…&type=a,b&music=…&when=…&sort=…`. Defaults are omitted and unknown values ignored. `readURL()` runs on load, `writeURL()` after every change (`history.replaceState`, which keeps the `#uke-…` hash), and the view tabs get the same query string. Type and music are checkbox pills (`input[name=type|music]`). Several ticked means any of them; none ticked means all. Search words must all match.
  - `.hidden` uses `display:none!important`: the row and cell rules (`.row`/`.cell` display) otherwise beat it, which once made filtering look broken while the counter still changed.
  - Tests: `test/js/filters.js` (Node, class names only) and the `filters in a real browser` testset. The latter loads pages in headless Chrome (`--dump-dom`) with an injected probe that records `getClientRects()` visibility. It finds Chrome through `TANGO_CHROME` or `google-chrome`/`chromium` on PATH (GitHub runners have Chrome) and skips otherwise. In the week view it shows one `.week` at a time: today's ISO week, ‹ › (disabled at the ends), «I dag», the ←/→ keys (ignored while typing in a field) and `#uke-YYYY-WW`. It also marks today's `.col` and sets the `#weeklabel` text.
  - Week view layout: each `.week` is a `.weekgrid` of 7 `.col` day columns (Monday first, weekends `.weekend`) holding `_cell` blocks, colour-coded by type (`t-<type>`). On screens under 760px the grid scrolls sideways with snap points. The headings and week nav depend on the `js` class on `<html>`, so without JS every week is shown with its heading.
  - List and week rows come from `_row`. Multi-day events appear on each day (`_days`) with «dag k av n».
  - `SITE_NAME` («Tangokalender | Oslo», in `labels.jl`) is the site name everywhere.
  - Icons: small stroke icons in `_ICON_PATHS` (24×24, `currentColor`), placed once per page as a hidden sprite (`_SPRITE`, inserted right after `<body>`) and referenced with `_icon(name, label)` → `<use href="#i-name">`. They're decorative (`aria-hidden`); `label` adds visually hidden text (`.sr`) for screen readers. Add new icons to `_ICON_PATHS`; the `icons` test checks that every `<use>` has a matching symbol.
- `src/render/event.jl`: `render_event_page` writes `arrangement/<id>/index.html` with relative links (`../../`). It includes schema.org JSON-LD (escaped `\u003c` for script context), OpenGraph tags and the other upcoming dates in the series. Pages are made for **all** events with an id and start, including past ones.
- `src/ics.jl`: `calendar_ics`/`event_ics` write RFC 5545. Times are in **UTC**, converted from the stored offset, so there's no VTIMEZONE. Date-only events use `VALUE=DATE` with an exclusive DTEND. Lines are CRLF, folded at 75 octets without splitting UTF-8. `kalender.ics` covers events from 30 days back onward.
- `src/rss.jl`: `rss_xml` lists upcoming events, newest `first_seen` first, capped at `RSS_MAX`. It escapes with `_xml`.
  - Julia string interpolation builds the markup directly; there is no templating library.
  - Private helpers (prefixed `_`): `_esc` (HTML escaping; every interpolated field must go through it), `_val` (a `get` that also maps JSON `null`/`nothing` to the default), `_date_label`, `_price`, `_card`.
  - `_date_label` shows the start and, when there is an `end`, the closing time (`21:00–01:30`). An end at or before 06:00 the next day still counts as the same evening, and a later end date shows as a range (`– søndag 11. okt`).
  - `SUBMIT_URL` (the new-event form) is linked from the hero and the footer, and each card's footer has «Rett opp» → `correction_url`. Both derive from `REPO_URL`. Override them with `submit_url=`/`correct_url=` or `build --submit-url=`/`--correct-url=` (empty hides the link).
  - `render_events_html` returns the whole document as one triple-quoted string. The CSS and the client-side filter JS are inlined in it.

### Event data contract

`schema/tango-event.schema.json` (draft-07, `additionalProperties: false`) is the source of truth for the v2 format. When you add a field, update the schema, `upgrade_event` and the renderer together. Files live at `events/YYYY/MM-englishmonth/YYYY-MM-DD-<id>.json`. **Every v2 event is dated** (`start` is required). Repeating events (weekly milongas, courses) are one file per date sharing a `series` id, because weekly events get cancelled and their details (DJ, price) vary from date to date. Cancelled dates use `status: "cancelled"` rather than being deleted. The weekly-only keys `recurrence`/`weekday`/`start_time`/`end_time` are v1-only and rejected by the schema. v2 adds `venue: {name, address, city}`, `music_style`, `flyer_url`, `video: {platform, id}` and `link` (the official page; `source`/`source_url` are crawl provenance). `examples/*.json` are v1 flat arrays (string `venue` plus top-level `address`/`city`). The renderer still accepts them, but they fail schema validation.

- `start` is either an ISO datetime with an offset (`2026-10-01T19:00:00+02:00`) or a bare date (`2026-10-02`). `_date_label` tries the datetime form first and falls back to the date form. The schema requires seconds in datetimes because `_date_label` parses `HH:MM:SS`.
- v1 recurring activities have no `start` and get the sentinel `data-date="9999-12-31"`, which sorts them last. The JS **"Faste aktiviteter"** filter matches cards with a non-empty `data-series` *or* that sentinel, so `_sortkey`, `_card` and the JS must stay in sync.
- Cancelled events render with class `cancelled` and an "Avlyst" chip, and stay visible on the page.
- `data-type`, `data-date`, `data-end`, `data-series`, `data-search` and `data-music` attributes on each `<article class="event">` are the interface between the Julia output and the inline JS. `data-end` comes from `_end_day`: the last day the event runs, using the same «ends by 06:00 = previous evening» rule as `_date_label`.
- The time filter defaults to **Kommende**: events whose end day is today or later, so ongoing festivals still show. Past events are hidden in the browser, not removed at build time, so the page stays correct between nightly builds. «Alle (også tidligere)» shows everything.
- `test/js/filters.js` runs the page's real inline script in Node against a fixed date with a minimal DOM stand-in. The `upcoming filter` testset uses it when `node` is on the PATH (it is on GitHub runners) and skips otherwise.

### Gotchas

- The JS lives inside a Julia `"""` string, so a JS template literal `${...}` must be written `\${...}`. Otherwise Julia tries to interpolate it.
- The test asserts that the `html.jl` **source text** contains the literal `$(st)–$(en)` (with an en dash). Don't rewrite that expression in `_date_label`. The test also asserts that the rendered output never contains the string `nothing`, so route optional fields through `_val`/`_esc`.
- `public/index.html` is generated output.
- JSONSchema.jl reports only the first issue per event. `_issue_message` in `src/validate.jl` turns it into a short message, and lists the key names for unknown-key errors.
- Video ids are re-checked with regexes in `_video` and URLs must be `http(s)` (`_http`) before they are embedded, independently of the schema. Keep both checks.

## GitHub workflows (`.github/workflows/`)

The repo is `github.com/Tangokalender/TangoKalender.jl`, and the site is published at https://tangokalender.github.io/TangoKalender.jl/ (Pages hostnames are lowercase).


- `ci.yml`: tests on the latest Julia release (`'1'`; the compat floor is 1.12, which Pkg apps need), plus `validate events`, on PRs and on `main`.
- `pages.yml`: runs `site events _site`, which writes `index.html` (the compact list), `uke.html`, `kort.html`, `arrangement/<id>/` plus `.ics`, `kalender.ics`, `rss.xml`, `for-ki.html`, `llms.txt` and both schemas under `schema/`, served at their `$id`s, e.g. `https://tangokalender.github.io/TangoKalender.jl/schema/tango-event.schema.json`. It deploys to GitHub Pages on `main` changes and nightly. `public/` and `_site/` are gitignored.
- `intake.yml`: issue opened or edited with the label `nytt-arrangement` or `rettelse` → `from-issue` → `peter-evans/create-pull-request` on branch `arrangement/issue-<n>`, then a comment on the issue with the report. `from-issue --outputs=$GITHUB_OUTPUT` emits a one-line `pr_title` and `issue_title`, which name the PR and rename the issue. `add-paths: events` must stay a directory, so that moved files are committed as deletions too. Failures get the `trenger-retting` label.
  - **Security:** the issue body and title are untrusted. Only pass them through `env:` or action inputs, never with `${{ }}` inside `run:`.
  - Bot PRs made with `GITHUB_TOKEN` don't trigger `ci.yml`. That's why `from-issue` validates the whole tree itself.
  - Lint with `actionlint` (and `shellcheck`) after editing workflows.
- Tests that depend on today's date must pin it: `events_from_form(...; today=)` or `from-issue --today=`. The fixtures in `test/fixtures/issues/` have fixed 2026 dates.

## Related design notes

`/workspace/design_notes.md` describes a planned "v2.0" pipeline: GitHub Issue Form → Action writes one JSON file per event under `events/` → a Julia build → GitHub Pages. The file layout, the extra fields, the issue form and the workflows have been adopted (the intake opens a PR instead of committing directly, and the Julia parser replaces the design doc's injection-prone github-script). Its Mustache/JSON3 build script has not. Its `start_date`/`notes`/`platform_youtube` shapes were deliberately mapped to `start`/`description`/`video.platform`.
