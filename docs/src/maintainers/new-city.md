# Start a new city

A city is a GitHub repository with its events, its settings and three short workflows that call this package.
`tangokalender init-site` writes all of it.

## 1. Create the data repository

Install the `tangokalender` app (Julia ≥ 1.12; `~/.julia/bin` must be on your `PATH`), then scaffold the repository:

```bash
julia -e 'using Pkg; Pkg.Apps.add(url="git@github.com:Tangokalender/TangoKalender.jl.git")'
tangokalender init-site bergen --slug=bergen --city=Bergen \
  --site-url=https://tangokalender.github.io/bergen --repo-url=https://github.com/Tangokalender/bergen
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

Add the domain under Settings → Pages, set `site_url` to it and rebuild. Calendar subscriptions (`kalender.ics`)
and RSS readers use the old address until people subscribe again, so pick the address before announcing the site.
