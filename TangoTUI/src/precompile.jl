# A PrecompileTools workload, so `julia -m TangoTUI` doesn't compile the editor on every start (it took about 7 s to
# the first screen, nearly all of it compiling Tachikoma's terminal loop, key dispatch and drawing for `Editor`).
# It runs the real app headlessly (Tachikoma's `io`/`tty_size`/`input`) on a small invented event tree with scripted
# keys, and drives the other modes (field edit, pick list, description window, save with the scope question, repeat
# panel) through `update!` and `view` on a TestBackend. Everything is written to a temporary directory.
"The workload's steps, in the site scope, on the event tree in `dir`."
function _workload(dir,weekly,today)
 root=joinpath(dir,"events")
 TK.save_event_tree([TK.expand_weekly(weekly("onsdagsmilonga","Onsdagsmilonga",["milonga"],"Wednesday","20:00","23:30");from=today,until=today+Day(42));
                     TK.expand_weekly(weekly("tirsdagskurs","Tirsdagskurs",["class"],"Tuesday","18:30","20:00");from=today,until=today+Day(42))],root)
 key!(m,k)=update!(m,k isa Char ? KeyEvent(k) : k isa Pair ? KeyEvent(k[1],k[2]) : KeyEvent(k))
 keys!(m,ks...)=foreach(k->k isa AbstractString ? foreach(c->key!(m,c),k) : key!(m,k),ks)
 draw(m)=(tb=Tachikoma.TestBackend(120,34); view(m,Tachikoma.Frame(tb.buf,Rect(1,1,120,34),Tachikoma.GraphicsRegion[],Tachikoma.PixelSnapshot[])))
 # the real app loop, headless: type, open, two fields down, Ctrl-R, then Ctrl-C closes panel, form and list
 m=search_editor(;root,today)
 task=@async Tachikoma.app(m;default_bindings=false,io=IOBuffer(),tty_size=(rows=34,cols=120),input=IOBuffer("milonga\r\e[B\e[B\x12\x03\x03\x03"))
 for _ in 1:300; istaskdone(task) && break; sleep(0.1); end
 istaskdone(task) || (m.quit=true; wait(task))          # never hang the precompilation
 # the other modes, without a terminal
 m=search_editor(;root,today); draw(m)
 keys!(m,"onsdag",:enter); draw(m)
 m.cursor=findfirst(f->f.key=="price_nok",m.fields); keys!(m,:enter,:backspace,"5",:enter); draw(m)
 m.cursor=findfirst(f->f.key=="types",m.fields); keys!(m,:enter," ",:down,:enter); draw(m)
 m.cursor=findfirst(f->f.key=="description",m.fields); keys!(m,:enter," Mer.",:enter,"Linje.",:up,:end_key); draw(m); keys!(m,:ctrl=>'s')
 keys!(m,:ctrl=>'s'); draw(m); keys!(m,"d"); draw(m)          # save: the «later dates» question, then this date only
 keys!(m,:ctrl=>'l'); draw(m); keys!(m,:enter); draw(m)        # Ctrl-L: that change to the later dates after all
 keys!(m,:ctrl=>'r',:down,:down,:enter,"2",:enter); draw(m); keys!(m,:ctrl=>'s'); draw(m)   # repeat 2 copies
 keys!(m,:ctrl=>'k'); draw(m); keys!(m,:escape,:escape); draw(m)
 draw(editor_for("edit",["tirsdagskurs"];root,today)); draw(editor_for("repeat",["tirsdagskurs"];root,today))
 draw(editor_for("new",["tirsdagskurs"];root,today)); draw(editor_for("new",String[];root,today))
end
@setup_workload begin
 venue=Dict("name"=>"Eksempelsalen","address"=>"Storgata 1","city"=>"Eksempelby")
 weekly(id,title,types,wd,t0,t1)=Dict("id"=>id,"title"=>title,"types"=>types,"weekday"=>wd,"start_time"=>t0,"end_time"=>t1,
  "venue"=>venue,"organizer"=>"Eksempel Tango","price_nok"=>120,"description"=>"Ukentlig, for alle nivåer.")
 today=Date(2026,10,26)
 @compile_workload begin
  mktempdir() do dir
   write(joinpath(dir,"site.toml"),"slug = \"eksempel\"\nname = \"Tangokalender | Eksempelby\"\ncity = \"Eksempelby\"\n"*
         "site_url = \"https://example.org\"\nrepo_url = \"https://github.com/eksempel/kalender\"\n")
   cd(()->TK._with_site(()->_workload(dir,weekly,today),TK._cli_site("")),dir)   # as `main` does: ./site.toml, then the site scope
  end
  precompile(main,(Vector{String},))
 end
end
