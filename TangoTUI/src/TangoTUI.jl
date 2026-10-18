"""
    TangoTUI

A full-screen editor for one event of a TangoKalender data repository, on Tachikoma.jl: the fields one by one with
their current values, a pick list where only some values are allowed, and a live preview card. Experimental, and
Julia only: Tachikoma can't be trimmed, so this is not part of the `tangoedit` executable. In a data repository:

    julia --project=PATH/TangoKalender.jl/TangoTUI -m TangoTUI [--all]              # search, then pick an event
    julia --project=PATH/TangoKalender.jl/TangoTUI -m TangoTUI edit TERM… [--all] [--root=events]
    julia --project=PATH/TangoKalender.jl/TangoTUI -m TangoTUI new [TERM…] [--root=events]

The form itself (fields, allowed values, reading and saving) is in TangoKalender (`form_fields`, `field_text`,
`set_field`, `save_form_event`), so another front end can share it.
"""
module TangoTUI
using Dates, Tachikoma, PrecompileTools
using TangoKalender
const TK=TangoKalender
@tachikoma_app

"""
A multi-line text with word wrap, for the long text fields (description) in a modal: `text` as characters, `cur`
the number of characters before the cursor, `top` the first visible wrapped line, `width` the wrap width last drawn.
"""
mutable struct WrapEditor
 text::Vector{Char}
 cur::Int
 top::Int
 width::Int
end
WrapEditor(s::AbstractString)=(t=collect(s); WrapEditor(t,length(t),0,60))
"""
The repeat panel (Ctrl-R, `repeat TERM…`): copies of `template` on the dates of a rule, as `tangoedit repeat`
(`TK.repeat_from`). The rule's fields are kept as typed (text) or as pick-list indices; `plan` is the last dry run.
"""
mutable struct RepeatForm
 template::TK.Event
 keys::Vector{String}
 group::Vector{TK.Event}          # the series the template is the latest of (for the holiday-special note), else empty
 saved::Bool                      # the template is in the tree: copies start the day after it; unsaved, on its own date
 back::Symbol                     # where Esc and a finished run go: :browse (the form) or :search (the list)
 rule::Int                        # 1 weekly, 2 monthly, 3 given dates
 every::String
 nth::Int                         # index into _NTH
 weekday::Int                     # 1 = Monday
 dates::String
 count::String
 until::String
 start::String
 except::String
 cursor::Int
 editing::Symbol                  # :none, :text, :pick
 input::TextInput
 pick::Int
 plan::Any                        # the NamedTuple from TK.repeat_from(…; dry_run=true), or nothing
 args::Any                        # the rule as read from the fields (keywords for TK.repeat_from), or nothing
 problem::String                  # a field that can't be read, in Norwegian
end
"The editor's state: the event before and after the edits, the form cursor and the current mode."
mutable struct Editor <: Model
 fields::Vector{TK.FormField}
 root::String
 today::Date
 tree_check::Function
 file::Union{Nothing,String}      # nothing: a new event, not saved yet
 keys::Vector{String}
 before::TK.Event
 event::TK.Event
 cursor::Int
 offset::Int
 mode::Symbol                     # :search, :browse, :text, :long, :pick, :confirm, :scope, :repeat, :spread
 input::TextInput
 pick::Int
 ticked::Vector{Bool}
 message::String
 level::Symbol                    # :info, :ok, :error
 quit::Bool
 saved::Vector{String}
 # the event list (:search): every event under `root` (file, event, keys), their search texts, the indices that
 # match `query` (upcoming only unless `past`), and whether the editor returns to the list (Esc) or quits
 events::Vector{Tuple{String,TK.Event,Vector{String}}}
 texts::Vector{String}
 hits::Vector{Int}
 query::TextInput
 past::Bool
 listoff::Int
 listing::Bool
 # changing several events (:scope): the search the event was opened from (its files and text), the changed fields,
 # and the later events of the series / of that selection, split by the organiser guardrail into targets and skipped
 selection::Vector{String}
 selquery::String
 scope::Vector{TK.FormField}
 sertargets::Vector{Tuple{String,TK.Event,Vector{String}}}
 serskip::Vector{Tuple{String,TK.Event,Vector{String}}}
 seltargets::Vector{Tuple{String,TK.Event,Vector{String}}}
 selskip::Vector{Tuple{String,TK.Event,Vector{String}}}
 then::Symbol
 rep::Union{Nothing,RepeatForm}   # the repeat panel (mode :repeat)
 long::WrapEditor                 # the long-text modal (mode :long)
 # copying this date's values to the later dates of its series (Ctrl-L, mode :spread): the fields that differ
 # (`TK.series_differences`), which are ticked, and the cursor; the targets are `sertargets`/`serskip`
 spread::Vector{Tuple{TK.FormField,Int,Union{Nothing,String}}}
 sticked::Vector{Bool}
 spick::Int
end
function Editor(file, e::TK.Event, keys::Vector{String}; root="events", today=Dates.today(), tree_check=TK.validate_event_tree)
 m=Editor(TK.form_fields(),root,today,tree_check,file,keys,e,e,1,0,:browse,TextInput(text=""),1,Bool[],"",:info,false,String[],
          Tuple{String,TK.Event,Vector{String}}[],String[],Int[],TextInput(text="",focused=true),false,0,false,
          String[],"",TK.FormField[],_none(),_none(),_none(),_none(),:stay,nothing,WrapEditor(""),Tuple{TK.FormField,Int,Union{Nothing,String}}[],Bool[],1)
 isnothing(file) && _new_id!(m)
 m
end
"""
    search_editor(; query="", past=false, root="events", today=today()) -> Editor

The editor on its event list: every event under `root`, filtered as you type `query` (upcoming only unless `past`).
"""
function search_editor(; query::AbstractString="", past::Bool=false, root="events", today::Date=Dates.today(), tree_check=TK.validate_event_tree)
 m=Editor(nothing,TK.new_event(;today),TK.new_event_keys();root,today,tree_check)
 m.query=TextInput(text=String(query),focused=true); m.past=past; m.listing=true
 _to_list!(m); m
end
should_quit(m::Editor)=m.quit
_none()=Tuple{String,TK.Event,Vector{String}}[]
_field(m::Editor)=m.fields[m.cursor]
"`file` relative to the folder that holds the events directory (`events/2026/…`)."
_rel(m::Editor,file)=relpath(file,dirname(abspath(m.root)))
_isnew(m::Editor)=isnothing(m.file)
_dirty(m::Editor)=_isnew(m) ? !isempty(m.event.title) : TK.event_text(m.event,m.keys)!=TK.event_text(m.before,m.keys)
_new_id!(m::Editor)=(_isnew(m) && (m.event=TK._put(m.event,Val(:id),TK.form_id(m.event))); nothing)
_say!(m::Editor,s::AbstractString,level::Symbol=:info)=(m.message=String(s); m.level=level; nothing)
function _load!(m::Editor,(file,e,ks))
 if m.mode===:search   # opened from the list: its result is the «selection» a change may also apply to
  m.selection=[m.events[i][1] for i in m.hits]; m.selquery=strip(text(m.query))
 else
  m.selection=String[]; m.selquery=""
 end
 m.file=file; m.event=m.before=e; m.keys=ks; m.cursor=1; m.offset=0; m.mode=:browse
 _say!(m,"Velg et felt med ↑/↓ og trykk Enter for å endre det.")
end
"A copy of `t` on today's date as a new event, with the date field open (`new TERM…`, Ctrl-K in the list)."
function _copy!(m::Editor,(f,t,ks))
 e=TK.repeat_event(t,m.today;today=m.today); e=TK._put(e,Val(:last_verified),TK._ymd_str(m.today))
 m.file=nothing; m.event=m.before=e; m.keys=TK._with_key(TK._with_key(ks,"first_seen"),"last_verified"); _new_id!(m)
 m.cursor=findfirst(f->f.key=="date",m.fields); m.offset=0
 m.input=TextInput(text=TK.field_text(e,m.fields[m.cursor]),focused=true); m.mode=:text
 _say!(m,"Kopi av $(t.id): skriv den nye datoen og trykk Enter.")
