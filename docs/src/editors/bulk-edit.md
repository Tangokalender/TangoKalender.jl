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

## 4. Create repeating dates

`repeat` copies an existing event to new dates. Then you don't have to submit every date of a weekly milonga or a
course again:

```bash
tangoedit repeat milonga-x-2026-11-20 --every=week --count=8                       # the next 8 Fridays
tangoedit repeat series:onsdagsmilonga --every=2weeks --until=2027-06-30            # continues the series
tangoedit repeat series:practica --every=month --on=last-friday                     # last Friday of each month
tangoedit repeat series:nybegynnerkurs --every=week --count=10 --except=2026-12-21..2027-01-03 dj=null
tangoedit repeat milonga-x-2026-11-20 --on=2026-12-27 'title=Juledagsmilonga'        # one date, on any weekday
```

- The search terms must find one event, or events of one series; then the latest one is copied.
- `--every=week`, `2weeks`, `month`, `3months`, … Weekly rules keep the template's weekday. Monthly rules keep its
  day of the month and skip months that don't have it (the 31st). With `--on=` they use a weekday instead:
  `1st-monday`, `2nd-thursday`, `last-friday`, `2nd-last-sunday`.
- `--on=DATE` (or several: `--on=2026-12-27,2027-01-03`) gives the dates directly instead of a rule, on any weekday.
  Use it for one extra date, such as a Sunday special of a Friday milonga.
- `--count=N` makes N new events. `--until=DATE` stops at a date. Without either, the dates run 6 months from today.
  `--start=DATE` sets the first possible date (the default is the day after the template).
- `--except=` skips dates, such as a holiday break: `2026-12-24`, or `2026-12-21..2027-01-03` for a range. You can
  list several, separated by commas. Skipped dates don't count towards `--count`, so a 10-week course with a break
  still gets 10 dates.
- Each copy keeps the template's times. Summer and winter time are handled, so 20:00 stays 20:00. The copy also
  gets the id `<series>-YYYY-MM-DD`, status scheduled and `first_seen` today. `KEY=VALUE` changes every copy,
  as in step 3.
- Dates that already have the event, or another event of the same series, are skipped, so running the same command
  again is safe, and a date that was added before the series was set isn't added twice. `--dry-run` and
  `--preview` show the new events without writing anything.

## 5. Publish

Commit the changed files and open a pull request. The *Validate* check runs, and the site is rebuilt once it's
merged.
