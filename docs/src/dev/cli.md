# Command line

`julia --project=. -m TangoKalender …` in a data repository, or the installed app `tangokalender …`. Paths are
relative to the current directory; `site.toml` there gives the site (or `--site=FILE`). Exit codes: 0 ok,
1 validation failed, 2 usage error.

```@example
using TangoKalender
print(TangoKalender.USAGE)
```

## `edit`

```@example
using TangoKalender
print(TangoKalender.EDIT_USAGE)
```

The stand-alone `tangoedit` is the same command; see [Bulk edits with tangoedit](@ref).
