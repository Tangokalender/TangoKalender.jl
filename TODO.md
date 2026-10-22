# TODO

## ActivityPub (fediverse)

Goal: tango events visible/followable from Mastodon, Mobilizon etc.

GitHub Pages limits what we can do: it serves `.json` as `application/json` (not
`application/activity+json`) and cannot answer POSTs (no inbox, no HTTP signatures). Since the site is the
organisation's root site (served at `tango.oslo.no`), a static `/.well-known/webfinger` file is possible, but it can't answer per-account queries.

Options, roughly in order of effort:

1. **Static ActivityStreams objects** – publish each event as an AS2 `Event` (plus an `actor` and an
   `outbox` `OrderedCollection`) next to the event page, and link it with
   `<link rel="alternate" type="application/activity+json">`. Machine-readable and importable, but not
   followable or searchable from Mastodon.
2. **Bot account** – a GitHub Action that, after a deploy, posts new or changed events (title, date,
   venue, link to the event page) to a fediverse account via its API. Needs an account and an access
   token secret; easy and gives followers in practice.
3. **Real federation** – a small service (e.g. a Cloudflare Worker) for WebFinger, actor, inbox and
   signed delivery to followers, or run/join a Gancio or Mobilizon instance and import `kalender.ics`.
   More setup and running cost.

## Spanish as the main text language (undecided)

Spanish titles and descriptions can be entered as an alternative text since 1.7.0: «Tittel (spansk)» and
«Beskrivelse (spansk)» in the new-event and correction forms and the spreadsheet, `translations.es` in the JSON
route, and the `es_title`/`es_description` fields in TangoTUI. Spanish pages show them, falling back to English and
then the original. What's left is Spanish as the event's *main* text language: «Tekstspråk» is Norsk/English only
(`lang` is `nb`/`en` in the schema), so an «Español» option would need a schema change, `_parse_lang`, the issue
forms and a check of the text fallbacks on the Norwegian and English pages. Also worth considering: a native speaker
proofreading the Spanish (rioplatense) interface text.

## TangoTUI in English and Spanish

TangoTUI (`TangoTUI/`, experimental) is Norwegian only: the field labels and help in `form_fields()`
(`src/eventform.jl`), and the messages, key hints and dialog texts in `TangoTUI/src/TangoTUI.jl`.
- Move them into `_T` (`src/i18n.jl`) with nb/en/es, like the site's interface text (a test then checks that every
  key has all three languages), and choose the language with `--lang=nb|en|es`, defaulting from the `LANG`
  environment variable.
- `check` messages (`src/eventstruct.jl`) are English; show them in the chosen language too.
- Make the demo per language (`bin/make_tui_demo.jl --lang=`, `tangotui-demo-en.svg` …) and use it on the docs page.
- The docs page (`docs/src/editors/tangotui.md`) quotes Norwegian field names; update it to match.
