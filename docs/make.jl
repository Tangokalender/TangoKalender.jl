# Builds the documentation (https://tangokalender.github.io/TangoKalender.jl/) with Documenter:
#   julia --project=docs -e 'using Pkg; Pkg.instantiate()'
#   julia --project=docs docs/make.jl            # → docs/build/; deploys only on GitHub Actions
using Documenter, TangoKalender
const TK=TangoKalender
# the animated terminal from the «Legg til» page, shown on the bulk-edit page
cp(TK.EDIT_DEMO_FILE,joinpath(@__DIR__,"src","assets","tangoedit-demo.svg");force=true)
DocMeta.setdocmeta!(TangoKalender,:DocTestSetup,:(using TangoKalender);recursive=true)
makedocs(
 sitename="TangoKalender.jl",
 modules=[TangoKalender],
 authors="Lars Hellemo and contributors",
 repo=Remotes.GitHub("Tangokalender","TangoKalender.jl"),
 format=Documenter.HTML(prettyurls=get(ENV,"CI","")=="true",canonical=TK.DOCS_URL,edit_link="main",
  footer="TangoKalender v$(pkgversion(TangoKalender)) · [Oslo](https://tangokalender.github.io/) · [GitHub](https://github.com/Tangokalender/TangoKalender.jl)"),
 checkdocs=:exports,
 doctest=true,
 linkcheck=false,   # GitHub rate-limits link checks from CI
 pages=[
  "Home"=>"index.md",
  "City maintainers"=>["Start a new city"=>"maintainers/new-city.md","site.toml"=>"maintainers/site-config.md",
   "Workflows and upgrades"=>"maintainers/workflows.md"],
  "Editors"=>["Events"=>"editors/events.md","Submissions and review"=>"editors/submissions.md",
   "Bulk edits with tangoedit"=>"editors/bulk-edit.md","Venues and maps"=>"editors/venues.md"],
  "Developers"=>["Architecture"=>"dev/architecture.md","Command line"=>"dev/cli.md","API reference"=>"dev/api.md",
   "Development and releases"=>"dev/development.md"],
 ])
deploydocs(repo="github.com/Tangokalender/TangoKalender.jl.git",devbranch="main",push_preview=false)