end
function _blank!(m::Editor)
 m.file=nothing; m.event=m.before=TK.new_event(;today=m.today); m.keys=TK.new_event_keys(); _new_id!(m)
 m.cursor=1; m.offset=0; m.mode=:browse; _say!(m,"Nytt arrangement: fyll ut feltene og lagre med Ctrl-S.")
end
_upcoming(m::Editor,e::TK.Event)=TK._lastday(e)>=m.today
"Filter the list by the query; keep the selected event if it is still there, else select the first upcoming one."
function _filter!(m::Editor; select::Union{Nothing,String}=nothing)
 cur=isnothing(select) && !isempty(m.hits) && m.pick<=length(m.hits) ? m.events[m.hits[m.pick]][1] : select
 q=text(m.query)
 m.hits=[i for (i,(_,e,_)) in enumerate(m.events) if (m.past || _upcoming(m,e)) && TK.search_matches(e,q;text=m.texts[i])]
 i=isnothing(cur) ? nothing : findfirst(j->m.events[j][1]==cur,m.hits)
 m.pick=something(i,findfirst(j->_upcoming(m,m.events[j][2]),m.hits),1)
 nothing
end
"(Re)load every event (files may have moved on save) and show the list."
function _to_list!(m::Editor; select::Union{Nothing,String}=nothing)
 m.events=TK.find_events(String[];root=m.root,from=nothing); m.texts=[TK.event_search_text(e) for (_,e,_) in m.events]
 m.mode=:search; _filter!(m;select)
 m.level===:ok || _say!(m,"Skriv for å søke; ↑/↓ og Enter åpner et arrangement.")   # keep «Lagret: …»
end
"Leave the form: back to the list when the editor came from it, else quit."
_leave!(m::Editor)=m.listing ? _to_list!(m;select=m.file) : (m.quit=true; nothing)

# ── Keys ──
_ctrl(ev::KeyEvent,c::Char)=ev.key===:ctrl && ev.char==c
_ch(ev::KeyEvent,c::Char)=ev.key===:char && ev.char==c
function update!(m::Editor, ev::KeyEvent)
 m.mode===:search ? _search_key!(m,ev) : m.mode===:text ? _text_key!(m,ev) : m.mode===:long ? _long_key!(m,ev) : m.mode===:pick ? _pick_key!(m,ev) :
 m.mode===:confirm ? _confirm_key!(m,ev) : m.mode===:scope ? _scope_key!(m,ev) : m.mode===:repeat ? _repeat_key!(m,ev) :
 m.mode===:spread ? _spread_key!(m,ev) : _browse_key!(m,ev)
 nothing
end
_move!(m::Editor,d::Int)=(m.cursor=clamp(m.cursor+d,1,length(m.fields)); nothing)
function _browse_key!(m::Editor, ev::KeyEvent)
 k=ev.key
 if k===:up || _ch(ev,'k'); _move!(m,-1)
 elseif k===:down || _ch(ev,'j') || k===:tab; _move!(m,1)
 elseif k===:backtab; _move!(m,-1)
 elseif k===:pageup; _move!(m,-10)
 elseif k===:pagedown; _move!(m,10)
 elseif k===:home; m.cursor=1
 elseif k===:end_key; m.cursor=length(m.fields)
 elseif k===:enter || k===:right || _ch(ev,' '); _begin_edit!(m)
 elseif k===:delete || k===:backspace; _apply!(m,_field(m).kind in (:choice,:multi) ? String[] : "")
 elseif _ctrl(ev,'s'); _save!(m)
 elseif _ctrl(ev,'r'); _repeat_form!(m)
 elseif _ctrl(ev,'l'); _spread!(m)
 elseif k===:escape || _ch(ev,'q') || k===:ctrl_c
  _dirty(m) ? (m.mode=:confirm; _say!(m,"Ulagrede endringer: lagre (s), forkast (f) eller fortsett å redigere (Esc)?",:error)) : _leave!(m)
 end
end
function _begin_edit!(m::Editor)
 f=_field(m)
 if f.kind in (:choice,:multi)
  vals=TK.field_values(m.event,f)
  m.ticked=[v in vals for (v,_) in f.choices]; m.pick=something(findfirst(m.ticked),1); m.mode=:pick
  _say!(m,f.kind===:multi ? "Mellomrom krysser av, Enter lagrer valget, Esc avbryter." : "Velg med ↑/↓ og Enter, Esc avbryter.")
 elseif f.kind===:longtext
  m.long=WrapEditor(TK.field_text(m.event,f)); m.mode=:long
  _say!(m,"Skriv i feltet; Enter gir linjeskift, Ctrl-S lagrer feltet, Esc avbryter.")
 else
  m.input=TextInput(text=TK.field_text(m.event,f),focused=true); m.mode=:text
  _say!(m,"Enter lagrer feltet, Tab går videre, Esc avbryter.")
 end
end
"""
The wrapped lines of `cs` at `width`, as character index ranges (newlines excluded; an empty paragraph is an empty
range): words move whole to the next line, a word longer than the line is cut.
"""
function _wrap_lines(cs::Vector{Char}, width::Int)
 w=max(width,2); out=UnitRange{Int}[]; n=length(cs); p=1
 while true
  q=something(findnext(==('\n'),cs,p),n+1)-1          # paragraph p..q
  a=p
  while q-a+1>w
   sp=findprev(==(' '),cs,a+w-1); b=isnothing(sp) || sp<a ? a+w-1 : sp
   push!(out,a:b); a=b+1
  end
  push!(out,a:q)
  q>=n && break
  p=q+2
 end
 out
end
"The wrapped line the cursor is on (the later one where two touch)."
_curline(ls,c::Int)=something(findlast(r->first(r)-1<=c,ls),1)
function _long_key!(m::Editor, ev::KeyEvent)
 w=m.long; t=w.text; k=ev.key; ls=_wrap_lines(t,w.width); i=_curline(ls,w.cur); col=w.cur-(first(ls[i])-1)
 soft(j)=j<length(ls) && first(ls[j+1])==last(ls[j])+1          # wrapped, not a line break: its end is the next line's start
 lastpos(j)=soft(j) ? last(ls[j])-1 : last(ls[j])
 vert(j)=(j=clamp(j,1,length(ls)); w.cur=min(first(ls[j])-1+col,lastpos(j)))
 if k===:escape; m.mode=:browse; _say!(m,"Avbrutt.")
 elseif _ctrl(ev,'s'); _apply!(m,String(t))
 elseif k===:char; insert!(t,w.cur+1,ev.char); w.cur+=1
 elseif k===:enter; insert!(t,w.cur+1,'\n'); w.cur+=1
 elseif k===:backspace; w.cur>0 && (deleteat!(t,w.cur); w.cur-=1)
 elseif k===:delete; w.cur<length(t) && deleteat!(t,w.cur+1)
 elseif k===:left; w.cur=max(0,w.cur-1)
 elseif k===:right; w.cur=min(length(t),w.cur+1)
 elseif k===:up; vert(i-1)
 elseif k===:down; vert(i+1)
 elseif k===:pageup; vert(i-8)
 elseif k===:pagedown; vert(i+8)
 elseif k===:home; w.cur=first(ls[i])-1
 elseif k===:end_key; w.cur=lastpos(i)
 end
 nothing
end
"Set the current field to `v` (text, or the chosen values); a value that can't be read stays in the editor."
function _apply!(m::Editor, v)
 f=_field(m)
 try m.event=TK.set_field(m.event,f,v) catch err
  err isa ArgumentError || rethrow(); _say!(m,err.msg,:error); return false
 end
 _new_id!(m); m.mode=:browse
 ps=TK.field_problems(m.event,f)
 isempty(ps) ? _say!(m,"«$(f.label)» endret. Ctrl-S lagrer.") : _say!(m,"«$(f.label)»: $(join(ps,"; "))",:error)
 true
end
function _text_key!(m::Editor, ev::KeyEvent)
 k=ev.key
 if k===:escape; m.mode=:browse; _say!(m,"Avbrutt.")
 elseif k===:enter; _apply!(m,text(m.input))
 elseif k===:tab || k===:backtab; _apply!(m,text(m.input)) && _move!(m,k===:tab ? 1 : -1)
 else handle_key!(m.input,ev) end
