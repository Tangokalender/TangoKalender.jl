using Test, Dates, TangoKalender
const ROOT=joinpath(@__DIR__,"..")
const V1=joinpath(ROOT,"examples","oslo_tango_events_2026-09-30.json")
const TREE=joinpath(ROOT,"events")
const MEDIA=joinpath(@__DIR__,"fixtures","media")
@testset "renderer" begin
 for e in (load_events(V1),load_events(TREE))
  h=render_events_html(e); @test occursin("<!doctype html>",h); @test occursin("Milonga ESA",h); @test !occursin("nothing",h)
 end
 @test occursin("\$(st)–\$(en)",read(joinpath(ROOT,"src","render","html.jl"),String))
 @test occursin("Ukentlig tirsdag",render_events_html(load_events(V1)))
end
@testset "event tree" begin
 tree=load_events(TREE)
 ids=Set(e["id"] for e in tree)
 @test length(tree)==125
 @test all(e["id"] in ids for e in load_events(V1) if !isnothing(e["start"]) && e["id"]!="ktw")
 @test count(startswith("oslotango-tue-"),ids)==11 && count(startswith("oslotango-thu-"),ids)==12
 @test all(get(e,"series",nothing)=="esa" for e in tree if startswith(e["id"],"esa-"))
 @test all(haskey(e,"start") && !isnothing(e["start"]) for e in tree)
 @test isempty(validate_event_tree(TREE))
 @test isempty(validate_event_tree(MEDIA))
 up=upgrade_events(load_events(V1)); @test length(up)==49 && all(isempty∘validate_event,up)
 e=Dict("id"=>"x","start"=>"2026-10-15T20:30:00+02:00")
 @test event_path(e)==joinpath("events","2026","10-october","2026-10-15-x.json")
 @test_throws ArgumentError event_path(Dict("id"=>"x","start"=>nothing))
end
@testset "weekly expansion" begin
 t=Dict{String,Any}("id"=>"kurs","title"=>"Kurs","type"=>"class","weekday"=>"Tuesday","start_time"=>"18:00","end_time"=>"20:00","dj"=>nothing)
 xs=expand_weekly(t; from=Date(2026,10,14), until=Date(2026,11,3), except=[Date(2026,10,27)])
 @test [x["id"] for x in xs]==["kurs-2026-10-20","kurs-2026-11-03"]
 @test xs[1]["start"]=="2026-10-20T18:00:00+02:00" && xs[2]["end"]=="2026-11-03T20:00:00+01:00"
 @test all(x["series"]=="kurs" && x["status"]=="scheduled" && !haskey(x,"weekday") for x in xs)
 @test all(isempty∘validate_event,xs)
 late=merge(t,Dict("weekday"=>"Saturday","start_time"=>"21:00"))
 @test expand_weekly(merge(late,Dict("end_time"=>"24:00")); from=Date(2026,10,24), until=Date(2026,10,24))[1]["end"]=="2026-10-25T00:00:00+02:00"
 @test expand_weekly(merge(late,Dict("end_time"=>"02:00")); from=Date(2026,10,24), until=Date(2026,10,24))[1]["end"]=="2026-10-25T02:00:00+02:00"
 @test oslo_offset(Date(2026,10,24))=="+02:00" && oslo_offset(Date(2026,10,25))=="+01:00"
 @test oslo_offset(Date(2026,10,25),"02:30")=="+02:00" && oslo_offset(Date(2026,3,29),"01:30")=="+01:00" && oslo_offset(Date(2026,3,29),"20:00")=="+02:00"
