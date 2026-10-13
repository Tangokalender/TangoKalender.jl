# Draws docs/src/assets/tangotui-demo.svg: TangoTUI (the experimental editor) in use on invented events. It searches
# for a venue, opens a weekly milonga, changes the price, applies it to the later dates of the series (the dialog shows
# another organiser's event at the same venue left out by the guardrail), saves, and returns to the list.
# The screens are TangoTUI's real ones, drawn headlessly into Tachikoma's TestBackend after each step; Tachikoma's
# export_svg turns them into an animated SVG (one frame per step, SMIL, looping; plays in an <img>).
# Needs Tachikoma, so run it in TangoTUI's environment, and commit the result after changing how TangoTUI looks:
#   julia --project=TangoTUI bin/make_tui_demo.jl [out.svg]
using Dates, Tachikoma, TangoTUI, TangoKalender
const TK=TangoKalender
out=get(ARGS,1,joinpath(@__DIR__,"..","docs","src","assets","tangotui-demo.svg"))
const W=120; const H=34              # terminal size in cells
const TODAY=Date(2026,10,26)
set_theme!(KOKAKU)

# Invented data: a weekly milonga, and another organiser's practica at the same venue.
venue=Dict("name"=>"Eksempelsalen","address"=>"Storgata 1","city"=>"Eksempelby")
milonga=Dict("id"=>"onsdagsmilonga","title"=>"Onsdagsmilonga","types"=>["milonga"],"weekday"=>"Wednesday",
 "start_time"=>"20:00","end_time"=>"23:30","venue"=>venue,"organizer"=>"Eksempel Tango","price_nok"=>120,
 "description"=>"Ukentlig milonga med tradisjonell musikk.")
practica=Dict("id"=>"lordagspractica","title"=>"Lørdagspractica","types"=>["practica"],"weekday"=>"Saturday",
 "start_time"=>"14:00","end_time"=>"16:00","venue"=>venue,"organizer"=>"Annen klubb","price_nok"=>60)
dir=mktempdir(); root=joinpath(dir,"events")
TK.save_event_tree([TK.expand_weekly(milonga;from=Date(2026,10,28),until=Date(2026,12,16));
                    TK.expand_weekly(practica;from=Date(2026,11,7),until=Date(2026,11,7))],root)

# The scenario: a snapshot after each step, held for the given seconds.
snaps=Vector{Tachikoma.Cell}[]; times=Float64[]; clock=Ref(0.0)
function snap!(m, hold)
 tb=Tachikoma.TestBackend(W,H)
 TangoTUI.view(m,Tachikoma.Frame(tb.buf,Rect(1,1,W,H),Tachikoma.GraphicsRegion[],Tachikoma.PixelSnapshot[]))
 push!(snaps,copy(tb.buf.content)); push!(times,clock[]); clock[]+=hold
end
key!(m, k)=TangoTUI.update!(m,k isa Char ? KeyEvent(k) : k isa Pair ? KeyEvent(k[1],k[2]) : KeyEvent(k))
cd(dir) do
 m=TangoTUI.search_editor(;root="events",today=TODAY)
 snap!(m,2.0)                                                      # the list of upcoming events
 q="eksempelsalen"
 for (i,c) in enumerate(q); key!(m,c); (i==5 || i==length(q)) && snap!(m,i==length(q) ? 2.0 : 0.3); end
 key!(m,:enter); snap!(m,2.5)                                      # open the first Wednesday
 for i in 1:13; key!(m,:down); i==6 && snap!(m,0.3); end; snap!(m,1.0)   # down to «Pris»
 key!(m,:enter); snap!(m,1.2)                                      # edit: the current value
 for _ in 1:3; key!(m,:backspace); end; for c in "150"; key!(m,c); end; snap!(m,1.0)
 key!(m,:enter); snap!(m,2.5)                                      # changed: 150 kr, old value struck through
 key!(m,:ctrl=>'s'); snap!(m,6.0)                                  # apply to later dates? (guardrail: Annen klubb skipped)
 key!(m,'a'); snap!(m,3.5)                                         # saved: this and the later dates
 key!(m,:escape); snap!(m,0.0)                                     # back to the list (export_svg holds the last frame
                                                                   # as long as the gap before it)
end
mkpath(dirname(out))
Tachikoma.export_svg(out,W,H,snaps,times)
println("wrote $out ($(filesize(out)) bytes, $(length(snaps)) frames, $(round(clock[];digits=1)) s loop)")
