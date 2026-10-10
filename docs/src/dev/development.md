# Development and releases

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

## Tests

- The tests run as a **test site**: `test/fixtures/site/` holds a `site.toml` and a frozen copy of the Oslo data, so
  they don't change when the real calendar does. `test/runtests.jl` sets that site; other sites in the tests (e.g.
  Bergen under a path) set their own.
- Tests that depend on today's date pin it (`today=`, `--today=`).
- The JavaScript tests run in Node and a real browser test runs in headless Chrome; both are skipped when the tool is
  missing (GitHub's runners have them).
- The «site URL drift» test fails on any site URL written into `src/` or `templates/`.

## Precompile workload

`src/precompile.jl` runs the CLI commands on a temporary tree during precompilation, so a CLI run takes about 2 s
instead of about 30 s. Add new commands or slow first-use paths there.

## The stand-alone tangoedit

`bin/build_tangoedit.sh` compiles `app/tangoedit.jl` with JuliaC (`--trim=safe`) into `build/tangoedit/`.
`.github/workflows/tangoedit.yml` builds it on Linux, Windows and macOS monthly and on every release tag, and
attaches the archives to the GitHub release.

## Documentation

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl          # → docs/build/index.html
```

Tables (event fields, `site.toml` keys) and the command reference are generated from the schemas and the usage
texts. `.github/workflows/docs.yml` builds the docs on pull requests and publishes them from `main` (`dev`) and
release tags (`stable`).

## Releases

1. Bump `version` in `Project.toml`, commit, tag `vX.Y.Z`, push both.
2. The tag builds the `tangoedit` binaries and the `stable` docs.
3. Each city moves its pin (see [Workflows and upgrades](@ref)); the page footer shows the version.

Lint workflows with `actionlint` after editing them.
