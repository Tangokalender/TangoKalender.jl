# TODO

## ActivityPub (fediverse)

Goal: tango events visible/followable from Mastodon, Mobilizon etc.

GitHub Pages limits what we can do: it serves `.json` as `application/json` (not
`application/activity+json`), cannot answer POSTs (no inbox, no HTTP signatures), and a project site
(`/TangoKalender.jl/`) cannot serve the domain-root `/.well-known/webfinger`.

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
