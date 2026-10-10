# `tangokalender edit`: find upcoming events by search terms, show them, and change fields in bulk. The events are read
# as `Event` structs (eventstruct.jl), changed with `set_path` and written back in their own key order.
function event_path(e::Event; root::AbstractString="events")
 d=_ymd(e.start); isnothing(d) && throw(ArgumentError("event \"$(e.id)\" has no valid start date"))
 joinpath(root,string(year(d)),"$(_two(month(d)))-$(MONTHS[month(d)])","$(first(e.start,10))-$(e.id).json")
end
"""
    check_event_tree(root) -> [(file, message)]

`validate_event_tree` on structs: every file reads as an `Event` and passes `check`, ids are unique and files are at
their `event_path`. Used by the trimmed app, which has no JSONSchema.
"""
function check_event_tree(root::AbstractString)
 problems=Tuple{String,String}[]; seen=Dict{String,String}()
 for f in event_files(root)
  e=try first(read_event(f)) catch ex
   m=ex isa ArgumentError ? ex.msg : nothing; push!(problems,(f,m isa String ? m : "cannot be read as an event")); continue
  end
  msgs=check(e); append!(problems,((f,m) for m in msgs)); isempty(msgs) || continue
  haskey(seen,e.id) ? push!(problems,(f,"duplicate id \"$(e.id)\" (also in $(seen[e.id]))")) : (seen[e.id]=f)
  want=event_path(e;root); normpath(want)==normpath(f) || push!(problems,(f,"should be at $want"))
 end
 problems
end
"Keys a plain search term looks in."
const SEARCH_KEYS=["id","title","series","organizer","venue","teachers","dj","start"]
"Short names for `key:text` search terms."
const _SEARCH_ALIAS=Dict("type"=>"types","teacher"=>"teachers","music"=>"music_style","org"=>"organizer")
_searchtext(::Nothing)=""
_searchtext(v::AbstractString)=String(v)
_searchtext(v::Vector{String})=join(v," ")
_searchtext(v::Venue)=join((something(v.name,""),something(v.address,""),something(v.city,""))," ")
_searchtext(v::Real)=string(v)
_searchtext(v::_Record)=JSON.json(v)
"""
A search term: plain text, matched in any of `SEARCH_KEYS`, or `key:text` (`series:esa-tandas`, `type:class`,
`venue:Lindern`), matched in that key only. Matching ignores case. A prefix that isn't a key (`18:00`) is plain text.
"""
struct SearchTerm
 key::Union{Nothing,String}
 text::String
end
function SearchTerm(s::AbstractString)
 m=match(r"^([a-z_$]+):(.*)$",s)
 if !isnothing(m)
  k=get(_SEARCH_ALIAS,m[1],String(m[1]))
  k in jsonkeys(Event) && return SearchTerm(k,lowercase(m[2]))
 end
 SearchTerm(nothing,lowercase(s))
end
_hit(e::Event,k::String,t::String)=occursin(t,lowercase(_withfield(_searchtext,e,k)))
matches(e::Event,t::SearchTerm)=isnothing(t.key) ? any(k->_hit(e,k,t.text),SEARCH_KEYS) : _hit(e,t.key,t.text)
"Last day of an event: the date of `end`, else of `start`."
_lastday(e::Event)=something(_ymd(something(e.end_,e.start)),Date(9999))
_firstday(e::Event)=something(_ymd(e.start),Date(0))
"""
    find_events(terms; root="events", from=today(), until=nothing) -> [(file, event, keys)]

Events under `root` that match **all** `terms` (strings or `SearchTerm`s), sorted by start. `from` drops events that
ended before it (`nothing` keeps past events); `until` drops events that start after it.
"""
function find_events(terms; root::AbstractString="events", from::Union{Nothing,Date}=Dates.today(), until::Union{Nothing,Date}=nothing)
 ts=SearchTerm[t isa SearchTerm ? t : SearchTerm(t) for t in terms]
 out=Tuple{String,Event,Vector{String}}[]
 for f in event_files(root)
  e,ks=read_event(f)
  isnothing(from) || _lastday(e)>=from || continue
  isnothing(until) || _firstday(e)<=until || continue
  all(t->matches(e,t),ts) && push!(out,(f,e,ks))
 end
 sort!(out,by=x->(x[2].start,x[2].id))
