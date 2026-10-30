# Draws a site's icons: the browser-tab favicon and the home-screen icons used when a phone bookmarks the site.
# The tab sizes (16, 32) are a white serif «T» over a short pink rule on the hero gradient; the home-screen sizes
# say «Tango» over the city in capitals (e.g. OSLO), like the link preview. The city comes from the site.toml in the
# current directory (or --site=FILE); without one, the package's generic set (the «T» at every size) is drawn.
# Run once per site after changing the design, commit the files and point `icons` in site.toml at the folder.
# Builds only copy them, so they need no Cairo.
#   julia bin/make_icons.jl [outdir] [--site=site.toml]      (default outdir: assets/icons)
using Pkg; Pkg.activate(temp=true); Pkg.add("Cairo"; io=devnull)
using Cairo, TOML
opt=Dict(split(a[3:end],'=';limit=2) for a in ARGS if startswith(a,"--") && occursin('=',a))
pos=filter(!startswith("--"),ARGS)
sitefile=get(opt,"site","site.toml"); site=isfile(sitefile) ? TOML.parsefile(sitefile) : Dict{String,Any}()
city=uppercase(get(site,"city",""))
out=get(pos,1,isempty(site) ? joinpath(@__DIR__,"..","assets","icons-generic") : joinpath("assets","icons"))
rgb(h)=(parse(Int,h[2:3];base=16)/255,parse(Int,h[4:5];base=16)/255,parse(Int,h[6:7];base=16)/255)
const PINK="#f7dce5"

function roundrect(c,x,y,w,h,r)
 new_sub_path(c); arc(c,x+w-r,y+r,r,-pi/2,0); arc(c,x+w-r,y+h-r,r,0,pi/2); arc(c,x+r,y+h-r,r,pi/2,pi); arc(c,x+r,y+r,r,pi,3pi/2); close_path(c)
end
# text centred on cx at baseline y, shrunk to fit width w (all in the icon's 24-unit space)
function centred(c,str,cx,y,size,col;w=Inf,bold=false)
 select_font_face(c,"DejaVu Serif",Cairo.FONT_SLANT_NORMAL,bold ? Cairo.FONT_WEIGHT_BOLD : Cairo.FONT_WEIGHT_NORMAL); set_font_size(c,size)
 e=text_extents(c,str); e[3]>w && (set_font_size(c,size*w/e[3]); e=text_extents(c,str))
 move_to(c,cx-e[3]/2-e[1],y); set_source_rgb(c,rgb(col)...); show_text(c,str)
end
"""
One icon, S×S pixels. `rounded`: transparent rounded corners (tab icons, «any» icons) instead of a full square (iOS and
Android mask those themselves). `k` scales the motif around the centre: maskable icons keep it in the safe zone.
"""
function icon(S;rounded,k,words)
 s=CairoARGBSurface(S,S); c=CairoContext(s)
 rounded ? roundrect(c,0,0,S,S,0.22S) : rectangle(c,0,0,S,S)
 g=pattern_create_linear(0,0,S,S)                       # the hero gradient of the site
 pattern_add_color_stop_rgb(g,0,rgb("#26151d")...); pattern_add_color_stop_rgb(g,1,rgb("#8b2949")...)
 set_source(c,g); fill(c)
 translate(c,S/2,S/2); scale(c,k*S/24,k*S/24); translate(c,-12,-12)
 set_source_rgb(c,rgb(PINK)...)
 if words && !isempty(city)                              # «Tango» / rule / CITY
  centred(c,"Tango",12,11.6,8,"#ffffff";w=16.5)
  set_source_rgb(c,rgb(PINK)...); rectangle(c,9.2,13.5,5.6,0.5); fill(c)
  centred(c,city,12,20,6.2,PINK;w=13.5)
 else                                                    # «T» over a short rule
  centred(c,"T",12,18.2,19,"#ffffff";bold=true)
  set_source_rgb(c,rgb(PINK)...); rectangle(c,8.5,20,7,S<=48 ? 1.4 : 0.9); fill(c)
 end
 s
end
png(s)=(io=IOBuffer(); write_to_png(s,io); take!(io))
"An .ico holding PNG images (allowed since Windows Vista; every current browser reads it)."
function ico(pngs::Vector{Pair{Int,Vector{UInt8}}})
 io=IOBuffer(); w16(x)=write(io,htol(UInt16(x))); w32(x)=write(io,htol(UInt32(x)))
 w16(0); w16(1); w16(length(pngs)); off=6+16length(pngs)
 for (S,b) in pngs
  write(io,UInt8(S%256)); write(io,UInt8(S%256)); write(io,0x00); write(io,0x00); w16(1); w16(32); w32(length(b)); w32(off); off+=length(b)
 end
 foreach(p->write(io,p[2]),pngs); take!(io)
end
mkpath(out)
f(name,bytes)=(write(joinpath(out,name),bytes); println("wrote ",joinpath(out,name)))
f("favicon.ico",ico([16=>png(icon(16;rounded=true,k=1.2,words=false)),32=>png(icon(32;rounded=true,k=1.2,words=false))]))
f("favicon-32.png",png(icon(32;rounded=true,k=1.2,words=false)))
f("apple-touch-icon.png",png(icon(180;rounded=false,k=0.95,words=true)))
f("icon-192.png",png(icon(192;rounded=true,k=0.95,words=true)))
f("icon-512.png",png(icon(512;rounded=true,k=0.95,words=true)))
f("icon-maskable-512.png",png(icon(512;rounded=false,k=0.78,words=true)))
