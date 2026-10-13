"""
    TangoTUI

A full-screen editor for one event of a TangoKalender data repository, on Tachikoma.jl: the fields one by one with
their current values, a pick list where only some values are allowed, and a live preview card. Experimental, and
Julia only: Tachikoma can't be trimmed, so this is not part of the `tangoedit` executable. In a data repository:

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
 mode::Symbol                     # :browse, :text, :pick, :confirm, :choose
 input::TextInput
 pick::Int
 ticked::Vector{Bool}
 message::String
 level::Symbol                    # :info, :ok, :error
 quit::Bool
 saved::Vector{String}
 matches::Vector{Tuple{String,TK.Event,Vector{String}}}   # :choose: the events to pick one from
end
function Editor(file, e::TK.Event, keys::Vector{String}; root="events", today=Dates.today(), tree_check=TK.validate_event_tree,
                matches=Tuple{String,TK.Event,Vector{String}}[])
 m=Editor(TK.form_fields(),root,today,tree_check,file,keys,e,e,1,0,isempty(matches) ? :browse : :choose,TextInput(text=""),1,Bool[],
          "",:info,false,String[],matches)
 isnothing(file) && _new_id!(m)
 m
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

# ── Keys ──
_ctrl(ev::KeyEvent,c::Char)=ev.key===:ctrl && ev.char==c
_ch(ev::KeyEvent,c::Char)=ev.key===:char && ev.char==c
function update!(m::Editor, ev::KeyEvent)
 m.mode===:choose ? _choose_key!(m,ev) : m.mode===:text ? _text_key!(m,ev) : m.mode===:pick ? _pick_key!(m,ev) :
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
  _dirty(m) ? (m.mode=:confirm; _say!(m,"Ulagrede endringer: lagre (s), forkast (f) eller fortsett å redigere (Esc)?",:error)) : (m.quit=true)
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
 if _ch(ev,'s') || _ctrl(ev,'s'); _save!(m) && (m.quit=true)
 elseif _ch(ev,'f'); m.quit=true
 else m.mode=:browse; _say!(m,"Fortsett å redigere.") end
end
function _choose_key!(m::Editor, ev::KeyEvent)
 n=length(m.matches); k=ev.key
 if k===:up; m.pick=mod1(m.pick-1,n)
 elseif k===:down; m.pick=mod1(m.pick+1,n)
 elseif k===:enter; _load!(m,m.matches[m.pick])
 elseif k===:escape || _ch(ev,'q') || k===:ctrl_c; m.quit=true
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
 head=m.mode===:choose ? "tangoedit · velg arrangement ($(length(m.matches)) treff)" :
  _isnew(m) ? "tangoedit · nytt arrangement · $(m.event.id)" : "tangoedit · $(_rel(m,m.file))"
 set_string!(buf,rows[1].x,rows[1].y,_short(head,rows[1].width),tstyle(:title,bold=true))
 if m.mode===:choose
  _view_matches(m,rows[2],buf)
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
function _view_matches(m::Editor, rect::Rect, buf::Buffer)
 blk=Block(title="Flere arrangementer passer – velg ett"); render(blk,rect,buf); r=inner_area(blk,rect)
 off=max(0,m.pick-r.height)
 for (i,(_,e,_)) in enumerate(m.matches)
  y=r.y+i-1-off; (y<r.y || y>bottom(r)) && continue
  segs=TK.line_segs(e;width=r.width-2); x=r.x+2
  set_string!(buf,r.x,y,i==m.pick ? "›" : " ",tstyle(:accent,bold=true),r)
  for (t,face) in segs; set_string!(buf,x,y,t,i==m.pick && face===:bold ? tstyle(:accent,bold=true) : _style(face),r); x+=textwidth(t); end
 end
end
function _view_footer(m::Editor, rect::Rect, buf::Buffer)
 x=rect.x; w=rect.width
 help=m.mode===:choose ? "" : _field(m).help
 set_string!(buf,x,rect.y,_short(help,w),tstyle(:text_dim))
 st=m.level===:error ? tstyle(:error,bold=true) : m.level===:ok ? tstyle(:success,bold=true) : tstyle(:text)
 set_string!(buf,x,rect.y+1,_short(m.message,w),st)
 keys=m.mode===:choose ? "↑/↓ velg · Enter åpne · Esc avslutt" :
  m.mode===:text ? "Enter lagre feltet · Tab neste · Esc avbryt" :
  m.mode===:pick ? "↑/↓ flytt · Mellomrom kryss av · Enter velg · Esc avbryt" :
  m.mode===:confirm ? "s lagre og avslutt · f forkast · Esc fortsett" :
  "↑/↓ felt · Enter endre · Del tøm · Ctrl-S lagre · Esc avslutt"
 render(StatusBar(left=[Span(" "*keys,tstyle(:text_bright))],right=[Span(_isnew(m) ? "nytt " : "",tstyle(:warning))]),Rect(x,rect.y+2,w,1),buf)
end

# ── Command line ──
const USAGE="""
TangoTUI - edit one event, or add one, in a full-screen form (experimental; Julia only)

Usage (in a data repository):
  julia --project=PATH/TangoTUI -m TangoTUI [edit] TERM… [--all] [--root=events]
  julia --project=PATH/TangoTUI -m TangoTUI new [TERM…] [--root=events]

edit   finds upcoming events as `tangoedit` does (TERM, KEY:TEXT); several matches: pick one.
new    a blank form; with TERM…, a copy of the matching event (the latest of its series) on a new date.
--all  include past events.

Keys: ↑/↓ choose a field, Enter edit it (a pick list where only some values are allowed), Del clear it,
Ctrl-S save, Esc quit. Saving writes the file (moved if the date changed); commit it with git afterwards.
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
  if i==1 && a in ("edit","new"); cmd=a
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
(the one matching event, or a list to pick from). Throws `ArgumentError` when nothing matches.
"""
function editor_for(cmd::AbstractString, terms::Vector{String}; root="events", past=false, today::Date=Dates.today(),
                    tree_check=TK.validate_event_tree)
 if cmd=="new"
  isempty(terms) && return Editor(nothing,TK.new_event(;today),TK.new_event_keys();root,today,tree_check)
  f,t,ks=TK.repeat_template(terms;root)
  e=TK.repeat_event(t,today;today); e=TK._put(e,Val(:last_verified),TK._ymd_str(today))
  m=Editor(nothing,e,TK._with_key(TK._with_key(ks,"first_seen"),"last_verified");root,today,tree_check)
  m.cursor=findfirst(f->f.key=="date",m.fields); m.input=TextInput(text=TK.field_text(e,m.fields[m.cursor]),focused=true); m.mode=:text
  _say!(m,"Kopi av $(t.id): skriv den nye datoen og trykk Enter.")
  return m
 end
 found=TK.find_events(terms;root,from=past ? nothing : today)
 isempty(found) && throw(ArgumentError("Ingen arrangementer passer til $(join(terms," "))$(past ? "" : " (bare kommende; --all tar med tidligere)")."))
 length(found)==1 && return (m=Editor(found[1]...;root,today,tree_check); _load!(m,found[1]); m)
 Editor(found[1]...;root,today,tree_check,matches=found)
end
end
