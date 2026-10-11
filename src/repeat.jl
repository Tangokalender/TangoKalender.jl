# `tangokalender repeat` / `tangoedit repeat`: copy an existing event to new dates on a recurrence rule (every N weeks,
# every N months on the same day or on the Nth/Nth-last weekday). Trimmed like edit.jl: dates are parsed and printed
# by hand (`_ymd`, `_ymd_str`) and the Oslo offset comes from `_oslo_offset`.
"""
    Recurrence(unit, n, nth, weekday)

Every `n` weeks (`unit=:week`) or months (`:month`). Monthly rules fall on the template's day of the month
(`nth=0`) or on the `nth` `weekday` (1 = Monday) of the month, counted from the end when `nth<0` (-1 = last).
"""
struct Recurrence
 unit::Symbol
 n::Int
 nth::Int
 weekday::Int
end
"`week`, `2weeks`, `2-weeks`, `weekly`, `month`, `3months`, `monthly` → `(unit, n)`."
function parse_every(s::AbstractString)
 t=lowercase(s)
 t=="weekly" && return (:week,1); t=="biweekly" && return (:week,2); t=="monthly" && return (:month,1)
 m=match(r"^([0-9]+)?-?(week|month)s?$",t)
 isnothing(m) && throw(ArgumentError("--every needs week, Nweeks, month or Nmonths (e.g. 2weeks), got \"$s\""))
 n=isnothing(m[1]) ? 1 : parse(Int,something(m[1]))
 n>=1 || throw(ArgumentError("--every needs a number of at least 1, got \"$s\""))
 (something(m[2])=="week" ? :week : :month,n)
end
const _ORDINALS=["first","second","third","fourth","fifth"]
"`thursday`, `thu` → 4; `nothing` if not a weekday."
function _weekday(s::AbstractString)
 t=lowercase(s)
 for (i,w) in enumerate(WEEKDAYS); (t==lowercase(w) || t==lowercase(first(w,3))) && return i; end
 nothing
end
function _ordinal(s::AbstractString)
 m=match(r"^([1-5])(st|nd|rd|th)?$",s); isnothing(m) || return parse(Int,something(m[1]))
 i=findfirst(==(s),_ORDINALS); isnothing(i) ? nothing : i
end
"`2nd-thursday`, `last-friday`, `2nd-last-sunday` → `(nth, weekday)` (`nth<0` counts from the end)."
function parse_on(s::AbstractString)
 bad()=throw(ArgumentError("--on needs e.g. 2nd-thursday, last-friday or 2nd-last-sunday, got \"$s\""))
 p=split(lowercase(s),'-'); length(p) in 2:3 || bad()
 wd=_weekday(p[end]); isnothing(wd) && bad()
 if length(p)==2
  p[1]=="last" && return (-1,wd)
  n=_ordinal(p[1]); isnothing(n) && bad(); return (n,wd)
 end
 p[2]=="last" || bad(); n=_ordinal(p[1]); isnothing(n) && bad()
 (-n,wd)
end
"The `nth` `weekday` of month `m` in year `y` (from the end when `nth<0`), or `nothing` if the month has none."
function nth_weekday(y::Integer, m::Integer, nth::Integer, wd::Integer)
 if nth>0
  f=Date(y,m,1); d=f+Day(mod(wd-dayofweek(f),7)+7*(nth-1))
 else
  l=lastdayofmonth(Date(y,m,1)); d=l-Day(mod(dayofweek(l)-wd,7)+7*(-nth-1))
 end
 month(d)==m ? d : nothing
end
"`2026-12-21..2027-01-03,2027-02-23` → `[(first, last), …]` (a single date is a one-day range)."
function parse_except(s::AbstractString)
 out=Tuple{Date,Date}[]
 for part in split(s,',')
  isempty(part) && continue
  ab=split(part,".."); length(ab) in 1:2 || throw(ArgumentError("--except: bad range \"$part\""))
  ds=Date[]
  for x in ab
   d=_ymd(x); (isnothing(d) || length(x)!=10) && throw(ArgumentError("--except needs dates YYYY-MM-DD or ranges DATE..DATE, got \"$part\""))
   push!(ds,d)
  end
  a=first(ds); b=last(ds); b<a && throw(ArgumentError("--except: range \"$part\" ends before it starts"))
  push!(out,(a,b))
 end
 out
