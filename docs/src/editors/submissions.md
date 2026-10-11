# Submissions and review

Anyone with a (free) GitHub account can submit events; an editor reviews them before they appear. The site's
«Legg til arrangement» page explains the routes for submitters.

| Route | Form | For |
|:--|:--|:--|
| One event | «Nytt arrangement» | A single event, or a simple weekly series («Gjentas: Ukentlig»). |
| Spreadsheet | «Nytt arrangement (fra tabell)» | Many dates: row 1 the column names, row 2 what all rows share, the rest only what differs. |
| AI | «Nytt arrangement (JSON fra KI)» | An AI assistant turns an event page into JSON, using the prompt on the site. |
| Correction | «Rett opp» on each event | Change or cancel one date, or all later dates in its series. A blank field means unchanged; `-` clears. |

## What the intake bot does

When an issue with the label `nytt-arrangement` or `rettelse` is opened or edited, the *Intake* workflow:

1. reads the form and writes or changes the event files, checking the whole calendar;
   new dates of an existing series join it (see below);
2. looks up map positions for new addresses (`venues.json`);
3. opens a pull request on the branch `arrangement/issue-<number>` with a summary, and comments on the issue.

If the form can't be read, the bot explains what's wrong in a comment and adds the label `trenger-retting`. When the
submitter edits the issue, the bot tries again. The AI form accepts a few field names that assistants tend to guess
(`price`, `flyer`, `image`, `url`, …) and renames them (`price_nok`, `flyer_url`, `link`); any other unknown field
is refused, and the comment lists the allowed ones.

## New dates of an existing series

A submitted event joins a series that is already in the calendar when it has the same title (or the same series id)
**and** the same organiser or venue name. It then gets that `series` and the id `<series>-YYYY-MM-DD`, so a single
new date of a regular milonga or practica shows up with its other dates. The bot's comment names the series
(«Legges til i den eksisterende serien …»). If a submitted date is already in the series, also under another id
with the same start time, the bot refuses it and points to «Rett opp». Same title but a different organiser and venue stays a separate event.

## Reviewing a bot pull request

- Read the summary in the pull request and the changed files. Check names against the source, the times and the
  venue.
- Pull requests opened by the bot don't start the *Validate* check (a GitHub rule), but the bot has already validated
  the whole calendar.
- Merge: the site is rebuilt within a few minutes. Merging also closes the issue.
- To change something first, push to the pull request's branch, or merge and fix it with
  [Bulk edits with tangoedit](@ref).
