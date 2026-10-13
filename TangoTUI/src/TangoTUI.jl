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
using Dates, Tachikoma
using TangoKalender
const TK=TangoKalender
@tachikoma_app

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
 mode::Symbol                     # :search, :browse, :text, :pick, :confirm
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
end
function Editor(file, e::TK.Event, keys::Vector{String}; root="events", today=Dates.today(), tree_check=TK.validate_event_tree)
 m=Editor(TK.form_fields(),root,today,tree_check,file,keys,e,e,1,0,:browse,TextInput(text=""),1,Bool[],"",:info,false,String[],
          Tuple{String,TK.Event,Vector{String}}[],String[],Int[],TextInput(text="",focused=true),false,0,false)
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
_field(m::Editor)=m.fields[m.cursor]
"`file` relative to the folder that holds the events directory (`events/2026/…`)."
_rel(m::Editor,file)=relpath(file,dirname(abspath(m.root)))
_isnew(m::Editor)=isnothing(m.file)
_dirty(m::Editor)=_isnew(m) ? !isempty(m.event.title) : TK.event_text(m.event,m.keys)!=TK.event_text(m.before,m.keys)
_new_id!(m::Editor)=(_isnew(m) && (m.event=TK._put(m.event,Val(:id),TK.form_id(m.event))); nothing)
_say!(m::Editor,s::AbstractString,level::Symbol=:info)=(m.message=String(s); m.level=level; nothing)
function _load!(m::Editor,(file,e,ks))
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
 _say!(m,isempty(m.saved) ? "Skriv for å søke; ↑/↓ og Enter åpner et arrangement." : "Lagret: $(_rel(m,m.saved[end]))",isempty(m.saved) ? :info : :ok)
end
"Leave the form: back to the list when the editor came from it, else quit."
_leave!(m::Editor)=m.listing ? _to_list!(m;select=m.file) : (m.quit=true; nothing)

# ── Keys ──
_ctrl(ev::KeyEvent,c::Char)=ev.key===:ctrl && ev.char==c
_ch(ev::KeyEvent,c::Char)=ev.key===:char && ev.char==c
function update!(m::Editor, ev::KeyEvent)
 m.mode===:search ? _search_key!(m,ev) : m.mode===:text ? _text_key!(m,ev) : m.mode===:pick ? _pick_key!(m,ev) :
 m.mode===:confirm ? _confirm_key!(m,ev) : _browse_key!(m,ev)
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
 else
  m.input=TextInput(text=TK.field_text(m.event,f),focused=true); m.mode=:text
  _say!(m,"Enter lagrer feltet, Tab går videre, Esc avbryter.")
 end
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
 if _ch(ev,'s') || _ctrl(ev,'s'); _save!(m) && _leave!(m)
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
 elseif k===:escape; isempty(text(m.query)) ? (m.quit=true) : (set_text!(m.query,""); _filter!(m))
 elseif k===:ctrl_c; m.quit=true
 else
  q=text(m.query); handle_key!(m.query,ev); text(m.query)==q || _filter!(m)
 end
end
"Save (refused while `check` finds problems: the cursor goes to the first field that has one)."
function _save!(m::Editor)
 file,errs=TK.save_form_event(m.file,m.event,m.keys;root=m.root,today=m.today,tree_check=m.tree_check)
 if isnothing(file)
  ps=TK.check(m.event); i=findfirst(f->!isempty(TK.field_problems(m.event,f;problems=ps)),m.fields)
  isnothing(i) || (m.cursor=i)
  _say!(m,"Ikke lagret: $(first(errs))$(length(errs)>1 ? " (+$(length(errs)-1) til)" : "")",:error); m.mode=:browse
  return false
 end
 e,ks=TK.read_event(file); m.file=file; m.event=m.before=e; m.keys=ks; m.mode=:browse
 file in m.saved || push!(m.saved,file)
 _say!(m,"Lagret: $(_rel(m,file))",:ok)
 true
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
  _isnew(m) ? "tangoedit · nytt arrangement · $(m.event.id)" : "tangoedit · $(_rel(m,m.file))"
 set_string!(buf,rows[1].x,rows[1].y,_short(head,rows[1].width),tstyle(:title,bold=true))
 if m.mode===:search
  _view_list(m,rows[2],buf)
 else
  body=rows[2]
  wide=body.width>=110
  parts=split_layout(Layout(wide ? Horizontal : Vertical,wide ? [Percent(52),Fill()] : [Fill(),Percent(45)]),body)
  _view_fields(m,parts[1],buf)
  length(parts)>1 && _view_card(m,parts[2],buf)
  m.mode===:pick && _view_pick(m,parts[1],buf)
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
 help=m.mode===:search ? "Alle ordene må passe: tittel, sted, arrangør, DJ, lærer, dato, ukedag, id, serie … («type:class», «venue:sentralen» søker i ett felt)." : _field(m).help
 set_string!(buf,x,rect.y,_short(help,w),tstyle(:text_dim))
 st=m.level===:error ? tstyle(:error,bold=true) : m.level===:ok ? tstyle(:success,bold=true) : tstyle(:text)
 set_string!(buf,x,rect.y+1,_short(m.message,w),st)
 keys=m.mode===:search ? "↑/↓ velg · Enter åpne · Ctrl-A $(m.past ? "bare kommende" : "også tidligere") · Ctrl-N nytt · Ctrl-K kopier · Esc $(isempty(text(m.query)) ? "avslutt" : "tøm søket")" :
  m.mode===:text ? "Enter lagre feltet · Tab neste · Esc avbryt" :
  m.mode===:pick ? "↑/↓ flytt · Mellomrom kryss av · Enter velg · Esc avbryt" :
  m.mode===:confirm ? "s lagre · f forkast · Esc fortsett" :
  "↑/↓ felt · Enter endre · Del tøm · Ctrl-S lagre · Esc $(m.listing ? "tilbake til listen" : "avslutt")"
 render(StatusBar(left=[Span(" "*keys,tstyle(:text_bright))],right=[Span(m.mode!==:search && _isnew(m) ? "nytt " : "",tstyle(:warning))]),Rect(x,rect.y+2,w,1),buf)
end

# ── Command line ──
const USAGE="""
TangoTUI - edit one event, or add one, in a full-screen form (experimental; Julia only)

Usage (in a data repository):
  julia --project=PATH/TangoTUI -m TangoTUI [--all] [--root=events]        # search the events, pick one
  julia --project=PATH/TangoTUI -m TangoTUI [edit] TERM… [--all] [--root=events]
  julia --project=PATH/TangoTUI -m TangoTUI new [TERM…] [--root=events]

(none)  a list of the upcoming events: type to search (every word must match, as on the web page), ↑/↓ and
        Enter to open one. Ctrl-A also shows past events, Ctrl-N starts a new event, Ctrl-K copies the selected.
edit    the event that matches TERM… (as `tangoedit`: TERM, KEY:TEXT); several or none: the list, searching TERM….
new     a blank form; with TERM…, a copy of the matching event (the latest of its series) on a new date.
--all   include past events.

In the form: ↑/↓ choose a field, Enter edit it (a pick list where only some values are allowed), Del clear it,
Ctrl-S save, Esc back to the list. Saving writes the file (moved if the date changed); commit it with git afterwards.
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
  if i==1 && a in ("edit","new","search"); cmd=a
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

The editor for `new` (blank, or a copy of `repeat_template(terms)` on `today`, with the date field open) or `edit`
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
 m=search_editor(;query=join(terms," "),past,root,today,tree_check)
 isempty(terms) || length(m.hits)!=1 || _load!(m,m.events[m.hits[1]])
 m
end
end