end
function _pick_key!(m::Editor, ev::KeyEvent)
 f=_field(m); n=length(f.choices); k=ev.key
 if k===:escape; m.mode=:browse; _say!(m,"Avbrutt.")
 elseif k===:up; m.pick=mod1(m.pick-1,n)
 elseif k===:down || k===:tab; m.pick=mod1(m.pick+1,n)
 elseif _ch(ev,' ') && f.kind===:multi; m.ticked[m.pick]=!m.ticked[m.pick]
 elseif k===:enter || _ch(ev,' ')
  _apply!(m,f.kind===:multi ? [v for ((v,_),t) in zip(f.choices,m.ticked) if t] : [f.choices[m.pick][1]])
 end
end
function _confirm_key!(m::Editor, ev::KeyEvent)
 if _ch(ev,'s') || _ctrl(ev,'s'); _save!(m;then=:leave)
 elseif _ch(ev,'f'); _leave!(m)
 else m.mode=:browse; _say!(m,"Fortsett å redigere.") end
end
function _search_key!(m::Editor, ev::KeyEvent)
 n=length(m.hits); k=ev.key; sel()=m.events[m.hits[m.pick]]
 if k===:up; m.pick=max(1,m.pick-1)
 elseif k===:down; m.pick=clamp(m.pick+1,1,max(1,n))
 elseif k===:pageup; m.pick=max(1,m.pick-10)
 elseif k===:pagedown; m.pick=clamp(m.pick+10,1,max(1,n))
 elseif k===:enter; n>0 ? _load!(m,sel()) : _say!(m,"Ingen arrangementer passer til søket.",:error)
 elseif _ctrl(ev,'a'); m.past=!m.past; _filter!(m); _say!(m,m.past ? "Viser også tidligere arrangementer." : "Viser bare kommende arrangementer.")
 elseif _ctrl(ev,'n'); _blank!(m)
 elseif _ctrl(ev,'k'); n>0 ? _copy!(m,sel()) : _say!(m,"Velg et arrangement å kopiere.",:error)
 elseif _ctrl(ev,'r'); n>0 ? _repeat!(m,sel()[2],sel()[3];saved=true,back=:search,group=_series_group(m,sel()[2])) : _say!(m,"Velg et arrangement å gjenta.",:error)
 elseif k===:escape; isempty(text(m.query)) ? (m.quit=true) : (set_text!(m.query,""); _filter!(m))
 elseif k===:ctrl_c; m.quit=true
 else
  q=text(m.query); handle_key!(m.query,ev); text(m.query)==q || _filter!(m)
 end
end
"""
Save. When fields of an existing event changed and later events of its series, or of the search it was opened from,
have the same organiser, ask first (:scope) whether the change applies to them too; `then=:leave` leaves the form
after saving.
"""
function _save!(m::Editor; then::Symbol=:stay)
 m.then=then
 if !_isnew(m) && isempty(TK.check(m.event))
  m.scope=TK.changed_fields(m.before,m.event;fields=m.fields)
  if !isempty(m.scope)
   m.sertargets,m.serskip=TK.split_by_organizer(m.before,TK.later_in_series(m.file,m.before;root=m.root))
   sel=isempty(m.selquery) ? _none() : TK.later_in_selection(m.file,m.before,m.selection;root=m.root)
   m.seltargets,m.selskip=TK.split_by_organizer(m.before,sel)
   if !isempty(m.sertargets) || !isempty(m.seltargets)
    m.mode=:scope; _say!(m,"Gjelder endringen flere datoer? Se valgene til høyre.")
    return false
   end
  end
 end
 _write!(m,_none())
end
_label(f::TK.FormField)=f.label
function _scope_keys(m::Editor)
 ks=String[]
 isempty(m.sertargets) || push!(ks,"a alle senere i serien"); isempty(m.seltargets) || push!(ks,"u alle senere i utvalget")
 join([ks;"d bare denne datoen";"Esc avbryt"]," · ")
end
"How many of `xs` have their own value (different from the edited event's old one) in a changed field: it is overwritten."
_overwrites(m::Editor,xs)=count(x->any(f->!TK.same_field(x[2],m.before,f),m.scope),xs)
function _scope_key!(m::Editor, ev::KeyEvent)
 if _ch(ev,'a') && !isempty(m.sertargets); _write!(m,m.sertargets)
 elseif _ch(ev,'u') && !isempty(m.seltargets); _write!(m,m.seltargets)
 elseif _ch(ev,'d'); _write!(m,_none())
 elseif ev.key===:escape; m.mode=:browse; _say!(m,"Ikke lagret.")
 end
end
"Write the event, and `later` with the changed fields copied (`TK.copy_fields`), all in one go."
function _write!(m::Editor, later)
 others=_none()
 for (f,x,ks) in later
  y=try TK.copy_fields(x,m.event,m.scope) catch err
   err isa ArgumentError || rethrow(); m.mode=:browse; _say!(m,"Ikke lagret: $(x.id): $(err.msg)",:error); return false
  end
  push!(others,(f,y,ks))
 end
 file,errs=TK.save_form_event(m.file,m.event,m.keys;root=m.root,today=m.today,tree_check=m.tree_check,others)
 if isnothing(file)
  ps=TK.check(m.event); i=findfirst(f->!isempty(TK.field_problems(m.event,f;problems=ps)),m.fields)
  isnothing(i) || (m.cursor=i)
  _say!(m,"Ikke lagret: $(first(errs))$(length(errs)>1 ? " (+$(length(errs)-1) til)" : "")",:error); m.mode=:browse
  return false
 end
 e,ks=TK.read_event(file); m.file=file; m.event=m.before=e; m.keys=ks; m.mode=:browse
 for f in [file;[x[1] for x in others]]; f in m.saved || push!(m.saved,f); end
 n=length(others)
 _say!(m,"Lagret: $(_rel(m,file))"*(n==0 ? "" : " og $n senere dato$(n==1 ? "" : "er")"),:ok)
 m.then===:leave && _leave!(m)
 true
end

# ── This date's values to the later dates (Ctrl-L): when a correction was made for one date but meant for the series ──
"""
Open the panel that copies fields of this (saved) event to the later dates of its series: the fields where they
differ, pre-ticked where every later date still has one other value (the old one), never Status; within the
organiser guardrail.
"""
function _spread!(m::Editor)
 _isnew(m) && return _say!(m,"Lagre arrangementet først.",:error)
 _dirty(m) && return _say!(m,"Lagre endringene først (Ctrl-S): da spør TangoTUI om de også gjelder senere datoer.",:error)
 isnothing(m.event.series) && return _say!(m,"Arrangementet er ikke del av en serie.",:error)
 later=TK.later_in_series(m.file,m.event;root=m.root)
 isempty(later) && return _say!(m,"Ingen senere datoer i serien «$(m.event.series)».",:error)
 m.sertargets,m.serskip=TK.split_by_organizer(m.event,later)
 isempty(m.sertargets) && return _say!(m,"De senere datoene har en annen arrangør; ingenting å endre.",:error)
 m.spread=TK.series_differences(m.event,m.sertargets)
 isempty(m.spread) && return _say!(m,"Alle senere datoer har allerede de samme verdiene som denne.",:ok)
 m.sticked=[!isnothing(sh) && f.key!="status" for (f,_,sh) in m.spread]; m.spick=1; m.mode=:spread
 _say!(m,"Kryss av feltene som skal gjelde alle senere datoer, og trykk Enter.")
end
function _spread_key!(m::Editor, ev::KeyEvent)
 n=length(m.spread); k=ev.key
 if k===:up; m.spick=mod1(m.spick-1,n)
 elseif k===:down || k===:tab; m.spick=mod1(m.spick+1,n)
 elseif _ch(ev,' '); m.sticked[m.spick]=!m.sticked[m.spick]
 elseif k===:enter || _ctrl(ev,'s')
  m.scope=[f for ((f,_,_),t) in zip(m.spread,m.sticked) if t]
  isempty(m.scope) && return _say!(m,"Kryss av minst ett felt (Mellomrom), eller avbryt med Esc.",:error)
  m.then=:stay; _write!(m,m.sertargets)
 elseif k===:escape || k===:ctrl_c; m.mode=:browse; _say!(m,"Ingenting endret.")
 end
 nothing
