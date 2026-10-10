# TangoKalender

Julia-pakken som bygger tangokalendere: statiske, filtrerbare nettsider for argentinsk tango – milongaer, practicaer,
kurs og festivaler – én side per by. Hver by har sitt eget **data-repo** med arrangementene (`events/`),
kartposisjoner (`venues.json`), innstillinger (`site.toml`) og innsendingsskjemaene; dette repoet har koden.

| By | Nettside | Data |
|---|---|---|
| Oslo | https://tangokalender.github.io/ | https://github.com/Tangokalender/tangokalender.github.io |

Redaktører trenger bare skrivetilgang til sin bys data-repo. Koden endres her og tas i bruk av hver by ved å
oppdatere versjonen i data-repoets `Project.toml`.

## Ny by

```bash
julia -e 'using Pkg; Pkg.Apps.add(url="https://github.com/Tangokalender/TangoKalender.jl")'   # appen `tangokalender`
tangokalender init-site bergen --slug=bergen --city=Bergen \
  --site-url=https://tangokalender.github.io/bergen --repo-url=https://github.com/Tangokalender/bergen
```

`init-site` lager `site.toml`, tomme `events/` og `venues.json`, `Project.toml` (fester pakkeversjonen),
arbeidsflyter som kaller de gjenbrukbare her (`site-validate`, `site-pages`, `site-intake`), Dependabot,
innsendingsskjemaene og en README med engangsoppsettet på GitHub (Pages, rettigheter, etiketter, grenbeskyttelse).
Innstillingene i `site.toml` er beskrevet i `schema/site.schema.json`.

## Kommandoer

Kjøres i et data-repo (`julia --project=. -m TangoKalender …` eller appen `tangokalender …`):

```bash
tangokalender validate events                 # valider alle arrangementer
tangokalender site events _site               # validerer først, bygger hele nettsiden (som Pages)
tangokalender from-issue sak.md               # skjema-tekst → arrangementsfiler (brukes av intake)
tangokalender geocode events                  # kartposisjoner for nye adresser → venues.json
tangokalender edit TERM… [KEY=VALUE…]         # finn og endre mange arrangementer (--preview, --dry-run)
tangokalender templates                       # oppdater skjemaene i .github/ISSUE_TEMPLATE etter ny pakkeversjon
tangokalender --help
```

### `tangoedit` for redaktører (uten Julia)

`tangoedit` er `tangokalender edit` som frittstående program. Last ned for Linux, Windows eller macOS (Apple-chip)
fra [siste utgivelse](https://github.com/Tangokalender/TangoKalender.jl/releases/latest), pakk ut og kjør
`tangoedit/bin/tangoedit` i en klone av byens data-repo:

```bash
tangoedit/bin/tangoedit milonga --until=2026-12-31                  # hvilke arrangementer treffer?
tangoedit/bin/tangoedit milonga type:milonga price_nok=150 --preview # slik blir de
tangoedit/bin/tangoedit milonga type:milonga price_nok=150           # skriv; send så en pull request
```

Programmene er ikke signert: på macOS må karantenen fjernes én gang (`xattr -dr com.apple.quarantine tangoedit`),
og Windows kan vise en SmartScreen-advarsel («Mer informasjon» → «Kjør likevel»). De bygges av
`.github/workflows/tangoedit.yml` ved hver versjonstag (og månedlig som test); lokalt med `bin/build_tangoedit.sh`.

## Utvikling

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

Testene kjører mot en frossen kopi av Oslo-dataene i `test/fixtures/site/`. Se `CLAUDE.md` for arkitekturen.
Ny versjon: øk `version` i `Project.toml`, tag `vX.Y.Z` og flytt `v1`-taggen for arbeidsflytene.

## Arrangementer: én fil per arrangement

```
events/
  2026/10-october/2026-10-06-esa-2026-10-06.json   # <startdato>-<id>.json
```

Alle arrangementer har dato. Faste aktiviteter (ukentlige milongaer, kurs) er én fil per dato med felles
`series`-id, slik at DJ, pris osv. kan variere fra gang til gang. Avlyste kvelder markeres med
`"status": "cancelled"` i stedet for at filen slettes. Formatet er beskrevet i `schema/tango-event.schema.json`
(JSON Schema draft-07); valideringen sjekker i tillegg at `id` er unik og at filen ligger på riktig sted.
