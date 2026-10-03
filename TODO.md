# TODO

## ActivityPub (fediverse)

Goal: tango events visible/followable from Mastodon, Mobilizon etc.

GitHub Pages limits what we can do: it serves `.json` as `application/json` (not
`application/activity+json`) and cannot answer POSTs (no inbox, no HTTP signatures). Since the site is now the
organisation's root site, a static `/.well-known/webfinger` file is possible, but it can't answer per-account queries.

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

## Custom domain

Goal: a short address (e.g. `tangokalender.no`) instead of `tangokalender.github.io`.

1. Register or choose the domain.
2. DNS: `CNAME www → tangokalender.github.io`, and for the apex the GitHub Pages `A`/`AAAA` records
   (see GitHub's docs on custom domains for Pages).
3. Repo → Settings → Pages → *Custom domain*, then *Enforce HTTPS* once the certificate is issued.
4. Code: set `SITE_URL` in `src/render/html.jl` and the `$id` in `schema/tango-event.schema.json`; the drift test
   in `test/runtests.jl` lists anything else still pointing at the old address. Optionally let `write_site` emit a
   `CNAME` file (Actions-based Pages takes the domain from the settings, the file only documents it).
5. GitHub redirects `tangokalender.github.io` to the custom domain for HTML pages, but calendar apps and
   feed readers subscribed to `kalender.ics`/`rss.xml` may need to re-subscribe; announce the new address.
