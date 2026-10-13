# TangoTUI without a terminal: keys go to `update!`, the screen is drawn into Tachikoma's TestBackend, and edits are
# saved into a copy of the package's test site (test/fixtures/site/events), checked with `validate_event_tree`.
using Test, Dates, Tachikoma, TangoTUI, TangoKalender
const TK=TangoKalender
const FIXTURE=joinpath(pkgdir(TK),"test","fixtures","site")
const TODAY=Date(2026,10,13)
function tree()
 d=mktempdir(); cp(joinpath(FIXTURE,"events"),joinpath(d,"events")); joinpath(d,"events")
end
"Run `f` as the Oslo test site (city, URLs), like the package tests."
site(f)=TK._with_site(f,TK.load_site(joinpath(FIXTURE,"site.toml")))
"Feed keys: a String types its characters, a Symbol is a named key, `:ctrl=>'s'` a control key."
function keys!(m, ks...)
 for k in ks
  if k isa AbstractString; foreach(c->TangoTUI.update!(m,KeyEvent(c)),k)
  elseif k isa Pair; TangoTUI.update!(m,KeyEvent(k[1],k[2]))
  else TangoTUI.update!(m,KeyEvent(k)) end
 end
 m
end
"The screen as lines of text (`w`×`h` cells)."
function screen(m; w=140, h=40)
 tb=Tachikoma.TestBackend(w,h)
 TangoTUI.view(m,Tachikoma.Frame(tb.buf,Rect(1,1,w,h),Tachikoma.GraphicsRegion[],Tachikoma.PixelSnapshot[]))
 [rstrip(Tachikoma.row_text(tb,y)) for y in 1:h]
