# Tangokalender | Oslo

**Nettside: https://tangokalender.github.io/**

Statisk, responsiv og filtrerbar kalender for argentinsk tango i Oslo – milongaer, practicaer, kurs og festivaler.
Siden bygges av Julia-pakken `TangoKalender` i dette repoet og publiseres med GitHub Pages.
Kildekode: https://github.com/Tangokalender/tangokalender.github.io

## Visninger og lenker

- **Liste** (forsiden): kompakt liste gruppert per dag. **Uke**: én uke om gangen med ‹ ›. **Kort**: utfyllende kort.
- Hvert arrangement har egen side, `https://tangokalender.github.io/arrangement/<id>/`, med alle detaljer,
  «Legg i kalender (.ics)», «Del lenke» og «Rett opp».
- Filtrene ligger i adressen og kan deles eller bokmerkes, f.eks.
  https://tangokalender.github.io/?type=milonga,practica
- Abonner på hele kalenderen: `webcal://tangokalender.github.io/kalender.ics`.
  RSS: https://tangokalender.github.io/rss.xml
- **Bygg inn på egen nettside:** https://tangokalender.github.io/bygg-inn.html – dagens og ukens program som bilde
  med lenker (`<object>`, oppdateres hver natt), en liste med filtre for `<iframe>` (f.eks. bare én arrangørs
  arrangementer med `?arr=`), samt `kalender.ics`, `rss.xml` og `events.json`.
- ActivityPub står på [TODO](TODO.md).

## Språk

Siden finnes på norsk (`/`), engelsk (`/en/`) og spansk (`/es/`), med de samme filnavnene, f.eks.
https://tangokalender.github.io/en/uke.html. Første besøk på en norsk side følger nettleserens språk (engelsk for
andre språk enn norsk/skandinavisk og spansk); valget i språkvelgeren (NO · EN · ES) huskes i nettleseren.
Tittel og beskrivelse kan sendes inn på norsk eller engelsk («Tekstspråk»), og eventuelt også på det andre språket –
ett språk er nok. Spanske sider viser engelsk tekst når den finnes. Skjemaene på GitHub er på norsk; de engelske og
spanske «Legg til»-sidene forklarer feltene.

## Legge inn arrangementer

Alt om innsending står på én side: **https://tangokalender.github.io/legg-til.html**

- **Ett arrangement** (eller en enkel ukentlig serie): skjemaet «Nytt arrangement». Faste kvelder legges inn med
  «Gjentas: Ukentlig».
- **Flere datoer fra regneark:** første rad kolonnenavn, andre rad alt som er felles, neste rader bare det som er
  annerledes (typisk Dato og DJ; tom celle = som andre rad, `-` fjerner, «Avlyst» i Status). Kopier cellene fra
  Excel/Google Regneark/Numbers og lim inn i «Nytt arrangement (fra tabell)». Mal:
  https://tangokalender.github.io/mal/arrangementer-mal.csv
- **Med KI:** kopier ledeteksten på siden inn i Copilot/Gemini/ChatGPT sammen med arrangementsteksten, og lim
  svaret (JSON) inn i «Nytt arrangement (JSON fra KI)». Instruksjoner for KI-agenter:
  https://tangokalender.github.io/llms.txt
- **Rette opp:** «Rett opp» på hvert arrangement (tomt felt = ingen endring, `-` fjerner en opplysning; gjelder
  denne datoen eller også alle senere i serien; avlysning med «Status: Avlyst»).
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
julia --project=. -m TangoKalender site events _site             # validerer først, bygger hele nettsiden (som Pages)
julia --project=. -m TangoKalender build events public/index.html # bare én side (kortvisning)
julia --project=. -m TangoKalender from-issue sak.md --root=events   # skjema-tekst → arrangementsfiler
julia --project=. -m TangoKalender --help
```

### Som app (Julia ≥ 1.12)

```bash
julia -e 'using Pkg; Pkg.Apps.add(url="https://github.com/Tangokalender/tangokalender.github.io")'   # eller Pkg.Apps.develop(path=".")
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
`"$schema": "https://tangokalender.github.io/schema/tango-event.schema.json"` i en fil for autoutfylling i editoren.
I tillegg til skjemaet sjekker valideringen at `id` er unik og at filen ligger på riktig sted.

Viktige felt: `title`, `type`, `start`/`end`, `venue` (`{name, address, city}`), `organizer`, `dj`, `teachers`,
priser (`price_nok`, `student_price_nok`, `class_price_nok`), `music_style` (`traditional`, `alternative`,
`live_orchestra`), `description`, `flyer_url`, `video` (`{platform: "youtube"|"vimeo", id}`),
`link` (offisiell side for arrangementet), `series` og `status` (`scheduled`/`cancelled`).
