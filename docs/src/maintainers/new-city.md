# Start a new city

A city is a GitHub repository with its events, its settings and three short workflows that call this package.
`tangokalender init-site` writes all of it.

## 1. Create the data repository

Install the `tangokalender` app (Julia ≥ 1.12; `~/.julia/bin` must be on your `PATH`), then scaffold the repository:

```bash
julia -e 'using Pkg; Pkg.Apps.add(url="git@github.com:Tangokalender/TangoKalender.jl.git")'
tangokalender init-site bergen --slug=bergen --city=Bergen \
  --site-url=https://tango.bergen.no --repo-url=https://github.com/Tangokalender/bergen
```

| File | What it is |
|:-----|:-----------|
| `site.toml` | The site's name, city, addresses and map (see [`site.toml`](@ref site-config)). |
| `events/`, `venues.json` | Empty: one JSON file per event, and the geocoding cache. |
| `Project.toml` | Pins this package to the current release (`[sources]`, over SSH). |
| `.github/workflows/` | `validate.yml`, `pages.yml`, `intake.yml`: each calls a reusable workflow here. |
| `.github/ISSUE_TEMPLATE/` | The submission and correction forms, filled in with the site's address and city. |
| `.github/dependabot.yml` | Weekly updates of the workflow versions. |
| `assets/og-image.png` | Link-preview image (a placeholder; see below). |
| `README.md` | These steps, for the people running the repository. |

Then install the pinned package once and commit everything, including `Manifest.toml`:

```bash
cd bergen
julia --project=. -e 'using Pkg; Pkg.instantiate()'
git init && git add -A && git commit -m "Tangokalender Bergen"
git remote add origin git@github.com:Tangokalender/bergen.git && git push -u origin main
```

## 2. One-time GitHub settings

1. **Settings → Pages → Source: GitHub Actions.** A repository that isn't `<owner>.github.io` is served at
   `https://<owner>.github.io/<repo>/`; `site_url` in `site.toml` must match, or set a custom domain (below).
   If the owner's `<owner>.github.io` site has a custom domain, the repository is served under *that* domain
   instead: in the Tangokalender organisation, whose root site is Oslo's `tango.oslo.no`, a `bergen` repository
   would appear at `https://tango.oslo.no/bergen/`. Give a new city in this organisation its own domain.
2. **Settings → Actions → General → Workflow permissions: Read and write**, and tick
   **Allow GitHub Actions to create and approve pull requests**. The intake bot opens pull requests.
3. **Labels:** create `nytt-arrangement`, `rettelse` and `trenger-retting` (Issues → Labels).
4. **Branch protection** on `main`: require the **Validate** check. Give editors the *Write* role.

Push a commit or run the *Pages* workflow by hand; the site appears at `site_url`.

## 3. Make it yours

- Set `[map] center` in `site.toml` to the city centre (`[lat, lon]`), so the map view opens in the right place.
- Draw the link-preview image with the city name: `julia <path to TangoKalender>/bin/make_og_image.jl` in the data
  repository writes `assets/og-image.png` (it reads `site.toml`).
- Texts that mention the city use it automatically. To change a text, override it under `[texts]` (see
  [`site.toml`](@ref site-config)).

## Custom domain

Oslo moved from `tangokalender.github.io` to `tango.oslo.no` this way. Pick the address before announcing the site
if you can.

1. **DNS** at the registrar. For the domain itself (an apex such as `tango.oslo.no`): `A` records
   `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153` and `AAAA` records
   `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`; for `www`, a `CNAME`
   to `<owner>.github.io.`. For a subdomain (`tango.example.no` in a zone you run), a `CNAME` to
   `<owner>.github.io.` is enough. A `CAA` record, if any, must allow `letsencrypt.org`.
2. **Verify the domain** for the owner: organisation (or user) Settings → Pages → *Add a domain*, add the `TXT`
   record GitHub shows (`_github-pages-challenge-<owner>.<domain>`), then *Verify*. Nobody else can then claim the
   domain on GitHub.
3. **Repository Settings → Pages → Custom domain**: enter the domain and save. GitHub checks the DNS and gets a
   Let's Encrypt certificate (minutes, at most about a day). Then tick **Enforce HTTPS**. With Actions-based Pages
   the setting lives here; a `CNAME` file in the repository is not needed.
4. **Only when `https://<domain>/` works**: in the data repository set `site_url` in `site.toml`, redraw the
   link-preview image (`bin/make_og_image.jl`, it prints the address), rerun `tangokalender templates` (the issue
   forms link to the site) and update the README; push, and the site is rebuilt with the new address.

Afterwards GitHub redirects every `https://<owner>.github.io/…` address to the domain, including the owner's other
Pages sites (for Tangokalender, this package's documentation moved to `https://tango.oslo.no/TangoKalender.jl/`).
Most calendar apps follow the redirect for `kalender.ics`, and so do most feed readers, but give out the new
addresses from then on. The calendar's event ids contain the host (`…@tango.oslo.no`), so subscribed calendars
replace the events once on their next refresh.