end
@testset "schema rejects" begin
 good=load_events(joinpath(MEDIA,"2026","12-december","2026-12-05-milonga-video.json"))
 @test isempty(validate_event(good))
 bad(f)=(e=deepcopy(good); f(e); !isempty(validate_event(e)))
 @test bad(e->e["type"]="disco")
 @test bad(e->delete!(e,"title"))
 @test bad(e->e["start"]="15.10.2026")
 @test bad(e->delete!(e,"start"))
 @test bad(e->e["start"]=nothing)
 @test bad(e->e["status"]="postponed")
 @test bad(e->e["series"]="Not A Slug")
 @test validate_event(merge(good,Dict("weekday"=>"Tuesday")))==["unknown key(s): weekday"]
 @test bad(e->e["video"]=Dict("platform"=>"youtube","id"=>"short"))
 @test bad(e->e["video"]=Dict("platform"=>"vimeo","id"=>"abc"))
 @test bad(e->e["music_style"]=["salsa"])
 @test bad(e->e["flyer_url"]="javascript:alert(1)")
 @test bad(e->e["venu"]="typo")
 @test bad(e->e["price_nok"]=-5)
 mktempdir() do d
  src=joinpath(MEDIA,"2026","12-december","2026-12-05-milonga-video.json")
  mkpath(joinpath(d,"2026","11-november")); cp(src,joinpath(d,"2026","11-november","2026-12-05-milonga-video.json"))
  p=validate_event_tree(d); @test length(p)==1 && occursin("should be at",p[1][2])
  mkpath(joinpath(d,"2026","12-december")); cp(src,joinpath(d,"2026","12-december","2026-12-05-milonga-video.json"))
  @test any(occursin("duplicate id",m) for (_,m) in validate_event_tree(d))
 end
end
@testset "media rendering" begin
 h=render_events_html(load_events(MEDIA))
 @test occursin("https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",h)
 @test occursin("https://player.vimeo.com/video/123456789",h)
 @test occursin("<img class=\"flyer\" src=\"https://example.org/flyer.png\"",h)
 @test occursin("Mer info ↗",h)
 @test occursin("<option value=\"live_orchestra\">Levende orkester</option>",h)
 @test occursin("data-music=\"traditional live_orchestra\"",h)
 @test occursin("Kulturhuset",h) && occursin("Storgata 1, 0155 Oslo",h)
 @test occursin("class=\"event cancelled\"",h) && occursin(">Avlyst<",h) && occursin("data-series=\"weekly\"",h)
 @test count("Avlyst",h)==1
 e=load_events(joinpath(MEDIA,"2026","12-december","2026-12-05-milonga-video.json"))
 e["video"]=Dict("platform"=>"youtube","id"=>"\"><script>x"); e["flyer_url"]="javascript:alert(1)"
 h=render_events_html([e]); @test !occursin("<iframe",h); @test !occursin("<img",h); @test !occursin("<script>x",h)
end
@testset "cli" begin
 quiet(f)=redirect_stdout(f,devnull)
 @test quiet(()->TangoKalender.main(["--help"]))==0
 @test redirect_stderr(()->TangoKalender.main(["--bogus"]),devnull)==2
 @test redirect_stderr(()->TangoKalender.main(["validate","a","b"]),devnull)==2
 @test quiet(()->TangoKalender.main(["validate",TREE]))==0
 mktempdir() do d
  out=joinpath(d,"site","index.html")
  @test quiet(()->TangoKalender.main([MEDIA,out,"--title=Testkalender"]))==0
  @test occursin("<title>Testkalender</title>",read(out,String))
  bad=joinpath(d,"bad"); cp(MEDIA,bad); mv(joinpath(bad,"2026","12-december"),joinpath(bad,"2026","11-november"))
  @test redirect_stderr(()->TangoKalender.main(["build",bad,joinpath(d,"x.html")]),devnull)==1
  @test !isfile(joinpath(d,"x.html"))
  @test quiet(()->redirect_stderr(()->TangoKalender.main(["build",bad,joinpath(d,"x.html"),"--no-validate"]),devnull))==0
  @test quiet(()->TangoKalender.main(["migrate",V1,joinpath(d,"tree")]))==0
  @test length(load_events(joinpath(d,"tree")))==49
 end
