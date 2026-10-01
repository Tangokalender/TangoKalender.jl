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
- `src/validate.jl`: `validate_event` checks one event against `schema/tango-event.schema.json` with JSONSchema.jl. `validate_event_tree` also flags duplicate ids and files not at their `event_path`.
- `src/render/html.jl`: all of the rendering. Julia string interpolation builds the markup directly; there is no templating library.
  - Private helpers (prefixed `_`): `_esc` (HTML escaping; every interpolated field must go through it), `_val` (a `get` that also maps JSON `null`/`nothing` to the default), `_date_label`, `_price`, `_card`.
  - `render_events_html` returns the whole document as one triple-quoted string. The CSS and the client-side filter JS are inlined in it.

### Event data contract

`schema/tango-event.schema.json` (draft-07, `additionalProperties: false`) is the source of truth for the v2 format. When you add a field, update the schema, `upgrade_event` and the renderer together. Files live at `events/YYYY/MM-englishmonth/YYYY-MM-DD-<id>.json`. **Every v2 event is dated** (`start` is required). Repeating events (weekly milongas, courses) are one file per date sharing a `series` id, because weekly events get cancelled and their details (DJ, price) vary from date to date. Cancelled dates use `status: "cancelled"` rather than being deleted. The weekly-only keys `recurrence`/`weekday`/`start_time`/`end_time` are v1-only and rejected by the schema. v2 adds `venue: {name, address, city}`, `music_style`, `flyer_url`, `video: {platform, id}` and `link` (the official page; `source`/`source_url` are crawl provenance). `examples/*.json` are v1 flat arrays (string `venue` plus top-level `address`/`city`). The renderer still accepts them, but they fail schema validation.

- `start` is either an ISO datetime with an offset (`2026-10-01T19:00:00+02:00`) or a bare date (`2026-10-02`). `_date_label` tries the datetime form first and falls back to the date form. The schema requires seconds in datetimes because `_date_label` parses `HH:MM:SS`.
- v1 recurring activities have no `start` and get the sentinel `data-date="9999-12-31"`, which sorts them last. The JS **"Faste aktiviteter"** filter matches cards with a non-empty `data-series` *or* that sentinel, so `_sortkey`, `_card` and the JS must stay in sync.
- Cancelled events render with class `cancelled` and an "Avlyst" chip, and stay visible on the page.
- `data-type`, `data-date`, `data-series`, `data-search` and `data-music` attributes on each `<article class="event">` are the interface between the Julia output and the inline JS.

### Gotchas

- The JS lives inside a Julia `"""` string, so a JS template literal `${...}` must be written `\${...}`. Otherwise Julia tries to interpolate it.
- The test asserts that the `html.jl` **source text** contains the literal `$(st)–$(en)` (with an en dash). Don't rewrite that expression in `_date_label`. The test also asserts that the rendered output never contains the string `nothing`, so route optional fields through `_val`/`_esc`.
- `public/index.html` is generated output.
- JSONSchema.jl reports only the first issue per event. `_issue_message` in `src/validate.jl` turns it into a short message, and lists the key names for unknown-key errors.
- Video ids are re-checked with regexes in `_video` and URLs must be `http(s)` (`_http`) before they are embedded, independently of the schema. Keep both checks.

## GitHub workflows (`.github/workflows/`)

The repo is `github.com/Tangokalender/TangoKalender.jl`, and the site is published at https://tangokalender.github.io/TangoKalender.jl/ (Pages hostnames are lowercase).


- `ci.yml`: tests on the latest Julia release (`'1'`; the compat floor is 1.12, which Pkg apps need), plus `validate events`, on PRs and on `main`.
- `pages.yml`: builds `_site/index.html` (plus `_site/schema/`, served at the schema's `$id`, `https://tangokalender.github.io/TangoKalender.jl/schema/tango-event.schema.json`) and deploys to GitHub Pages on `main` changes and nightly. `public/` and `_site/` are gitignored.
- `intake.yml`: issue opened or edited with the label `nytt-arrangement` → `from-issue` → `peter-evans/create-pull-request` on branch `arrangement/issue-<n>`, then a comment on the issue with the report. Failures get the `trenger-retting` label.
  - **Security:** the issue body and title are untrusted. Only pass them through `env:` or action inputs, never with `${{ }}` inside `run:`.
  - Bot PRs made with `GITHUB_TOKEN` don't trigger `ci.yml`. That's why `from-issue` validates the whole tree itself.
  - Lint with `actionlint` (and `shellcheck`) after editing workflows.
- Tests that depend on today's date must pin it: `events_from_form(...; today=)` or `from-issue --today=`. The fixtures in `test/fixtures/issues/` have fixed 2026 dates.

## Related design notes

`/workspace/design_notes.md` describes a planned "v2.0" pipeline: GitHub Issue Form → Action writes one JSON file per event under `events/` → a Julia build → GitHub Pages. The file layout, the extra fields, the issue form and the workflows have been adopted (the intake opens a PR instead of committing directly, and the Julia parser replaces the design doc's injection-prone github-script). Its Mustache/JSON3 build script has not. Its `start_date`/`notes`/`platform_youtube` shapes were deliberately mapped to `start`/`description`/`video.platform`.
