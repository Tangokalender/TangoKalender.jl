# Workflows and upgrades

A data repository has three short workflows. Each calls a **reusable workflow** in this repository at the release
it is pinned to, and runs the TangoKalender version that `Project.toml` pins:

| Data repo workflow | Calls | When | What it does |
|:--|:--|:--|:--|
| `validate.yml` | `site-validate.yml` | pull requests, pushes to `main` | `tangokalender validate events`: schema, unique ids, file locations; warns (without failing) about two events of one series with the same start. |
| `pages.yml` | `site-pages.yml` | pushes to `main`, nightly, by hand | Builds the site and deploys it to GitHub Pages. |
| `intake.yml` | `site-intake.yml` | an issue with label `nytt-arrangement` or `rettelse` is opened or edited | Turns the form into event files and opens a pull request (see [Submissions and review](@ref)). |

The nightly build runs just after midnight Norwegian time, so «today», past events and the embedded images stay right.

## How the package is fetched

`Project.toml` names the package by its SSH address:

```toml
[sources]
TangoKalender = {rev = "v1.1.0", url = "git@github.com:Tangokalender/TangoKalender.jl.git"}
```

Locally that uses your SSH key like any other git command. GitHub's runners have no key, so the reusable workflows
rewrite `git@github.com:` to `https://github.com/` before installing (the code repository is public).

## Upgrading to a new release

`Pkg.update()` does **not** move a pinned version. Use `Pkg.add` with the new tag, here `v1.2.0`:

```bash
julia --project=. -e 'using Pkg; Pkg.add(url="git@github.com:Tangokalender/TangoKalender.jl.git", rev="v1.2.0")'
julia --project=. -m TangoKalender templates      # refresh the issue forms, in case they changed
```

Then set `@v1.2.0` in the three workflow files (Dependabot opens a pull request for those), and commit
`Project.toml`, `Manifest.toml`, the workflows and any changes under `.github/ISSUE_TEMPLATE`. The footer of every
page says which version built it («Bygget med TangoKalender v1.2.0»).

## The issue forms

The forms in `.github/ISSUE_TEMPLATE` are generated from the templates in this package, because their field labels
are what the intake parser reads. Never edit them by hand: change the templates here, release, and run
`tangokalender templates` in the data repository.

## When something fails

- **Pages or Validate fails right away, without jobs:** GitHub couldn't load the reusable workflow. Check that the
  `@vX.Y.Z` tag exists in this repository and that the repository is public.
- **«Instantiate» fails:** the pinned tag doesn't exist, or `Manifest.toml` wasn't updated after changing the pin.
- **The intake run failed on an issue:** edit the issue (any change) to start a fresh run; re-running the old run
  reuses the old commit.
- **Two submissions for the same event close together:** when the first one's pull request is merged while the
  second is still running, the intake reads the second form again on the new `main` and carries on. If the form
  no longer applies (the first one already made the same change), or the pull request can't be opened for
  another reason, the issue gets a ⚠️ comment and the `trenger-retting` label instead of «✅ Takk».