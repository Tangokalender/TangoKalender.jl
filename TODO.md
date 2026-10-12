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

## Spanish event text (undecided)

The site is in Norwegian, English and Spanish (see `src/i18n.jl`), but event titles and descriptions can only be
entered in Norwegian or English. Spanish pages show English text when there is any, otherwise the original.
The schema already accepts `translations.es`; offering it means a «Español» option in «Tekstspråk» (`_parse_lang`,
the issue forms) and «andre språk» fields that can hold more than one language. Also worth considering: a native
speaker proofreading the Spanish (rioplatense) interface text.