end
_spread_keys()="↑/↓ felt · Mellomrom kryss av · Enter kopier til senere datoer · Esc avbryt"

# ── Repeat (Ctrl-R): copies on the dates of a rule, with a live list of the dates ──
const _RULES=["Ukentlig","Månedlig","Bestemte datoer"]
const _NTH=[(0,""),(1,"1."),(2,"2."),(3,"3."),(4,"4."),(5,"5."),(-1,"siste"),(-2,"nest siste"),(-3,"3. siste"),(-4,"4. siste"),(-5,"5. siste")]
const _UKEDAGER=["mandag","tirsdag","onsdag","torsdag","fredag","lørdag","søndag"]
# (key, label, kind, help): the panel's fields, in order
const _RFIELDS=[
 (:rule,"Regel",:pick,"Ukentlig og månedlig følger malens ukedag og dato; «Bestemte datoer» tar en liste med datoer."),
 (:every,"Hver",:text,"1 = hver uke/måned, 2 = annenhver, 3 = hver tredje … (i takt med malens dato)."),
 (:nth,"Dag i måneden",:pick,"Malens dato i måneden, eller N-te / N-te siste ukedag (måneder uten den hoppes over)."),
 (:weekday,"Ukedag",:pick,"Ukedagen for «Dag i måneden»."),
 (:dates,"Datoer",:text,"Datoer skilt med komma, hvilken som helst ukedag: 2026-12-27, 03.01.2027."),
 (:count,"Antall",:text,"Antall nye arrangementer (unntatte datoer teller ikke). Tomt: «Til og med» bestemmer."),
 (:until,"Til og med",:text,"Siste mulige dato. Tomt og uten antall: 6 måneder fram."),
 (:start,"Fra og med",:text,"Første mulige dato (tomt: dagen etter malen). Rytmen følger fortsatt malen."),
 (:except,"Unntatt",:text,"Hopp over datoer: 2026-12-24, eller perioder 2026-12-21..2027-01-03, skilt med komma."),
]
"Whether field `k` applies to the chosen rule (others are dimmed and skipped)."
function _rapplies(r::RepeatForm,k::Symbol)
 k in (:rule,:except) && return true
 r.rule==3 && return k===:dates
 k===:dates && return false
 k===:nth && return r.rule==2
 k===:weekday && return r.rule==2 && _NTH[r.nth][1]!=0
 true
end
_tday(r::RepeatForm)=something(TK._ymd(r.template.start),Date(2000,1,1))
_nthlabel(r::RepeatForm,i::Int)=i==1 ? "samme dato ($(day(_tday(r))).)" : _NTH[i][2]
function _rchoices(r::RepeatForm,k::Symbol)
 k===:rule ? _RULES : k===:weekday ? _UKEDAGER : [_nthlabel(r,i) for i in eachindex(_NTH)]
end
_rpicked(r::RepeatForm,k::Symbol)=k===:rule ? r.rule : k===:weekday ? r.weekday : r.nth
function _rtext(r::RepeatForm,k::Symbol)
 k===:every ? r.every : k===:dates ? r.dates : k===:count ? r.count : k===:until ? r.until : k===:start ? r.start : r.except
end
function _rset!(r::RepeatForm,k::Symbol,v)
 k===:rule ? (r.rule=v) : k===:nth ? (r.nth=v) : k===:weekday ? (r.weekday=v) : k===:every ? (r.every=v) : k===:dates ? (r.dates=v) :
 k===:count ? (r.count=v) : k===:until ? (r.until=v) : k===:start ? (r.start=v) : (r.except=v)
 nothing
end
"The value as shown in the panel (with what an empty field means)."
function _rshow(m::Editor,r::RepeatForm,k::Symbol)
 kind=_RFIELDS[findfirst(f->f[1]===k,_RFIELDS)][3]
 kind===:pick && return k===:nth ? _nthlabel(r,r.nth) : _rchoices(r,k)[_rpicked(r,k)]
 v=strip(_rtext(r,k)); !isempty(v) && return k===:every ? "$v"*_every_hint(v,r.rule) : String(v)
 k===:every ? "1 (hver gang)" : k===:until ? (isempty(strip(r.count)) ? "– (6 måneder: $(TK._ymd_str(m.today+Month(6))))" : "–") :
  k===:start ? "– ($(r.saved ? "dagen etter malen" : "malens dato"))" : "–"
end
function _every_hint(v,rule)
 n=tryparse(Int,v); unit=rule==2 ? "måned" : "uke"
 isnothing(n) ? "" : n==1 ? " (hver $unit)" : n==2 ? " (annenhver $unit)" : " (hver $n. $unit)"
end
"Dates in `s` (comma or space separated, YYYY-MM-DD or DD.MM.YYYY), or a Norwegian error."
function _rdates(s::AbstractString)
 ds=Date[]
 for x in split(s,[',',' ',';'];keepempty=false)
  d=TK._date(x); isnothing(d) && return "«$x» er ikke en dato (2026-12-27 eller 27.12.2026)"; push!(ds,d)
 end
 ds
end
_rdate(s::AbstractString,label)=(d=TK._date(s); isnothing(d) ? "$label: «$(strip(s))» er ikke en dato (2026-12-27 eller 27.12.2026)" : d)
"The series events when `e` is the latest of its series (as `repeat TERM` picks it), for the holiday-special note."
function _series_group(m::Editor,e::TK.Event)
 isnothing(e.series) && return TK.Event[]
 g=TK.Event[x for (_,x,_) in m.events if x.series==e.series]
 !isempty(g) && last(g).id==e.id ? g : TK.Event[]
end
"Open the repeat panel for template `t` (keys `ks`)."
function _repeat!(m::Editor,t::TK.Event,ks::Vector{String}; saved::Bool, back::Symbol, group::Vector{TK.Event}=TK.Event[])
 d=something(TK._ymd(t.start),m.today)
 m.rep=RepeatForm(t,ks,group,saved,back,1,"",1,dayofweek(d),"","","","","",1,:none,TextInput(text=""),1,nothing,nothing,"")
 m.mode=:repeat; _replan!(m)
 _say!(m,"Gjenta $(t.id): velg regel og periode; datoene vises til høyre. Ctrl-S lager dem.")
end
"Ctrl-R in the form: the event as it stands in the form is the template (changed fields included)."
function _repeat_form!(m::Editor)
 ps=TK.check(m.event)
 isempty(ps) || return _say!(m,"Kan ikke gjenta før skjemaet er gyldig: $(first(ps))",:error)
 _repeat!(m,m.event,m.keys;saved=!_isnew(m),back=:browse,group=_isnew(m) || _dirty(m) ? TK.Event[] : _series_group(m,m.event))
end
"Read the fields and run the repeat as a dry run; a field that can't be read goes to `problem`."
function _replan!(m::Editor)
 r=m.rep; r.plan=nothing; r.args=nothing; r.problem=""
 fail(s)=(r.problem=s; nothing)
 n=1; if !isempty(strip(r.every)); x=tryparse(Int,strip(r.every)); (isnothing(x) || x<1) && return fail("Hver: skriv et helt tall, minst 1"); n=x; end
 count=nothing; if r.rule!=3 && !isempty(strip(r.count)); x=tryparse(Int,strip(r.count)); (isnothing(x) || x<1) && return fail("Antall: skriv et helt tall, minst 1"); count=x; end
 until=nothing; if r.rule!=3 && !isempty(strip(r.until)); x=_rdate(r.until,"Til og med"); x isa String && return fail(x); until=x; end
 start=nothing; if r.rule!=3 && !isempty(strip(r.start)); x=_rdate(r.start,"Fra og med"); x isa String && return fail(x); start=x; end
 !isnothing(count) && !isnothing(until) && return fail("Velg enten «Antall» eller «Til og med», ikke begge.")
 r.saved || !isnothing(start) || r.rule==3 || (start=_tday(r))   # an unsaved template: its own date is one of the copies
 iso=replace(r.except,r"\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b"=>s->(d=TK._date(s); isnothing(d) ? s : TK._ymd_str(d)))
 except=try TK.parse_except(replace(iso,' '=>"")) catch err
  err isa ArgumentError || rethrow(); return fail("Unntatt: skriv datoer (2026-12-24) eller perioder (2026-12-21..2027-01-03), skilt med komma")
 end
 dates=Date[]
 if r.rule==3
  x=_rdates(r.dates); x isa String && return fail("Datoer: $x"); dates=x
  isempty(dates) && return fail("Skriv inn datoene i «Datoer».")
 end
 rule=r.rule==3 ? nothing : TK.Recurrence(r.rule==1 ? :week : :month,n,r.rule==2 ? _NTH[r.nth][1] : 0,r.weekday)
 r.args=(;rule,dates,count,until,start,except)
 r.plan=try TK.repeat_from(r.template,r.keys;r.args...,root=m.root,today=m.today,dry_run=true)
 catch err
  err isa ArgumentError || rethrow(); return fail(err.msg isa String ? err.msg : "kan ikke gjenta")
 end
 nothing