end
"""
    recurrence_dates(r, anchor; from, until=nothing, count=nothing, except=[]) -> (dates, excepted)

Dates of rule `r` on or after `from`, in step with `anchor` (the template's date: its weekday, day of the month and
the phase of every-N rules). Stops after `until` or after `count` dates. Dates inside an `except` range go to
`excepted` and don't count. Months without the day (the 31st) or the weekday (a 5th Friday) are skipped.
"""
function recurrence_dates(r::Recurrence, anchor::Date; from::Date, until::Union{Nothing,Date}=nothing, count::Union{Nothing,Int}=nothing,
                          except::Vector{Tuple{Date,Date}}=Tuple{Date,Date}[])
 dates=Date[]; excepted=Date[]
 isnothing(until) && isnothing(count) && throw(ArgumentError("recurrence_dates needs until or count"))
 m0=firstdayofmonth(anchor)
 k=r.unit===:week ? fld(Dates.value(from-anchor),7*r.n) :
  fld((year(from)-year(anchor))*12+month(from)-month(anchor),r.n)
 for _ in 1:10_000   # a guard; --count and --until end the loop long before
  if r.unit===:week
   d=anchor+Day(7*r.n*k)
   !isnothing(until) && d>until && break
  else
   f=m0+Month(r.n*k)
   !isnothing(until) && f>until && break
   d=r.nth==0 ? (day(anchor)<=daysinmonth(f) ? Date(year(f),month(f),day(anchor)) : nothing) : nth_weekday(year(f),month(f),r.nth,r.weekday)
  end
  k+=1
  (isnothing(d) || d<from || (!isnothing(until) && d>until)) && continue
  _in_ranges(d,except) ? push!(excepted,d) : push!(dates,d)
  !isnothing(count) && length(dates)>=count && break
 end
 (dates,excepted)
end
_in_ranges(d::Date,rs::Vector{Tuple{Date,Date}})=any(r->r[1]<=d<=r[2],rs)
"`2026-10-01`, printed by hand (`Dates.format` can't be trimmed)."
_ymd_str(d::Date)="$(year(d))-$(_two(month(d)))-$(_two(day(d)))"
"Stamp `s` (a date, or a datetime) moved to day `d`, keeping its time and recomputing the Oslo offset."
function _move_stamp(s::String, d::Date)
 m=match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T([0-9]{2}):([0-9]{2}):([0-9]{2})",s)
 isnothing(m) && return _ymd_str(d)
 h=something(m[1])
 "$(_ymd_str(d))T$h:$(something(m[2])):$(something(m[3]))$(_oslo_offset(d,parse(Int,h)))"
end
"The series of new copies of `t`: its `series`, else its id without a trailing date."
_repeat_series(t::Event)=something(t.series,replace(t.id,r"-[0-9]{4}-[0-9]{2}-[0-9]{2}$"=>""))
"""
    repeat_event(t, d; series, today) -> Event

A copy of template `t` on day `d`: same times (offset recomputed for summer/winter time) and the same number of days
between start and end, id `<series>-YYYY-MM-DD`, status scheduled, `first_seen` today and no verification or crawl
dates.
"""
function repeat_event(t::Event, d::Date; series::String=_repeat_series(t), today::Date=Dates.today())
 s=something(_ymd(t.start),d)
 en=t.end_; en=isnothing(en) ? nothing : _move_stamp(en,d+Day(Dates.value(something(_ymd(en),s)-s)))
 e=_put(t,Val(:id),"$series-$(_ymd_str(d))"); e=_put(e,Val(:status),"scheduled"); e=_put(e,Val(:series),series)
 e=_put(e,Val(:start),_move_stamp(t.start,d)); e=_put(e,Val(:end_),en); e=_put(e,Val(:first_seen),_ymd_str(today))
 e=_put(e,Val(:published_date),nothing); e=_put(e,Val(:last_verified),nothing); _put(e,Val(:crawl_timestamp),nothing)
end
_put(x::Event,::Val{F},v) where {F}=Accessors.set(x,Accessors.PropertyLens{F}(),v)
"`ks` with key `k` added (if missing) after the nearest key that comes before it in the schema's order."
function _with_key(ks::Vector{String}, k::String)
 k in ks && return ks
 order=jsonkeys(Event); i=findfirst(==(k),order)
 for j in something(i,1)-1:-1:1
  p=findfirst(==(order[j]),ks); isnothing(p) || return insert!(copy(ks),p+1,k)
 end
 vcat([k],ks)
