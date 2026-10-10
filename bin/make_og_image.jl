# Draws a site's link-preview image (1200×630 PNG) for pages and events without a flyer. City and address come from
# the site.toml in the current directory (or --site=FILE); without one, the package's generic image is drawn.
# Run once per site after changing the design, commit the PNG and point `og_image` in site.toml at it.
# Builds only copy it, so they need no Cairo.
#   julia bin/make_og_image.jl [out.png] [--site=site.toml]      (default out: assets/og-image.png)
using Pkg; Pkg.activate(temp=true); Pkg.add("Cairo"; io=devnull)
using Cairo, TOML
const W,H=1200,630
opt=Dict(split(a[3:end],'=';limit=2) for a in ARGS if startswith(a,"--") && occursin('=',a))
pos=filter(!startswith("--"),ARGS)
sitefile=get(opt,"site","site.toml"); site=isfile(sitefile) ? TOML.parsefile(sitefile) : Dict{String,Any}()
city=get(site,"city",""); host=replace(get(site,"site_url",""),r"^https?://"=>"")
out=get(pos,1,isempty(site) ? joinpath(@__DIR__,"..","assets","og-image.png") : joinpath("assets","og-image.png"))
rgb(h)=(parse(Int,h[2:3];base=16)/255,parse(Int,h[4:5];base=16)/255,parse(Int,h[6:7];base=16)/255)
s=CairoRGBSurface(W,H); c=CairoContext(s)
g=pattern_create_linear(0,0,W,H)                       # the hero gradient of the site
pattern_add_color_stop_rgb(g,0,rgb("#26151d")...); pattern_add_color_stop_rgb(g,1,rgb("#8b2949")...)
set_source(c,g); rectangle(c,0,0,W,H); fill(c)
function text(str,x,y,size;font="DejaVu Serif",col="#ffffff",bold=false)
 select_font_face(c,font,Cairo.FONT_SLANT_NORMAL,bold ? Cairo.FONT_WEIGHT_BOLD : Cairo.FONT_WEIGHT_NORMAL)
 set_font_size(c,size); set_source_rgb(c,rgb(col)...); move_to(c,x,y); show_text(c,str)
end
text("Tangokalender",90,260,118)
isempty(city) || text(city,94,350,64;col="#f7dce5")
set_source_rgb(c,rgb("#f7dce5")...); rectangle(c,94,395,140,4); fill(c)
text("Milongaer, practicaer, kurs og festivaler",94,470,36;font="DejaVu Sans")
isempty(host) || text(host,94,560,28;font="DejaVu Sans",col="#f7dce5",bold=true)
mkpath(dirname(out)); write_to_png(s,out); println("wrote ",out)