end
"Norwegian note when the template is the latest of its series but unlike most of it (a holiday special)."
function _rnote(r::RepeatForm)
 ow,ot,u=TK._template_oddity(r.template,r.group); isnothing(u) && return ""
 what=join([x for x in (ow ? "en annen ukedag" : "",ot ? "en annen tittel" : "") if !isempty(x)]," og ")
 "Merk: malen er den siste i serien, men har $what enn de fleste. Vanlig: $(u.id) – velg den i listen og trykk Ctrl-R for å kopiere den i stedet."
end
_rmove!(r::RepeatForm,d::Int)=(i=r.cursor; for _ in 1:length(_RFIELDS); i=mod1(i+d,length(_RFIELDS)); _rapplies(r,_RFIELDS[i][1]) && break; end; r.cursor=i; nothing)
function _repeat_key!(m::Editor,ev::KeyEvent)
 r=m.rep; (k,label,kind,_)=_RFIELDS[r.cursor]; key=ev.key
 if r.editing===:text
  if key===:escape; r.editing=:none
  elseif key in (:enter,:tab,:backtab)
   _rset!(r,k,text(r.input)); r.editing=:none; _replan!(m)
   key===:tab ? _rmove!(r,1) : key===:backtab ? _rmove!(r,-1) : nothing
  else handle_key!(r.input,ev) end
 elseif r.editing===:pick
  n=length(_rchoices(r,k))
  if key===:escape; r.editing=:none
  elseif key===:up; r.pick=mod1(r.pick-1,n)
  elseif key===:down || key===:tab; r.pick=mod1(r.pick+1,n)
  elseif key===:enter || _ch(ev,' '); _rset!(r,k,r.pick); r.editing=:none; _replan!(m)
  end
 elseif key===:up || key===:backtab; _rmove!(r,-1)
 elseif key===:down || key===:tab; _rmove!(r,1)
 elseif key===:enter || key===:right || _ch(ev,' ')
  if kind===:pick; r.pick=_rpicked(r,k); r.editing=:pick
  else r.input=TextInput(text=_rtext(r,k),focused=true); r.editing=:text end
 elseif key===:delete || key===:backspace
  kind===:text ? _rset!(r,k,"") : _rset!(r,k,k===:weekday ? dayofweek(_tday(r)) : 1); _replan!(m)
 elseif _ctrl(ev,'s'); _run_repeat!(m)
 elseif key===:escape || key===:ctrl_c; _repeat_back!(m); _say!(m,"Ingenting laget.")
 end
 nothing
end
function _repeat_back!(m::Editor)
 back=m.rep.back; m.rep=nothing
 back===:search ? _to_list!(m) : (m.mode=:browse; nothing)
end
"Ctrl-S in the panel: write the copies (all or nothing, checked like `tangoedit repeat`)."
function _run_repeat!(m::Editor)
 r=m.rep; _replan!(m)
 isempty(r.problem) || return _say!(m,r.problem,:error)
 p=r.plan; isempty(p.errors) || return _say!(m,"Ikke laget: $(first(p.errors))",:error)
 isempty(p.events) && return _say!(m,"Ingen nye datoer å lage.",:error)
 res=TK.repeat_from(r.template,r.keys;r.args...,root=m.root,today=m.today,tree_check=m.tree_check)
 isempty(res.errors) || return _say!(m,"Ikke laget: $(first(res.errors))",:error)
 for f in res.written; f in m.saved || push!(m.saved,f); end
 ds=[TK._ymd(e.start) for (_,e) in res.events]
 msg="Laget $(length(res.written)) arrangement$(length(res.written)==1 ? "" : "er"): $(_dmy(first(ds)))"*(length(ds)>1 ? " – $(_dmy(last(ds)))" : "")
 unsaved=!r.saved; back=r.back; m.rep=nothing
 _say!(m,msg,:ok)
 if back===:search || (unsaved && m.listing); _to_list!(m)
 elseif unsaved; m.quit=true        # `new TERM` + Ctrl-R: the form's event is now one of the copies
 else m.mode=:browse end
end
_dmy(d)=isnothing(d) ? "" : "$(TK._two(day(d))).$(TK._two(month(d))).$(year(d))"
function _repeat_keys(r::RepeatForm)
 r.editing===:text ? "Enter lagre feltet · Tab neste · Esc avbryt" :
 r.editing===:pick ? "↑/↓ flytt · Enter velg · Esc avbryt" :
 "↑/↓ felt · Enter endre · Del tøm · Ctrl-S lag arrangementene · Esc avbryt"
end

# ── View ──
const _LABEL_W=26
"Tachikoma styles for the terminal card's faces (render/term.jl)."
function _style(face::Symbol)
 face===:bold ? tstyle(:text_bright,bold=true) : face===:italic ? tstyle(:text,italic=true) : face===:shadow ? tstyle(:text_dim) :
 face===:tangokalender_date ? tstyle(:accent,bold=true) : face===:tangokalender_chip ? tstyle(:primary,bold=true) :
 face===:tangokalender_cancelchip ? tstyle(:error,bold=true) : face===:tangokalender_cancelled ? tstyle(:text,bold=true,strikethrough=true) :
 face===:tangokalender_new ? tstyle(:warning,bold=true) : face===:tangokalender_old ? tstyle(:text_dim,strikethrough=true) :
 face===:problem ? tstyle(:error) : tstyle(:text)
end
_short(s::AbstractString,n::Int)=n<=0 ? "" : textwidth(s)<=n ? String(s) : (t=String(s); while textwidth(t)>n-1; t=chop(t); end; t*"…")
function view(m::Editor, frame::Frame)
 buf=frame.buffer; area=frame.area
 rows=split_layout(Layout(Vertical,[Fixed(1),Fill(),Fixed(3)]),area)
 length(rows)<3 && return
 head=m.mode===:search ? "tangoedit · finn et arrangement" :
  m.mode===:repeat ? "tangoedit · gjenta $(m.rep.template.id)" :
  _isnew(m) ? "tangoedit · nytt arrangement · $(m.event.id)" : "tangoedit · $(_rel(m,m.file))"
 set_string!(buf,rows[1].x,rows[1].y,_short(head,rows[1].width),tstyle(:title,bold=true))
 if m.mode===:search
  _view_list(m,rows[2],buf)
 else
  body=rows[2]
  wide=body.width>=110
  parts=split_layout(Layout(wide ? Horizontal : Vertical,wide ? [Percent(52),Fill()] : [Fill(),Percent(45)]),body)
  if m.mode===:repeat
   _view_repeat(m,parts[1],buf); length(parts)>1 && _view_plan(m,parts[2],buf)
   m.rep.editing===:pick && _view_rpick(m.rep,parts[1],buf)
   _view_footer(m,rows[3],buf); return
  end
  _view_fields(m,parts[1],buf)
  length(parts)>1 && _view_card(m,parts[2],buf)
  m.mode===:pick && _view_pick(m,parts[1],buf)
  m.mode===:scope && length(parts)>1 && _view_scope(m,parts[2],buf)
  m.mode===:spread && length(parts)>1 && _view_spread(m,parts[2],buf)
  m.mode===:long && _view_long(m,body,buf)
 end
 _view_footer(m,rows[3],buf)