end
has(m,s;kw...)=any(l->occursin(s,l),screen(m;kw...))
to!(m,key)=(m.cursor=findfirst(f->f.key==key,m.fields); m)
@testset "TangoTUI" begin
 site() do
 @testset "edit: fields, pick lists, save" begin
  root=tree()
  m=TangoTUI.editor_for("edit",["ktf-milonga-2027-05-22"];root,today=TODAY)
  @test m.mode===:browse && m.event.id=="ktf-milonga-2027-05-22"
  @test has(m,"Milonga med show") && has(m,"Øvre Slottsgate 3") && has(m,"Forhåndsvisning") && has(m,"Ctrl-S lagre")
  # text field: Enter opens it with the current value, typing edits it, Enter applies
  t0=m.event.title; keys!(to!(m,"title"),:enter,:end_key," (ekstra)",:enter)
  @test m.event.title==t0*" (ekstra)" && has(m,"● endret")
  # a pick list: only the allowed values; Space ticks, Enter applies
  keys!(to!(m,"types"),:enter)
  @test m.mode===:pick && has(m,"[x] Milonga") && has(m,"[ ] Kurs")
  keys!(m,:up,:up," ",:enter)   # from Milonga up to Kurs
  @test m.event.types==["class","milonga"]
  keys!(to!(m,"status"),:enter,:down,:enter)
  @test m.event.status=="cancelled" && has(m,"AVLYST")
  # a value that can't be read stays open with a Norwegian message
  keys!(to!(m,"price_nok"),:enter,"gratis",:enter)
  @test m.mode===:text && occursin("ikke et helt tall",m.message)
  keys!(m,:escape); @test m.mode===:browse && isnothing(m.event.price_nok)
  keys!(m,:enter,"250",:enter); @test m.event.price_nok==250
  # a new date moves the file on save; offsets follow summer/winter time
  keys!(to!(m,"date"),:enter); m.input=TextInput(text="",focused=true); keys!(m,"2027-11-06",:enter)
  @test m.event.start=="2027-11-06T20:30:00+01:00"
  old=m.file; keys!(m,:ctrl=>'s')
  @test m.mode===:scope && has(m,"Gjelder endringen flere datoer?")   # the series has later dates: asked first
  keys!(m,"d")
  @test m.level===:ok && !isfile(old) && endswith(m.file,"2027/11-november/2027-11-06-ktf-milonga-2027-05-22.json")
  @test isempty(TK.validate_event_tree(root)) && m.saved==[m.file] && !TangoTUI._dirty(m)
  e,_=TK.read_event(m.file); @test e.last_verified=="2026-10-13" && e.types==["class","milonga"]
 end
 @testset "save refused while a field has a problem" begin
  root=tree(); m=TangoTUI.editor_for("edit",["ktf-milonga-2027-05-22"];root,today=TODAY)
  keys!(to!(m,"link"),:enter,:home); m.input=TextInput(text="ftp://x",focused=true); keys!(m,:enter)
  @test has(m,"Problemer:") && occursin("http",m.message)
  keys!(to!(m,"title"),:ctrl=>'s')
  @test m.level===:error && startswith(m.message,"Ikke lagret") && m.fields[m.cursor].key=="link"
  @test TK.read_event(m.file)[1].link=="https://www.kristianiatangofestival.com"   # file untouched
 end
 @testset "new event: blank, then a copy of a series" begin
  root=tree(); m=TangoTUI.editor_for("new",String[];root,today=TODAY)
  @test m.mode===:browse && TangoTUI._isnew(m) && m.event.venue.city=="Oslo"
  keys!(to!(m,"title"),:enter,"Practica på Majorstuen",:enter)
  keys!(to!(m,"types"),:enter,:down,:down,:down," ",:enter)   # Kurs → Workshop → Milonga → Practica
  keys!(to!(m,"start_time"),:enter,"12:00",:enter); keys!(to!(m,"end"),:enter,"14:00",:enter)
  @test m.event.id=="practica-pa-majorstuen-2026-10-13" && m.event.types==["practica"] && has(m,"nytt arrangement")
  keys!(m,:ctrl=>'s')
  @test m.level===:ok && endswith(m.file,"2026/10-october/2026-10-13-practica-pa-majorstuen-2026-10-13.json") && isempty(TK.validate_event_tree(root))
  # a copy: the latest of the series, on today's date, with the date field open
  c=TangoTUI.editor_for("new",["series:kristiania-tango-festival-2027"];root,today=TODAY)
  @test c.mode===:text && c.fields[c.cursor].key=="date" && occursin("Kopi av",c.message)
  c.input=TextInput(text="2028-05-20",focused=true); keys!(c,:enter)
  @test c.event.id=="kristiania-tango-festival-2027-2028-05-20" && c.event.series=="kristiania-tango-festival-2027"
 end
 @testset "search list: type to filter, ↑/↓ and Enter to open, Esc back" begin
  root=tree(); m=TangoTUI.search_editor(;root,today=TODAY)
  up=count(x->TK._lastday(x[2])>=TODAY,m.events)
  @test m.mode===:search && length(m.hits)==up && has(m,"Søk:") && has(m,"$up av $up kommende")
  @test all(i->TK._lastday(m.events[i][2])>=TODAY,m.hits) && issorted([m.events[i][2].start for i in m.hits])
  keys!(m,"kristiania show")                                         # every word must match, as on the web page
  @test !isempty(m.hits) && all(i->occursin("show",m.texts[i]) && occursin("kristiania",m.texts[i]),m.hits) && has(m,"Milonga med show")
  @test any(i->!occursin("show",lowercase(m.events[i][2].title)),m.hits)   # the description counts, as on the web page
  keys!(m,:escape); @test isempty(text(m.query)) && length(m.hits)==up && !m.quit   # first Esc clears the search
  keys!(m,"type:festival"); @test !isempty(m.hits) && all(i->"festival" in m.events[i][2].types,m.hits)
  keys!(m,:escape,"lørdag sentralen"); @test !isempty(m.hits) && all(i->dayofweek(TK._ymd(m.events[i][2].start))==6,m.hits)
  keys!(m,:escape,:ctrl=>'a'); @test m.past && length(m.hits)==length(m.events) && has(m,"også tidligere")
  @test m.events[m.hits[m.pick]][2].start>=string(TODAY)            # the selection starts at today, not in the past
  keys!(m,:ctrl=>'a',"ktf-milonga-2027-05-2"); n=length(m.hits); @test n>1
  keys!(m,:down,:enter); e=m.events[m.hits[2]]
  @test m.mode===:browse && m.file==e[1] && has(m,"Esc tilbake til listen")
  keys!(to!(m,"dj"),:enter,"DJ Test",:enter,:escape)
  @test m.mode===:confirm && !m.quit
  keys!(m,"s"); @test m.mode===:scope                               # save on quit asks the same question
  keys!(m,"d"); @test m.mode===:search && m.saved==[e[1]] && m.events[m.hits[m.pick]][1]==e[1] && has(m,"Lagret: ")
  @test m.events[m.hits[m.pick]][2].dj=="DJ Test" && text(m.query)=="ktf-milonga-2027-05-2"   # reloaded, search kept
  keys!(m,:enter,:escape); @test m.mode===:search                   # unchanged: straight back
  keys!(m,:escape,:escape); @test Tachikoma.should_quit(m)
 end
 @testset "search list: new and copy; edit TERM opens the one match" begin
  root=tree(); m=TangoTUI.search_editor(;root,today=TODAY)
  keys!(m,:ctrl=>'n'); @test m.mode===:browse && TangoTUI._isnew(m) && isempty(m.event.title)
  keys!(m,:escape); @test m.mode===:search                         # nothing typed: back without asking
  keys!(m,"ktf-milonga-2027-05-22",:ctrl=>'k')
  @test m.mode===:text && TangoTUI._isnew(m) && m.fields[m.cursor].key=="date" && occursin("Kopi av ktf-milonga-2027-05-22",m.message)
  o=TangoTUI.editor_for("edit",["ktf-milonga-2027-05-22"];root,today=TODAY)
  @test o.mode===:browse && o.listing && endswith(o.file,"2027-05-22-ktf-milonga-2027-05-22.json")
  keys!(o,:escape); @test o.mode===:search && text(o.query)=="ktf-milonga-2027-05-22" && length(o.hits)==1
  z=TangoTUI.editor_for("edit",["finnes-ikke"];root,today=TODAY)
  @test z.mode===:search && isempty(z.hits) && has(z,"Ingen treff")
  @test_throws ArgumentError TangoTUI.editor_for("new",["finnes-ikke"];root,today=TODAY)
 end
 @testset "a change for all later dates: the series or the search, same organiser only" begin
  root=tree(); m=TangoTUI.search_editor(;root,today=TODAY)
  keys!(m,"series:otra",:enter); e0=m.before; f0=m.file
  later=TK.later_in_series(f0,e0;root); @test length(later)>3
  earlier=[x for x in TK.find_events(["series:otra"];root,from=nothing) if x[2].start<e0.start]
  keys!(to!(m,"price_nok"),:enter,"180",:enter); keys!(to!(m,"start_time"),:enter); m.input=TextInput(text="19:30",focused=true); keys!(m,:enter)
  keys!(m,:ctrl=>'s')
  @test m.mode===:scope && has(m,"Endret: Starttid, Pris") && has(m,"a  Alle senere i serien «$(e0.series)»: $(length(later)) datoer") && has(m,"a alle senere i serien")
  keys!(m,:escape); @test m.mode===:browse && TK.read_event(f0)[1].price_nok!=180   # Esc: nothing saved
  keys!(m,:ctrl=>'s',"a")
  @test m.level===:ok && occursin("og $(length(later)) senere datoer",m.message) && length(m.saved)==length(later)+1
  for (f,x,_) in later
   y=TK.read_event(f)[1]
   @test y.price_nok==180 && occursin("T19:30:00",y.start) && y.start[1:10]==x.start[1:10] && y.last_verified=="2026-10-13"
  end
  @test occursin("T19:30:00+01:00",TK.read_event(later[end][1])[1].start)                # winter time on the December dates
  @test all(x->TK.read_event(x[1])[1].price_nok==x[2].price_nok,earlier)                   # earlier dates untouched
  @test isempty(TK.validate_event_tree(root))
  # the search as scope: only events with the same organiser change; the rest are listed as skipped
  m=TangoTUI.search_editor(;root,today=TODAY); keys!(m,"sentralen")
  sel=[m.events[i] for i in m.hits]; @test length(unique(something(x[2].organizer,"") for x in sel))>1
  i=findfirst(x->begin xs=TK.later_in_selection(x[1],x[2],[y[1] for y in sel];root); !isempty(xs) && any(y->y[2].organizer!=x[2].organizer,xs) end,sel)
  @test !isnothing(i)
  m.pick=i; keys!(m,:enter); ev=m.before
  keys!(to!(m,"dj"),:enter,"DJ Felles",:enter,:ctrl=>'s')
  @test m.mode===:scope && !isempty(m.selskip) && all(x->x[2].organizer!=ev.organizer,m.selskip) && all(x->x[2].organizer==ev.organizer,m.seltargets)
  @test has(m,"Hoppes over, annen arrangør: $(length(m.selskip))")
  if isempty(m.seltargets)
   @test !has(m,"u alle senere i utvalget"); keys!(m,"u"); @test m.mode===:scope    # nothing to apply: «u» does nothing
   keys!(m,"d")
  else
   skipped=m.selskip; keys!(m,"u")
   @test m.level===:ok && all(x->TK.read_event(x[1])[1].dj=="DJ Felles",m.seltargets) && all(x->TK.read_event(x[1])[1].dj==x[2].dj,skipped)
  end
  @test TK.read_event(m.file)[1].dj=="DJ Felles" && isempty(TK.validate_event_tree(root))
  # no search (opened directly): the selection isn't offered
  o=TangoTUI.Editor(TK.find_events(["series:otra"];root,from=TODAY)[1]...;root,today=TODAY)
  keys!(to!(o,"dj"),:enter,"X",:enter,:ctrl=>'s'); @test o.mode===:scope && isempty(o.seltargets) && !isempty(o.sertargets)
 end
 @testset "relative --root, as in a data repository" begin
  cd(dirname(tree())) do
   m=TangoTUI.editor_for("edit",["ktf-milonga-2027-05-22"];root="events",today=TODAY)
   @test has(m,"tangoedit · events/2027/05-may/2027-05-22-ktf-milonga-2027-05-22.json")
   keys!(to!(m,"dj"),:enter,"DJ Test",:enter,:ctrl=>'s',"d")
   @test m.level===:ok && m.message=="Lagret: events/2027/05-may/2027-05-22-ktf-milonga-2027-05-22.json"
  end
 end
 @testset "narrow terminal" begin
  m=TangoTUI.editor_for("edit",["ktf-milonga-2027-05-22"];root=tree(),today=TODAY)
  s=screen(m;w=72,h=30); @test any(l->occursin("Tittel",l),s) && all(l->textwidth(l)<=72,s)
 end
 end
end
