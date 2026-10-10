# [`site.toml`](@id site-config)

Every city's settings live in `site.toml` at the root of its data repository. The commands read it from the current
directory (or `--site=FILE`), and a wrong value stops the build with a message naming the key.

```toml
slug = "oslo"
name = "Tangokalender | Oslo"
city = "Oslo"
site_url = "https://tangokalender.github.io"
repo_url = "https://github.com/Tangokalender/tangokalender.github.io"
og_image = "assets/og-image.png"

[map]
center = [59.9139, 10.7522]
zoom = 12

[geocode]
countrycodes = "no"
```

## Keys

The table is generated from the schema, `schema/site.schema.json`.

```@example
using TangoKalender, JSON, Markdown
s=JSON.parsefile(TangoKalender.SITE_SCHEMA_FILE); req=Set(s["required"])
rows=String[]
row(k,p)=push!(rows,"| `$k` | $(k in req ? "yes" : "") | $(replace(get(p,"description",""),"|"=>"\\|")) |")
for (k,p) in s["properties"]
 if k in ("map","geocode")
  for (k2,p2) in p["properties"]; row("$k.$k2",p2); end
 elseif k!="texts"
  row(k,p)
 end
end
row("texts.nb / .en / .es",s["properties"]["texts"])
Markdown.parse("| Key | Required | Meaning |\n|:--|:--|:--|\n"*join(rows,"\n"))
```

## Changing texts

Any text on the site can be replaced per language under `[texts.nb]`, `[texts.en]` or `[texts.es]`, keyed like the
package's strings in `src/i18n.jl`. `{city}` and `{CITY}` (upper case) are replaced by the city:

```toml
[texts.nb]
"site.subtitle" = "Milongaer, practicaer og kurs i {city} og omegn"
[texts.en]
"site.subtitle" = "Milongas, practicas and classes in and around {city}"
```

## Norway only

All sites share Norwegian time (`Europe/Oslo`), prices in kroner and the Norwegian issue forms, so a city outside
Norway would need changes in the package.