end
function _view_fields(m::Editor, rect::Rect, buf::Buffer)
 blk=Block(title="Felter",title_right=_dirty(m) ? "● endret" : "",title_right_style=tstyle(:warning,bold=true),
           border_style=m.mode in (:browse,:text) ? tstyle(:border_focus) : tstyle(:border))
 render(blk,rect,buf); r=inner_area(blk,rect); h=r.height; h<=0 && return
 m.offset=clamp(m.offset,max(0,m.cursor-h),m.cursor-1)
 ps=TK.check(m.event)
 for (i,f) in enumerate(m.fields)
  y=r.y+i-1-m.offset; (y<r.y || y>bottom(r)) && continue
  cur=i==m.cursor; val=TK.field_text(m.event,f); old=TK.field_text(m.before,f)
  bad=!isempty(TK.field_problems(m.event,f;problems=ps)); changed=!_isnew(m) && val!=old
  mark=bad ? "!" : changed ? "●" : " "
  set_string!(buf,r.x,y,cur ? "›" : " ",tstyle(:accent,bold=true),r)
  set_string!(buf,r.x+1,y,mark,bad ? tstyle(:error,bold=true) : tstyle(:warning,bold=true),r)
  set_string!(buf,r.x+3,y,_short(f.label,_LABEL_W-1),cur ? tstyle(:accent,bold=true) : tstyle(:text_dim),r)
  vx=r.x+3+_LABEL_W; vw=right(r)-vx+1
  if cur && m.mode===:text
   render(m.input,Rect(vx,y,max(vw,1),1),buf)
  else
   shown=isempty(val) ? "–" : replace(val,'\n'=>" ⏎ ")
   st=isempty(val) ? tstyle(:text_dim) : bad ? tstyle(:error) : changed ? tstyle(:warning,bold=true) : tstyle(:text)
   set_string!(buf,vx,y,_short(shown,vw),st,r)
  end
 end
end
function _view_card(m::Editor, rect::Rect, buf::Buffer)
 blk=Block(title="Forhåndsvisning"); render(blk,rect,buf); r=inner_area(blk,rect)
 r.width<10 && return
 lines=TK.card_lines(m.event;before=_isnew(m) ? nothing : m.before,width=r.width)
 ps=TK.check(m.event)
 isempty(ps) || (push!(lines,TK.Seg[]); push!(lines,TK.Seg[("Problemer:",:tangokalender_cancelchip)]); append!(lines,[TK.Seg[("• "*p,:problem)] for p in ps]))
 for (i,l) in enumerate(lines)
  y=r.y+i-1; y>bottom(r) && break
  x=r.x
  for (t,face) in l
   x>right(r) && break
   set_string!(buf,x,y,t,_style(face),r)
   x+=textwidth(t)
  end
 end
end
"The Ctrl-L panel: the fields that differ on later dates (ticked ones are copied), the dates, and the guardrail's skips."
function _view_spread(m::Editor, rect::Rect, buf::Buffer)
 for yy in rect.y:bottom(rect); set_string!(buf,rect.x,yy," "^rect.width,tstyle(:text)); end
 blk=Block(title="Til senere datoer i serien «$(something(m.event.series,""))»",border_style=tstyle(:border_focus)); render(blk,rect,buf); r=inner_area(blk,rect)
 lines=Tuple{String,Style}[]; add(t,st=tstyle(:text))=push!(lines,(t,st))
 nt=length(m.sertargets)
 add("Felt der senere datoer er annerledes enn denne:",tstyle(:text_dim))
 for (i,(f,n,sh)) in enumerate(m.spread)
  v=TK.field_text(m.event,f); v=isempty(v) ? "–" : replace(v,'\n'=>" ⏎ ")
  others=isnothing(sh) ? "$n av $nt har andre verdier" : "alle $nt har «$(_short(isempty(sh) ? "–" : replace(sh,'\n'=>" "),24))»"
  add((i==m.spick ? "› " : "  ")*(m.sticked[i] ? "[x] " : "[ ] ")*rpad(_short(f.label,18),19)*_short(v,28)*"   ($others)",
      i==m.spick ? tstyle(:accent,bold=true) : m.sticked[i] ? tstyle(:text) : tstyle(:text_dim))
 end
 add("")
 short(x)=(e=x[2]; d=TK._ymd(e.start); (isnothing(d) ? e.start : "$(TK._wd3(d)) $(TK._two(day(d))).$(TK._two(month(d)))")*"  "*e.title)
 add("Gjelder $nt senere dato$(nt==1 ? "" : "er"):",tstyle(:accent,bold=true))
 for x in first(m.sertargets,6); add("   "*short(x)); end
 nt>6 && add("   … og $(nt-6) til",tstyle(:text_dim))
 isempty(m.serskip) || add("Hoppes over, annen arrangør: $(length(m.serskip)) ("*join(unique(something(x[2].organizer,"uten arrangør") for x in m.serskip),", ")*")",tstyle(:error))
 add(""); add("Avkrysset der alle senere datoer har den samme, gamle verdien.",tstyle(:text_dim))
 for (i,(t,st)) in enumerate(lines); y=r.y+i-1; y>bottom(r) && break; set_string!(buf,r.x+1,y,_short(t,r.width-1),st,r); end
end
"The scope question: the changed fields, each choice with its dates, and the events the guardrail leaves out."
function _view_scope(m::Editor, rect::Rect, buf::Buffer)
 for yy in rect.y:bottom(rect); set_string!(buf,rect.x,yy," "^rect.width,tstyle(:text)); end
 blk=Block(title="Gjelder endringen flere datoer?",border_style=tstyle(:border_focus)); render(blk,rect,buf); r=inner_area(blk,rect)
 lines=Tuple{String,Style}[]
 add(t,st=tstyle(:text))=push!(lines,(t,st))
 add("Endret: "*join(_label.(m.scope),", "),tstyle(:warning,bold=true)); add("")
 short(x)=(e=x[2]; d=TK._ymd(e.start); (isnothing(d) ? e.start : "$(TK._wd3(d)) $(TK._two(day(d))).$(TK._two(month(d)))")*"  "*e.title)
 function choice(key,what,xs,skip)
  isempty(xs) && isempty(skip) && return
  if isempty(xs); add("   $what: ingen med samme arrangør",tstyle(:text_dim))
  else
   o=_overwrites(m,xs)
   add("$key  $what: $(length(xs)) dato$(length(xs)==1 ? "" : "er")"*(o>0 ? " – $o har egen verdi som overskrives" : ""),tstyle(:accent,bold=true))
   for x in first(xs,6); add("     "*short(x)*(any(f->!TK.same_field(x[2],m.before,f),m.scope) ? "  (egen verdi)" : "")); end
   length(xs)>6 && add("     … og $(length(xs)-6) til",tstyle(:text_dim))
  end
  isempty(skip) || add("   Hoppes over, annen arrangør: $(length(skip)) ("*join(unique(something(x[2].organizer,"uten arrangør") for x in skip),", ")*")",tstyle(:error))
  add("")
 end
 choice("a","Alle senere i serien «$(something(m.before.series,""))»",m.sertargets,m.serskip)
 choice("u","Alle senere i utvalget «$(m.selquery)»",m.seltargets,m.selskip)
 add("d  Bare denne datoen",tstyle(:accent,bold=true)); add("Esc  Avbryt (ingenting lagres)",tstyle(:text_dim))
 for (i,(t,st)) in enumerate(lines); y=r.y+i-1; y>bottom(r) && break; set_string!(buf,r.x+1,y,_short(t,r.width-1),st,r); end
