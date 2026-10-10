function create_event(; title, types=["other"], kwargs...)
 d=Dict{String,Any}("title"=>title,"types"=>collect(types))
 for (k,v) in kwargs; d[string(k)]=v; end
 d
end
const MONTHS=["january","february","march","april","may","june","july","august","september","october","november","december"]
"Canonical path of an event file: `root/YYYY/MM-month/YYYY-MM-DD-id.json`."
function event_path(e; root::AbstractString="events")
 id=string(e["id"]); s=get(e,"start",nothing)
 (isnothing(s) || isempty(string(s))) && throw(ArgumentError("event \"$id\" has no start date"))
 d=Date(first(string(s),10))
 joinpath(root,string(year(d)),"$(lpad(month(d),2,'0'))-$(MONTHS[month(d)])","$(Dates.format(d,"yyyy-mm-dd"))-$id.json")
end
event_files(dir::AbstractString)=sort!([joinpath(r,f) for (r,_,fs) in walkdir(dir) for f in fs if endswith(f,".json")])
load_event_tree(dir::AbstractString)=[JSON.parsefile(f) for f in event_files(dir)]
"Events from a directory tree (`events/`) or from a single JSON file holding an array of events."
load_events(path::AbstractString="events")=isdir(path) ? load_event_tree(path) : JSON.parsefile(path)
function save_events(events,file::AbstractString="events.json")
 mkpath(dirname(abspath(file))); open(file,"w") do io; JSON.print(io,events,4); write(io,'\n'); end; file
end
save_event_tree(events,dir::AbstractString="events")=[save_events(e,event_path(e;root=dir)) for e in events]
const WEEKDAYS=["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
_last_sunday(y,m)=(d=lastdayofmonth(Date(y,m)); d-Day(mod(dayofweek(d),7)))
"""
UTC offset in Oslo at local time `t` (\"HH:MM\") on date `d`: CEST from 02:00 on the last Sunday of March
until 03:00 (CEST) on the last Sunday of October.
"""
function oslo_offset(d::Date,t::AbstractString="12:00")
 tm=Time(t); spring=_last_sunday(year(d),3); fall=_last_sunday(year(d),10)
 summer=(d>spring || (d==spring && tm>=Time(2))) && (d<fall || (d==fall && tm<Time(3)))
 summer ? "+02:00" : "+01:00"
end
_stamp(d,t)=isnothing(t) || isempty(string(t)) ? Dates.format(d,"yyyy-mm-dd") : "$(Dates.format(d,"yyyy-mm-dd"))T$(t):00$(oslo_offset(d,string(t)))"
"End stamp for a weekly event: an end time of `24:00`, or one not after the start, falls on the next day."
_end_stamp(d,st,et)=et=="24:00" ? _stamp(d+Day(1),"00:00") : et<=st ? _stamp(d+Day(1),et) : _stamp(d,et)
"""
Expand a weekly event (`weekday`, `start_time`, `end_time`) into one dated event per week,
from `from` through `until`, skipping dates in `except`. Each copy gets
`id = "<series>-YYYY-MM-DD"` and `series` (defaults to the template id).
"""
function expand_weekly(e; from::Date, until::Date, except=Date[], series=string(e["id"]))
 wd=findfirst(==(string(e["weekday"])),WEEKDAYS); isnothing(wd) && throw(ArgumentError("unknown weekday $(e["weekday"])"))
 first_day=from+Day(mod(wd-dayofweek(from),7))
 out=JSON.Object{String,Any}[]
 for d in first_day:Week(1):until
  d in except && continue
  x=JSON.Object{String,Any}("id"=>"$series-$(Dates.format(d,"yyyy-mm-dd"))","title"=>e["title"],"types"=>e["types"],"status"=>"scheduled","series"=>series,
   "start"=>_stamp(d,get(e,"start_time",nothing)))
  et=get(e,"end_time",nothing); isnothing(et) || (x["end"]=_end_stamp(d,string(get(e,"start_time","00:00")),string(et)))
  for (k,v) in e
   k in ("id","title","types","status","series","start","end","weekday","start_time","end_time") || (x[k]=v)
  end
  push!(out,x)
 end
 out
end
"`p` relative to `root` when it is inside it (`relpath` without the filesystem calls, which can't be trimmed)."
_rel(p::AbstractString,root::AbstractString)=(r=rstrip(root,'/')*"/"; startswith(p,r) ? p[ncodeunits(r)+1:end] : String(p))
"""
    _write_files!(updates, root; taken, check=validate_event_tree) -> (written, errors)

Write `(old_file, new_file, text)` updates under `root` as one change. A file whose event moved (new date or id) is
removed from its old place; a move onto an existing file is refused with `taken(path)` as the message. After writing,
`check(root)` (`(file, message)` pairs) must find nothing, otherwise every file is restored and `written` is empty.
"""
function _write_files!(updates, root; taken::T=p->"$p already exists", check::C=validate_event_tree) where {T,C}
 errs=String[]; written=String[]
 for (old,new,_) in updates
  normpath(new)!=normpath(old) && isfile(new) && (push!(errs,taken(_rel(new,root))); return (written,errs))
 end
 backup=Dict(f=>read(f) for (f,_,_) in updates)
 for (old,new,text) in updates
  normpath(new)==normpath(old) || rm(old)
  mkpath(dirname(new)); write(new,text); push!(written,new)
 end
 for (f,m) in check(root); push!(errs,"$f: $m"); end
 if !isempty(errs)   # roll back
  foreach(f->isfile(f) && rm(f),written); for (f,b) in backup; mkpath(dirname(f)); write(f,b); end
  written=String[]
 end
 (written,errs)
end
