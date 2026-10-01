const SCHEMA_FILE=joinpath(@__DIR__,"..","schema","tango-event.schema.json")
const _SCHEMA=Ref{Any}(nothing)
event_schema()=(isnothing(_SCHEMA[]) && (_SCHEMA[]=JSONSchema.Schema(JSON.parsefile(SCHEMA_FILE))); _SCHEMA[])
"Schema problems for one event, as a vector of messages (empty when valid)."
function validate_event(e)
 # Validate the JSON form of `e` (what save_events writes), so e.g. SubString values count as strings.
 issue=JSONSchema.validate(event_schema(),JSON.parse(JSON.json(e)))
 isnothing(issue) ? String[] : [_issue_message(e,issue)]
end
const _KNOWN=Set(keys(JSON.parsefile(SCHEMA_FILE)["properties"]))
function _issue_message(e,issue)
 at=isempty(issue.path) ? "" : "$(issue.path): "
 if issue.reason=="additionalProperties" && isempty(issue.path) && e isa AbstractDict
  return "unknown key(s): $(join(sort([k for k in keys(e) if !(k in _KNOWN)]),", "))"
 end
 issue.x isa AbstractDict || issue.x isa AbstractVector ? "$(at)fails $(issue.reason)=$(JSON.json(issue.val))" :
  "$(at)$(JSON.json(issue.x)) fails $(issue.reason)=$(JSON.json(issue.val))"
end
"""
Validate every `*.json` under `dir` (or the events of a single array file).
Returns `(file, message)` pairs: schema issues, duplicate ids, and files not at their `event_path`.
"""
function validate_event_tree(dir::AbstractString)
 ispath(dir) || return [(dir,"no such file or directory")]
 isdir(dir) || return [(dir,"$i: $m") for (i,e) in enumerate(load_events(dir)) for m in validate_event(e)]
 problems=Tuple{String,String}[]; seen=Dict{String,String}()
 for f in event_files(dir)
  e=try JSON.parsefile(f) catch err; push!(problems,(f,"invalid JSON: $(sprint(showerror,err))")); continue end
  e isa AbstractDict || (push!(problems,(f,"expected one event object")); continue)
  msgs=validate_event(e); append!(problems,((f,m) for m in msgs)); isempty(msgs) || continue
  id=string(e["id"])
  haskey(seen,id) ? push!(problems,(f,"duplicate id \"$id\" (also in $(seen[id]))")) : (seen[id]=f)
  want=event_path(e;root=dir); normpath(want)==normpath(f) || push!(problems,(f,"should be at $want"))
 end
 problems
end
