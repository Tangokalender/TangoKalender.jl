# Draws docs/src/assets/tangotui-repeat-demo.svg: TangoTUI's repeat panel (Ctrl-R) on invented events. It searches for
# a weekly course, opens the panel on its latest date, sets the number of new dates and the Christmas weeks to skip
# (the list of dates on the right follows each change), creates them and returns to the list.
# Same technique as bin/make_tui_demo.jl: TangoTUI's real screens, drawn headlessly after each step and exported by
# Tachikoma's export_svg as an animated SVG. Run it in TangoTUI's environment and commit the result:
#   julia --project=TangoTUI bin/make_tui_repeat_demo.jl [out.svg]
using Dates, Tachikoma, TangoTUI, TangoKalender
const TK=TangoKalender
out=get(ARGS,1,joinpath(@__DIR__,"..","docs","src","assets","tangotui-repeat-demo.svg"))
const W=120; const H=34              # terminal size in cells
const TODAY=Date(2026,12,1)
set_theme!(KOKAKU)

# Invented data: a weekly course whose autumn term ends on 15 December.
venue=Dict("name"=>"Eksempelsalen","address"=>"Storgata 1","city"=>"Eksempelby")
kurs=Dict("id"=>"tirsdagskurs","title"=>"Tirsdagskurs","types"=>["class"],"weekday"=>"Tuesday",
 "start_time"=>"18:30","end_time"=>"20:00","venue"=>venue,"organizer"=>"Eksempel Tango","price_nok"=>250,
 "description"=>"Kurs for lett øvede, hver tirsdag.")
dir=mktempdir(); root=joinpath(dir,"events")
TK.save_event_tree(TK.expand_weekly(kurs;from=Date(2026,11,3),until=Date(2026,12,15)),root)

snaps=Vector{Tachikoma.Cell}[]; times=Float64[]; clock=Ref(0.0)
function snap!(m, hold)
 tb=Tachikoma.TestBackend(W,H)
 TangoTUI.view(m,Tachikoma.Frame(tb.buf,Rect(1,1,W,H),Tachikoma.GraphicsRegion[],Tachikoma.PixelSnapshot[]))
 push!(snaps,copy(tb.buf.content)); push!(times,clock[]); clock[]+=hold
end
key!(m, k)=TangoTUI.update!(m,k isa Char ? KeyEvent(k) : k isa Pair ? KeyEvent(k[1],k[2]) : KeyEvent(k))
type!(m, s)=foreach(c->key!(m,c),s)
cd(dir) do
 m=TangoTUI.search_editor(;root="events",today=TODAY)
 type!(m,"tirsdagskurs"); snap!(m,1.5)                             # the course's dates
 key!(m,:pagedown); snap!(m,1.2)                                   # its latest date, 15 December
 key!(m,:ctrl=>'r'); snap!(m,3.5)                                  # the panel: weekly for 6 months, dates on the right
 key!(m,:down); key!(m,:down); snap!(m,0.8)                        # down to «Antall» (fields that don't apply are skipped)
 key!(m,:enter); type!(m,"10"); snap!(m,0.8)
 key!(m,:enter); snap!(m,2.5)                                      # 10 new dates
 for _ in 1:3; key!(m,:down); end; key!(m,:enter); type!(m,"2026-12-22..2027-01-05"); snap!(m,1.2)
 key!(m,:enter); snap!(m,4.0)                                      # Christmas skipped, still 10 new dates
 key!(m,:ctrl=>'s'); snap!(m,3.5)                                  # created: back to the list with the new dates
 snap!(m,0.0)                                                      # export_svg holds the last frame as long as the gap before it
end
mkpath(dirname(out))
Tachikoma.export_svg(out,W,H,snaps,times)
println("wrote $out ($(filesize(out)) bytes, $(length(snaps)) frames, $(round(clock[];digits=1)) s loop)")