end
"""
    repeat_template(terms; root="events") -> (file, event, keys)

The event to copy: the only event matching all `terms` (past ones included), or the latest one when all matches
share one series, or the latest of the series a `series:` term names exactly. `ArgumentError` otherwise.
"""
function repeat_template(terms; root::AbstractString="events")
 found=find_events(terms;root,from=nothing)
 isempty(found) && throw(ArgumentError("no event matches $(join(terms," "))"))
 length(found)==1 && return found[1]
 ss=unique([x[2].series for x in found])
 length(ss)==1 && !isnothing(ss[1]) && return found[end]
 for t in terms   # series:esa also matches esa-tandas; the series named exactly wins
  st=t isa SearchTerm ? t : SearchTerm(t)
  st.key=="series" || continue
  exact=filter(x->lowercase(something(x[2].series,""))==st.text,found)
  isempty(exact) || return exact[end]
 end
 ids=[x[2].id for x in found]
 throw(ArgumentError("$(length(found)) events from different series match $(join(terms," ")); use a narrower term or the id: "*
  join(first(ids,10),", ")*(length(ids)>10 ? ", …" : "")))
end
"""
    repeat_events(terms, rule; root="events", count=nothing, until=nothing, start=nothing, except=[], edits=[],
                  today=today(), dry_run=false, tree_check=validate_event_tree) -> NamedTuple

Copy the template (`repeat_template(terms)`) to the dates of `rule` (`recurrence_dates`): after the template's date,
or from `start`, until `until`, or `count` new events; without either, until 6 months after `today`. `edits`
(`"key=value"`, see `set_path`) apply to every copy. Dates that already have the event (same id or file, or any event
of the series that day) are skipped.
Every copy must pass `check`; then the files are written unless `dry_run`, and `tree_check(root)` runs (rolling back
on problems). Returns `(template, keys, events, exists, excepted, written, errors)`, `events` as `(file, event)`.

    repeat_events(terms, dates::Vector{Date}; root="events", except=[], edits=[], today=today(), dry_run=false, …)

The same, on the given `dates` (any weekday) instead of a rule.
"""
function repeat_events(terms, rule::Recurrence; root::AbstractString="events", count::Union{Nothing,Int}=nothing,
                       until::Union{Nothing,Date}=nothing, start::Union{Nothing,Date}=nothing, except::Vector{Tuple{Date,Date}}=Tuple{Date,Date}[],
                       edits=String[], today::Date=Dates.today(), dry_run::Bool=false, tree_check::C=validate_event_tree) where {C}
 es=Tuple{Vector{String},String}[x isa AbstractString ? parse_edit(x) : (String.(collect(x[1])),String(x[2])) for x in edits]
 _repeat_events(terms,rule,Date[],String(root),something(count,0),something(until,_NO_DATE),something(start,_NO_DATE),except,es,today,dry_run,tree_check)
end
function repeat_events(terms, dates::Vector{Date}; root::AbstractString="events", except::Vector{Tuple{Date,Date}}=Tuple{Date,Date}[],
                       edits=String[], today::Date=Dates.today(), dry_run::Bool=false, tree_check::C=validate_event_tree) where {C}
 isempty(dates) && throw(ArgumentError("repeat_events needs at least one date"))
 es=Tuple{Vector{String},String}[x isa AbstractString ? parse_edit(x) : (String.(collect(x[1])),String(x[2])) for x in edits]
 _repeat_events(terms,Recurrence(:week,1,0,0),dates,String(root),0,_NO_DATE,_NO_DATE,except,es,today,dry_run,tree_check)
