module TangoKalender
using JSON, JSONSchema, Dates
include("models.jl")
include("validate.jl")
include("labels.jl")
include("render/html.jl")
include("issue.jl")
include("correction.jl")
include("submission.jl")
include("ics.jl")
include("rss.jl")
include("render/event.jl")
include("llms.jl")
include("cli.jl")
export create_event, load_events, save_events, render_events_html, render_events_file
export render_event_page, calendar_ics, event_ics, rss_xml, write_site
export event_path, load_event_tree, save_event_tree, expand_weekly, oslo_offset, validate_event, validate_event_tree
end
