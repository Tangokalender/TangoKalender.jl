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
```

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
| Esc | clear the search; on an empty search, quit |

## The form

| Key | |
|:--|:--|
| ↑ ↓, Tab, PgUp PgDn | choose a field |
| Enter | edit the field; Enter saves it, Tab saves and goes to the next, Esc cancels |
| in a pick list | ↑ ↓ to move, Space to tick (where several are allowed), Enter to choose |
| Del | clear the field |
| Ctrl-S | save the event |
| Esc | back to the list (asks first if there are unsaved changes) |

A field that breaks a rule of the [event format](@ref events) is marked `!` in red, with the reason below the form;
saving is refused until it's fixed. Some fields take short forms:

- **Dato**: `2026-11-04` or `04.11.2026`. A new date moves the end along, and the file moves to the new date's folder.
- **Starttid**: `20:00`; empty for events without a time (festivals).
- **Slutt**: `23:30`, or a time before the start for after midnight (`01:30`); `2026-11-08` for an event over several
  days, or `2026-11-08 18:00`. Summer and winter time are handled.
- **Lærere**: names separated by commas. **Pris**: whole kroner (`150` or `150 kr`), or
  «betal det du kan» for pay what you can, optionally with a suggested amount («betal det du kan, 100»).
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

## After saving

Saving writes the event files in their own key order and sets `last_verified` to today. TangoTUI never commits:
when you quit, it lists the files it saved. Review and commit them as usual:

```bash
git diff
git add events && git commit -m "Onsdagsmilonga: ny pris fra 28. oktober"
git push
```

The animation above is made by `bin/make_tui_demo.jl` from TangoTUI's real screens, on invented events.
