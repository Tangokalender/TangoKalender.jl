# TangoKalender.jl

TangoKalender builds tango calendars: static, searchable websites listing the milongas, practicas, classes and
festivals of one city, in Norwegian, English and Spanish. Each city keeps its events in its own **data repository**;
this package turns them into the site and handles submissions, corrections and bulk edits.

| City | Site | Data repository |
|:-----|:-----|:----------------|
| Oslo | <https://tangokalender.github.io/> | [Tangokalender/tangokalender.github.io](https://github.com/Tangokalender/tangokalender.github.io) |

## How the pieces fit

```
data repo (one per city)                     code repo (this package)
  site.toml, events/, venues.json   ──uses──▶  reusable workflows: site-validate, site-pages, site-intake
  .github/ISSUE_TEMPLATE (forms)               TangoKalender (pinned in the data repo's Project.toml)
  .github/workflows (3 short files)             issue-form templates, schemas, tangoedit binaries
          │
          ├─ issue form ──▶ intake bot ──▶ pull request ──▶ editor merges
          └─ main ──▶ Pages build (also nightly) ──▶ https://<city site>/
```

Editors only need write access to their city's data repository. The code is changed here and a city picks up a new
version by moving the pin in its `Project.toml` (see [Workflows and upgrades](@ref)).

## Start here

- **Starting or running a city:** [Start a new city](@ref), [`site.toml`](@ref site-config), [Workflows and upgrades](@ref).
- **Editing events:** [Events](@ref events) (the file format), [Submissions and review](@ref), [Bulk edits with tangoedit](@ref),
  [Venues and maps](@ref).
- **Working on the code:** [Architecture](@ref), [Command line](@ref), [API reference](@ref),
  [Development and releases](@ref).