end
@testset "date labels" begin
 L(st,en=nothing)=TangoKalender._date_label(isnothing(en) ? Dict("start"=>st) : Dict("start"=>st,"end"=>en))
 @test L("2026-10-02T21:00:00+02:00","2026-10-03T01:30:00+02:00")=="fredag 2. okt · 21:00–01:30"     # past midnight
 @test L("2026-10-06T20:00:00+02:00","2026-10-06T23:00:00+02:00")=="tirsdag 6. okt · 20:00–23:00"
 @test L("2026-10-09T17:00:00+02:00","2026-10-12T00:00:00+02:00")=="fredag 9. okt · 17:00 – søndag 11. okt"
 @test L("2026-10-02","2026-10-06")=="fredag 2. okt – tirsdag 6. okt"
 @test L("2026-10-05T20:00:00+02:00","2026-10-04T00:00:00+02:00")=="mandag 5. okt · 20:00"            # end before start ignored
 @test occursin("<aside>fredag 15. jan</aside>",render_events_html([Dict("title"=>"x","type"=>"festival","start"=>"2027-01-15")]))
 @test occursin("<aside>fredag 9. okt · 17:00</aside>",render_events_html([Dict("title"=>"x","type"=>"festival","start"=>"2026-10-09T17:00:00+02:00")]))
end
@testset "submit link" begin
 h=render_events_html([Dict("title"=>"a","type"=>"milonga","start"=>"2026-10-01")])
 @test count(TangoKalender.SUBMIT_URL,h)==2 && occursin("+ Legg til arrangement</a>",h)
 @test !occursin("Legg til arrangement",render_events_html([Dict("title"=>"a","type"=>"milonga","start"=>"2026-10-01")]; submit_url=""))
 @test !occursin("javascript:",render_events_html([Dict("title"=>"a","type"=>"milonga","start"=>"2026-10-01")]; submit_url="javascript:alert(1)"))
end
@testset "norwegian labels" begin
 h=render_events_html([Dict("title"=>"a","type"=>"class_and_social","start"=>"2026-10-01"),Dict("title"=>"b","type"=>"class","start"=>"2026-10-02")])
 @test occursin("<span class=\"chip\">Kurs og milonga</span>",h) && occursin("<option value=\"class\">Kurs</option>",h)
 @test !occursin("Class And Social",h)
