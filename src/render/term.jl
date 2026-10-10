# Events in the terminal: `event_card`, a compact version of the web card (`_card` in html.jl), and the one-line
# `event_line` for lists. Both read the `Event` struct directly. The layout is built once as lines of `(text, face)`
# segments; `styled_text` turns them into a StyledStrings `AnnotatedString` (the app, the REPL), and `ansi_text` into
# a plain `String` with ANSI codes (the trimmed `tangoedit` executable: StyledStrings can't be trimmed yet).
# Colour is used only when the output stream supports it.
"A piece of text and its face: `:default`, `:bold`, `:italic`, `:shadow` or one of `TERM_FACES`."
const Seg=Tuple{String,Symbol}
"Our StyledStrings faces, registered in `__init__`; `_sgr` has the same styles as ANSI codes."
const TERM_FACES=(
 tangokalender_date=StyledStrings.Face(foreground=:magenta,weight=:bold),
 tangokalender_chip=StyledStrings.Face(inverse=true),
 tangokalender_cancelchip=StyledStrings.Face(foreground=:red,weight=:bold,inverse=true),
 tangokalender_cancelled=StyledStrings.Face(weight=:bold,strikethrough=true),
 tangokalender_new=StyledStrings.Face(foreground=:yellow,weight=:bold),
 tangokalender_old=StyledStrings.Face(foreground=:bright_black,strikethrough=true))
_register_term_faces()=foreach(k->StyledStrings.addface!(k=>TERM_FACES[k]),keys(TERM_FACES))
function _sgr(f::Symbol)
 f===:bold ? "1" : f===:italic ? "3" : f===:shadow ? "90" : f===:tangokalender_date ? "1;35" : f===:tangokalender_chip ? "7" :
 f===:tangokalender_cancelchip ? "1;7;31" : f===:tangokalender_cancelled ? "1;9" : f===:tangokalender_new ? "1;33" :
 f===:tangokalender_old ? "90;9" : ""
end
"Lines of segments as a StyledStrings `AnnotatedString`."
function styled_text(lines::Vector{Vector{Seg}})
 out=Base.AnnotatedString{String}[]
 for (i,l) in enumerate(lines)
  for (t,f) in l; push!(out,f===:default ? Base.AnnotatedString(t) : styled"{$f:$t}"); end
  i<length(lines) && push!(out,Base.AnnotatedString("\n"))
 end
 isempty(out) ? Base.AnnotatedString("") : reduce(*,out)
end
"Lines of segments as text with ANSI codes (plain text when `color` is false)."
function ansi_text(lines::Vector{Vector{Seg}}; color::Bool=true)
 io=IOBuffer()
 for (i,l) in enumerate(lines)
  for (t,f) in l
   c=_sgr(f); color && !isempty(c) ? print(io,"\e[",c,"m",t,"\e[0m") : print(io,t)
  end
  i<length(lines) && print(io,'\n')
 end
 String(take!(io))
end
_types_label(e::Event)=join(_type_label.(sort(e.types,by=t->something(findfirst(==(t),TYPE_ORDER),99)))," · ")
_date_label(e::Event)=_date_label(e.start,something(e.end_,""))
function _price(e::Event)
 parts=String[]
 for (v,label) in ((e.price_nok,""),(e.student_price_nok,_t("price.student")*" "),(e.class_price_nok,_t("price.class")*" "))
  isnothing(v) || push!(parts,"$(label)$(v) kr")
 end
 join(parts," · ")