end
"Stands for «not given» in `_repeat_events`, whose arguments are concrete (unions in keyword calls don't trim)."
const _NO_DATE=Date(0)
function _repeat_events(terms, rule::Recurrence, ondates::Vector{Date}, root::String, count::Int, until::Date, start::Date, except::Vector{Tuple{Date,Date}},
                        es::Vector{Tuple{Vector{String},String}}, today::Date, dry_run::Bool, tree_check::C) where {C}
 _,t,ks=repeat_template(terms;root)
 anchor=something(_ymd(t.start),today)
 count==0 && until==_NO_DATE && (until=today+Month(6))
 from=start==_NO_DATE ? anchor+Day(1) : start
 dates,excepted=if isempty(ondates)
  recurrence_dates(rule,anchor;from,until=until==_NO_DATE ? Date(9999,12,31) : until,count=count==0 ? typemax(Int) : count,except)
 else
  ds=sort!(unique(ondates)); (filter(d->!_in_ranges(d,except),ds),filter(d->_in_ranges(d,except),ds))
 end
 series=_repeat_series(t)
 taken=Set{String}(); files=Set{String}(); days=Set{Date}()   # days: dates that already have an event of the series
 for (f,e,_) in find_events(String[];root,from=nothing)
  push!(taken,e.id); push!(files,normpath(f))
  e.series==series && (d=_ymd(e.start); isnothing(d) || push!(days,d))
 end
 keys_=ks; for k in ("status","series","first_seen"); keys_=_with_key(keys_,k); end
 out=Tuple{String,Event}[]; exists=Date[]; errs=String[]
 for d in dates
  e=repeat_event(t,d;series,today)
  for (p,v) in es; e=set_path(e,p,v)::Event; end
  f=event_path(e;root); id=e.id
  if id in taken || normpath(f) in files || d in days; push!(exists,d); continue; end
  for m in check(e); push!(errs,"$id: $m"); end
  push!(out,(f,e))
 end
 written=String[]
 if !dry_run && !isempty(out) && isempty(errs)
  ups=Tuple{Union{Nothing,String},String,String}[(nothing,f,event_text(e,keys_)) for (f,e) in out]
  written,errs=_write_files!(ups,root; check=tree_check)
 end
 (template=t,keys=keys_,events=out,exists,excepted,written,errors=errs)
