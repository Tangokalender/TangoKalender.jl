module TangoKalender
using JSON, JSONSchema, Dates, Downloads
include("models.jl")
include("validate.jl")
include("labels.jl")
include("i18n.jl")
include("render/html.jl")
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
include("llms.jl")
include("cli.jl")
export create_event, load_events, save_events, render_events_html, render_events_file
export today_svg, week_svg, events_json, render_event_page, calendar_ics, event_ics, rss_xml, write_site
export load_venues, save_venues, venue_coords, geocode!, validate_venues
export event_path, load_event_tree, save_event_tree, expand_weekly, oslo_offset, validate_event, validate_event_tree
end