end
"The long-text modal: the field's text wrapped to the window, the cursor kept in view, and its length."
function _view_long(m::Editor, under::Rect, buf::Buffer)
 f=_field(m); w=m.long
 mw=min(under.width-4,100); mh=min(under.height-2,max(12,under.height*2÷3))
 (mw<20 || mh<5) && return
 r=Rect(under.x+(under.width-mw)÷2,under.y+(under.height-mh)÷2,mw,mh)
 for yy in r.y:bottom(r); set_string!(buf,r.x,yy," "^r.width,tstyle(:text)); end
 n=length(w.text)
 blk=Block(title=f.label,title_right="$n tegn",title_right_style=tstyle(:text_dim),border_style=tstyle(:border_focus))
 render(blk,r,buf); ir=inner_area(blk,r)
 tr=Rect(ir.x+1,ir.y,ir.width-2,ir.height-2); (tr.width<2 || tr.height<1) && return
 set_string!(buf,ir.x+1,bottom(ir),_short(f.help,ir.width-2),tstyle(:text_dim),ir)
 w.width=tr.width-1                                           # room for the cursor after the last character
 ls=_wrap_lines(w.text,w.width); i=_curline(ls,w.cur)
 w.top=clamp(w.top,max(0,i-tr.height),i-1)
 cst=Style(; fg=Color256(0), bg=tstyle(:accent).fg)
 for (row,li) in enumerate(w.top+1:min(length(ls),w.top+tr.height))
  y=tr.y+row-1; seg=ls[li]
  set_string!(buf,tr.x,y,String(w.text[seg]),tstyle(:text),tr)
  if li==i
   c=w.cur-(first(seg)-1); ch=w.cur+1<=last(seg) ? string(w.text[w.cur+1]) : " "
   set_string!(buf,tr.x+c,y,ch,cst,tr)
  end
 end
end
function _view_pick(m::Editor, under::Rect, buf::Buffer)
 f=_field(m); n=length(f.choices)
 w=min(under.width-4,max(30,maximum(textwidth(l) for (_,l) in f.choices)+10)); h=n+2
 y=clamp(under.y+m.cursor-m.offset+1,under.y,max(under.y,bottom(under)-h+1))
 r=Rect(under.x+_LABEL_W÷2,y,w,h)
 for yy in r.y:bottom(r); set_string!(buf,r.x,yy," "^r.width,tstyle(:text)); end
 render(Block(title=f.label,border_style=tstyle(:border_focus)),r,buf)
 for (i,(v,l)) in enumerate(f.choices)
  box=f.kind===:multi ? (m.ticked[i] ? "[x] " : "[ ] ") : (m.pick==i ? "(•) " : "( ) ")
  set_string!(buf,r.x+2,r.y+i,(i==m.pick ? "› " : "  ")*box*l,i==m.pick ? tstyle(:accent,bold=true) : tstyle(:text),r)
 end
end
"The repeat panel's fields (left): the rule, dimmed where it doesn't apply."
function _view_repeat(m::Editor, rect::Rect, buf::Buffer)
 r=m.rep
 blk=Block(title="Gjenta «$(r.template.title)»",border_style=tstyle(:border_focus)); render(blk,rect,buf); ir=inner_area(blk,rect)
 ir.height<=0 && return
 for (i,(k,label,_,_)) in enumerate(_RFIELDS)
  y=ir.y+i-1; y>bottom(ir) && break
  on=_rapplies(r,k); cur=i==r.cursor
  set_string!(buf,ir.x,y,cur ? "›" : " ",tstyle(:accent,bold=true),ir)
  set_string!(buf,ir.x+3,y,_short(label,_LABEL_W-1),cur ? tstyle(:accent,bold=true) : on ? tstyle(:text_dim) : tstyle(:text_dim,strikethrough=true),ir)
  vx=ir.x+3+_LABEL_W; vw=right(ir)-vx+1
  if cur && r.editing===:text; render(r.input,Rect(vx,y,max(vw,1),1),buf)
  else
   v=on ? _rshow(m,r,k) : "–"
   empty=!on || startswith(v,"–")
   set_string!(buf,vx,y,_short(v,vw),empty ? tstyle(:text_dim) : tstyle(:text),ir)
  end
 end
 y=ir.y+length(_RFIELDS)+1
 y<=bottom(ir) && set_string!(buf,ir.x+1,y,_short("Kopiene får verdiene i malen (skjemaet), nye id-er og status «planlagt».",ir.width-1),tstyle(:text_dim),ir)
end
function _view_rpick(r::RepeatForm, under::Rect, buf::Buffer)
 k=_RFIELDS[r.cursor][1]; cs=_rchoices(r,k); n=length(cs)
 w=min(under.width-4,max(26,maximum(textwidth,cs)+10)); h=n+2
 y=clamp(under.y+r.cursor+1,under.y,max(under.y,bottom(under)-h+1))
 rr=Rect(under.x+_LABEL_W÷2,y,w,h)
 for yy in rr.y:bottom(rr); set_string!(buf,rr.x,yy," "^rr.width,tstyle(:text)); end
 render(Block(title=_RFIELDS[r.cursor][2],border_style=tstyle(:border_focus)),rr,buf)
 for (i,l) in enumerate(cs)
  set_string!(buf,rr.x+2,rr.y+i,(i==r.pick ? "› " : "  ")*(i==r.pick ? "(•) " : "( ) ")*l,i==r.pick ? tstyle(:accent,bold=true) : tstyle(:text),rr)
 end
end
"The dates the rule gives (right): new ones as list lines, skipped ones dimmed with the reason; problems in red."
function _view_plan(m::Editor, rect::Rect, buf::Buffer)
 r=m.rep
 for yy in rect.y:bottom(rect); set_string!(buf,rect.x,yy," "^rect.width,tstyle(:text)); end
 blk=Block(title="Datoer"); render(blk,rect,buf); ir=inner_area(blk,rect)
 ir.width<10 && return
 lines=Vector{Tuple{String,Style}}[]
 add(segs...)=push!(lines,collect(Tuple{String,Style},segs))
 add(("Mal: ",tstyle(:text_dim)),[(t,_style(f)) for (t,f) in TK.line_segs(r.template;width=ir.width-5)]...)
 note=_rnote(r); isempty(note) || add((note,tstyle(:warning)))
 add()
 p=r.plan
 if !isempty(r.problem); add((r.problem,tstyle(:error,bold=true)))
 elseif !isnothing(p)
  n=length(p.events); skip=length(p.exists)+length(p.excepted)
  add(("$n $(n==1 ? "nytt arrangement" : "nye arrangementer")"*(skip>0 ? " · $skip hoppes over" : ""),tstyle(:accent,bold=true)))
  for (a,b) in p.unused_except; add(("Unntatt $(_dmy(a))$(a==b ? "" : "–"*_dmy(b)) treffer ingen dato i regelen.",tstyle(:warning))); end
  for e in p.errors; add(("• "*e,tstyle(:error))); end
  rows=sort!(vcat([(something(TK._ymd(e.start),m.today),1,e) for (_,e) in p.events],
                  [(d,2,nothing) for d in p.exists],[(d,3,nothing) for d in p.excepted]);by=x->(x[1],x[2]))
  room=bottom(ir)-ir.y+1-length(lines)
  for (i,(d,kind,e)) in enumerate(rows)
   if i==room && length(rows)>room; add(("… og $(length(rows)-room+1) til",tstyle(:text_dim))); break; end
   if kind==1; add(("+ ",tstyle(:success,bold=true)),[(t,_style(f)) for (t,f) in TK.line_segs(e::TK.Event;width=ir.width-2)]...)
   else add(("· $(TK._wd3(d)) $(TK._two(day(d))).$(TK._two(month(d))).$(TK._two(year(d)%100))  hoppes over ($(kind==2 ? "finnes fra før" : "unntatt"))",tstyle(:text_dim))) end
  end
 end
 for (i,l) in enumerate(lines)
  y=ir.y+i-1; y>bottom(ir) && break
  x=ir.x
  for (t,st) in l; x>right(ir) && break; set_string!(buf,x,y,_short(t,right(ir)-x+1),st,ir); x+=textwidth(t); end
 end