end
const REPEAT_USAGE="""
tangokalender repeat - copy an event to new dates

Usage:
  tangokalender repeat TERM… --every=RULE [--on=WHICH-WEEKDAY] [--count=N | --until=DATE] [KEY=VALUE…] [options]
  tangokalender repeat TERM… --on=DATE[,DATE…] [KEY=VALUE…] [options]

TERM     finds the template, as in edit (past events included): it must match one event, or events of one series,
         of which the latest is copied (series:esa-tandas continues that series; an exact series name wins).
The copies get the template's times (summer/winter time recomputed), id <series>-YYYY-MM-DD, status scheduled and
first_seen today. Dates that already have the event, or any event of its series, are skipped, so running the same
command again is safe.
KEY=VALUE sets a key on every copy, as in edit (dj=null, price_nok=150).

Rules:
  --every=week|Nweeks       every week, every N weeks (2weeks), on the template's weekday
  --every=month|Nmonths     every month, every N months, on the template's day of the month (months without it,
                            e.g. the 31st, are skipped)
  --on=WHICH-WEEKDAY        with month rules: the Nth or Nth-last weekday instead: 1st-monday, 2nd-thursday,
                            last-friday, 2nd-last-sunday (months without a 5th … are skipped)
  --on=DATE[,DATE…]         instead of a rule: just these dates, on any weekday (2026-12-27); may be repeated

Options:
  --count=N         create N events (dates in --except don't count)
  --until=DATE      create events up to and including DATE (default without --count: 6 months from today)
  --start=DATE      first possible date (default: the day after the template); the rhythm stays the template's
  --except=DATES    skip dates: 2026-12-24 or a range 2026-12-21..2027-01-03, comma-separated; may be repeated
  --preview         show each new event as a card; writes nothing
  --dry-run         list the new events; writes nothing
  --root=DIR        the events directory (default: events)
"""
"""
    repeat_main(args; io=stdout, err=stderr, tree_check=validate_event_tree, render=styled_text, today=today()) -> exit code

The `repeat` subcommand (also `tangoedit repeat …`, through `edit_main`). 0 = done, 1 = a new event is invalid
(nothing written), 2 = usage error.
"""
function repeat_main(args::AbstractVector{<:AbstractString}; io::IO=stdout, err::IO=stderr, tree_check::C=validate_event_tree,
                     render::R=styled_text, today::Date=Dates.today()) where {C,R}
 usage(msg::String)=(println(err,msg,"\n"); print(err,REPEAT_USAGE); 2)
 fail(msg::String)=(println(err,msg); 2)
 terms=String[]; edits=String[]; root="events"; every=""; on=""; count=0; until=_NO_DATE; start=_NO_DATE
 except=Tuple{Date,Date}[]; dry=false; preview=false; ondates=Date[]
 for a in args
  if a in ("-h","--help"); print(io,REPEAT_USAGE); return 0
  elseif startswith(a,"--")
   kv=split(a[3:end],'=';limit=2); k=kv[1]; v=length(kv)==2 ? String(kv[2]) : ""
   if k=="root" && !isempty(v); root=v
   elseif k=="every" && !isempty(v); every=v
   elseif k=="on" && occursin(r"^[0-9]{4}-",v)
    for x in split(v,','; keepempty=false)
     d=_ymd(x); (isnothing(d) || length(x)!=10) && return usage("--on needs dates YYYY-MM-DD, got \"$x\""); push!(ondates,d)
    end
   elseif k=="on" && !isempty(v); on=v
   elseif k=="count" && !isempty(v)
    n=tryparse(Int,v); (isnothing(n) || n<1) && return usage("--count needs a whole number of at least 1, got \"$v\""); count=n
   elseif k in ("until","start") && !isempty(v)
    d=_ymd(v); (isnothing(d) || length(v)!=10) && return usage("--$k needs a date YYYY-MM-DD, got \"$v\"")
    k=="until" ? (until=d) : (start=d)
   elseif k=="except" && !isempty(v)
    try append!(except,parse_except(v)) catch ex; ex isa ArgumentError || rethrow(); return usage(ex.msg isa String ? ex.msg : "bad --except") end
   elseif k=="dry-run" && length(kv)==1; dry=true
   elseif k=="preview" && length(kv)==1; preview=true
   else return usage("unknown option $a") end
  elseif occursin('=',a); push!(edits,a)
  else push!(terms,a) end
 end
 isempty(terms) && return usage("repeat needs a search term for the template event")
 if !isempty(ondates)
  (!isempty(every) || !isempty(on) || count>0 || until!=_NO_DATE || start!=_NO_DATE) &&
   return usage("--on=DATE gives the dates itself; leave out --every, --on=WEEKDAY, --count, --until and --start")
 else
  isempty(every) && return usage("repeat needs --every=week, Nweeks, month or Nmonths, or --on=DATE")
 end
 count>0 && until!=_NO_DATE && return usage("use either --count or --until, not both")
 isdir(root) || return usage("no events directory \"$root\" (use --root=DIR)")
 rule=isempty(ondates) ? try
  unit,n=parse_every(every); nth,wd=isempty(on) ? (0,0) : parse_on(on)
  unit===:week && nth!=0 && throw(ArgumentError("--on goes with --every=month or Nmonths"))
  Recurrence(unit,n,nth,wd)
 catch ex; ex isa ArgumentError || rethrow(); return usage(ex.msg isa String ? ex.msg : "bad rule") end : Recurrence(:week,1,0,0)
 es=try Tuple{Vector{String},String}[parse_edit(x) for x in edits]
 catch ex; ex isa ArgumentError || rethrow(); return usage(ex.msg isa String ? ex.msg : "invalid edit") end
 res=try _repeat_events(terms,rule,ondates,root,count,until,start,except,es,today,dry || preview,tree_check)
 catch ex; ex isa ArgumentError || rethrow(); return fail(ex.msg isa String ? ex.msg : "invalid repeat") end
 w=displaysize(io)[2]
 show_(lines::Vector{Vector{Seg}})=println(io,render(lines))
 show_(Vector{Seg}[Seg[("Template:",:shadow)],line_segs(res.template;width=w)]); println(io)
 for (_,e) in res.events; preview ? (show_(card_lines(e;width=w)); println(io)) : show_([line_segs(e;width=w)]); end
 skipped=sort!(vcat([(d,"already there") for d in res.exists],[(d,"--except") for d in res.excepted]))
 isempty(skipped) || show_([Seg[("  $(_ymd_str(d)): skipped ($why)",:shadow)] for (d,why) in skipped])
 for (a,b) in except
  any(d->a<=d<=b,res.excepted) || println(err,"Warning: --except $(_ymd_str(a))$(a==b ? "" : ".."*_ymd_str(b)) matches no date of the rule.")
 end
 if !isempty(res.errors)
  foreach(m->println(err,m),res.errors); println(err,"Nothing written: $(length(res.errors)) problem(s)."); return 1
 end
 n=length(res.events)
 summary=n==0 ? "No new events: no dates in the range$(isempty(skipped) ? "" : " that aren't skipped")." :
  "$n event$(n==1 ? "" : "s") $(isempty(res.written) ? "would be created" : "created")"
 println(io,summary,n>0 && isempty(res.written) ? " (dry run: nothing written)." : n>0 ? "." : "")
 isnothing(res.template.series) && n>0 && println(io,"The template has no series; to join it: tangoedit $(res.template.id) series=$(_repeat_series(res.template))")
 0
end