end
_price_text(e::Event)=(p=_price(e); isempty(p) ? _t("price.none") : p)
_venue_name(e::Event)=(v=e.venue; n=isnothing(v) ? "" : strip(something(v.name,"")); isempty(n) ? _t("venue.none") : String(n))
_venue_where(e::Event)=(v=e.venue; isnothing(v) ? "" : String(strip(!isnothing(v.address) ? v.address : !isnothing(v.city) ? v.city : "")))
_venue_text(e::Event)=(w=_venue_where(e); isempty(w) ? _venue_name(e) : "$(_venue_name(e)) · $w")
function _people(e::Event)
 parts=String[]
 isnothing(e.organizer) || isempty(e.organizer) || push!(parts,"⚑ $(e.organizer)")
 isnothing(e.teachers) || isempty(e.teachers) || push!(parts,"☺ $(join(e.teachers,", "))")
 isnothing(e.dj) || isempty(e.dj) || push!(parts,"♫ DJ $(e.dj)")
 isnothing(e.music_style) || isempty(e.music_style) || push!(parts,"♪ $(join(_music_label.(e.music_style),", "))")
 join(parts,"   ")
end
_host(u)=(m=match(r"^https?://(?:www\.)?([^/?#]+)"i,u); isnothing(m) ? String(u) : String(something(m[1])))
function _footer(e::Event)
 parts=[e.id]
 isnothing(e.series) || push!(parts,"$(_t("term.series")) $(e.series)")
 isnothing(e.flyer_url) || push!(parts,"flyer ✓")
 isnothing(e.video) || push!(parts,"video ✓")
 isnothing(e.link) || push!(parts,"↗ $(_host(e.link))")
 join(parts," · ")
end
_cancelled(e::Event)=e.status=="cancelled"
"Keys shown in the card's sections; a change to any other key gets its own «✎ key: old → new» line."
const _CARD_KEYS=Set(["start","end","types","status","price_nok","student_price_nok","class_price_nok","title","venue",
 "organizer","teachers","dj","music_style","description","id","series","flyer_url","video","link"])
"`f(e)` in `face`, or, when it differs from `f(before)`, highlighted and followed by the old value struck through."
function _hl(f, e::Event, before::Union{Nothing,Event}, face::Symbol)
 new=f(e)::String
 isnothing(before) && return Seg[(new,face)]
 old=f(before)::String
 old==new ? Seg[(new,face)] : Seg[(new,:tangokalender_new),(" ",:default),(isempty(old) ? "–" : old,:tangokalender_old)]
end
"Word-wrap `s` to `width` columns, keeping at most `maxlines` lines (the last ends with … when cut)."
function _wrap_lines(s::AbstractString, width::Int, maxlines::Int)
 lines=String[]; cur=""
 for w in split(s)
  if isempty(cur); cur=String(w)
  elseif textwidth(cur)+1+textwidth(w)<=width; cur*=" "*w
  else push!(lines,cur); cur=String(w) end
 end
 isempty(cur) || push!(lines,cur)
 length(lines)<=maxlines && return lines
 kept=lines[1:maxlines]; last_=kept[end]
 while textwidth(last_)+2>width && !isempty(last_); last_=String(chop(last_)); end
 kept[end]=rstrip(last_)*" …"; kept
