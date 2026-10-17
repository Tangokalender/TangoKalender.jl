# API reference

The functions behind the command line. Names marked `TangoKalender.` aren't exported.

## Site and build

```@docs
TangoKalender.SiteConfig
TangoKalender.load_site
write_site
render_events_html
render_archive_html
TangoKalender.ARCHIVE_PAGE
TangoKalender.archive_file
render_events_file
render_event_page
calendar_ics
event_ics
rss_xml
events_json
today_svg
week_svg
```

## Events

```@docs
load_events
load_event_tree
save_events
save_event_tree
event_path
create_event
expand_weekly
oslo_offset
validate_event
validate_event_tree
```

## Bulk edits

```@docs
Event
read_event
write_event
set_path
TangoKalender.check
TangoKalender.check_event_tree
find_events
edit_events
TangoKalender.edit_main
repeat_events
TangoKalender.repeat_main
TangoKalender.repeat_template
TangoKalender.repeat_from
TangoKalender.repeat_event
TangoKalender.Recurrence
TangoKalender.recurrence_dates
event_card
event_line
TangoKalender.styled_text
TangoKalender.ansi_text
```

## Intake

```@docs
TangoKalender.parse_issue_form
TangoKalender.events_from_form
TangoKalender.events_from_table
TangoKalender.events_from_json
TangoKalender.apply_correction
TangoKalender.correction_url
TangoKalender.submission_schema
```

## New cities

```@docs
TangoKalender.init_site
TangoKalender.write_templates
```

## Venues

```@docs
load_venues
save_venues
venue_coords
geocode!
validate_venues
```
