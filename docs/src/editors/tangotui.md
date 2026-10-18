# Interactive editor (experimental)

!!! warning "Experimental, Julia only"
    TangoTUI is an **experimental** full-screen editor. It needs **Julia** (1.12 or newer) and a clone of this
    repository: it is **not** part of the stand-alone `tangoedit` download, because the terminal library it uses,
    [Tachikoma.jl](https://github.com/kahliburke/Tachikoma.jl), can't be compiled into one. The screens are in
    **Norwegian only** for now. How it looks and works may still change; for anything that matters, check the result
    with `git diff` before you commit.

![TangoTUI: searching for a venue, opening a weekly milonga, changing the price for all later dates (invented events)](../assets/tangotui-demo.svg)

TangoTUI edits **one event at a time** in a form, so you needn't know field names, JSON or event ids:

- It starts on a list of the upcoming events. **Type to search**, as on the web page, and open an event with ↑/↓ and
  Enter.
- Every field is shown with its current value. Fields with a fixed set of values (type, status, music, text
  language) open a **pick list**, so only allowed values can be chosen.
- A preview card shows the event as the site will, with changes highlighted and the old value struck through.
- When you save a change to a date that has **later dates**, it asks whether the change applies to them too, but
  never to another organiser's events.
- **Ctrl-R** repeats an event on the dates of a rule, with every option of
  [`tangoedit repeat`](@ref "Bulk edits with tangoedit"), and lists the dates it will create as you set the rule.

For changes to many events in one go, or without Julia, use [`tangoedit`](@ref "Bulk edits with tangoedit").

## Set up and start

In a clone of your city's data repository (the folder with `events/` and `site.toml`), with this repository cloned at
`PATH`:

```bash
julia --project=PATH/TangoTUI -e 'using Pkg; Pkg.instantiate()'    # once, and after updating PATH

julia --project=PATH/TangoTUI -m TangoTUI                    # the list of upcoming events
julia --project=PATH/TangoTUI -m TangoTUI --all              # … including past events
julia --project=PATH/TangoTUI -m TangoTUI edit otra-2026-11-02     # straight to one event
julia --project=PATH/TangoTUI -m TangoTUI new                # a blank form
julia --project=PATH/TangoTUI -m TangoTUI new series:otra    # a copy of the series' latest event, on a new date
julia --project=PATH/TangoTUI -m TangoTUI repeat series:otra # repeat the series' latest event on the dates of a rule
```

The first start after installing or updating compiles TangoTUI once, which takes a little while; after that it
opens in a second or two.

`edit` takes the same search terms as `tangoedit` (`series:otra`, `type:class`, `venue:sentralen`). When several
events match, or none, it opens the list searching for them.

## The list

| Key | |
|:--|:--|
| letters | search: every word must match, in the title (any language), venue, address, organiser, DJ, teachers, description, date, weekday, id or series; `key:text` searches one field |
| ↑ ↓, PgUp PgDn, Enter | choose an event and open it |
| Ctrl-A | also show past events (press again for upcoming only) |
| Ctrl-N | a new, blank event |
| Ctrl-K | a copy of the selected event on a new date (the date field opens first) |
| Ctrl-R | repeat the selected event on the dates of a rule (see [below](@ref "Repeat an event")) |
| Esc | clear the search; on an empty search, quit |

## The form

| Key | |
|:--|:--|
| ↑ ↓, Tab, PgUp PgDn | choose a field |
| Enter | edit the field; Enter saves it, Tab saves and goes to the next, Esc cancels |
| in a description | the field opens in a larger window with word wrap: Enter makes a line break, the arrow keys, Home and End move, **Ctrl-S** keeps the text, Esc cancels |
| in a pick list | ↑ ↓ to move, Space to tick (where several are allowed), Enter to choose |
| Del | clear the field |
| Ctrl-S | save the event |
| Ctrl-R | repeat the event **as it stands in the form** (see [below](@ref "Repeat an event")) |
| Ctrl-L | copy this date's values to the **later dates** of its series (see [below](@ref "Fix later dates after a one-date correction")) |
| Esc | back to the list (asks first if there are unsaved changes) |

A field that breaks a rule of the [event format](@ref events) is marked `!` in red, with the reason below the form;
saving is refused until it's fixed. Some fields take short forms:

- **Dato**: `2026-11-04` or `04.11.2026`. A new date moves the end along, and the file moves to the new date's folder.
- **Starttid**: `20:00`; empty for events without a time (festivals).
- **Slutt**: `23:30`, or a time before the start for after midnight (`01:30`); `2026-11-08` for an event over several
  days, or `2026-11-08 18:00`. Summer and winter time are handled.
- **Lærere**: names separated by commas. **Pris**: whole kroner (`150` or `150 kr`). For pay what you can, set
  **Betal det du kan** to «Ja»; **Pris** is then the suggested amount, or empty.
- **Tittel**: the event's own name, without the organiser (it has its own field and is shown in the list).

A new event gets the id `<series or title>-YYYY-MM-DD`, like events from the submission forms.

## The same change on several dates

When you save a change to an event that has later dates, TangoTUI asks:

- **a**: all later dates of the event's **series**, from this date on;
- **u**: all later events of the **search** you opened the event from (offered only when the list was filtered);
- **d**: only this date;
- **Esc**: cancel; nothing is saved.

Only the fields you changed are copied, never the date. A new start or end time is set on each date with the right
summer or winter time, and an end some days later keeps its length. The question lists the dates, and marks those
that had their own value (for example a special price) that would be overwritten.

**Guardrail:** only events with the **same organiser** as the event you edit are changed. Events by other organisers
in the series or the search are left alone and listed as skipped. All files are written together: if the check of
the event tree fails, none of them are.

## Fix later dates after a one-date correction

Organisers sometimes correct one date with «Rett opp» but forget to choose «Denne og alle senere datoer i
serien», so only that date changes. Open the corrected date and press **Ctrl-L**: a panel lists the fields in which
the later dates of the series differ from this one, with this date's value and theirs.

- A field is ticked already when **all** later dates still share one value, the old one: the typical trace of such a
  correction. Fields where the later dates vary (a DJ per date) and Status are not ticked.
- **Space** ticks or unticks, **Enter** writes the ticked fields to every later date of the series, **Esc** cancels.
- Times are set on each date with the right summer or winter time, earlier dates are never touched, and the
  [guardrail](@ref "The same change on several dates") applies: only events with the same organiser change.

Save your own changes to the event first (Ctrl-S); Ctrl-L only copies what is already saved.

## Repeat an event

![TangoTUI: repeating a weekly course, 10 new dates with the Christmas weeks skipped (invented events)](../assets/tangotui-repeat-demo.svg)

**Ctrl-R** opens a panel that creates copies of an event on many dates: the same rules as
`tangoedit repeat`, set in fields instead of options. On the right, the dates are listed as you go: each new event
as a list line, and the dates that are skipped with the reason (already there, or excepted). **Ctrl-S** creates
them; **Esc** cancels and nothing is written.

The template is the event **as it stands in the form**: to give every copy a new DJ or price, change it in the form
first, then press Ctrl-R (the event itself is only changed if you also save it). From the list, Ctrl-R repeats the
selected event; `repeat TERM…` starts with the latest event of a series, like `tangoedit repeat`. When that latest
event is unlike the rest of its series (another weekday or title, e.g. a Christmas special), the panel says so and
names a typical one.

| Field | | `tangoedit repeat` |
|:--|:--|:--|
| Regel | Ukentlig, Månedlig or Bestemte datoer | `--every=week`/`month`, or `--on=DATE,…` |
| Hver | 1 = every, 2 = every other, 3 = every third … | `--every=2weeks`, `3months` |
| Dag i måneden, Ukedag | monthly: the template's day of the month, or the 1st–5th or last … 5th-last weekday | `--on=2nd-thursday`, `last-friday`, `2nd-last-sunday` |
| Datoer | Bestemte datoer: dates on any weekday, comma-separated (`2026-12-27, 03.01.2027`) | `--on=2026-12-27,2027-01-03` |
| Antall | how many new events (excepted dates don't count) | `--count=N` |
| Til og med | the last possible date; empty and without Antall: 6 months ahead | `--until=DATE` |
| Fra og med | the first possible date (default: the day after the template); the rhythm stays the template's | `--start=DATE` |
| Unntatt | dates or ranges to skip: `2026-12-24, 2026-12-21..2027-01-03` | `--except=…` |

Fields that don't apply to the chosen rule are dimmed. Dates that already have the event, or any event of its series,
are skipped, so repeating again is safe. A new event that hasn't been saved yet (after Ctrl-N or Ctrl-K) is created on
its own date too. All files are written together, checked like any other save.

## After saving

Saving writes the event files in their own key order and sets `last_verified` to today. TangoTUI never commits:
when you quit, it lists the files it saved. Review and commit them as usual:

```bash
git diff
git add events && git commit -m "Onsdagsmilonga: ny pris fra 28. oktober"
git push
```

The animations are made by `bin/make_tui_demo.jl` and `bin/make_tui_repeat_demo.jl` from TangoTUI's real screens, on
invented events.