end
_short(s::AbstractString,n::Int)=textwidth(s)<=n ? String(s) : (t=String(s); while textwidth(t)>n-1; t=String(chop(t)); end; rstrip(t)*"…")
"The card as lines of segments (see `event_card`)."
function card_lines(e::Event; before::Union{Nothing,Event}=nothing, width::Int=80)
 w=clamp(width,40,110); bar=("│  ",:shadow)
 head=Seg[("╭─ ",:shadow)]; append!(head,_hl(_date_label,e,before,:tangokalender_date)); push!(head,("  ",:default))
 caps=_t("cancelled.caps")
 if !isnothing(before) && _cancelled(e)!=_cancelled(before)
  push!(head,_cancelled(e) ? (" $caps ",:tangokalender_new) : (caps,:tangokalender_old),(" ",:default))
 elseif _cancelled(e)
  push!(head,(" $caps ",:tangokalender_cancelchip),(" ",:default))
 end
 if !isnothing(before) && before.types!=e.types; append!(head,_hl(_types_label,e,before,:default))
 else for t in split(_types_label(e)," · "); push!(head,(" $t ",:tangokalender_chip),(" ",:default)); end end
 push!(head,(" ",:default)); append!(head,_hl(_price_text,e,before,isempty(_price(e)) ? :shadow : :default))
 lines=[head]
 push!(lines,[bar;_hl(x->x.title,e,before,_cancelled(e) ? :tangokalender_cancelled : :bold)])
 push!(lines,[bar;("⌖ ",:shadow);_hl(_venue_text,e,before,isnothing(e.venue) || isnothing(e.venue.name) ? :shadow : :default)])
 isempty(_people(e)) && (isnothing(before) || isempty(_people(before))) || push!(lines,[bar;_hl(_people,e,before,:default)])
 desc=String(strip(something(e.description,""))); olddesc=isnothing(before) ? desc : String(strip(something(before.description,"")))
 if olddesc!=desc
  for l in _wrap_lines(isempty(desc) ? "–" : desc,w-3,3); push!(lines,Seg[bar,(l,:tangokalender_new)]); end
  for l in _wrap_lines(isempty(olddesc) ? "–" : olddesc,w-3,2); push!(lines,Seg[bar,(l,:tangokalender_old)]); end
 elseif !isempty(desc)
  for l in _wrap_lines(desc,w-3,2); push!(lines,Seg[bar,(l,:italic)]); end
 end
 if !isnothing(before)
  for k in jsonkeys(Event)
   k in _CARD_KEYS && continue
   old=_withfield(JSON.json,before,k); new=_withfield(JSON.json,e,k)
   old==new || push!(lines,Seg[bar,("✎ ",:shadow),("$k: ",:default),(old,:tangokalender_old),(" → ",:default),(new,:tangokalender_new)])
  end
 end
 push!(lines,[Seg[("╰─ ",:shadow)];_hl(_footer,e,before,:shadow)])
 lines
end
"The list line as segments (see `event_line`)."
function line_segs(e::Event; width::Int=80)
 p=_parse_dt(e.start); d=_ymd(e.start)
 when=!isnothing(p) ? "$(_wd3(p[1])) $(_two(day(p[1]))).$(_two(month(p[1]))).$(_two(year(p[1])%100)) $(_hm(p[1]))" :
  !isnothing(d) ? "$(_wd3(d)) $(_two(day(d))).$(_two(month(d))).$(_two(year(d)%100))" : e.start
 rest=max(width-20-16-4-textwidth(e.id),50)   # title and venue share what's left; long ids may wrap
 tw=(rest*2)÷3; vw=rest-tw
 Seg[(_pad(when,20),:tangokalender_date),(_pad(_short(_types_label(e),15),16),:shadow),
     (_pad(_short(e.title,tw),tw),_cancelled(e) ? :tangokalender_cancelled : :bold),("  ",:default),
     (_pad(_short(_venue_name(e),vw),vw),:default),("  ",:default),(e.id,:shadow)]
end
"""
    event_card(e::Event; before=nothing, width=terminal width) -> AnnotatedString

A compact terminal card of `e`, laid out like the web card: date and time, type chips (and AVLYST), price, title,
venue, organiser/teachers/DJ/music, the start of the description, and id/series/links. With `before` (the event
before an edit), every changed part is highlighted with the old value struck through after it, and changed keys
that the card doesn't show get a «✎ key: old → new» line.
"""
event_card(e::Event; before::Union{Nothing,Event}=nothing, width::Int=displaysize(stdout)[2])=styled_text(card_lines(e;before,width))
"""
    event_line(e::Event; width=terminal width) -> AnnotatedString

One line per event for match lists: short date and time, types, title, venue and id, in columns.
"""
event_line(e::Event; width::Int=displaysize(stdout)[2])=styled_text([line_segs(e;width)])
Base.show(io::IO, ::MIME"text/plain", e::Event)=print(io,event_card(e;width=displaysize(io)[2]))
