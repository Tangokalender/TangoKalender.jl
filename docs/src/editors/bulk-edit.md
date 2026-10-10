# Bulk edits with tangoedit

To change many events at once, such as cancelling a month, moving a series to a new venue or correcting a price,
editors with write access use the command line in a clone of the data repository:

- **`tangoedit`**, a stand-alone program for Linux, Windows and macOS (Apple chips). Download it from the
  [latest release](https://github.com/Tangokalender/TangoKalender.jl/releases/latest), unpack it and run
  `tangoedit/bin/tangoedit`. Nothing to install.
- or, with Julia, `julia --project=. -m TangoKalender edit …` in the data repository (the same command).

The programs aren't signed. On macOS, remove the quarantine once with `xattr -dr com.apple.quarantine tangoedit`; on
Windows, SmartScreen may warn («More info» → «Run anyway»).

![tangoedit cancelling a weekly milonga for November (invented events)](../assets/tangoedit-demo.svg)

## 1. Find the events

```bash
tangoedit milonga                                   # upcoming events containing «milonga»
tangoedit milonga type:milonga venue:sentralen      # all terms must match
tangoedit series:onsdagsmilonga --from=2026-11-01 --until=2026-11-30
```

- A plain word matches the id, title, series, organiser, venue, teachers, DJ or start time, ignoring case.
- `key:text` searches one field: any event field, or the short names `type:`, `teacher:`, `music:` and `org:`.
- Only upcoming events (ending today or later) by default; `--from`/`--until` set the dates, `--all` includes past
  events.
- A leading `edit` is ignored, so `tangoedit edit milonga` works too.

## 2. Look before you change

`--dry-run` prints each change as `key: old → new`; `--preview` prints each event as a card, with the changes
highlighted and the old value struck through. Neither writes anything.

## 3. Change

Add `KEY=VALUE` to the search:

```bash
tangoedit series:onsdagsmilonga --from=2026-11-01 --until=2026-11-30 status=cancelled
tangoedit series:fredagsmilonga venue.name="Kulturhuset" venue.address="Storgata 1"
tangoedit series:nybegynnerkurs class_price_nok=250
tangoedit milonga-x-2026-11-20 teachers='["A", "B"]' dj=null
```

- The value is read as JSON when it is valid JSON (`250`, `null`, `["A","B"]`, `"text"`), otherwise as plain text.
- Nested fields use dots: `venue.name`, `translations.en.title`.
- Every changed event is checked before anything is written. If one is invalid, nothing is written, and an error
  while writing restores every file.
- Changing `start` to another date moves the file; the id stays.

## 4. Publish

Commit the changed files and open a pull request. The *Validate* check runs, and the site is rebuilt once it's
merged.
