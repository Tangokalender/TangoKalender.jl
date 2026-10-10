# Draws assets/tangoedit-demo.svg: an animated terminal showing `tangoedit` cancelling a weekly series for one month
# (invented events), for the «Legg til» page (#kommandolinje). The output is the program's real output: the script
# runs `edit_main` on a temporary tree and turns its ANSI colours into SVG. Pure SVG + CSS animation, so it plays in an
# <img>; with «reduce motion» it shows the dry run as a still. Run after changing the terminal output, and commit:
#   julia --project=. bin/make_edit_demo.jl [out.svg]
using TangoKalender, Dates
const TK=TangoKalender
out=get(ARGS,1,joinpath(@__DIR__,"..","assets","tangoedit-demo.svg"))
const COLS=118                       # terminal width in characters
const CW=8.4; const LH=19.0; const FS=14   # character width, line height, font size (px)
const PAD=16; const TOP=44           # margins; the title bar is above TOP
const BG="#1e1a1d"; const FG="#e9e4e0"
const COLOR=Dict(31=>"#ff7b72",33=>"#f2c94c",35=>"#e48fc0",90=>"#958c91")

# Invented data: a weekly milonga, so the month filter has something before and after November.
tmpl=Dict("id"=>"onsdagsmilonga","title"=>"Onsdagsmilonga","types"=>["milonga"],"weekday"=>"Wednesday",
 "start_time"=>"20:00","end_time"=>"23:30","venue"=>Dict("name"=>"Eksempelsalen","address"=>"Storgata 1","city"=>"Eksempelby"),
 "organizer"=>"Eksempel Tango","price_nok"=>120)
dir=mktempdir(); TK.save_event_tree(TK.expand_weekly(tmpl;from=Date(2026,10,28),until=Date(2026,12,16)),joinpath(dir,"events"))
base="series:onsdagsmilonga --from=2026-11-01 --until=2026-11-30"
scenes=[("tangoedit $base",String[]),("tangoedit $base status=cancelled --dry-run",String[]),("tangoedit $base status=cancelled",String[])]
function run(cmd)
 io=IOContext(IOBuffer(),:displaysize=>(40,COLS),:color=>true)
 args=String.(split(cmd)[2:end])
 cd(dir) do; TK.edit_main(args;io,err=devnull,render=l->TK.ansi_text(l;color=true)); end
 split(rstrip(String(take!(io.io))),'\n')
end
scenes=[(c,run(c)) for (c,_) in scenes]

esc(s)=replace(s,'&'=>"&amp;",'<'=>"&lt;",'>'=>"&gt;")
"One line of ANSI text as SVG: a <text> with a positioned <tspan> per style run (and a box behind inverse runs)."
function line_svg(line,y)
 parts=String[]; boxes=String[]; col=0; st=Set{Int}()
 for m in eachmatch(r"\e\[([0-9;]*)m|([^\e]+)",line)
  if !isnothing(m[1])
   codes=[parse(Int,c) for c in split(m[1],';') if !isempty(c)]
   (isempty(codes) || 0 in codes) && empty!(st); union!(st,filter(!=(0),codes))
  else
   t=m[2]; w=textwidth(t); x=PAD+col*CW
   fg=something((get(COLOR,c,nothing) for c in (31,33,35,90) if c in st)...,FG)
   if 7 in st; push!(boxes,"<rect x=\"$(round(x;digits=1))\" y=\"$(y-LH+5)\" width=\"$(round(w*CW;digits=1))\" height=\"$LH\" rx=\"3\" fill=\"$fg\"/>"); fg=BG; end
   a=["x=\"$(round(x;digits=1))\"","fill=\"$fg\""]
   1 in st && push!(a,"font-weight=\"700\""); 3 in st && push!(a,"font-style=\"italic\""); 9 in st && push!(a,"text-decoration=\"line-through\"")
   w>1 && push!(a,"textLength=\"$(round(w*CW;digits=1))\" lengthAdjust=\"spacing\"")
   push!(parts,"<tspan $(join(a," "))>$(esc(t))</tspan>"); col+=w
  end
 end
 join(boxes)*"<text y=\"$y\" xml:space=\"preserve\">$(join(parts))</text>"
end