end
"`\"venue.name=Ny sal\"` → `([\"venue\",\"name\"], \"Ny sal\")`."
function parse_edit(s::AbstractString)
 i=findfirst('=',s); isnothing(i) && throw(ArgumentError("an edit is KEY=VALUE, got $(repr(s))"))
 key=s[1:prevind(s,i)]; isempty(key) && throw(ArgumentError("missing key in $(repr(s))"))
 (String.(split(key,'.')),String(s[nextind(s,i):end]))
end
"One edited event: where it was and will be, before and after, and `(key, old, new)` per change (compact JSON)."
struct EventEdit
 file::String
 new_file::String
 before::Event
 after::Event
 keys::Vector{String}
 changes::Vector{Tuple{String,String,String}}
end
"""
    edit_events(terms, edits; root="events", from=today(), until=nothing, dry_run=false, tree_check=validate_event_tree) -> (edits, written, errors)

Apply `edits` (`"key=value"` strings or `(path, value)` pairs, see `set_path`) to every event `find_events` returns.
Events that don't change are left out. Nothing is written when `dry_run` is set or any edited event fails `check`.
Otherwise the files are written (and moved when `start` or `id` changed) and `tree_check(root)` runs, rolling
back on problems (the trimmed app passes `check_event_tree`, which needs no JSONSchema).
A bad key or value throws `ArgumentError`.
"""
function edit_events(terms, edits; root::AbstractString="events", from::Union{Nothing,Date}=Dates.today(), until::Union{Nothing,Date}=nothing,
                     dry_run::Bool=false, tree_check::C=validate_event_tree) where {C}
 es=Tuple{Vector{String},String}[x isa AbstractString ? parse_edit(x) : (String.(collect(x[1])),String(x[2])) for x in edits]
 out=EventEdit[]; errs=String[]
 for (f,e,ks) in find_events(terms;root,from,until)
  after=e
  for (p,v) in es; after=set_path(after,p,v); end
  changes=Tuple{String,String,String}[]
  for (p,_) in es
   old=path_json(e,p); new=path_json(after,p); k=join(p,".")
   old==new || any(c->c[1]==k,changes) || push!(changes,(k,old,new))
  end
  isempty(changes) && continue
  append!(errs,("$(e.id): $m" for m in check(after)))
  push!(out,EventEdit(f,event_path(after;root),e,after,ks,changes))
 end
 (dry_run || isempty(out) || !isempty(errs)) && return (out,String[],errs)
 files=[(x.file,x.new_file,event_text(x.after,x.keys)) for x in out]
 written,errs=_write_files!(files,root; check=tree_check)
 (out,written,errs)