end
@testset "issue form" begin
 ISSUES=joinpath(@__DIR__,"fixtures","issues"); T=Date(2026,10,1)
 form(f)=TangoKalender.parse_issue_form(read(joinpath(ISSUES,"$f.md"),String))
 f=form("single"); @test f["Gjentas til"]=="" && f["Tittel"]=="Milonga på Torget"
 ev,errs=TangoKalender.events_from_form(f; issue_url="https://github.com/o/r/issues/7", today=T)
 @test isempty(errs) && length(ev)==1
 e=ev[1]
 @test e["id"]=="milonga-pa-torget-2026-11-14" && e["type"]=="milonga" && isnothing(e["series"])
 @test e["start"]=="2026-11-14T20:30:00+01:00" && e["end"]=="2026-11-15T01:00:00+01:00"
 @test e["price_nok"]==150 && e["student_price_nok"]==100 && e["music_style"]==["traditional","live_orchestra"]
 @test e["flyer_url"]=="https://github.com/user-attachments/assets/0a1b2c3d-1111-2222-3333-444455556666"
 @test e["video"]==Dict("platform"=>"youtube","id"=>"dQw4w9WgXcQ") && e["source_url"]=="https://github.com/o/r/issues/7"
 ev,errs=TangoKalender.events_from_form(form("weekly"); today=T)
 @test isempty(errs) && [x["id"] for x in ev]==["ovingskveld-pa-lokka-2026-$d" for d in ("10-20","10-27","11-10","11-17")]
 @test all(x["series"]=="ovingskveld-pa-lokka" && x["type"]=="class_and_practica" for x in ev)
 @test ev[2]["start"]=="2026-10-27T19:00:00+01:00" && ev[1]["teachers"]==["Lærer A","Lærer B"] && ev[1]["video"]["platform"]=="vimeo"
 ev,errs=TangoKalender.events_from_form(form("invalid"); today=T)
 @test isempty(ev) && length(errs)==8
 @test any(occursin("«Sted» må fylles ut",m) for m in errs) && any(occursin("«Samtykke»",m) for m in errs)
 @test !isempty(TangoKalender.events_from_form(form("single"); today=Date(2026,12,1))[2])   # date has passed
 @test TangoKalender._video_from_url("https://youtu.be/dQw4w9WgXcQ")["id"]=="dQw4w9WgXcQ"
 @test TangoKalender._video_from_url("https://www.youtube.com/shorts/dQw4w9WgXcQ")["id"]=="dQw4w9WgXcQ"
 @test isnothing(TangoKalender._video_from_url("https://example.org/watch?v=dQw4w9WgXcQ"))
 @test TangoKalender._image_url("<img width=\"300\" src=\"https://x.org/a.png\">")=="https://x.org/a.png"
 @test TangoKalender._slug("Ærlig Øl & Åpen Gård!")=="aerlig-ol-apen-gard" && TangoKalender._slug("!!!")=="arrangement"
 # drift guard: every label in the issue template is a field the parser knows
 tmpl=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","nytt-arrangement.yml"),String)
 labels=[strip(m[1]) for m in eachmatch(r"^      label: (.+)$"m,tmpl)]
 @test Set(labels)==Set(TangoKalender.FORM_FIELDS)
 # GitHub's YAML loader rejects the whole form if a scalar parses as a Date/Time ("Tried to load unspecified class: Date")
 @test isempty([l for l in split(tmpl,'\n') if occursin(r"^\s+[a-z_]+: (\d{4}-\d{1,2}-\d{1,2}|\d{1,2}:\d{2})",l)])
 opts=Set(strip(m[1]) for m in eachmatch(r"^        - (?!label:)(.+)$"m,tmpl))
 @test all(v in opts for v in values(TangoKalender._TYPES))
 @test all(v in Set(strip(m[1]) for m in eachmatch(r"^        - label: (.+)$"m,tmpl)) for v in values(TangoKalender._MUSIC))
end
@testset "from-issue cli" begin
 ISSUES=joinpath(@__DIR__,"fixtures","issues")
 mktempdir() do d
  root=joinpath(d,"events"); rep=joinpath(d,"r.md")
  out=joinpath(d,"gh_output"); write(out,"earlier=1\n")
  run1()=TangoKalender.main(["from-issue",joinpath(ISSUES,"weekly.md"),"--root=$root","--report=$rep","--issue-url=https://github.com/o/r/issues/9","--today=2026-10-01","--outputs=$out"])
  @test redirect_stdout(run1,devnull)==0
  @test read(out,String)=="earlier=1\ntitle=Øvingskveld på Løkka (4 datoer fra 20. okt)\n"
  @test length(load_events(root))==4 && isempty(validate_event_tree(root))
  r=read(rep,String); @test startswith(r,"✅") && occursin("| tirsdag 20. okt · 19:00–22:00 | Øvingskveld på Løkka | Løkka Dans |",r)
  @test redirect_stdout(()->redirect_stderr(run1,devnull),devnull)==1      # refuses to overwrite
  @test occursin("finnes allerede",read(rep,String)) && length(load_events(root))==4
  bad()=TangoKalender.main(["from-issue",joinpath(ISSUES,"invalid.md"),"--root=$root","--report=$rep","--today=2026-10-01"])
  @test redirect_stdout(()->redirect_stderr(bad,devnull),devnull)==1 && startswith(read(rep,String),"❌")
  @test redirect_stdout(()->TangoKalender.main(["from-issue",joinpath(ISSUES,"single.md"),"--root=$root","--report=$rep","--today=2026-10-01"]),devnull)==0
  @test occursin("@​someone",read(rep,String)) || !occursin("@someone",read(rep,String))
 end
end
