using Test, Dates, JSON, TangoKalender
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
 @test length(ids)==length(tree) && length(tree)>=49   # unique ids; grows as events are submitted
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
 @test count(">Avlyst<",h)==1   # one visible chip (the «Rett opp» link also mentions the status)
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
  @test read(out,String)=="earlier=1\npr_title=Nytt arrangement: Øvingskveld på Løkka (4 datoer fra 20. okt)\nissue_title=Arrangement: Øvingskveld på Løkka (4 datoer fra 20. okt)\n"
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
@testset "corrections" begin
 T=Date(2026,10,1); TK=TangoKalender
 tick="- [X] Ja"
 # a correction body as GitHub renders it: every form heading, unset fields as _No response_
 body(vals)=join(("### $l\n\n$(get(vals,l,"_No response_"))" for l in TK.CORRECTION_FIELDS),"\n\n")
 form(vals)=TK.parse_issue_form(body(merge(Dict("Samtykke"=>tick),vals)))
 prefill(e)=Dict(lbl=>TK.correction_fields(e)[id] for (id,lbl) in TK.CORRECTION_IDS)
 mktempdir() do d
  root=joinpath(d,"events"); cp(TREE,root)
  esa(dd)=load_events(only(f for f in TK.event_files(root) if endswith(f,"-esa-2026-$dd.json")))
  # unchanged prefill → nothing to do
  u,errs,_=TK.apply_correction(form(prefill(esa("10-13"))),root;today=T)
  @test isempty(u) && any(occursin("Ingen endringer",m) for m in errs)
  # blank fields = unchanged, so an id alone (prefill lost) is also "no changes", never a wipe
  @test any(occursin("Ingen endringer",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-13")),root;today=T)[2])
  # DJ on one date
  u,errs,ch=TK.apply_correction(form(merge(prefill(esa("10-13")),Dict("DJ"=>"Gjeste-DJ"))),root;today=T)
  @test isempty(errs) && length(u)==1 && ch==[("DJ","Varierer","Gjeste-DJ")]
  old=esa("10-13"); new=u[1][2]
  @test Set(k for k in keys(new) if new[k]!=old[k])==Set(["dj","last_verified"])
  # "-" clears an optional field; required fields can't be cleared
  @test isnothing(TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-13","DJ"=>"-")),root;today=T)[1][1][2]["dj"])
  @test any(occursin("«Sted» kan ikke fjernes",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-13","Sted"=>"-")),root;today=T)[2])
  # start time for this and all later dates, across the 25 Oct clock change
  u,errs,_=TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-20","Starttid"=>"19:00","Gjelder"=>TK.SERIES_SCOPE)),root;today=T)
  @test isempty(errs) && [x["id"] for (_,x) in u]==["esa-2026-$dd" for dd in ("10-20","10-27","11-03","11-10","11-17","11-24")]
  @test u[1][2]["start"]=="2026-10-20T19:00:00+02:00" && u[2][2]["start"]=="2026-10-27T19:00:00+01:00" && u[2][2]["end"]=="2026-10-27T23:00:00+01:00"
  # cancel the rest of a series
  u,errs,ch=TK.apply_correction(form(Dict("Arrangement-ID"=>"otq-2026-11-04","Status"=>"Avlyst","Gjelder"=>TK.SERIES_SCOPE)),root;today=T)
  @test isempty(errs) && length(u)==4 && all(x["status"]=="cancelled" for (_,x) in u) && ch==[("Status","Gjennomføres","Avlyst")]
  # errors
  @test any(occursin("én dato om gangen",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-20","Dato"=>"2026-10-21","Gjelder"=>TK.SERIES_SCOPE)),root;today=T)[2])
  @test any(occursin("Fant ikke",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"finnes-ikke")),root;today=T)[2])
  @test any(occursin("«Starttid» må være",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"esa-2026-10-13","Starttid"=>"kveld")),root;today=T)[2])
  @test any(occursin("ikke del av en serie",m) for m in TK.apply_correction(form(Dict("Arrangement-ID"=>"galla-1128","DJ"=>"X","Gjelder"=>TK.SERIES_SCOPE)),root;today=T)[2])
  # CLI: date change moves the file, keeps the id, writes titles
  bf=joinpath(d,"b.md"); rep=joinpath(d,"r.md"); out=joinpath(d,"out")
  write(bf,body(Dict("Samtykke"=>tick,"Arrangement-ID"=>"esa-2026-10-13","Dato"=>"2026-10-14","Kommentar"=>"Flyttet\n@noen sa det")))
  @test redirect_stdout(()->TK.main(["from-issue",bf,"--root=$root","--report=$rep","--outputs=$out","--today=2026-10-01"]),devnull)==0
  @test !isfile(joinpath(root,"2026","10-october","2026-10-13-esa-2026-10-13.json"))
  moved=load_events(joinpath(root,"2026","10-october","2026-10-14-esa-2026-10-13.json"))
  @test moved["id"]=="esa-2026-10-13" && moved["start"]=="2026-10-14T20:00:00+02:00" && isempty(validate_event_tree(root))
  r=read(rep,String); @test startswith(r,"✅") && occursin("| Dato | 2026-10-13 | 2026-10-14 |",r) && occursin("> @​noen sa det",r)
  @test read(out,String)=="pr_title=Rettelse: Milonga ESA (14. okt)\nissue_title=Rettelse: Milonga ESA (14. okt)\n"
  # rollback: an invalid file elsewhere in the tree makes validation fail → nothing changes
  before=read(joinpath(root,"2026","10-october","2026-10-20-esa-2026-10-20.json"),String)
  write(joinpath(root,"2026","10-october","broken.json"),"{\"id\":\"broken\"}")
  write(bf,body(Dict("Samtykke"=>tick,"Arrangement-ID"=>"esa-2026-10-20","DJ"=>"Ny")))
  @test redirect_stdout(()->redirect_stderr(()->TK.main(["from-issue",bf,"--root=$root","--report=$rep","--today=2026-10-01"]),devnull),devnull)==1
  @test read(joinpath(root,"2026","10-october","2026-10-20-esa-2026-10-20.json"),String)==before && startswith(read(rep,String),"❌")
 end
 # links
 e=load_events(joinpath(TREE,"2026","10-october","2026-10-06-esa-2026-10-06.json"))
 u=TK.correction_url(e)
 @test startswith(u,TK.CORRECT_URL*"&") && occursin("&arrangement_id=esa-2026-10-06&",u) && !occursin(' ',u)
 # editable fields are never prefilled (GitHub resets URL-prefilled fields on edit); current values go in «navaerende»
 @test !any(occursin("&$id=",u) for (id,_) in TK.CORRECTION_IDS if id!="arrangement_id")
 @test occursin("&navaerende=",u) && occursin("Sted: Halvorsens Conditori\nAdresse: Prinsens gate 26, Oslo",TK.current_summary(e))
 long=merge(Dict{String,Any}(e),Dict("description"=>repeat("x",10_000))); @test !occursin("xxxx",TK.correction_url(long)) && length(TK.correction_url(long))<=TK.MAX_URL
 h=render_events_html([e]); @test occursin("aria-label=\"Rett opp: Milonga ESA\">Rett opp ↗</a>",h) && occursin("arrangement_id=esa-2026-10-06",h)
 @test !occursin("Rett opp",render_events_html([e]; correct_url=""))
 # drift guard for the correction template
 tmpl=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","rett-arrangement.yml"),String)
 @test Set(strip(m[1]) for m in eachmatch(r"^      label: (.+)$"m,tmpl))==Set(TK.CORRECTION_FIELDS)
 ids=Set(strip(m[1]) for m in eachmatch(r"^    id: (.+)$"m,tmpl)); @test all(id in ids for (id,_) in TK.CORRECTION_IDS)
 @test isempty([l for l in split(tmpl,'\n') if occursin(r"^\s+[a-z_]+: (\d{4}-\d{1,2}-\d{1,2}|\d{1,2}:\d{2})",l)])
end
@testset "upcoming filter" begin
 TK=TangoKalender
 @test TK._end_day(Dict("start"=>"2026-10-02T21:00:00+02:00","end"=>"2026-10-03T01:30:00+02:00"))=="2026-10-02"   # evening past midnight
 @test TK._end_day(Dict("start"=>"2026-10-09T17:00:00+02:00","end"=>"2026-10-12T00:00:00+02:00"))=="2026-10-11"
 @test TK._end_day(Dict("start"=>"2026-10-02","end"=>"2026-10-06"))=="2026-10-06" && TK._end_day(Dict("start"=>"2026-11-28"))=="2026-11-28"
 evs=[Dict("title"=>"Fortid","type"=>"milonga","start"=>"2026-09-30T20:00:00+02:00"),
      Dict("title"=>"Festival","type"=>"festival","start"=>"2026-10-01","end"=>"2026-10-04"),
      Dict("title"=>"Sen milonga","type"=>"milonga","start"=>"2026-10-01T21:00:00+02:00","end"=>"2026-10-02T01:00:00+02:00"),
      Dict("title"=>"I dag","type"=>"practica","start"=>"2026-10-02T19:00:00+02:00","series"=>"s"),
      Dict("title"=>"Neste uke","type"=>"milonga","start"=>"2026-10-08T20:00:00+02:00")]
 h=render_events_html(evs)
 @test occursin("<option value=\"upcoming\" selected>Kommende</option>",h) && occursin("data-end=\"2026-10-04\"",h)
 node=Sys.which("node")
 if isnothing(node)
  @info "node not found – skipping the in-browser filter check"
 else
  mktempdir() do d
   f=joinpath(d,"p.html"); write(f,h)
   r=JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2026-10-02`,String))
   c=r["counts"]
   @test r["default"]=="upcoming" && r["reset"]=="upcoming"
   @test sort(c["upcoming"])==["2026-10-01","2026-10-02","2026-10-08"]   # ongoing festival + today + future; past and yesterday's late milonga hidden
   @test length(c["all"])==5 && sort(c["today"])==["2026-10-01","2026-10-02"] && c["recurring"]==["2026-10-02"]
   @test sort(c["week"])==["2026-10-01","2026-10-02","2026-10-08"]
  end
 end
end