end
const EDIT_USAGE="""
tangokalender edit - find events and change them in bulk

Usage:
  tangokalender edit TERM… [KEY=VALUE…] [options]

TERM     matches events containing it in id, title, series, organizer, venue, teachers, dj or start (ignoring case);
         KEY:TEXT matches one key only (series:esa-tandas, type:class, venue:Lindern, status:cancelled).
         Several terms must all match.
KEY=VALUE sets a key on every match. VALUE is read as JSON (250, null, ["A","B"], "text"), else as plain text.
         Nested keys use dots: venue.name=…, translations.en.title=….
Without KEY=VALUE, the matches are only listed.

Options:
  --preview         show each event as a card (after the edits, changes highlighted); writes nothing
  --dry-run         list the changes; writes nothing
  --from=DATE       only events that end on or after DATE (default: today)
  --until=DATE      only events that start on or before DATE
  --all             include past events
  --root=DIR        the events directory (default: events)
"""
"""
    edit_main(args; io=stdout, err=stderr, tree_check=validate_event_tree, render=styled_text) -> exit code

The `edit` subcommand. `render` turns lines of `(text, face)` segments into something printable: `styled_text`
(StyledStrings) here, `ansi_text` in the trimmed `tangoedit` app, which also passes `tree_check=check_event_tree`.
0 = done (also when nothing matches), 1 = an edited event is invalid (nothing written), 2 = usage error.
"""
function edit_main(args::AbstractVector{<:AbstractString}; io::IO=stdout, err::IO=stderr, tree_check::C=validate_event_tree,
                   render::R=styled_text) where {C,R}   # type parameters: specialise on the functions (needed for trimming)
 usage(msg::String)=(println(err,msg,"\n"); print(err,EDIT_USAGE); 2)
 terms=String[]; edits=String[]; root="events"; from=Dates.today(); until=nothing; dry=false; preview=false; past=false
 for a in args
  if a in ("-h","--help"); print(io,EDIT_USAGE); return 0
  elseif startswith(a,"--")
   kv=split(a[3:end],'=';limit=2); k=kv[1]; v=length(kv)==2 ? String(kv[2]) : ""
   if k=="root" && !isempty(v); root=v
   elseif k in ("from","until") && !isempty(v)
    d=_ymd(v); (isnothing(d) || length(v)!=10) && return usage("--$k needs a date YYYY-MM-DD, got \"$v\"")
    k=="from" ? (from=d) : (until=d)
   elseif k=="all" && length(kv)==1; past=true
   elseif k=="dry-run" && length(kv)==1; dry=true
   elseif k=="preview" && length(kv)==1; preview=true
   else return usage("unknown option $a") end
  elseif occursin('=',a); push!(edits,a)
  else push!(terms,a) end
 end
 isempty(terms) && return usage("edit needs at least one search term")
 isdir(root) || return usage("no events directory \"$root\" (use --root=DIR)")
 past && (from=nothing)
 w=displaysize(io)[2]
 show_(lines::Vector{Vector{Seg}})=println(io,render(lines))
 if isempty(edits)
  found=find_events(terms;root,from,until)
  for (_,e,_) in found; preview ? (show_(card_lines(e;width=w)); println(io)) : show_([line_segs(e;width=w)]); end
  n=length(found)
  println(io,n==0 ? "No events match $(join(terms," "))$(past ? "" : " (upcoming only; --all includes past events)")." : "$n event$(n==1 ? "" : "s")")
  return 0
 end
 res,written,errs=try edit_events(terms,edits;root,from,until,dry_run=dry || preview,tree_check)
 catch ex; ex isa ArgumentError || rethrow(); return usage(ex.msg isa String ? ex.msg : "invalid edit") end
 for x in res
  if preview; show_(card_lines(x.after;before=x.before,width=w)); println(io)
  else
   lines=[line_segs(x.after;width=w)]
   for (k,old,new) in x.changes; push!(lines,Seg[("    $k: ",:default),(old,:shadow),(" → ",:default),(new,:bold)]); end
   x.new_file==x.file || push!(lines,Seg[("    moves to $(_rel(x.new_file,root))",:shadow)])
   show_(lines)
  end
 end
 n=length(res); moved=count(x->x.new_file!=x.file,res)
 if !isempty(errs)
  foreach(m->println(err,m),errs); println(err,"Nothing written: $(length(errs)) problem(s)."); return 1
 end
 summary=n==0 ? "No changes: the matching events already have these values (or nothing matches)." :
  "$n event$(n==1 ? "" : "s") $(isempty(written) ? "would change" : "changed")$(moved>0 ? ", $moved file$(moved==1 ? "" : "s") moved" : "")"
 println(io,summary,n>0 && isempty(written) ? " (dry run: nothing written)." : ".")
 0
end