# Timeline: per scene, type the command, show the output, hold; then the next scene starts on a cleared screen.
const TYPE_CPS=28.0; const PAUSE=0.4
holds=[3.5,6.0,4.0]
t=0.0; spans=Tuple{Float64,Float64,Float64}[]   # (start, typed, end)
for (i,(cmd,_)) in enumerate(scenes)
 typed=t+length(cmd)/TYPE_CPS; push!(spans,(t,typed,typed+PAUSE+holds[i])); global t=typed+PAUSE+holds[i]+0.4
end
T=t; pc(x)=round(100x/T;digits=2)
nlines=maximum(length(o) for (_,o) in scenes)+2
W=round(Int,2PAD+COLS*CW); H=round(Int,TOP+nlines*LH+PAD)
css=String[]; body=String[]
for (i,((cmd,outl),(s,typed,e))) in enumerate(zip(scenes,spans))
 # visible from s to e (command) / typed+PAUSE to e (output)
 push!(css,"@keyframes v$i{0%,$(pc(s))%{opacity:0}$(pc(s)+0.01)%,$(pc(e))%{opacity:1}$(pc(e)+0.01)%,100%{opacity:0}}")
 push!(css,"@keyframes o$i{0%,$(pc(typed+PAUSE))%{opacity:0}$(pc(typed+PAUSE)+0.01)%,$(pc(e))%{opacity:1}$(pc(e)+0.01)%,100%{opacity:0}}")
 cw=length(cmd)*CW
 push!(css,"@keyframes c$i{0%,$(pc(s))%{transform:translateX(0);animation-timing-function:steps($(length(cmd)))}$(pc(typed))%,100%{transform:translateX($(round(cw+CW;digits=1))px)}}")
 push!(css,".v$i{animation:v$i $(T)s infinite}.o$i{animation:o$i $(T)s infinite}.c$i{animation:c$i $(T)s infinite}")
 y=TOP+LH
 prompt="<text y=\"$y\" xml:space=\"preserve\"><tspan x=\"$PAD\" fill=\"#7ee0a1\" font-weight=\"700\">\$ </tspan><tspan x=\"$(PAD+2CW)\" fill=\"$FG\">$(esc(cmd))</tspan></text>"
 cover="<rect class=\"c$i cover\" x=\"$(PAD+2CW)\" y=\"$(y-LH+4)\" width=\"$(round(cw+2CW;digits=1))\" height=\"$(LH+2)\" fill=\"$BG\"/>"
 lines=join((line_svg(l,TOP+LH*(k+1)) for (k,l) in enumerate(outl)),"")
 push!(body,"<g class=\"v$i sc$i\">$prompt$cover<g class=\"o$i sc$i\">$lines</g></g>")
end
svg="""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" width="$W" height="$H" role="img" aria-labelledby="t d">
<title id="t">tangoedit: avlys en ukentlig milonga for én måned</title>
<desc id="d">Terminal: tangoedit lister de fire onsdagene i november i serien onsdagsmilonga, viser endringen status=cancelled med --dry-run, og skriver den. Oppdiktede arrangementer.</desc>
<style>
text{font-family:"DejaVu Sans Mono",Menlo,Consolas,"Liberation Mono",monospace;font-size:$(FS)px}
.v1,.v2,.v3,.o1,.o2,.o3{opacity:0}
$(join(css,"\n"))
@media (prefers-reduced-motion:reduce){*{animation:none!important}.sc2{opacity:1!important}.cover{display:none}}
</style>
<rect width="$W" height="$H" rx="12" fill="$BG"/>
<rect width="$W" height="30" rx="12" fill="#2d272b"/><rect y="18" width="$W" height="12" fill="#2d272b"/>
<circle cx="20" cy="15" r="6" fill="#ff5f57"/><circle cx="40" cy="15" r="6" fill="#febc2e"/><circle cx="60" cy="15" r="6" fill="#28c840"/>
<text x="$(W÷2)" y="20" text-anchor="middle" fill="#958c91" style="font-size:12px">tangoedit — data-repo</text>
$(join(body,"\n"))
</svg>
"""
mkpath(dirname(out)); write(out,svg); println("wrote $out ($(length(svg)) bytes, $(round(T;digits=1)) s loop)")
