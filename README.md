# TangoKalender.jl

Statisk, responsiv og filtrerbar tango-kalender basert på `JSON.jl`, publisert med GitHub Pages
(https://tangokalender.github.io/TangoKalender.jl/), kildekode på https://github.com/Tangokalender/TangoKalender.jl.

## Legge inn arrangementer

- **Skjema (anbefalt):** Issues → New issue → «Nytt arrangement». En robot gjør skjemaet om til
  arrangementsfiler og åpner en pull request; svaret (eller feil som må rettes) kommer som kommentar.
  Faste arrangementer legges inn med «Gjentas: Ukentlig».
- **Med KI:** har du arrangementet på Facebook eller en nettside, følg
  [Bruk KI til å legge inn arrangementer](https://tangokalender.github.io/TangoKalender.jl/for-ki.html): kopier
  ledeteksten inn i Copilot/Gemini/ChatGPT sammen med arrangementsteksten, og lim svaret (JSON) inn i skjemaet
  «Nytt arrangement (JSON fra KI)». Instruksjoner for KI-agenter ligger i
  [`llms.txt`](https://tangokalender.github.io/TangoKalender.jl/llms.txt), og formatet i
  [innsendingsskjemaet](https://tangokalender.github.io/TangoKalender.jl/schema/tango-event-submission.schema.json).
- **Rette opp:** klikk «Rett opp» på arrangementet. Skjemaet viser hva som står der nå; fyll bare inn
  feltene som skal endres (tomt felt = ingen endring, `-` fjerner en opplysning), velg om endringen gjelder bare denne datoen eller
  også alle senere i serien, og send inn. Avlysninger meldes med «Status: Avlyst».
- **Pull request:** legg til eller endre filer under `events/` direkte. CI validerer alle filer.

En redaktør ser over og merger; siden bygges og publiseres automatisk fra `main`.

## For redaktører

- `.github/workflows/ci.yml`: tester og validering på alle PR-er og på `main`.
- `.github/workflows/pages.yml`: bygger siden og publiserer til Pages ved endringer på `main` og hver natt.
- `.github/workflows/intake.yml`: skjema → filer → PR (gren `arrangement/issue-<nr>`). Saker med feil får
  etiketten `trenger-retting`. PR-er laget av roboten kjører ikke CI automatisk, men er validert av roboten.

Engangsoppsett på GitHub: Settings → Pages → Source: *GitHub Actions*; Settings → Actions → General →
Workflow permissions: *Read and write* og *Allow GitHub Actions to create and approve pull requests*;
opprett etikettene `nytt-arrangement`, `rettelse` og `trenger-retting`.

## Utvikling

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project=. -m TangoKalender validate                      # valider alle arrangementer i events/
julia --project=. -m TangoKalender build events public/index.html # validerer først, bygger så siden
julia --project=. -m TangoKalender from-issue sak.md --root=events   # skjema-tekst → arrangementsfiler
julia --project=. -m TangoKalender --help
```

### Som app (Julia ≥ 1.12)

```bash
julia -e 'using Pkg; Pkg.Apps.add(url="<git-url til TangoKalender.jl>")'   # eller Pkg.Apps.develop(path=".")
tangokalender                  # = tangokalender build events public/index.html, i gjeldende mappe
tangokalender validate events
tangokalender build --title="Tango i Oslo" --no-validate
```

`~/.julia/bin` må ligge i `PATH`. Skriptene i `bin/` er tynne omslag rundt `TangoKalender.main`.

## Arrangementer: én fil per arrangement

```
events/
  2026/10-october/2026-10-06-esa-2026-10-06.json   # <startdato>-<id>.json
```

Alle arrangementer har dato. Faste aktiviteter (ukentlige milongaer, kurs) er én fil per dato
med felles `series`-id, slik at DJ, pris osv. kan variere fra gang til gang. Avlyste kvelder
markeres med `"status": "cancelled"` (vises som «Avlyst») i stedet for at filen slettes.

Formatet er beskrevet i `schema/tango-event.schema.json` (JSON Schema draft-07). Legg til
`"$schema": "https://tangokalender.github.io/TangoKalender.jl/schema/tango-event.schema.json"` i en fil for autoutfylling i editoren.
I tillegg til skjemaet sjekker valideringen at `id` er unik og at filen ligger på riktig sted.

Nye felt i v2: `venue` (`{name, address, city}`), `music_style` (`traditional`,
`alternative`, `live_orchestra`), `flyer_url`, `video` (`{platform: "youtube"|"vimeo", id}`)
og `link` (offisiell side for arrangementet), samt `series` og `status` (`scheduled`/`cancelled`).

`examples/oslo_tango_events_2026-09-30.json` er det gamle v1-formatet (én liste). Det kan
konverteres med `julia --project=. bin/migrate_v1.jl <input.json> <events-mappe>`. Ukentlige
aktiviteter utvides da til én fil per dato (`expand_weekly`) fra `first_seen` til `end`.
