# TangoTUI (experimental)

A full-screen editor for **one** event of a TangoKalender data repository, built on
[Tachikoma.jl](https://github.com/kahliburke/Tachikoma.jl). On the left is every field with its current value; on the right, a
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

julia --project=PATH/TangoTUI -m TangoTUI edit milonga-social-2026-11-13   # one event (search terms as in tangoedit)
julia --project=PATH/TangoTUI -m TangoTUI edit series:otra --all            # several matches: pick one from a list
julia --project=PATH/TangoTUI -m TangoTUI new                               # a blank form
julia --project=PATH/TangoTUI -m TangoTUI new series:practica-tempranito    # a copy of the series' latest event, new date
```

| Key | |
|---|---|
| ↑ ↓, Tab, PgUp PgDn | choose a field |
| Enter | edit the field: type, then Enter (Tab saves and goes on, Esc cancels) |
| in a pick list | ↑ ↓, Space ticks (several allowed), Enter chooses |
| Del | clear the field |
| Ctrl-S | save (refused while a field has a problem, marked `!` in red) |
| Esc, q | quit (asks first when there are unsaved changes) |

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
