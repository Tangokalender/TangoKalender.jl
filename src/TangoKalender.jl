module TangoKalender
using JSON, JSONSchema, Dates, Downloads, StructUtils, Accessors, StyledStrings
include("models.jl")
include("labels.jl")
include("eventstruct.jl")
include("validate.jl")
include("i18n.jl")
include("render/html.jl")
include("render/og.jl")
include("issue.jl")
include("correction.jl")
include("geo.jl")
include("render/map.jl")
include("submission.jl")
include("table.jl")
include("ics.jl")
include("rss.jl")
include("render/event.jl")
include("render/submit.jl")
include("render/about.jl")
include("render/svg.jl")
include("render/embed.jl")
include("render/term.jl")
include("edit.jl")
include("llms.jl")
include("cli.jl")
__init__()=_register_term_faces()
export create_event, load_events, save_events, render_events_html, render_events_file
export today_svg, week_svg, events_json, render_event_page, calendar_ics, event_ics, rss_xml, write_site
export load_venues, save_venues, venue_coords, geocode!, validate_venues
export Event, read_event, write_event, set_path, event_card, event_line
export find_events, edit_events
export event_path, load_event_tree, save_event_tree, expand_weekly, oslo_offset, validate_event, validate_event_tree
end
