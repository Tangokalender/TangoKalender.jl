# Files a city's data repo gets from the package: the GitHub issue forms (rendered from templates/ISSUE_TEMPLATE with
# the site's URL and city). The forms' labels are the parser's keys (FORM_FIELDS, CORRECTION_FIELDS, …), so they are
# kept here with the code and copied into each data repo by `tangokalender templates`.
const TEMPLATE_DIR=joinpath(@__DIR__,"..","templates")
"Fill a template's `{{site_url}}` and `{{city}}` from the current site."
render_template(text::AbstractString)=replace(text,"{{site_url}}"=>site_url(),"{{city}}"=>site_city())
"""
    write_templates(dir=".") -> files

Write the issue forms for the current site into `dir/.github/ISSUE_TEMPLATE/` (overwriting the package's forms,
leaving other files there alone).
"""
function write_templates(dir::AbstractString=".")
 src=joinpath(TEMPLATE_DIR,"ISSUE_TEMPLATE"); out=joinpath(dir,".github","ISSUE_TEMPLATE"); mkpath(out)
 [(f=joinpath(out,n); write(f,render_template(read(joinpath(src,n),String))); f) for n in sort(readdir(src)) if endswith(n,".yml")]
end
"The code repo (the package, the reusable workflows and the issue-form templates)."
const CODE_REPO_URL="https://github.com/Tangokalender/TangoKalender.jl"
const PACKAGE_UUID="8fa2004d-d644-4dc6-9815-18e81ae74980"
_toml_str(s)=sprint(TOML.print,Dict("x"=>s))[5:end-1]   # a TOML string literal, quoted and escaped
"""
    init_site(dir; slug, city, site_url, repo_url, name="Tangokalender | <city>", version=package version) -> files

Start a new city's data repo in `dir`: `site.toml`, an empty `events/` and `venues.json`, a `Project.toml` that pins
TangoKalender `version` from `CODE_REPO_URL`, workflows that call the package's reusable ones, Dependabot, the issue
forms, a placeholder link-preview image, `.gitignore` and a README with the one-time GitHub setup.
Refuses to overwrite an existing `site.toml`.
"""
function init_site(dir::AbstractString; slug::AbstractString, city::AbstractString, site_url::AbstractString, repo_url::AbstractString,
                   name::AbstractString="Tangokalender | $city", version::AbstractString=string(pkgversion(@__MODULE__)))
 isfile(joinpath(dir,SITE_FILE)) && throw(ArgumentError("$(joinpath(dir,SITE_FILE)) already exists"))
 ref="v$version"; files=String[]
 w(rel,text)=(f=joinpath(dir,rel); mkpath(dirname(f)); write(f,text); push!(files,f))
 w(SITE_FILE,"""
 # $(name): settings for this city's calendar site. See $(CODE_REPO_URL)/blob/main/schema/site.schema.json
 slug = $(_toml_str(slug))
 name = $(_toml_str(name))
 city = $(_toml_str(city))
 site_url = $(_toml_str(rstrip(site_url,'/')))
 repo_url = $(_toml_str(rstrip(repo_url,'/')))
 og_image = "assets/og-image.png"   # redraw for this city: julia <TangoKalender>/bin/make_og_image.jl

 [map]   # shown when no event has a map position
 center = [59.9139, 10.7522]   # TODO: the city centre (lat, lon)
 zoom = 12

 [geocode]
 countrycodes = "no"
 """)
 site=try load_site(joinpath(dir,SITE_FILE)) catch   # checks what was written; leave nothing half-made
  rm(joinpath(dir,SITE_FILE)); rethrow()
 end
 mkpath(joinpath(dir,"events")); w(joinpath("events",".gitkeep"),"")
 w(VENUES_FILE,"[]\n")
 w("Project.toml","""
 # The calendar code, pinned to a release. Upgrade by changing `rev`, then run
 #   julia --project=. -e 'using Pkg; Pkg.update()'   and commit Manifest.toml.
 [deps]
 TangoKalender = "$PACKAGE_UUID"

 [sources]
 TangoKalender = {url = "$CODE_REPO_URL", rev = "$ref"}
 """)
 wf(file,body)=w(joinpath(".github","workflows",file),body)
 wf("validate.yml","""
 name: Validate
 on:
   pull_request:
   push:
     branches: [main]
 permissions:
   contents: read
 jobs:
   validate:
     uses: Tangokalender/TangoKalender.jl/.github/workflows/site-validate.yml@$ref
 """)
 wf("pages.yml","""
 name: Pages
 on:
   push:
     branches: [main]
   workflow_dispatch:
   schedule:   # just after midnight Norwegian time (summer and winter), so «today» and past events stay right
     - cron: '17 22 * * *'
     - cron: '17 23 * * *'
 permissions:
   contents: read
   pages: write
   id-token: write
 concurrency:
   group: pages
   cancel-in-progress: false
 jobs:
   pages:
     uses: Tangokalender/TangoKalender.jl/.github/workflows/site-pages.yml@$ref
 """)
 wf("intake.yml","""
 # Issue forms → event files → pull request for review.
 name: Intake
 on:
   issues:
     types: [opened, edited]
 permissions:
   contents: write
   pull-requests: write
   issues: write
 concurrency:
   group: intake-\${{ github.event.issue.number }}
   cancel-in-progress: true
 jobs:
   intake:
     uses: Tangokalender/TangoKalender.jl/.github/workflows/site-intake.yml@$ref
 """)
 w(joinpath(".github","dependabot.yml"),"""
 version: 2
 updates:
   - package-ecosystem: github-actions   # also bumps the TangoKalender workflow refs
     directory: /
     schedule:
       interval: weekly
 """)
 append!(files,_with_site(()->write_templates(dir),site))
 w(joinpath("assets","og-image.png"),read(OG_IMAGE_FILE))
 w(".gitignore","_site/\npublic/\n")
 w("README.md","""
 # $(name)

 Event data for $(site.site_url)/: one JSON file per event under `events/`, map positions in `venues.json`, site
 settings in `site.toml`. The site is built by [TangoKalender]($CODE_REPO_URL) ($ref, see `Project.toml`).

 ## Adding and fixing events
 - Through the issue forms: [new event]($(site.repo_url)/issues/new?template=nytt-arrangement.yml) or «Rett opp» on an event.
   A bot turns the form into a pull request; an editor reviews and merges it.
 - By hand: `julia --project=. -m TangoKalender edit TERM… [KEY=VALUE…]` (see `--help`), then
   `julia --project=. -m TangoKalender validate events` and open a pull request.

 ## One-time GitHub setup
 1. Settings → Pages → Source: **GitHub Actions**. A repo that is not `<owner>.github.io` is served under
    `https://<owner>.github.io/<repo>/`; `site_url` in `site.toml` must match (or set a custom domain).
 2. Settings → Actions → General → Workflow permissions: **Read and write**, and **Allow GitHub Actions to create and
    approve pull requests** (the intake bot opens PRs).
 3. Labels: `nytt-arrangement`, `rettelse` and `trenger-retting`.
 4. Branch protection on `main`: require the **Validate** check; give editors the Write role.
 5. `julia --project=. -e 'using Pkg; Pkg.instantiate()'` and commit `Manifest.toml`.
 6. Set `[map] center` in `site.toml`, and redraw `assets/og-image.png` with the package's `bin/make_og_image.jl`.
 7. After changing the package version, rerun `julia --project=. -m TangoKalender templates` to update the issue forms.
 """)
 files
end
