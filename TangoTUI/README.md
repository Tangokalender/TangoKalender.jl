# TangoTUI (experimental)

A full-screen editor for the events of a TangoKalender data repository, built on
[Tachikoma.jl](https://github.com/kahliburke/Tachikoma.jl). It starts on a list of the upcoming events: type to search, as on
the web page, then pick one with ↑/↓ and Enter. In the form, every field is on the left with its current value; on the right, a
live preview card that marks changes in yellow and shows the old value struck through. Fields with a fixed set of
values (type, status, music, text language) open a pick list, so only allowed values can be chosen.

It needs Julia. Tachikoma can't be compiled with `juliac --trim` (its dependencies pull in REPL and Pkg), so this is
**not** part of the stand-alone `tangoedit` executable, and Tachikoma is not a dependency of TangoKalender itself.
The form logic (fields, allowed values, reading and saving) is in TangoKalender (`src/eventform.jl`:
`form_fields`, `field_text`, `set_field`, `save_form_event`), so a trimmed front end can reuse it later.

## Use

In a clone of a data repository (the folder with `events/` and `site.toml`), with this repository at `PATH`:

```bash
julia --project=PATH/TangoTUI -e 'using Pkg; Pkg.instantiate()'     # once

julia --project=PATH/TangoTUI -m TangoTUI                                   # search the list, open an event
julia --project=PATH/TangoTUI -m TangoTUI --all                             # … including past events
julia --project=PATH/TangoTUI -m TangoTUI edit milonga-social-2026-11-13   # straight to one event (terms as in tangoedit)
julia --project=PATH/TangoTUI -m TangoTUI edit series:otra                  # several matches: the list, searching for them
julia --project=PATH/TangoTUI -m TangoTUI new                               # a blank form
julia --project=PATH/TangoTUI -m TangoTUI new series:practica-tempranito    # a copy of the series' latest event, new date
```

In the list:

| Key | |
|---|---|
| type | search: every word must match (title in any language, venue, address, organiser, DJ, teachers, description, date, weekday, id, series); `type:class` or `venue:sentralen` searches one field |
| ↑ ↓, PgUp PgDn, Enter | choose an event and open it |
| Ctrl-A | also show past events (again: only upcoming) |
| Ctrl-N, Ctrl-K | a new blank event; a copy of the selected event on a new date |
| Esc | clear the search; on an empty search, quit |

In the form:

| Key | |
|---|---|
| ↑ ↓, Tab, PgUp PgDn | choose a field |
| Enter | edit the field: type, then Enter (Tab saves and goes on, Esc cancels) |
| in a pick list | ↑ ↓, Space ticks (several allowed), Enter chooses |
| Del | clear the field |
| Ctrl-S | save (refused while a field has a problem, marked `!` in red); with later dates: **a**/**u**/**d** (below) |
| Esc, q | back to the list (asks first when there are unsaved changes) |

### The same change on several dates

When you save a change to an event that has later dates, TangoTUI asks whether the change applies to them too:

- **a**: all later dates of the event's **series** (from this date on; a festival's other events the same day count);
- **u**: all later events of the **search** you opened the event from (offered only when the list was filtered);
- **d**: only this date; **Esc** cancels (nothing is saved).

Only the fields you changed are copied, never the date. A new start or end time is set for each date (summer or
winter time), and an end some days later keeps its length. The question lists the dates and marks those that had
their own value (e.g. a special price) that would be overwritten.

**Guardrail:** only events with the **same organiser** as the edited event (ignoring case and spacing) are ever
changed. Events of other organisers in the series or the search are left alone, and the question lists them as
skipped. All files are written together: if the tree check fails, none are.

### Saving

Saving writes the event file in its own key order, sets `last_verified` to today, moves the file when the date
changes, and refuses to overwrite another event. A new event gets the id `<series or title>-YYYY-MM-DD`.
Commit the changes with git afterwards; TangoTUI prints which files it saved.

The «Slutt» field takes `TT:MM` (an end before the start time is after midnight), `ÅÅÅÅ-MM-DD` for a multi-day
event, or `ÅÅÅÅ-MM-DD TT:MM`. Changing «Dato» moves the end along; summer and winter time are handled.

## Tests

```bash
julia --project=TangoTUI -e 'using Pkg; Pkg.test()'
```

The tests drive the editor with key events and draw the screen into Tachikoma's `TestBackend`, saving into a copy
of the package's test site.
