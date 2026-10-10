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
2. looks up map positions for new addresses (`venues.json`);
3. opens a pull request on the branch `arrangement/issue-<number>` with a summary, and comments on the issue.

If the form can't be read, the bot explains what's wrong in a comment and adds the label `trenger-retting`. When the
submitter edits the issue, the bot tries again.

## Reviewing a bot pull request

- Read the summary in the pull request and the changed files. Check names against the source, the times and the
  venue.
- Pull requests opened by the bot don't start the *Validate* check (a GitHub rule), but the bot has already validated
  the whole calendar.
- Merge: the site is rebuilt within a few minutes. Merging also closes the issue.
- To change something first, push to the pull request's branch, or merge and fix it with
  [Bulk edits with tangoedit](@ref).