end
function _view_list(m::Editor, rect::Rect, buf::Buffer)
 rect.height<3 && return
 set_string!(buf,rect.x,rect.y,"Søk: ",tstyle(:accent,bold=true))
 cnt="$(length(m.hits)) av $(count(e->m.past || _upcoming(m,e[2]),m.events)) $(m.past ? "(alle, også tidligere)" : "kommende")"
 cx=right(rect)-textwidth(cnt)+1
 render(m.query,Rect(rect.x+5,rect.y,max(1,cx-rect.x-6),1),buf)
 set_string!(buf,cx,rect.y,cnt,tstyle(:text_dim))
 lr=Rect(rect.x,rect.y+1,rect.width,rect.height-1)
 blk=Block(title=isempty(text(m.query)) ? "Arrangementer" : "Treff",border_style=tstyle(:border_focus)); render(blk,lr,buf); r=inner_area(blk,lr)
 r.height<=0 && return
 isempty(m.hits) && (set_string!(buf,r.x+2,r.y,"Ingen treff. Esc tømmer søket$(m.past ? "" : ", Ctrl-A tar med tidligere arrangementer").",tstyle(:text_dim),r); return)
 m.listoff=clamp(m.listoff,max(0,m.pick-r.height),m.pick-1)
 for (row,i) in enumerate(m.hits)
  y=r.y+row-1-m.listoff; (y<r.y || y>bottom(r)) && continue
  e=m.events[i][2]; cur=row==m.pick; x=r.x+2
  set_string!(buf,r.x,y,cur ? "›" : " ",tstyle(:accent,bold=true),r)
  for (t,face) in TK.line_segs(e;width=r.width-2)
   st=cur && face===:bold ? tstyle(:accent,bold=true) : !_upcoming(m,e) && face!==:tangokalender_cancelled ? tstyle(:text_dim) : _style(face)
   set_string!(buf,x,y,t,st,r); x+=textwidth(t)
  end
 end
end
function _view_footer(m::Editor, rect::Rect, buf::Buffer)
 x=rect.x; w=rect.width
 help=m.mode===:search ? "Alle ordene må passe: tittel, sted, arrangør, DJ, lærer, dato, ukedag, id, serie … («type:class», «venue:sentralen» søker i ett felt)." :
  m.mode===:repeat ? _RFIELDS[m.rep.cursor][4] : _field(m).help
 set_string!(buf,x,rect.y,_short(help,w),tstyle(:text_dim))
 st=m.level===:error ? tstyle(:error,bold=true) : m.level===:ok ? tstyle(:success,bold=true) : tstyle(:text)
 set_string!(buf,x,rect.y+1,_short(m.message,w),st)
 keys=m.mode===:search ? "↑/↓ velg · Enter åpne · Ctrl-A $(m.past ? "bare kommende" : "også tidligere") · Ctrl-N nytt · Ctrl-K kopier · Ctrl-R gjenta · Esc $(isempty(text(m.query)) ? "avslutt" : "tøm søket")" :
  m.mode===:text ? "Enter lagre feltet · Tab neste · Esc avbryt" :
  m.mode===:long ? "Enter linjeskift · Ctrl-S lagre feltet · ←/→/↑/↓ flytt · Esc avbryt" :
  m.mode===:pick ? "↑/↓ flytt · Mellomrom kryss av · Enter velg · Esc avbryt" :
  m.mode===:confirm ? "s lagre · f forkast · Esc fortsett" :
  m.mode===:scope ? _scope_keys(m) :
  m.mode===:repeat ? _repeat_keys(m.rep) :
  m.mode===:spread ? _spread_keys() :
  "↑/↓ felt · Enter endre · Ctrl-S lagre · Ctrl-R gjenta · Ctrl-L til senere datoer · Esc $(m.listing ? "tilbake til listen" : "avslutt")"
 render(StatusBar(left=[Span(" "*keys,tstyle(:text_bright))],right=[Span(m.mode ∉ (:search,:repeat) && _isnew(m) ? "nytt " : "",tstyle(:warning))]),Rect(x,rect.y+2,w,1),buf)
end

# ── Command line ──
const USAGE="""
TangoTUI - edit one event, or add one, in a full-screen form (experimental; Julia only)

Usage (in a data repository):
  julia --project=PATH/TangoTUI -m TangoTUI [--all] [--root=events]        # search the events, pick one
  julia --project=PATH/TangoTUI -m TangoTUI [edit] TERM… [--all] [--root=events]
  julia --project=PATH/TangoTUI -m TangoTUI new [TERM…] [--root=events]
  julia --project=PATH/TangoTUI -m TangoTUI repeat TERM… [--root=events]

(none)  a list of the upcoming events: type to search (every word must match, as on the web page), ↑/↓ and
        Enter to open one. Ctrl-A also shows past events, Ctrl-N starts a new event, Ctrl-K copies the selected,
        Ctrl-R repeats it on the dates of a rule.
edit    the event that matches TERM… (as `tangoedit`: TERM, KEY:TEXT); several or none: the list, searching TERM….
new     a blank form; with TERM…, a copy of the matching event (the latest of its series) on a new date.
repeat  copies of the matching event (the latest of its series) on the dates of a rule, as `tangoedit repeat`:
        every N weeks or months, the Nth (last) weekday of the month, or given dates; a number of copies or an end
        date, a start date and dates to skip. The dates are listed as you set the rule; Ctrl-S creates them.
--all   include past events.

In the form: ↑/↓ choose a field, Enter edit it (a pick list where only some values are allowed), Del clear it,
Ctrl-S save, Ctrl-R repeat the event as it stands in the form, Esc back to the list. Saving writes the file (moved if the date changed); commit it with git afterwards.
"""
function (@main)(args::Vector{String})
 site=try TK._cli_site("") catch err
  err isa ArgumentError || rethrow(); println(stderr,err.msg); return 2
 end
 TK._with_site(()->_run(args),site)
end
function _run(args::Vector{String}; today::Date=Dates.today())
 cmd="edit"; root="events"; past=false; terms=String[]
 for (i,a) in enumerate(args)
  if i==1 && a in ("edit","new","search","repeat"); cmd=a
  elseif a in ("-h","--help"); print(USAGE); return 0
  elseif startswith(a,"--root="); root=a[8:end]
  elseif a=="--all"; past=true
  elseif startswith(a,"--"); println(stderr,"unknown option $a\n"); print(stderr,USAGE); return 2
  else push!(terms,a) end
 end
 isdir(root) || (println(stderr,"no events directory \"$root\" (use --root=DIR)"); return 2)
 stdin isa Base.TTY || (println(stderr,"TangoTUI needs a terminal (stdin is not one)."); return 2)
 m=try editor_for(cmd,terms;root,past,today) catch err
  err isa ArgumentError || rethrow(); println(stderr,err.msg); return 1
 end
 app(m;default_bindings=false)
 for f in m.saved; println("Lagret: $(relpath(f))"); end
 isempty(m.saved) || println("Husk å committe endringene (git add events && git commit).")
 0
end
"""
    editor_for(cmd, terms; root="events", past=false, today=today()) -> Editor

The editor for `new` (blank, or a copy of `repeat_template(terms)` on `today`, with the date field open), `repeat`
(the list, with the repeat panel open on `repeat_template(terms)`; Esc goes to the list) or `edit`
(the one matching event; with several or none, or without terms, the list searching `terms`). Esc in an opened
event goes back to the list. Throws `ArgumentError` when `new TERM…` matches nothing.
"""
function editor_for(cmd::AbstractString, terms::Vector{String}; root="events", past=false, today::Date=Dates.today(),
                    tree_check=TK.validate_event_tree)
 if cmd=="new"
  isempty(terms) && return Editor(nothing,TK.new_event(;today),TK.new_event_keys();root,today,tree_check)
  m=Editor(nothing,TK.new_event(;today),TK.new_event_keys();root,today,tree_check)
  _copy!(m,TK.repeat_template(terms;root))
  return m
 end
 if cmd=="repeat"
  isempty(terms) && throw(ArgumentError("repeat needs a search term for the event to repeat"))
  (_,t,ks),g=TK._repeat_template(terms;root)
  m=search_editor(;root,today,tree_check)
  _repeat!(m,t,ks;saved=true,back=:search,group=g)
  return m
 end
 m=search_editor(;query=join(terms," "),past,root,today,tree_check)
 isempty(terms) || length(m.hits)!=1 || _load!(m,m.events[m.hits[1]])
 m
end
include("precompile.jl")
end
