using Test, Dates, JSON, TangoKalender
const ROOT=joinpath(@__DIR__,"..")
const TREE=joinpath(ROOT,"events")
const MEDIA=joinpath(@__DIR__,"fixtures","media")
@testset "renderer" begin
 h=render_events_html(load_events(TREE)); @test occursin("<!doctype html>",h); @test occursin("Milonga ESA",h); @test !occursin("nothing",h)
 @test !occursin("9999-12-31",h)                                               # every event is dated; no placeholder dates
end
@testset "event tree" begin
 tree=load_events(TREE)
 ids=Set(e["id"] for e in tree)
 @test length(ids)==length(tree) && length(tree)>=49   # unique ids; grows as events are submitted
 @test count(startswith("oslotango-tue-"),ids)==11 && count(startswith("oslotango-thu-"),ids)==12
 @test all(get(e,"series",nothing)=="esa" for e in tree if occursin(r"^esa-\d",e["id"]))   # the milonga; its classes are esa-nybegynner/esa-tandas
 @test all(haskey(e,"start") && !isnothing(e["start"]) for e in tree)
 @test isempty(validate_event_tree(TREE))
 @test isempty(validate_event_tree(MEDIA))
 e=Dict("id"=>"x","start"=>"2026-10-15T20:30:00+02:00")
 @test event_path(e)==joinpath("events","2026","10-october","2026-10-15-x.json")
 @test_throws ArgumentError event_path(Dict("id"=>"x","start"=>nothing))
end
@testset "weekly expansion" begin
 t=Dict{String,Any}("id"=>"kurs","title"=>"Kurs","types"=>["class"],"weekday"=>"Tuesday","start_time"=>"18:00","end_time"=>"20:00","dj"=>nothing)
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
 @test bad(e->e["types"]=["disco"]) && bad(e->e["types"]=String[]) && bad(e->delete!(e,"types")) && bad(e->e["types"]="milonga")
 @test bad(e->e["types"]=["milonga","milonga"])                                  # unique
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
 @test occursin("<input type=\"checkbox\" name=\"music\" value=\"live_orchestra\"><span>Levende orkester</span>",h)
 @test occursin("data-music=\"traditional live_orchestra\"",h)
 @test occursin("Kulturhuset",h) && occursin("Storgata 1, 0155 Oslo",h)
 @test occursin("class=\"event ev cancelled\"",h) && occursin(">Avlyst<",h) && occursin("data-series=\"weekly\"",h)
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
 end
end
@testset "date labels" begin
 L(st,en=nothing)=TangoKalender._date_label(isnothing(en) ? Dict("start"=>st) : Dict("start"=>st,"end"=>en))
 @test L("2026-10-02T21:00:00+02:00","2026-10-03T01:30:00+02:00")=="fredag 2. okt · 21:00–01:30"     # past midnight
 @test L("2026-10-06T20:00:00+02:00","2026-10-06T23:00:00+02:00")=="tirsdag 6. okt · 20:00–23:00"
 @test L("2026-10-09T17:00:00+02:00","2026-10-12T00:00:00+02:00")=="fredag 9. okt · 17:00 – søndag 11. okt"
 @test L("2026-10-02","2026-10-06")=="fredag 2. okt – tirsdag 6. okt"
 @test L("2026-10-05T20:00:00+02:00","2026-10-04T00:00:00+02:00")=="mandag 5. okt · 20:00"            # end before start ignored
 @test occursin("<aside>fredag 15. jan</aside>",render_events_html([Dict("title"=>"x","types"=>["festival"],"start"=>"2027-01-15")]))
 @test occursin("<aside>fredag 9. okt · 17:00</aside>",render_events_html([Dict("title"=>"x","types"=>["festival"],"start"=>"2026-10-09T17:00:00+02:00")]))
end
@testset "submit link" begin
 h=render_events_html([Dict("title"=>"a","types"=>["milonga"],"start"=>"2026-10-01")])
 @test count(TangoKalender.submit_form_url(),h)==2 && occursin("+ Legg til arrangement</a>",h)
 @test !occursin("Legg til arrangement",render_events_html([Dict("title"=>"a","types"=>["milonga"],"start"=>"2026-10-01")]; submit_url=""))
 @test !occursin("javascript:",render_events_html([Dict("title"=>"a","types"=>["milonga"],"start"=>"2026-10-01")]; submit_url="javascript:alert(1)"))
end
@testset "norwegian labels" begin
 h=render_events_html([Dict("title"=>"a","types"=>["class","milonga"],"start"=>"2026-10-01"),Dict("title"=>"b","types"=>["class"],"start"=>"2026-10-02")])
 @test occursin("<span class=\"chip\">Kurs</span> <span class=\"chip\">Milonga</span>",h) && occursin("<input type=\"checkbox\" name=\"type\" value=\"class\"><span>Kurs</span>",h)
 @test !occursin("Class And Social",h)
end
@testset "issue form" begin
 ISSUES=joinpath(@__DIR__,"fixtures","issues"); T=Date(2026,10,1)
 form(f)=TangoKalender.parse_issue_form(read(joinpath(ISSUES,"$f.md"),String))
 f=form("single"); @test f["Gjentas til"]=="" && f["Tittel"]=="Milonga på Torget"
 ev,errs=TangoKalender.events_from_form(f; issue_url="https://github.com/o/r/issues/7", today=T)
 @test isempty(errs) && length(ev)==1
 e=ev[1]
 @test e["id"]=="milonga-pa-torget-2026-11-14" && e["types"]==["milonga"] && isnothing(e["series"])
 @test e["start"]=="2026-11-14T20:30:00+01:00" && e["end"]=="2026-11-15T01:00:00+01:00"
 @test e["price_nok"]==150 && e["student_price_nok"]==100 && e["music_style"]==["traditional","live_orchestra"]
 @test e["flyer_url"]=="https://github.com/user-attachments/assets/0a1b2c3d-1111-2222-3333-444455556666"
 @test e["video"]==Dict("platform"=>"youtube","id"=>"dQw4w9WgXcQ") && e["source_url"]=="https://github.com/o/r/issues/7"
 ev,errs=TangoKalender.events_from_form(form("weekly"); today=T)
 @test isempty(errs) && [x["id"] for x in ev]==["ovingskveld-pa-lokka-2026-$d" for d in ("10-20","10-27","11-10","11-17")]
 @test all(x["series"]=="ovingskveld-pa-lokka" && x["types"]==["class","practica"] for x in ev)
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
 @test all(v in Set(strip(m[1]) for m in eachmatch(r"^        - label: (.+)$"m,tmpl)) for v in values(TangoKalender._TYPES))
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
 @test startswith(u,TK.correct_form_url()*"&") && occursin("&arrangement_id=esa-2026-10-06&",u) && !occursin(' ',u)
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
 evs=[Dict("title"=>"Fortid","types"=>["milonga"],"start"=>"2026-09-30T20:00:00+02:00"),
      Dict("title"=>"Festival","types"=>["festival"],"start"=>"2026-10-01","end"=>"2026-10-04"),
      Dict("title"=>"Sen milonga","types"=>["milonga"],"start"=>"2026-10-01T21:00:00+02:00","end"=>"2026-10-02T01:00:00+02:00"),
      Dict("title"=>"I dag","types"=>["practica"],"start"=>"2026-10-02T19:00:00+02:00","series"=>"s"),
      Dict("title"=>"Neste uke","types"=>["milonga"],"start"=>"2026-10-08T20:00:00+02:00")]
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
@testset "JSON submissions (KI)" begin
 TK=TangoKalender; T=Date(2026,10,1)
 # submission schema: derived from the stored one, loads as a schema, no bot-managed fields
 s=TK.submission_schema(); ev=s["definitions"]["event"]["properties"]
 @test isnothing(TK.JSONSchema.validate(TK.JSONSchema.Schema(s),JSON.parse(TK.EXAMPLE_OUTPUT)))       # the published example is valid
 @test !any(haskey(ev,k) for k in TK.BOT_FIELDS) && haskey(ev,"video_url")
 enum=JSON.parsefile(TK.SCHEMA_FILE)["properties"]["types"]["items"]["enum"]
 @test ev["types"]["items"]["enum"]==enum && Set(enum)==Set(TK.TYPE_ORDER)==Set(keys(TK._TYPES))
 # drift guard: the worked example in llms.txt converts to valid stored events
 events,errs=TK.events_from_json(TK.EXAMPLE_OUTPUT; issue_url="https://github.com/o/r/issues/3", today=Date(2027,1,1))
 @test isempty(errs) && length(events)==1
 e=events[1]
 @test e["id"]=="milonga-del-fiordo-2027-03-12" && e["start"]=="2027-03-12T21:00:00+01:00" && e["end"]=="2027-03-13T01:30:00+01:00"
 @test e["source"]=="Innsendt via KI-skjema" && e["source_url"]=="https://github.com/o/r/issues/3" && isnothing(e["series"]) && isempty(validate_event(e))
 @test occursin(TK.EXAMPLE_OUTPUT,TK.llms_txt()) && occursin(TK.submission_schema_url(),TK.llm_prompt())
 # fences + prose, arrays → series, Oslo offsets recomputed (wrong +01:00 in October), same-day end before start → next day
 ev1(d,st,en;kw...)=Dict{String,Any}("title"=>"Practica på Løkka","types"=>["practica"],"start"=>"$(d)T$st","end"=>"$(d)T$en",
  "venue"=>Dict("name"=>"Løkka Dans","address"=>"Thorvald Meyers gate 1"),"organizer"=>"Løkka Tango","link"=>"https://example.org/p",(string(k)=>v for (k,v) in kw)...)
 arr=[ev1("2026-10-21","19:00+01:00","22:00";id="hacked",confidence=0.1),ev1("2026-10-28","21:00","01:30";video_url="https://youtu.be/dQw4w9WgXcQ")]
 events,errs=TK.events_from_json("Her er svaret:\n```json\n$(JSON.json(arr,2))\n```\nSi ifra om noe mangler!"; today=T)
 @test isempty(errs) && [x["id"] for x in events]==["practica-pa-lokka-2026-10-21","practica-pa-lokka-2026-10-28"]
 @test all(x["series"]=="practica-pa-lokka" for x in events) && events[1]["confidence"]==1.0
 @test events[1]["start"]=="2026-10-21T19:00:00+02:00" && events[2]["start"]=="2026-10-28T21:00:00+01:00" && events[2]["end"]=="2026-10-29T01:30:00+01:00"
 @test events[2]["video"]==Dict("platform"=>"youtube","id"=>"dQw4w9WgXcQ") && events[1]["venue"]["city"]=="Oslo"
 # errors (Norwegian, with JSON paths)
 msg(t)=TK.events_from_json(t; today=T)[2]
 @test only(msg("ingen json her"))|>m->occursin("Fant ingen JSON",m)
 @test only(msg("{\"title\": \"x\""))|>m->occursin("kan ikke leses",m)
 @test only(msg(JSON.json(ev1("2026-10-21","19:00","22:00";types=["disco"]))))=="«types[1]»: \"disco\" er ikke en gyldig verdi. Lovlige verdier: milonga, practica, class, workshop, festival, marathon, outdoor, other."
 # an assistant may still answer with the old singular field (or a combined value): converted, not rejected
 old=ev1("2026-10-21","19:00","22:00"); delete!(old,"types"); old["type"]="class_and_social"
 r=TK.events_from_json(JSON.json(old);today=T); @test isempty(r[2]) && r[1][1]["types"]==["class","milonga"]
 @test occursin("«[1].venue.name»",only(msg(JSON.json([ev1("2026-10-21","19:00","22:00"),ev1("2026-10-28","19:00","22:00";venue=Dict("name"=>3,"address"=>"b"))]))))
 @test occursin("mangler påkrevd felt: types, start, venue, organizer, link",only(msg("{\"title\":\"X\"}")))
 # organizer is mandatory, and the rules tell the model where to find it
 noorg=ev1("2026-10-24","16:00","18:00"); delete!(noorg,"organizer")
 @test only(msg(JSON.json([noorg])))=="«[0]» mangler påkrevd felt: organizer."
 @test occursin("\"organizer\" is the group or person",TK.llm_rules()) && occursin("\"organizer\" and \"link\"",TK.llm_rules())
 @test occursin("har allerede vært",only(msg(JSON.json(ev1("2026-09-01","19:00","22:00")))))
 @test occursin("to ganger",only(msg(JSON.json([ev1("2026-10-21","19:00","22:00"),ev1("2026-10-21","19:00","22:00")]))))
 @test occursin("Høyst 60",only(msg(JSON.json([ev1("2026-10-21","19:00","22:00") for _ in 1:61]))))
 # CLI round trip through the JSON issue form (GitHub wraps a render: json textarea in a code fence)
 mktempdir() do d
  root=joinpath(d,"events"); bf=joinpath(d,"b.md"); rep=joinpath(d,"r.md"); out=joinpath(d,"o")
  write(bf,"### JSON\n\n```json\n$(JSON.json(arr,2))\n```\n\n### Samtykke\n\n- [X] Ja")
  @test redirect_stdout(()->TK.main(["from-issue",bf,"--root=$root","--report=$rep","--outputs=$out","--today=2026-10-01"]),devnull)==0
  @test length(load_events(root))==2 && isempty(validate_event_tree(root)) && startswith(read(rep,String),"✅")
  @test occursin("pr_title=Nytt arrangement: Practica på Løkka (2 datoer fra 21. okt)",read(out,String))
  write(bf,"### JSON\n\n```json\n$(JSON.json(ev1("2026-11-04","19:00","22:00")))\n```\n\n### Samtykke\n\n- [ ] Ja")
  @test redirect_stdout(()->redirect_stderr(()->TK.main(["from-issue",bf,"--root=$root","--report=$rep","--today=2026-10-01"]),devnull),devnull)==1
  @test occursin("«Samtykke» må krysses av",read(rep,String)) && length(load_events(root))==2
  # site: all files, links between them
  site=joinpath(d,"site"); @test redirect_stdout(()->TK.main(["site",MEDIA,site]),devnull)==0
  @test all(isfile(joinpath(site,f)) for f in ("index.html","legg-til.html","for-ki.html","llms.txt",".nojekyll",joinpath("mal","arrangementer-mal.csv"),joinpath("schema","tango-event.schema.json"),joinpath("schema","tango-event-submission.schema.json")))
  idx=read(joinpath(site,"index.html"),String)
  @test occursin("<a class=\"submit\" href=\"legg-til.html\">+ Legg til arrangement</a>",idx) && !occursin("Bruk KI",idx)   # one button
  ki=read(joinpath(site,"legg-til.html"),String)
  @test occursin(TK.submission_schema_url(),ki) && occursin(TK.json_form_url(),ki) && occursin("id=\"copy\"",ki)
  @test occursin(TK.submit_form_url(),ki) && occursin(TK.table_form_url(),ki) && all(occursin("id=\"$a\"",ki) for a in ("skjema","tabell","ki","rette"))
  @test occursin("url=legg-til.html#ki",read(joinpath(site,"for-ki.html"),String))                        # old address redirects
  @test JSON.parsefile(joinpath(site,"schema","tango-event-submission.schema.json"))["\$id"]==TK.submission_schema_url()
 end
 # the JSON issue form uses the labels the parser expects
 tmpl=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","nytt-arrangement-json.yml"),String)
 @test Set(strip(m[1]) for m in eachmatch(r"^      label: (.+)$"m,tmpl))==Set(["JSON","Samtykke"]) && occursin("render: json",tmpl)
 @test isempty([l for l in split(tmpl,'\n') if occursin(r"^\s+[a-z_]+: (\d{4}-\d{1,2}-\d{1,2}|\d{1,2}:\d{2})",l)])
end
@testset "views, event pages, ics, rss" begin
 TK=TangoKalender; T=Date(2026,10,2)
 E(id,st;kw...)=Dict{String,Any}("id"=>id,"title"=>"Milonga $id","types"=>["milonga"],"start"=>st,"venue"=>Dict("name"=>"Salen","address"=>"Gata 1, Oslo"),
  "organizer"=>"Klubben","last_verified"=>"2026-10-01","first_seen"=>"2026-09-30",(string(k)=>v for (k,v) in kw)...)
 evs=[E("a","2026-10-24T16:00:00+02:00";end_="x"),E("b","2026-11-14T16:00:00+01:00";first_seen="2026-10-01",series="s"),
      E("c","2026-10-09";types=["festival"],var"end"="2026-10-11",title="Festival & <Fest>"),E("old","2026-09-01T20:00:00+02:00"),
      E("d","2026-11-21T16:00:00+01:00";series="s",status="cancelled",dj="DJ Æøå",price_nok=150)]
 for e in evs; delete!(e,"end_"); end
 # --- ICS
 ics=TK.calendar_ics(evs;today=T)
 @test occursin("UID:a@tangokalender.github.io",ics) && occursin("DTSTART:20261024T140000Z",ics) && occursin("DTSTART:20261114T150000Z",ics)
 @test occursin("DTSTART;VALUE=DATE:20261009",ics) && occursin("DTEND;VALUE=DATE:20261012",ics)        # exclusive end
 @test occursin("STATUS:CANCELLED",ics) && count("BEGIN:VEVENT",ics)==5 && occursin("SUMMARY:Festival & <Fest>",ics)
 @test !occursin(r"[^\r]\n",ics) && all(ncodeunits(l)<=75 for l in split(ics,"\r\n"))
 long=TK.calendar_ics([E("l","2026-10-24T16:00:00+02:00";description=repeat("Æøå, ;tango\n",20))];today=T)
 unf=replace(long,"\r\n "=>""); @test occursin("DESCRIPTION:Æøå\\, \\;tango\\nÆøå",unf) && all(ncodeunits(l)<=75 for l in split(long,"\r\n")) && isvalid(long)
 @test TK._utc("2026-10-25T02:30:00+02:00")=="20261025T003000Z" && TK._utc("2026-10-02")===nothing
 # --- RSS
 rss=TK.rss_xml(evs;today=T)
 @test !occursin("Milonga old",rss) && count("<item>",rss)==4
 @test findfirst("Milonga b",rss)<findfirst("Milonga a",rss)                                            # newest addition first
 @test occursin("Festival &amp; &lt;Fest&gt;",rss) && !occursin("<Fest>",rss) && occursin("<guid isPermaLink=\"true\">$(TK.site_url())/arrangement/a/</guid>",rss)
 @test occursin("<pubDate>Thu, 01 Oct 2026 00:00:00 +0200</pubDate>",rss) && occursin("AVLYST: ",rss)
 @test count("<item>",TK.rss_xml([E("r$i","2026-12-01T20:00:00+01:00") for i in 1:150];today=T))==TK.RSS_MAX
 if !isnothing(Sys.which("python3"))
  mktempdir() do d; f=joinpath(d,"r.xml"); write(f,rss); @test success(`python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" $f`); end
 end
 # --- event page
 x=Dict{String,Any}(evs[3]); x["title"]="<script>alert(1)</script>"
 p=TK.render_event_page(x,evs;today=T); @test !occursin("<script>alert",p) && occursin("&lt;script&gt;",p)
 @test JSON.parse(match(r"<script type=\"application/ld\+json\">(.*?)</script>"s,p)[1])["name"]=="<script>alert(1)</script>"   # escaped JSON still decodes
 p=TK.render_event_page(evs[2],evs;today=T)
 ld=JSON.parse(match(r"<script type=\"application/ld\+json\">(.*?)</script>"s,p)[1])
 @test ld["@type"]=="Event" && ld["startDate"]=="2026-11-14T16:00:00+01:00" && ld["eventStatus"]=="https://schema.org/EventScheduled"
 @test occursin("<link rel=\"canonical\" href=\"$(TK.site_url())/arrangement/b/\">",p) && occursin("property=\"og:title\" content=\"Milonga b · ",p)
 @test occursin("href=\"../b.ics\" download",p) && occursin("Rett opp ↗",p) && occursin("href=\"../d/\"",p) && occursin("Flere datoer i denne serien",p)
 pd=TK.render_event_page(evs[5],evs;today=T); @test occursin("EventCancelled",pd) && occursin("<b>Avlyst.</b>",pd) && occursin("DJ Æøå",pd)
 @test occursin("Dette arrangementet har vært",TK.render_event_page(evs[4],evs;today=T))
 # --- compact list and week view
 c=render_events_html(evs;view="compact",site=true)
 heads=[m[1] for m in eachmatch(r"<section class=\"group\" data-group=\"([^\"]+)\">",c)]
 @test heads==sort(heads) && issubset(["2026-10-09","2026-10-10","2026-10-11"],heads)                  # festival on each of its days
 @test count("data-eid=\"c\"",c)==3 && occursin("dag 2 av 3",c) && occursin("<a href=\"arrangement/a/\">Milonga a</a>",c)
 @test occursin("class=\"on\" aria-current=\"page\">Liste</a>",c) && !occursin("id=\"sort\"",c) && occursin("href=\"rss.xml\"",c)
 @test !occursin("arrangement/",render_events_html(evs;view="compact"))                                 # no event pages outside the site
 w=render_events_html(evs;view="week",site=true)
 @test occursin("data-week=\"2026-W41\"",w) && occursin("id=\"uke-2026-41\"",w) && occursin("data-label=\"Uke 41 · 5.–11. okt\"",w)
 @test occursin("data-label=\"Uke 44 · 26. okt – 1. nov\"",w) && !occursin("id=\"when\"",w)                # range across months
 # a 7-column grid per week, Monday first, weekends marked, empty days get a placeholder
 sec=match(r"<section class=\"week\" id=\"uke-2026-41\".*?</section>"s,w).match
 cols=[m[1] for m in eachmatch(r"<div class=\"group col[^\"]*\" data-keep=\"1\" data-group=\"([^\"]+)\">",sec)]
 @test cols==string.(Date(2026,10,5):Day(1):Date(2026,10,11)) && count("class=\"group col weekend\"",sec)==2
 @test occursin("<span class=\"wd\">man</span> <span class=\"dm\">5. okt</span>",sec) && occursin("title=\"mandag 5. oktober\"",sec)
 @test occursin("class=\"weekgrid\"",w) && occursin("<p class=\"none\">–</p>",w)
 # the class for days without events must not collide with a display:none rule (it hid empty week columns)
 css=match(r"<style>(.*?)</style>"s,w)[1]
 for cls in eachmatch(r"classList\.toggle\('([a-z]+)',!has\)",TK._JS)
  k=cls[1]; k=="hidden" && continue
  @test !occursin(Regex("(^|[},])\\.$k\\{[^}]*display:none"),css)
 end
 @test occursin("class=\"cell ev t-festival\"",w) && occursin("<span class=\"dayn\">2/3</span>",w) && occursin("<a href=\"arrangement/c/\">",w)
 node=Sys.which("node")
 if !isnothing(node)
  mktempdir() do d
   run_(page,now,hash="")=(f=joinpath(d,"p.html"); write(f,page); JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f $now $hash`,String)))
   r=run_(c,"2026-10-10")
   @test r["default"]=="upcoming" && !("2026-09-01" in r["counts"]["upcoming"]) && !("2026-10-09" in r["groups"]["upcoming"]) && "2026-10-10" in r["groups"]["upcoming"]
   r=run_(w,"2026-10-10"); @test r["weeks"]["default"]=="2026-W41" && r["weeks"]["next"]=="2026-W42" && r["weeks"]["prev"]=="2026-W40"
   @test r["weeks"]["label"]=="Uke 41 · 5.–11. okt" && r["weeks"]["today"]==["2026-10-10"]
   @test r["weeks"]["keyRight"]=="2026-W42" && r["weeks"]["keyInInput"]=="2026-W42"                    # arrow keys, but not while typing
   @test run_(w,"2026-01-01")["weeks"]["prevDisabledAtStart"]                                            # no week before the first
   @test run_(w,"2026-10-10","#uke-2026-46")["weeks"]["hash"]=="2026-W46"
   @test run_(w,"2027-06-01")["weeks"]["default"]==last([m[1] for m in eachmatch(r"data-week=\"([^\"]+)\"",w)])   # after the last week: show the last
  end
 end
 # --- whole site: files and links
 mktempdir() do d
  files=TK.write_site(d,evs;today=T)
  @test all(isfile(joinpath(d,f)) for f in ("index.html","uke.html","kort.html","kalender.ics","rss.xml","legg-til.html","for-ki.html","llms.txt",joinpath("arrangement","a","index.html"),joinpath("arrangement","a.ics")))
  @test occursin("class=\"group\"",read(joinpath(d,"index.html"),String))                                # index = compact list
  k=read(joinpath(d,"kalender.ics"),String); @test count("BEGIN:VEVENT",k)==4 && !occursin("UID:old@",k)   # window: 30 days back (old is 31)
  broken=String[]
  for (r,_,fs) in walkdir(d), f in fs
   endswith(f,".html") || continue
   html=replace(read(joinpath(r,f),String),r"<script>.*?</script>"s=>"")      # code in scripts is not a link
   bm=match(r"<base href=\"([^\"]+)\"",html)                                       # <base> = relative to a language root
   base=isnothing(bm) ? r : joinpath(d,replace(bm[1],TangoKalender.site_url()*"/"=>""))
   for m in eachmatch(r"(?:href|src)=\"([^\"]+)\"",html)
    u=replace(m[1],"&amp;"=>"&"); occursin(r"^(https?:|webcal:|mailto:|#|data:)",u) && continue
    t=normpath(joinpath(base,first(split(u,['#','?'])))); (endswith(u,"/") || isdir(t)) && (t=joinpath(t,"index.html"))
    isfile(t) || push!(broken,"$(relpath(joinpath(r,f),d)) → $u")
   end
  end
  @test isempty(broken)
 end
end
@testset "icons" begin
 TK=TangoKalender
 e=Dict{String,Any}("id"=>"x","title"=>"Milonga X","types"=>["milonga"],"start"=>"2026-10-24T20:00:00+02:00","venue"=>Dict("name"=>"Salen","address"=>"Gata 1"),
  "organizer"=>"Klubben","dj"=>"DJ Y","teachers"=>["A","B"],"price_nok"=>150,"music_style"=>["traditional"])
 pages=[render_events_html([e];view=v,site=true) for v in ("compact","week","cards")]; push!(pages,TK.render_event_page(e,[e]))
 for h in pages
  used=Set(m[1] for m in eachmatch(r"<use href=\"#i-([a-z]+)\"/>",h))
  @test !isempty(used) && all(occursin("<symbol id=\"i-$u\"",h) for u in used)                    # every icon is in the page sprite
  @test count("<svg class=\"ic\" aria-hidden=\"true\"",h)==count("<use href=\"#i-",h)                 # all decorative
  @test count("<svg width=\"0\" height=\"0\"",h)==1
 end
 c=pages[1]
 @test occursin("<span class=\"f\" title=\"DJ\"><svg class=\"ic\" aria-hidden=\"true\" focusable=\"false\"><use href=\"#i-dj\"/></svg><span class=\"sr\">DJ: </span>DJ Y</span>",c)
 @test occursin("#i-price",c) && occursin("#i-teachers",c) && occursin("#i-pin",c)
 @test occursin("<dt><svg class=\"ic\" aria-hidden=\"true\" focusable=\"false\"><use href=\"#i-dj\"/></svg>DJ</dt>",pages[4])
 @test_throws ArgumentError TK._icon("nope")
end

# ---------------------------------------------------------------------------------------------------------------
# Filters: multi-select and URL state (Node harness), and what a real browser actually shows (headless Chrome).
FILTER_EVENTS=[Dict{String,Any}("id"=>id,"title"=>t,"types"=>[ty],"start"=>st,"venue"=>Dict("name"=>"Salen $id","address"=>"Gata 1"),"organizer"=>"Klubb",
  "music_style"=>mu,(isnothing(en) ? () : ("end"=>en,))...) for (id,t,ty,st,en,mu) in [
 ("a","Milonga A","milonga","2035-03-05T20:00:00+01:00",nothing,Any[]),
 ("b","Practica B","practica","2035-03-06T19:00:00+01:00",nothing,Any["traditional"]),
 ("c","Kurs C","class","2035-03-07T18:00:00+01:00",nothing,Any["alternative"]),
 ("f","Festival F","festival","2035-03-05","2035-03-07",Any[]),
 ("p","Gammel P","milonga","2020-01-05T20:00:00+01:00",nothing,Any[])]]
@testset "filters: multi-select + URL (harness)" begin
 node=Sys.which("node")
 if isnothing(node); @info "node not found – skipping"; else
 mktempdir() do d
  run_(page,search)=(f=joinpath(d,"p.html"); write(f,page); JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2034-01-01 "" $search`,String)))
  c=render_events_html(FILTER_EVENTS;view="compact",site=true)
  @test count("name=\"type\"",c)==4 && count("name=\"music\"",c)==2 && occursin("id=\"sharefilter\"",c)
  types(r)=Set(x[2] for x in r["initial"]["rows"]); eids(r)=Set(x[3] for x in r["initial"]["rows"])
  r=run_(c,""); @test eids(r)==Set(["a","b","c","f"]) && r["initial"]["search"]==""                   # default: upcoming, all types
  r=run_(c,"?type=milonga,practica")
  @test types(r)==Set(["milonga","practica"]) && Set(r["initial"]["checked"])==Set(["type:milonga","type:practica"])
  @test r["initial"]["search"]=="?type=milonga,practica" && all(endswith(t,"?type=milonga,practica") for t in r["initial"]["tabs"])
  @test eids(run_(c,"?music=traditional,alternative"))==Set(["b","c"])                                  # any of the ticked music styles
  @test eids(run_(c,"?q=kurs%20salen"))==Set(["c"]) && eids(run_(c,"?q=Salen%20Kurs"))==Set(["c"])       # several words: all must match, any order
  @test "p" in eids(run_(c,"?when=all")) && run_(c,"?when=all")["initial"]["when"]=="all"
  r=run_(c,"?when=bogus&type=nope&sort=x"); @test eids(r)==Set(["a","b","c","f"]) && r["initial"]["search"]==""   # unknown values ignored
  r=run_(c,"?type=class"); @test r["afterReset"]["search"]=="" && r["afterReset"]["checked"]==0           # «Nullstill» clears URL too
  w=render_events_html(FILTER_EVENTS;view="week",site=true)
  r=run_(w,"?type=practica"); @test eids(r)==Set(["b"]) && r["initial"]["search"]=="?type=practica" && occursin("type=practica",r["initial"]["tabs"][1])
  @test count("class=\"week\"",render_events_html(FILTER_EVENTS;view="week",site=true,today=Date(2035,3,1)))==6        # from 4 weeks back, not from 2020
 end; end
end
"Headless Chrome/Chromium for browser tests: TANGO_CHROME, or a chrome/chromium on PATH; `nothing` skips them."
function find_chrome()
 p=get(ENV,"TANGO_CHROME",""); !isempty(p) && isfile(p) && return p
 for c in ("google-chrome","google-chrome-stable","chromium","chromium-browser","chrome","chrome-headless-shell"); x=Sys.which(c); isnothing(x) || return x; end
 nothing
end
const PROBE="<script>document.querySelectorAll('.ev,.group').forEach(e=>e.setAttribute('data-vis',e.getClientRects().length?'1':'0'));document.querySelectorAll('input[type=checkbox]').forEach(b=>b.setAttribute('data-checked',b.checked?'1':'0'));document.body.setAttribute('data-url',location.search+location.hash);var m=document.getElementById('morefilters'),c=document.getElementById('fcount');if(m)document.body.setAttribute('data-more',m.getClientRects().length?'1':'0');if(c)document.body.setAttribute('data-fcount',c.textContent);</script>"
"Load `page` in headless Chrome at `?search`, return (visible event ids, ticked boxes, url, dom)."
function browser_view(chrome,dir,page,search;size="1280,900")
 f=joinpath(dir,"b.html"); write(f,replace(page,"</body>"=>PROBE*"</body>"))
 dom=read(pipeline(`$chrome --headless --no-sandbox --disable-gpu --window-size=$size --virtual-time-budget=3000 --dump-dom file://$f$search`;stderr=devnull),String)
 vis=Set(m[1] for m in eachmatch(r"<article class=\"[^\"]*\bev\b[^\"]*\" data-eid=\"([^\"]+)\"[^>]*data-vis=\"1\"",dom))
 hid=Set(m[1] for m in eachmatch(r"<article class=\"[^\"]*\bev\b[^\"]*\" data-eid=\"([^\"]+)\"[^>]*data-vis=\"0\"",dom))
 ticked=Set(m[1] for m in eachmatch(r"<input type=\"checkbox\" name=\"[a-z]+\" value=\"([^\"]+)\" data-checked=\"1\"",dom))
 url=something(match(r"<body[^>]*data-url=\"([^\"]*)\"",dom),(nothing,""))[1]
 more=something(match(r"<body[^>]*data-more=\"([01])\"",dom),(nothing,""))[1]
 fcount=something(match(r"<body[^>]*data-fcount=\"([^\"]*)\"",dom),(nothing,""))[1]
 (vis=setdiff(vis,Set{String}()),hid,ticked,url=replace(url,"&amp;"=>"&"),more,fcount,dom)
end
@testset "filters in a real browser" begin
 chrome=find_chrome()
 if isnothing(chrome)
  @info "No Chrome/Chromium found (set TANGO_CHROME) – skipping browser tests"
 else
  mktempdir() do d
   pages=Dict(v=>render_events_html(FILTER_EVENTS;view=v,site=true,today=Date(2035,3,1)) for v in ("compact","week","cards"))
   r=browser_view(chrome,d,pages["compact"],"")
   @test r.vis==Set(["a","b","c","f"]) && "p" in r.hid                                                    # past event really hidden
   r=browser_view(chrome,d,pages["compact"],"?type=milonga,practica")
   @test r.vis==Set(["a","b"]) && r.ticked==Set(["milonga","practica"]) && r.url=="?type=milonga,practica"
   @test occursin("href=\"uke.html?type=milonga,practica\"",r.dom)                                       # tabs keep the filter
   @test browser_view(chrome,d,pages["compact"],"?q=kurs%20salen").vis==Set(["c"])
   @test browser_view(chrome,d,pages["compact"],"?music=traditional,alternative").vis==Set(["b","c"])
   @test "p" in browser_view(chrome,d,pages["compact"],"?when=all").vis
   r=browser_view(chrome,d,pages["week"],"?type=practica#uke-2035-10")                                  # the bug: rows stayed visible
   @test r.vis==Set(["b"]) && issubset(Set(["a","c","f"]),r.hid) && startswith(r.url,"?type=practica#uke-2035-10")
   r=browser_view(chrome,d,pages["cards"],"?type=class,festival"); @test r.vis==Set(["c","f"])
   # phones: the filter block is folded away by default; the toggle shows how many filters are active
   @test browser_view(chrome,d,pages["compact"],"").more=="1"                                            # desktop: always visible
   r=browser_view(chrome,d,pages["compact"],"";size="390,844"); @test r.more=="0" && r.fcount==""
   r=browser_view(chrome,d,pages["compact"],"?type=milonga,practica&when=all";size="390,844")
   @test r.more=="0" && r.fcount==" (3)" && r.vis==Set(["a","b","p"])                                     # folded, but still filtering
  end
 end
end
@testset "site URL drift" begin
 TK=TangoKalender
 @test TK.site_url()=="https://tangokalender.github.io" && TK.repo_url()=="https://github.com/Tangokalender/tangokalender.github.io"
 @test JSON.parsefile(TK.SCHEMA_FILE)["\$id"]==TK.site_url()*"/schema/tango-event.schema.json"
 # every absolute link to the site or the repo in source, schema, issue forms and docs uses the current site_url()/repo_url()
 host=replace(TK.site_url(),r"^https://"=>""); repo=replace(TK.repo_url(),r"^https://"=>"")
 bad=String[]
 for dir in ("src","schema",".github","events"), (r,_,fs) in walkdir(joinpath(ROOT,dir)), f in fs
  p=joinpath(r,f); t=read(p,String)
  occursin("github.io/TangoKalender.jl",t) && push!(bad,"$p: old project-site path")
  for m in eachmatch(r"(?:https?|webcal)://([a-z0-9.-]*github\.(?:io|com)/[A-Za-z0-9._-]*)",t)
   u=m[1]; (startswith(u,host) || startswith(u,repo)) && continue
   occursin(r"^(github\.com/(orgs|julia-actions|actions|peter-evans|stefanbuck)|[a-z0-9-]+\.github\.io/?$|user-attachments)",u) && continue
   occursin(r"^github\.com/[A-Za-z0-9-]+/?$",u) && continue
   startswith(u,"github.com/Tangokalender") && push!(bad,"$p: $u")
   startswith(u,"tangokalender.github.io/") && push!(bad,"$p: $u")
  end
 end
 for f in ("README.md","CLAUDE.md","TODO.md"); occursin("github.io/TangoKalender.jl/",read(joinpath(ROOT,f),String)) && push!(bad,f); end
 @test isempty(bad)
end
@testset "table input (pasted spreadsheet cells)" begin
 TK=TangoKalender; T=Date(2026,10,4)
 # parsing: tabs (Excel/Sheets clipboard), semicolon CSV, quoted cells with separators/line breaks, code fence
 @test TK.parse_table("A\tB\n1\t2\n\t3\n")==[["A","B"],["1","2"],["","3"]]
 @test TK.parse_table("```text\nA;B\n\"x;y\";\"to\nlinjer\"\n```")==[["A","B"],["x;y","to\nlinjer"]]
 @test TK.parse_table("A,B\n1,2")==[["A","B"],["1","2"]] && TK.parse_table("A\tB\n\t\n1\t2")==[["A","B"],["1","2"]]   # empty rows dropped
 H="Tittel\tType\tDato\tStarttid\tSluttid\tSted\tAdresse\tArrangør\tDJ\tPris (kr)\tMusikk\tLenke\tStatus\n"
 row(c...)=join(c,"\t")*"\n"
 full=row("Fredagsmilonga","Milonga","16.10.2026","20:00","00:30","Salen","Gata 1, Oslo","Klubben","DJ A","150 kr","Tradisjonell, Alternativ / neo","https://example.org","")
 ev,errs=TK.events_from_table(H*full*row("","","23.10.2026","","","","","","DJ B","","","","")*row("","","2026-10-30","","","","","","-","","","","Avlyst"); today=T)
 @test isempty(errs) && [e["id"] for e in ev]==["fredagsmilonga-2026-10-$d" for d in ("16","23","30")]
 @test [e["dj"] for e in ev]==["DJ A","DJ B",nothing] && [e["status"] for e in ev]==["scheduled","scheduled","cancelled"]   # defaults, deviation, «-», Avlyst
 @test all(e["series"]=="fredagsmilonga" && e["price_nok"]==150 && e["music_style"]==["traditional","alternative"] && e["source"]=="Innsendt via tabell" for e in ev)
 @test ev[3]["start"]=="2026-10-30T20:00:00+01:00" && ev[1]["end"]=="2026-10-17T00:30:00+02:00"        # clock change, past midnight
 one,_=TK.events_from_table(H*full;today=T); @test isnothing(one[1]["series"])                          # a single row is not a series
 # column headings: any order, aliases, unknown/duplicate columns rejected
 ev2,e2=TK.events_from_table("dato\ttittel\ttype\ttid\tsted\tadresse\tarrangor\tlenke\tpris\n16.10.2026\tX\tPractica\t19:00\tS\tA\tK\thttps://x\t80";today=T)
 @test isempty(e2) && ev2[1]["types"]==["practica"] && ev2[1]["price_nok"]==80
 @test occursin("Ukjent kolonne «Farge»",only(TK.events_from_table("Tittel\tFarge\nX\tblå";today=T)[2]))
 @test occursin("finnes flere ganger",only(TK.events_from_table("Dato\tDato\n1\t2";today=T)[2]))
 # errors carry the spreadsheet row number and the form's messages
 errs=TK.events_from_table(H*full*row("","","32.10.2026","kveld","","","","","","","","","Utsatt");today=T)[2]
 @test any(startswith(m,"Rad 3: «Dato» må være en dato") for m in errs) && any(startswith(m,"Rad 3: «Starttid»") for m in errs) && any(occursin("ukjent «Status»",m) for m in errs)
 @test occursin("samme arrangement og dato",only(TK.events_from_table(H*full*row("","","16.10.2026","","","","","","","","","","");today=T)[2]))
 @test occursin("minst én rad",only(TK.events_from_table("Tittel\tDato";today=T)[2]))
 # the downloadable template is valid input (opened in Excel, then copied → same cells)
 csv=TK.table_template_csv(); @test startswith(csv,"\ufeff") && occursin("Arrangør",csv)
 ev3,e3=TK.events_from_table(replace(csv,"\ufeff"=>"");today=Date(2026,12,1))
 @test isempty(e3) && length(ev3)==3 && ev3[3]["status"]=="cancelled" && ev3[2]["dj"]=="DJ B"
 @test TK.parse_table(replace(csv,"\ufeff"=>""))[1]==TK.TABLE_COLUMNS
 # issue form: the label the parser keys on; CLI round trip through from-issue
 tmpl=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","nytt-arrangement-tabell.yml"),String)
 @test Set(strip(m[1]) for m in eachmatch(r"^      label: (.+)$"m,tmpl))==Set(["Tabell","Samtykke"]) && occursin("labels: [\"nytt-arrangement\"]",tmpl)
 @test isempty([l for l in split(tmpl,'\n') if occursin(r"^\s+[a-z_]+: (\d{4}-\d{1,2}-\d{1,2}|\d{1,2}:\d{2})",l)])
 mktempdir() do d
  root=joinpath(d,"events"); bf=joinpath(d,"b.md"); rep=joinpath(d,"r.md"); out=joinpath(d,"o")
  write(bf,"### Tabell\n\n```text\n"*H*full*row("","","23.10.2026","","","","","","DJ B","","","","")*"```\n\n### Samtykke\n\n- [X] Ja")
  @test redirect_stdout(()->TK.main(["from-issue",bf,"--root=$root","--report=$rep","--outputs=$out","--today=2026-10-04"]),devnull)==0
  @test length(load_events(root))==2 && isempty(validate_event_tree(root)) && occursin("2 datoer fra 16. okt",read(out,String))
 end
end
@testset "about page" begin
 TK=TangoKalender
 h=TK.om_html()
 @test occursin("Et felles prosjekt",h) && occursin("frivillige og arrangører",h) && occursin("Slik støtter du kalenderen",h)
 @test occursin("spandere en drink",h) && occursin("href=\"legg-til.html\"",h) && occursin("<link rel=\"canonical\" href=\"$(TK.site_url())/om.html\">",h)
 ev=[Dict{String,Any}("id"=>"a","title"=>"A","types"=>["milonga"],"start"=>"2035-03-05T20:00:00+01:00","venue"=>Dict("name"=>"S","address"=>"G"))]
 @test occursin("<a href=\"om.html\">Om kalenderen</a>",render_events_html(ev;view="compact",site=true))      # footer link on the site
 @test !occursin("om.html",render_events_html(ev))                                                            # not on a standalone page
 @test occursin("href=\"../../om.html\"",TK.render_event_page(ev[1],ev)) && occursin("href=\"om.html\"",TK.legg_til_html())
 mktempdir() do d; TK.write_site(d,ev); @test isfile(joinpath(d,"om.html")); end
end
@testset "several types per event, utetango" begin
 TK=TangoKalender
 E(id,ts)=Dict{String,Any}("id"=>id,"title"=>"Ev $id","types"=>ts,"start"=>"2035-03-05T20:00:00+01:00","venue"=>Dict("name"=>"S","address"=>"G"))
 evs=[E("km",["class","milonga"]),E("ute",["milonga","outdoor"]),E("pr",["practica"])]
 @test TK._types(E("x",["milonga","class","outdoor"]))==["class","milonga","outdoor"]                 # display order: Kurs · Milonga · Utetango
 c=render_events_html(evs;view="compact",site=true)
 @test occursin("data-type=\"class milonga\"",c) && occursin("<span class=\"chip\">Kurs</span> <span class=\"chip\">Milonga</span>",c)
 @test occursin("<span class=\"chip outdoor\">Utetango</span>",c) && occursin("name=\"type\" value=\"outdoor\"><span>Utetango</span>",c)
 pills=[m[1] for m in eachmatch(r"name=\"type\" value=\"([a-z]+)\"",c)]; @test pills==["class","milonga","practica","outdoor"]   # only types in use
 w=render_events_html(evs;view="week",site=true); @test occursin("class=\"cell ev t-milonga outdoor\"",w) && occursin("class=\"cell ev t-class\"",w)
 @test occursin("CATEGORIES:Kurs,Milonga\r\n",TK.calendar_ics([evs[1]])) && count("<category>",TK.rss_xml(evs[1:1];today=Date(2035,1,1)))==2
 # filtering: an event matches if it has any of the ticked types
 node=Sys.which("node")
 if !isnothing(node)
  mktempdir() do d
   f=joinpath(d,"p.html"); write(f,c)
   vis(q)=Set(x[3] for x in JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2034-01-01 "" $q`,String))["initial"]["rows"])
   @test vis("?type=milonga")==Set(["km","ute"]) && vis("?type=outdoor")==Set(["ute"]) && vis("?type=class,practica")==Set(["km","pr"])
  end
 end
 # forms: checkboxes (several), lists from the spreadsheet; at least one type
 @test TK._parse_field("Type","- [X] Kurs\n- [ ] Practica\n- [X] Milonga")==(["class","milonga"],nothing)
 @test TK._parse_field("Type","Milonga, Utetango")[1]==["milonga","outdoor"] && TK._parse_field("Type","Kurs og practica")[1]==["class","practica"]
 @test TK._parse_field("Type","- [ ] Milonga")==(nothing,"Velg minst én «Type».") && TK._parse_field("Type","Disco")[2]=="Ukjent «Type»: Disco."
 tm=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","nytt-arrangement.yml"),String)
 @test occursin("type: checkboxes\n    id: type",tm) && all(occursin("- label: $l\n",tm) for l in values(TK._TYPES))
 tr=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","rett-arrangement.yml"),String)
 @test occursin("type: checkboxes\n    id: type",tr) && all(occursin("- label: $l\n",tr) for l in values(TK._TYPES))
 # the stored data has no combined or singular types left
 @test all(haskey(e,"types") && !haskey(e,"type") for e in load_events(TREE))
end
@testset "embeds: SVG today/week, iframe list, events.json, guide" begin
 TK=TangoKalender; D=Date(2035,3,6)   # a Tuesday
 E(id,st;kw...)=Dict{String,Any}("id"=>id,"title"=>"Milonga $id","types"=>["milonga"],"start"=>st,"venue"=>Dict("name"=>"Salen","address"=>"Gata 1"),"organizer"=>"Klubben",(string(k)=>v for (k,v) in kw)...)
 evs=[E("a","2035-03-06T20:00:00+01:00";title="Milonga & <Venner> med et svært langt navn som må brytes over flere linjer i bildet"),
      E("f","2035-03-05";types=["festival"],var"end"="2035-03-07",title="Festival F",organizer="Festivalen"),
      E("x","2035-03-06T19:00:00+01:00";status="cancelled",types=["class","milonga"]),
      E("old","2035-02-01T20:00:00+01:00")]
 # _wrap: limits respected, ellipsis when cut
 l=TK._wrap("Moira Castellano & Sebastian de la Vallina i Oslo",15,3)
 @test length(l)<=3 && all(length(x)<=15 for x in l) && endswith(l[end],"…")
 @test TK._wrap("Kort",15,2)==["Kort"] && TK._wrap("Supercalifragilistisk",10,1)==["Supercali…"]
 xmlok(s)=isnothing(Sys.which("python3")) || mktempdir() do d; f=joinpath(d,"x.svg"); write(f,s); success(`python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" $f`); end
 t=TK.today_svg(evs;today=D)
 @test xmlok(t) && startswith(t,"<svg xmlns=\"http://www.w3.org/2000/svg\"") && occursin("viewBox=\"0 0 600 ",t)
 @test occursin("<a href=\"$(TK.site_url())/\" xlink:href=\"$(TK.site_url())/\" target=\"_top\">",t)                      # title → the list
 @test occursin("href=\"$(TK.site_url())/arrangement/a/\"",t) && occursin("href=\"$(TK.site_url())/arrangement/f/\"",t) && !occursin("arrangement/old/",t)
 @test occursin("Milonga &amp; &lt;Venner&gt;",t) && !occursin("<Venner>",t) && occursin(">pågår<",t)                  # escaped; festival in progress
 @test occursin("text-decoration=\"line-through\"",t) && occursin(">AVLYST<",t) && count("target=\"_top\"",t)>=4
 h1=parse(Int,match(r"viewBox=\"0 0 600 (\d+)\"",t)[1]); h0=parse(Int,match(r"viewBox=\"0 0 600 (\d+)\"",TK.today_svg(evs[1:1];today=D))[1]); @test h1>h0   # grows with rows
 empty=TK.today_svg(evs;today=Date(2035,4,1)); @test occursin("Ingen arrangementer i dag",empty) && xmlok(empty)
 # the image carries 8 days (today_svg) / 2 weeks (week_svg); only the build date's group is visible without script
 groups(s)=[(m[1],m[2]) for m in eachmatch(r"<g data-date=\"([^\"]+)\"[^>]*display=\"(inline|none)\"",s)]
 @test [g[1] for g in groups(t)]==[string.(D:Day(1):D+Day(7));"stale"] && [g[2] for g in groups(t)]==["inline";fill("none",8)]
 @test [g[1] for g in groups(TK.week_svg(evs;today=D))]==["2035-03-05","2035-03-12","stale"]
 @test occursin("timeZone:'Europe/Oslo'",t) && occursin("<![CDATA[",t)
 node=Sys.which("node")
 if !isnothing(node)
  mktempdir() do dd
   tf=joinpath(dd,"t.svg"); wf=joinpath(dd,"w.svg"); write(tf,TK.today_svg(evs;today=Date(2026,10,9))); write(wf,TK.week_svg(evs;today=Date(2026,10,9)))
   shown(f,at)=strip(read(`$node $(joinpath(@__DIR__,"js","svgday.js")) $f $at`,String))
   @test shown(tf,"2026-10-09T10:00:00Z")=="2026-10-09"
   @test shown(tf,"2026-10-11T22:30:00Z")=="2026-10-12" && shown(tf,"2026-10-11T21:30:00Z")=="2026-10-11"   # midnight in Oslo (CEST), not UTC
   @test shown(tf,"2026-10-26T23:30:00Z")=="stale"                                                         # past the last day: notice, never an old program
   @test shown(wf,"2026-10-11T22:30:00Z")=="2026-10-12" && shown(wf,"2026-10-11T21:30:00Z")=="2026-10-05"   # next ISO week from Oslo's Monday
  end
 end
 w=TK.week_svg(evs;today=D)
 @test xmlok(w) && occursin("viewBox=\"0 0 980 ",w) && occursin("href=\"$(TK.site_url())/uke.html#uke-2035-10\"",w) && occursin("Uke 10 · 5.–11. mar",w)
 days=[m[1] for m in eachmatch(r"<g data-day=\"([0-9-]+)\">",w)]; @test days==string.(Date(2035,3,5):Day(1):Date(2035,3,18))   # Monday first, 7 columns × this and next week
 @test length(Set(m[1] for m in eachmatch(r"<clipPath id=\"([^\"]+)\"",w)))==14                      # clip ids unique across weeks
 @test count(" href=\"$(TK.site_url())/arrangement/f/\"",w)==3 && occursin("stroke=\"#872b49\" stroke-width=\"2\"",w)                            # festival on each day; today outlined
 # iframe list: just the list, links open in the top window, URL filters incl. ?arr= (organiser)
 L=render_events_html(evs;view="compact",site=true,embed=true)
 @test occursin("<base href=\"$(TK.site_url())/\" target=\"_top\">",L) && occursin("<body class=\"embed\">",L) && !occursin("class=\"hero\"",L) && !occursin("class=\"tabs\"",L)
 @test occursin("data-org=\"festivalen\"",L)
 node=Sys.which("node")
 if !isnothing(node)
  mktempdir() do d
   f=joinpath(d,"l.html"); write(f,L)
   vis(q)=Set(x[3] for x in JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2035-03-01 "" $q`,String))["initial"]["rows"])   # after «old»
   @test vis("?arr=festivalen")==Set(["f"]) && vis("?arr=klubb&type=milonga")==Set(["a","x"])
   @test JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2035-01-01 "" "?arr=festivalen"`,String))["initial"]["search"]=="?arr=festivalen"   # kept in the URL
  end
 end
 # events.json: upcoming only, every item valid
 j=JSON.parse(TK.events_json(evs;today=D)); @test [x["id"] for x in j]==["f","x","a"] && all(isempty∘validate_event,j)
 # guide page and links to it
 g=TK.bygg_inn_html()
 @test occursin("data=&quot;$(TK.site_url())/embed/i-dag.svg&quot;",g) && occursin("data=&quot;$(TK.site_url())/embed/uke.svg&quot;",g) && occursin("$(TK.site_url())/embed/liste.html",g)   # code examples are HTML-escaped
 @test occursin("&lt;img&gt;",g) && occursin("Egendefinert HTML",g) && count("class=\"copybtn\"",g)==4
 @test occursin("href=\"bygg-inn.html\"",TK.om_html()) && occursin("href=\"bygg-inn.html\">Bygg inn</a>",render_events_html(evs;view="compact",site=true))
 mktempdir() do d
  TK.write_site(d,evs;today=D)
  @test all(isfile(joinpath(d,f)) for f in ("bygg-inn.html","events.json",joinpath("embed","i-dag.svg"),joinpath("embed","uke.svg"),joinpath("embed","liste.html")))
 end
end
@testset "languages (nb, en, es)" begin
 TK=TangoKalender; T=Date(2026,10,5); L=TK.LANGS
 # every string, label and prose block exists in all three languages
 @test all(all(!isempty,(v.nb,v.en,v.es)) for v in values(TK._T))
 @test all(issubset(Set(TK.TYPE_ORDER),keys(TK._TYPES_I18N[l])) && issubset(keys(TK._MUSIC),keys(TK._MUSIC_I18N[l])) for l in ("en","es"))
 @test all(Set(keys(d))==Set(L) for d in (TK._about(),TK._add_text(),TK._embed_text(),TK._COLUMN_HELP,TK._DATES))
 @test all(length(TK._COLUMN_HELP[l])==length(TK._COLUMN_HELP["nb"]) for l in L) && Set(keys(TK._GLOSSARY))==Set(["en","es"])
 # dates
 d=Date(2026,10,9); w=Date(2026,9,28)
 @test [TK._with_lang(()->TK._day(d),l) for l in L]==["fredag 9. okt","Friday 9 Oct","viernes 9 oct"]
 @test [TK._with_lang(()->TK._longday(d),l) for l in L]==["fredag 9. oktober","Friday 9 October","viernes 9 de octubre"]
 @test [TK._with_lang(()->TK._weeklabel(w),l) for l in L]==["Uke 40 · 28. sep – 4. okt","Week 40 · 28 Sep – 4 Oct","Semana 40 · 28 sep – 4 oct"]
 @test TK._with_lang(()->TK._weeklabel(Date(2026,10,5)),"en")=="Week 41 · 5–11 Oct" && TK._weeklabel(Date(2026,10,5))=="Uke 41 · 5.–11. okt"
 @test TK._lang()=="nb" && TK._type_label("class")=="Kurs" && TK._with_lang(()->TK._type_label("outdoor"),"es")=="Al aire libre"
 @test_throws ArgumentError render_events_html([];lang="de")
 # event text: page language → (es: en) → original; note and lang attribute when it differs
 E(;kw...)=Dict{String,Any}("id"=>"x","title"=>"Kveldsmilonga","types"=>["milonga"],"start"=>"2026-10-24T20:00:00+02:00","description"=>"Hyggelig kveld.",
  "venue"=>Dict("name"=>"Salen","address"=>"Gata 1"),(string(k)=>v for (k,v) in kw)...)
 bi=E(translations=Dict("en"=>Dict("title"=>"Evening milonga","description"=>"A nice evening.")))
 @test [TK._with_lang(()->TK._text(bi,"title"),l) for l in L]==[("Kveldsmilonga","nb"),("Evening milonga","en"),("Evening milonga","en")]
 @test TK._with_lang(()->TK._text(E(),"description"),"es")==("Hyggelig kveld.","nb")
 en=E(title="English night",description="In English.",lang="en")
 @test TK._text(en,"title")==("English night","en") && TK._with_lang(()->TK._text(en,"title"),"es")==("English night","en")
 h=render_events_html([bi,en];view="cards",lang="es")
 @test occursin("<a href=\"arrangement/x/\" lang=\"en\">Evening milonga</a>",render_events_html([bi];view="compact",site=true,lang="es"))
 @test occursin("<span lang=\"en\">A nice evening.</span> <small class=\"tnote\">(en inglés)</small>",h) && occursin("(en inglés)",h)
 @test !occursin("class=\"tnote\"",render_events_html([bi];view="cards",lang="en")) && occursin("<html lang=\"es\">",h)
 @test occursin("evening milonga",h) && occursin("kveldsmilonga",h) && occursin("hyggelig kveld",render_events_html([bi];view="cards",lang="en"))   # search covers all languages
 p=TK.render_event_page(bi,[bi];today=T,lang="en")
 @test occursin("<h1 class=\"\">Evening milonga</h1>",p) && occursin("og:locale\" content=\"en_GB\"",p) && occursin("\"inLanguage\":\"en\"",p)
 @test occursin("<link rel=\"canonical\" href=\"$(TK.site_url())/en/arrangement/x/\">",p) && occursin("hreflang=\"x-default\" href=\"$(TK.site_url())/arrangement/x/\"",p)
 @test occursin("href=\"../../../arrangement/x/\" data-lang=\"nb\"",p) && occursin("href=\"../../../es/arrangement/x/\" data-lang=\"es\"",p) && occursin("class=\"on\" aria-current=\"true\">EN",p)
 @test occursin("Suggest a correction",p) && occursin(TK._urlenc("Rettelse: Kveldsmilonga (24. okt)"),p)    # the correction form stays Norwegian
 @test occursin("SUMMARY:Evening milonga",TK.event_ics(bi;today=T,lang="en")) && occursin("<language>es</language>",TK.rss_xml([bi];today=T,lang="es"))
 @test occursin("Evening milonga",TK.today_svg([bi];today=Date(2026,10,24),lang="en")) && occursin("Today · Saturday 24 October",TK.today_svg([bi];today=Date(2026,10,24),lang="en"))
 @test occursin("$(TK.site_url())/es/uke.html#uke-2026-43",TK.week_svg([bi];today=Date(2026,10,24),lang="es"))
 # whole site: three trees, no Norwegian left in the English/Spanish interface (event text here is English)
 evs=[E(title="Friday night",description="Traditional music.",lang="en",dj="DJ A",price_nok=150,series="s"),
      E(id="y",title="Practice",description="All levels.",lang="en",start="2026-10-25",types=["practica","outdoor"],status="cancelled",series="s")]
 mktempdir() do dir
  TK.write_site(dir,evs;today=T)
  for l in ("en","es"), f in ("index.html","uke.html","kort.html","om.html","bygg-inn.html",joinpath("arrangement","x","index.html"),joinpath("embed","liste.html"),joinpath("embed","i-dag.svg"),joinpath("embed","uke.svg"),"rss.xml")
   t=read(joinpath(dir,l,f),String)
   @test occursin(Regex("(<html|<svg)[^>]* (xml:)?lang=\"$l\"|<language>$l<"),t)
   t=replace(t,r"<script.*?</script>"s=>" ",r"<style.*?</style>"s=>" ",r"<code.*?</code>"s=>" ",r"<[^>]+>"=>" ",r"https?://\S+"=>" ")
   bad=[m.match for m in eachmatch(r"\S*[æøåÆØÅ]\S*|\b(Avlyst|Kommende|arrangementer|Legg til|Søk|Pris|Sted|Uke|hele dagen|Kopier)\b",t)]
   @test isempty(bad) || (println("$l/$f: ",bad); false)
  end
  @test occursin("Kommende",read(joinpath(dir,"index.html"),String)) && isfile(joinpath(dir,"en","arrangement","x.ics")) && !isfile(joinpath(dir,"en","llms.txt"))
  @test occursin("The form fields in English",read(joinpath(dir,"en","legg-til.html"),String))
  @test occursin("href=\"../$(TK.TEMPLATE_CSV)\"",read(joinpath(dir,"es","legg-til.html"),String)) && occursin("href=\"../events.json\"",read(joinpath(dir,"en","bygg-inn.html"),String))
  g=read(joinpath(dir,"en","bygg-inn.html"),String)
  @test occursin("data=&quot;$(TK.site_url())/en/embed/i-dag.svg&quot;",g) && occursin("data-tpl=\"&lt;object type=&quot;image/svg+xml&quot; data=&quot;{BASE}embed/i-dag.svg",g)
  # flags: every <use href="#flag-…"> has a symbol on the same page
  for f in ("index.html",joinpath("en","om.html"),joinpath("es","arrangement","x","index.html"))
   t=read(joinpath(dir,f),String); @test all(occursin("<symbol id=\"flag-$(m[1])\"",t) for m in eachmatch(r"<use href=\"#flag-([a-z]+)\"",t)) && count("data-lang=",t)==3
  end
  # the head script: redirect from Norwegian pages by browser language, stored choice, never for bots or /en/ /es/
  node=Sys.which("node")
  if isnothing(node); @info "node not found – skipping language script tests"; else
   UA="Mozilla/5.0 (X11) Chrome/130"
   js(f,langs,stored="",ua=UA,loc="")=JSON.parse(read(`$node $(joinpath(@__DIR__,"js","lang.js")) $(joinpath(dir,f)) $langs $stored $ua $loc`,String))
   @test js("uke.html","en-GB,nb")["redirect"]=="en/uke.html"
   @test js("uke.html","en-GB","",UA,"?type=milonga#uke-2026-43")["redirect"]=="en/uke.html?type=milonga#uke-2026-43"
   @test js("index.html","es-AR,es")["redirect"]=="es/" && js("index.html","nb-NO,en")["redirect"]===nothing && js("index.html","nn")["redirect"]===nothing
   @test js("index.html","de-DE")["redirect"]=="en/" && js("index.html","")["redirect"]=="en/"
   @test js("index.html","en-GB","nb")["redirect"]===nothing && js("index.html","nb-NO","es")["redirect"]=="es/"   # stored choice wins
   @test js("index.html","en-GB","THROW")["redirect"]=="en/"                                                      # blocked storage
   @test js("index.html","en-GB","","Googlebot/2.1")["redirect"]===nothing && js("index.html","en-GB","","HeadlessChrome/130")["redirect"]===nothing
   @test js(joinpath("arrangement","x","index.html"),"es")["redirect"]=="../../es/arrangement/x/"
   @test js(joinpath("en","index.html"),"nb-NO")["redirect"]===nothing && js(joinpath("es","om.html"),"en")["redirect"]===nothing
   c=js("uke.html","nb","nb",UA,"?type=practica#uke-2026-43")["click"]
   @test c["href"]=="en/uke.html?type=practica#uke-2026-43" && c["stored"]=="en"                                   # the switch keeps filters and week
  end
  chrome=find_chrome()
  if !isnothing(chrome)
   r=browser_view(chrome,dir,read(joinpath(dir,"en","index.html"),String),"?type=practica&when=all")
   @test r.vis==Set(["y"]) && occursin("1 of 2 events",r.dom)
  end
 end
 # input: «Tekstspråk» and the other-language fields in the form, spreadsheet, JSON and corrections
 f=Dict("Tekstspråk"=>"English","Tittel"=>"Friday milonga","Type"=>"- [X] Milonga","Dato"=>"2026-11-13","Starttid"=>"20:00","Sted"=>"S","Adresse"=>"A",
  "Arrangør"=>"K","Lenke"=>"https://x.org","Beskrivelse"=>"Nice.","Tittel (andre språk)"=>"Fredagsmilonga","Samtykke"=>"- [X] ok")
 ev,er=TK.events_from_form(f;today=T); e=only(ev)
 @test isempty(er) && e["lang"]=="en" && e["translations"]==Dict("nb"=>Dict("title"=>"Fredagsmilonga")) && isempty(validate_event(e))
 ev,_=TK.events_from_form(delete!(copy(f),"Tittel (andre språk)");today=T); @test only(ev)["lang"]=="en" && isnothing(only(ev)["translations"])
 @test occursin("«Tekstspråk»",only(TK.events_from_form(merge(f,Dict("Tekstspråk"=>"Klingon"));today=T)[2]))
 ev,er=TK.events_from_form(merge(f,Dict("Tekstspråk"=>"","Type"=>"Class, Open-air")),today=T); @test only(ev)["lang"]=="nb" && only(ev)["types"]==["class","outdoor"]   # labels in any language
 tab="Title\tType\tDate\tStart time\tVenue\tAddress\tOrganiser\tLink\tLanguage\tTitle (other language)\tMusic\n"*
     "Night\tMilonga\t13/11/2026\t20:00\tS\tA\tK\thttps://x.org\tEnglish\tNatt\tTraditional, Live orchestra\n\t\t20/11/2026\t\t\t\t\t\t\t-\t\n"
 ev,er=TK.events_from_table(tab;today=T)
 @test isempty(er) && [x["start"][1:10] for x in ev]==["2026-11-13","2026-11-20"] && all(x["lang"]=="en" && x["music_style"]==["traditional","live_orchestra"] for x in ev)
 @test ev[1]["translations"]==Dict("nb"=>Dict("title"=>"Natt")) && isnothing(ev[2]["translations"])
 @test TK.parse_table(replace(TK.table_template_csv(),"﻿"=>""))[1]==TK.TABLE_COLUMNS && "Tekstspråk" in TK.TABLE_COLUMNS
 j="""{"title":"Night","types":["milonga"],"start":"2026-11-13T20:00","venue":{"name":"S","address":"A"},"organizer":"K","link":"https://x.org","lang":"en","translations":{"nb":{"title":"Natt","description":" "},"en":{"title":"x"}}}"""
 ev,er=TK.events_from_json(j;today=T); @test isempty(er) && only(ev)["lang"]=="en" && only(ev)["translations"]==Dict("nb"=>Dict("title"=>"Natt"))
 @test !isempty(TK.events_from_json(replace(j,"\"nb\":"=>"\"de\":");today=T)[2])                                  # unknown language rejected by the schema
 @test !isempty(validate_event(merge(E(),Dict("translations"=>Dict("de"=>Dict("title"=>"x")))))) && !isempty(validate_event(merge(E(),Dict("lang"=>"es"))))
 tmpl=read(joinpath(ROOT,".github","ISSUE_TEMPLATE","rett-arrangement.yml"),String)
 @test issubset(Set(["Tekstspråk","Tittel (andre språk)","Beskrivelse (andre språk)"]),Set(strip(m[1]) for m in eachmatch(r"^      label: (.+)$"m,tmpl)))
 @test issubset(Set(["tittel_annet","beskrivelse_annet"]),Set(strip(m[1]) for m in eachmatch(r"^    id: (.+)$"m,tmpl)))
 mktempdir() do root
  x=E(id="x-2026-10-24",lang="nb",translations=Dict("en"=>Dict("title"=>"Evening milonga")),organizer="K",link="https://x.org"); save_event_tree([x],root)
  base=Dict("Arrangement-ID"=>"x-2026-10-24","Samtykke"=>"- [X] ok")
  u,er,ch=TK.apply_correction(merge(base,Dict("Beskrivelse (andre språk)"=>"A nice evening.")),root;today=T)
  @test isempty(er) && u[1][2]["translations"]==Dict("en"=>Dict("title"=>"Evening milonga","description"=>"A nice evening.")) && ("Beskrivelse (andre språk)","","A nice evening.") in ch
  u,er,_=TK.apply_correction(merge(base,Dict("Tittel (andre språk)"=>"-")),root;today=T); @test isempty(er) && isnothing(u[1][2]["translations"])
  u,er,ch=TK.apply_correction(merge(base,Dict("Tekstspråk"=>"English")),root;today=T)     # mislabelled: swap the languages
  @test isempty(er) && u[1][2]["lang"]=="en" && u[1][2]["translations"]==Dict("nb"=>Dict("title"=>"Evening milonga")) && ("Tekstspråk","Norsk","English") in ch
  @test occursin("Tittel (andre språk): Evening milonga",TK.current_summary(x)) && occursin("Tekstspråk: Norsk",TK.current_summary(x))
 end
end
@testset "maps: venue cache, geocoding, event map, «Kart» view" begin
 TK=TangoKalender; T=Date(2026,10,5)
 @test TK._addrkey("Prinsens gate 26, 0157 Oslo")==TK._addrkey("Prinsens gate 26, Oslo")=="prinsens gate 26" && TK._addrkey("Karl Johans gt. 1")=="karl johans gate 1"
 E(id,addr;kw...)=Dict{String,Any}("id"=>id,"title"=>"Milonga $id","types"=>["milonga"],"start"=>"2026-10-08T20:00:00+02:00","venue"=>Dict("name"=>"Sal $id","address"=>addr),(string(k)=>v for (k,v) in kw)...)
 evs=[E("a","Storgata 1, 0155 Oslo"),E("b","Veien 2"),E("c","Ukjent sted 9"),E("d","Storgata 1, Oslo";types=["practica"]),E("e","Manuell vei 5")]
 # geocoding with a stubbed Nominatim: house hit, street-only hit, not found, network error
 calls=String[]
 fake(q)=(push!(calls,q); startswith(q,"Storgata") ? Dict("lat"=>"59.91","lon"=>"10.75","address"=>Dict("house_number"=>"1"),"osm_type"=>"node","osm_id"=>1) :
  startswith(q,"Veien") ? Dict("lat"=>"59.9","lon"=>"10.7","category"=>"highway","address"=>Dict("road"=>"Veien")) :
  startswith(q,"Ukjent") ? nothing : error("timeout"))
 v=Dict{String,Any}("manuell vei 5"=>Dict{String,Any}("address"=>"Manuell vei 5","lat"=>59.95,"lon"=>10.8,"precision"=>"street","source"=>"manual"))
 added,failed=TK.geocode!(v,evs;fetch=fake,pause=0,today=T)
 @test added==["Storgata 1, 0155 Oslo","Veien 2, Oslo","Ukjent sted 9, Oslo"] && isempty(failed) && calls==added              # one query per address; manual untouched
 @test v["storgata 1"]["precision"]=="house" && v["veien 2"]["precision"]=="street" && v["ukjent sted 9"]["precision"]=="none" && v["storgata 1"]["osm"]=="node/1"
 empty!(calls); TK.geocode!(v,evs;fetch=fake,pause=0); @test isempty(calls)                                                  # cached, «none» not retried
 TK.geocode!(v,evs;fetch=fake,pause=0,retry=true); @test calls==["Ukjent sted 9, Oslo"]
 @test only(TK.geocode!(Dict{String,Any}(),[E("x","Feil 1")];fetch=q->error("timeout"),pause=0)[2]) |> s->occursin("timeout",s)     # network errors: not stored
 # only precise (house) or manual positions are used
 @test venue_coords(evs[1],v)==(59.91,10.75)==venue_coords(evs[4],v) && isnothing(venue_coords(evs[2],v)) && isnothing(venue_coords(evs[3],v)) && venue_coords(evs[5],v)==(59.95,10.8)
 @test isnothing(venue_coords(Dict("venue"=>nothing),v)) && isnothing(venue_coords(evs[1]))                                  # no cache in scope
 mktempdir() do d
  f=joinpath(d,"venues.json"); save_venues(v,f); @test load_venues(f)==JSON.parse(JSON.json(v)) && isempty(validate_venues(f))
  write(f,"[{\"address\":\"X\",\"lat\":1,\"lon\":2,\"precision\":\"exact\",\"source\":\"nominatim\"}]"); @test !isempty(validate_venues(f))
  @test isempty(validate_venues(joinpath(d,"none.json")))
 end
 @test isempty(validate_venues(joinpath(ROOT,"venues.json")))                                                                  # the committed cache
 # event page: map card and JSON-LD geo only with a precise position
 p=TK._with_venues(()->TK.render_event_page(evs[1],evs;today=T),v)
 @test occursin("id=\"evmap\"",p) && occursin("data-lat=\"59.91\"",p) && occursin("leaflet.js\" integrity=\"sha512-",p) && occursin("\"geo\":{\"@type\":\"GeoCoordinates\"",p)
 p2=TK._with_venues(()->TK.render_event_page(evs[2],evs;today=T),v); @test !occursin("evmap",p2) && !occursin("leaflet",p2) && !occursin("GeoCoordinates",p2)
 @test occursin("<h2>Mapa</h2>",TK._with_venues(()->TK.render_event_page(evs[1],evs;today=T,lang="es"),v))
 # the «Kart» view: rows carry positions, default period «next 7 days», same filters
 k=TK._with_venues(()->render_events_html(evs;view="map",site=true,today=T),v)
 @test count("data-lat=",k)==3 && occursin("id=\"map\"",k) && occursin("data-default=\"week\"",k) && occursin("<option value=\"week\" selected>",k) && occursin("leaflet.js",k)
 @test !occursin("leaflet",TK._with_venues(()->render_events_html(evs;view="compact",site=true,today=T),v))
 @test all(occursin("href=\"kart.html\"",TK._with_venues(()->render_events_html(evs;view="week",site=true,today=T,lang=l),v)) for l in TK.LANGS)
 node=Sys.which("node")
 if !isnothing(node)
  mktempdir() do d
   run_(page,search)=(f=joinpath(d,"p.html"); write(f,page); JSON.parse(read(`$node $(joinpath(@__DIR__,"js","filters.js")) $f 2026-10-05 "" $search`,String)))
   r=run_(k,""); m=r["initial"]["markers"]
   @test r["initial"]["when"]=="week" && r["initial"]["search"]=="" && length(m["markers"])==2 && m["without"]==2      # a+d share Storgata 1
   @test Set(length(x["items"]) for x in m["markers"])==Set([2,1]) && Set(x["venue"] for x in m["markers"])==Set(["Sal a","Sal e"])
   r=run_(k,"?type=practica"); @test [x["venue"] for x in r["initial"]["markers"]["markers"]]==["Sal d"] && r["initial"]["markers"]["without"]==0
   r=run_(k,"?when=upcoming"); @test r["initial"]["when"]=="upcoming" && r["initial"]["search"]=="?when=upcoming"           # overriding the default stays in the URL
   @test run_(k,"?type=class")["afterReset"]["search"]==""
  end
 end
 chrome=find_chrome()
 if !isnothing(chrome)
  mktempdir() do d
   page=replace(k,r"<link rel=\"stylesheet\" href=\"https://cdnjs[^>]*>|<script src=\"https://cdnjs[^>]*></script>"=>"")   # no network: marker data only
   r=browser_view(chrome,d,replace(page,"</body>"=>"<script>document.body.setAttribute('data-markers',JSON.stringify(window.__markers.markers.map(m=>m.items.length)))</script></body>"),"?type=milonga&when=all")
   @test r.vis==Set(["a","b","c","e"]) && occursin("data-markers=\"[1,1]\"",r.dom)                                       # d (practica) filtered off its shared marker
  end
 end
 # the whole site: kart.html in every language, venues schema published
 mktempdir() do d
  TK.write_site(d,evs;today=T,venues=v)
  @test all(isfile(joinpath(d,TK._prefix(l),"kart.html")) for l in TK.LANGS) && isfile(joinpath(d,"schema","venues.schema.json"))
  @test count("data-lat=",read(joinpath(d,"en","kart.html"),String))==3
 end
end

@testset "link previews (OpenGraph, Twitter card)" begin
 TK=TangoKalender; T=Date(2026,10,1)
 ev(; kw...)=Dict{String,Any}("id"=>"p","title"=>"Milonga P","types"=>["milonga"],"start"=>"2026-10-20T20:00:00+02:00",
  "venue"=>Dict("name"=>"Salen","address"=>"Gata 1, Oslo","city"=>"Oslo"),(string(k)=>v for (k,v) in kw)...)
 og(p,k)=(m=match(Regex("<meta (?:property|name)=\"$(replace(k,"."=>"\\."))\" content=\"([^\"]*)\">"),p); isnothing(m) ? nothing : m[1])
 sq="https://images.squarespace-cdn.com/content/v1/abc/KTF.jpg"
 @test TK.og_image(ev(flyer_url=sq))==(sq*"?format=1500w","Flyer: Milonga P")
 @test first(TK.og_image(ev(flyer_url=sq*"?format=750w")))==sq*"?format=750w"
 @test first(TK.og_image(ev(flyer_url="https://example.org/f.png")))=="https://example.org/f.png"
 @test first(TK.og_image(ev(video=Dict("platform"=>"youtube","id"=>"7mY5BMxr_t0"))))=="https://i.ytimg.com/vi/7mY5BMxr_t0/hqdefault.jpg"
 @test first(TK.og_image(ev(video=Dict("platform"=>"youtube","id"=>"\"><x")))) ==TK.og_image_url()
 @test first(TK.og_image(ev(flyer_url="javascript:alert(1)")))==TK.og_image_url() && first(TK.og_image(ev()))==TK.og_image_url()
 @test TK.og_image_url()==TK.site_url()*"/og-image.png" && isfile(TK.OG_IMAGE_FILE)
 p=TK.render_event_page(ev(flyer_url="https://example.org/f.png"),[];today=T)
 @test og(p,"og:image")=="https://example.org/f.png" && og(p,"twitter:image")=="https://example.org/f.png" && og(p,"og:image:alt")=="Flyer: Milonga P"
 @test og(p,"twitter:card")=="summary_large_image" && og(p,"og:site_name")==TK._esc(TK.site_name()) && og(p,"og:url")==TK.site_url()*"/arrangement/p/"
 @test startswith(og(p,"og:title"),"Milonga P · ") && occursin("Salen",og(p,"og:description")) && isnothing(og(p,"og:image:width"))
 @test og(p,"og:locale")=="nb_NO" && occursin("og:locale:alternate\" content=\"en_GB\"",p) && occursin("og:locale:alternate\" content=\"es_AR\"",p)
 p=TK.render_event_page(ev(status="cancelled",title="<b>&"),[];today=T)
 @test startswith(og(p,"og:title"),"AVLYST: &lt;b&gt;&amp; · ") && og(p,"og:image")==TK.og_image_url() && og(p,"og:image:width")=="1200"
 @test startswith(og(TK.render_event_page(ev(status="cancelled"),[];today=T,lang="en"),"og:title"),"CANCELLED: Milonga P · ")
 e=TK.render_event_page(ev(),[];today=T,lang="es"); @test og(e,"og:locale")=="es_AR" && og(e,"og:url")==TK.site_url()*"/es/arrangement/p/"
 # site pages get the site image; the iframe list and standalone pages don't
 i=render_events_html([ev()];view="compact",site=true,lang="en")
 @test og(i,"og:image")==TK.og_image_url() && og(i,"og:url")==TK.site_url()*"/en/" && og(i,"og:description")==TK._with_lang(()->TK._t("site.description"),"en")
 @test og(render_events_html([ev()];view="week",site=true),"og:url")==TK.site_url()*"/uke.html"
 @test isnothing(og(render_events_html([ev()];view="compact",site=true,embed=true),"og:image")) && isnothing(og(render_events_html([ev()];view="cards"),"og:image"))
 for (h,rel) in ((TK.legg_til_html(),TK.ADD_PAGE),(TK.om_html(),TK.ABOUT_PAGE),(TK.bygg_inn_html(),TK.EMBED_PAGE))
  @test og(h,"og:image")==TK.og_image_url() && og(h,"og:url")==TK.site_url()*"/"*rel && endswith(og(h,"og:title"),TK._esc(TK.site_name()))
 end
 mktempdir() do d; TK.write_site(d,[ev()];today=T); @test read(joinpath(d,"og-image.png"))==read(something(TK.SITE[].og_image,TK.OG_IMAGE_FILE)) && !isfile(joinpath(d,"en","og-image.png")); end
end
@testset "bulk edit (Event struct, tangokalender edit)" begin
 TK=TangoKalender
 schema=JSON.parsefile(joinpath(ROOT,"schema","tango-event.schema.json"))
 @test TK.jsonkeys(Event)==collect(keys(schema["properties"]))             # the struct follows the schema, in order
 @test TK.jsonkeys(TK.Venue)==collect(keys(schema["properties"]["venue"]["properties"]))
 for f in TK.event_files(TREE)                                               # unchanged events are written back byte for byte
  e,ks=read_event(f); @test TK.event_text(e,ks)==read(f,String); @test isempty(TK.check(e))
 end
 obj(ps...)=JSON.Object{String,Any}(ps...)
 ev(id,start;kw...)=obj("id"=>id,"title"=>"Kurs $id","types"=>["class"],"status"=>"scheduled","series"=>"kurs","start"=>start,
  "venue"=>obj("name"=>"Sal A","address"=>"Gate 1, Oslo","city"=>"Oslo"),"organizer"=>"Org","teachers"=>["T"],"class_price_nok"=>200,
  "link"=>"https://facebook.com",(string(k)=>v for (k,v) in kw)...)
 today=Date(2026,10,10)
 tree(d)=save_event_tree([ev("kurs-2026-10-01","2026-10-01T19:00:00+02:00"),ev("kurs-2026-10-15","2026-10-15T19:00:00+02:00"),
  ev("kurs-2026-10-22","2026-10-22T19:00:00+02:00"),ev("milonga-2026-10-16","2026-10-16T20:00:00+02:00";types=["milonga"],series=nothing,venue=nothing,title="Milonga")],d)
 mktempdir() do d
  tree(d); snap()=Dict(f=>read(f,String) for f in TK.event_files(d))
  ids(r)=[x[2].id for x in r]
  @test ids(find_events(["kurs"];root=d,from=today))==["kurs-2026-10-15","kurs-2026-10-22"]   # upcoming only
  @test ids(find_events(["kurs"];root=d,from=nothing))==["kurs-2026-10-01","kurs-2026-10-15","kurs-2026-10-22"]
  @test ids(find_events(["kurs","10-22"];root=d,from=today))==["kurs-2026-10-22"]                # terms narrow (AND)
  @test ids(find_events(["type:milonga"];root=d,from=today))==["milonga-2026-10-16"]
  @test ids(find_events(["series:kurs","sal a"];root=d,from=today,until=Date(2026,10,20)))==["kurs-2026-10-15"]
  @test isempty(find_events(["series:milonga"];root=d,from=today))                               # key-scoped: not the title
  @test ids(find_events(["19:00"];root=d,from=today))==["kurs-2026-10-15","kurs-2026-10-22"]     # not a key: plain text
  before=snap()
  r,w,errs=edit_events(["kurs"],["link=https://www.instagram.com/x/"];root=d,from=today,dry_run=true)
  @test length(r)==2 && isempty(w) && isempty(errs) && snap()==before
  r,w,errs=edit_events(["kurs"],["link=https://www.instagram.com/x/"];root=d,from=today)
  @test isempty(errs) && length(w)==2 && r[1].changes==[("link","\"https://facebook.com\"","\"https://www.instagram.com/x/\"")]
  after=snap(); f=r[1].file
  @test after[f]==replace(before[f],"\"https://facebook.com\""=>"\"https://www.instagram.com/x/\"")   # only that line
  @test after[r[1].file]!=before[r[1].file] && count(k->after[k]!=before[k],collect(keys(before)))==2
  @test first(edit_events(["kurs"],["link=https://www.instagram.com/x/"];root=d,from=today))==[]     # already set: no change
  r,w,errs=edit_events(["milonga"],["venue.name=Ny sal","price_nok=150","teachers=[\"A\",\"B\"]","status=null","translations.en.title=Milonga (en)"];root=d,from=today)
  @test isempty(errs)
  x=JSON.parsefile(only(w))
  @test x["venue"]==Dict("name"=>"Ny sal","address"=>nothing,"city"=>nothing) && x["price_nok"]===150 && x["teachers"]==["A","B"]
  @test isnothing(x["status"]) && x["translations"]==Dict("en"=>Dict("title"=>"Milonga (en)")) && isempty(validate_event_tree(d))
  before=snap()
  for bad in (["status=foo"],["class_price_nok=abc"],["class_price_nok=-5"],["types=[\"dance\"]"],["link=ftp://x"])
   r,w,errs=try edit_events(["kurs"],bad;root=d,from=today) catch err; (nothing,String[],[sprint(showerror,err)]) end
   @test !isempty(errs) && isempty(w) && snap()==before
  end
  @test_throws ArgumentError edit_events(["kurs"],["nope=1"];root=d,from=today)
  @test_throws ArgumentError edit_events(["kurs"],["title.x=1"];root=d,from=today)
  r,w,errs=edit_events(["kurs-2026-10-22"],["start=2026-10-23T19:00:00+02:00"];root=d,from=today)   # a new date moves the file
  @test isempty(errs) && w==[joinpath(d,"2026","10-october","2026-10-23-kurs-2026-10-22.json")] && !isfile(r[1].file)
  # CLI
  out=IOBuffer(); @test TK.edit_main(["kurs","--root=$d","--all"];io=out,err=devnull)==0
  s=String(take!(out)); @test occursin("3 events",s) && occursin("kurs-2026-10-01",s)
  before=snap()
  @test TK.edit_main(["kurs","class_price_nok=260","--root=$d","--from=2026-10-10","--preview"];io=out,err=devnull)==0
  s=String(take!(out)); @test occursin("260 kr",s) && occursin("200 kr",s) && occursin("dry run",s) && snap()==before
  @test TK.edit_main(["kurs","class_price_nok=260","--root=$d","--from=2026-10-10","--dry-run"];io=out,err=devnull)==0
  s=String(take!(out)); @test occursin("class_price_nok: 200 → 260",s) && snap()==before
  @test TK.edit_main(["kurs","status=foo","--root=$d","--from=2026-10-10"];io=out,err=devnull)==1
  @test TK.edit_main(["kurs","nope=1","--root=$d"];io=out,err=devnull)==2
  @test TK.edit_main(["edit","kurs","--root=$d","--all"];io=out)==0 && occursin("3 events",String(take!(out)))   # `tangoedit edit …`
  @test TK.edit_main(["--root=$d"];io=out,err=devnull)==2
  @test TK.edit_main(["kurs","--from=10.10.2026","--root=$d"];io=out,err=devnull)==2
  @test snap()==before
 end
 # terminal display
 e=Event(id="x-1",title="Milonga X",types=["milonga","class"],start="2026-10-16T20:00:00+02:00",end_="2026-10-17T01:00:00+02:00",
  price_nok=150,series="x",dj="DJ Y",description="Lang tekst "^30)
 s=sprint(print,event_card(e;width=80))
 @test occursin("fredag 16. okt · 20:00–01:00",s) && occursin("Kurs",s) && occursin("Milonga",s) && occursin("150 kr",s)
 @test occursin("Sted ikke oppgitt",s) && occursin("x-1",s) && occursin("DJ Y",s) && !occursin("\e[",s)   # no colour in a buffer
 @test all(l->textwidth(l)<=80,split(s,'\n')) && count(contains("Lang tekst"),split(s,'\n'))==2           # description: 2 lines
 c=TK.set_path(TK.set_path(e,["status"],"cancelled"),["price_nok"],"200")
 s=sprint(print,event_card(c;before=e,width=80);context=:color=>true)
 @test occursin("\e[",s) && occursin("AVLYST",s) && occursin("200 kr",s) && occursin("150 kr",s)
 s=sprint(print,event_card(TK.set_path(e,["confidence"],"0.5");before=e))
 @test occursin("✎ confidence: null → 0.5",s)
 @test !occursin('\n',sprint(print,event_line(e))) && occursin("x-1",sprint(print,event_line(e)))
 @test occursin("Milonga X",sprint(show,MIME("text/plain"),e))
 lines=TK.card_lines(c;before=e,width=80)                                     # the ANSI renderer of the trimmed app
 @test TK.ansi_text(lines;color=false)==sprint(print,TK.styled_text(lines))  # same text as StyledStrings
 @test occursin("\e[1;33m",TK.ansi_text(lines)) && !occursin("\e[",TK.ansi_text(lines;color=false))
 # the trimmed app's configuration: struct checks instead of JSONSchema, ANSI output
 @test isempty(TK.check_event_tree(TREE))
 mktempdir() do d
  tree(d); out=IOBuffer()
  @test TK.edit_main(["kurs","link=https://x.no/","--root=$d","--from=2026-10-10"];io=out,err=devnull,
   tree_check=TK.check_event_tree,render=l->TK.ansi_text(l;color=false))==0
  @test occursin("2 events changed",String(take!(out))) && isempty(validate_event_tree(d))
  f=first(TK.event_files(d)); write(f,replace(read(f,String),"\"kurs-"=>"\"Kurs-"))
  @test !isempty(TK.check_event_tree(d))
 end
end
@testset "site config (one site per city)" begin
 TK=TangoKalender
 @test TK.load_site(SITE_TOML).city=="Oslo" && TK.site_city()=="Oslo"     # the tests run as the Oslo site
 d=mktempdir(); toml=joinpath(d,"site.toml"); write(joinpath(d,"og.png"),"png")
 write(toml,"""slug = "bergen"\nname = "Tangokalender | Bergen"\ncity = "Bergen"\nsite_url = "https://tango.example.no/bergen/"
  repo_url = "https://github.com/Tangokalender/bergen"\nog_image = "og.png"\n[map]\ncenter = [60.39, 5.32]\nzoom = 13
  [geocode]\ncountrycodes = "no"\nviewbox = "5.2,60.3,5.4,60.5"\n[texts.nb]\n"site.subtitle" = "Milongaer i {city}"\n""")
 site=TK.load_site(toml)
 @test site.site_url=="https://tango.example.no/bergen" && site.og_image==joinpath(d,"og.png") && site.map_center==(60.39,5.32)
 bad=joinpath(d,"bad.toml"); write(bad,"slug = \"Bergen By\"\nname = \"x\"\ncity = \"x\"\nsite_url = \"x\"\nrepo_url = \"x\"\n")
 @test_throws ArgumentError TK.load_site(bad)
 @test_throws ArgumentError TK.load_site(joinpath(d,"none.toml"))
 ev=[Dict("id"=>"m-2026-10-16","title"=>"Milonga","types"=>["milonga"],"start"=>"2026-10-16T20:00:00+02:00","organizer"=>"Bergen Tango",
  "venue"=>Dict("name"=>"Kulturhuset","address"=>"Strandgaten 1","city"=>"Bergen"),"link"=>"https://example.org")]
 out=joinpath(d,"_site"); files=write_site(out,ev;site,today=Date(2026,10,10))
 r(f)=read(joinpath(out,f),String)
 @test occursin("<link rel=\"canonical\" href=\"https://tango.example.no/bergen/\">",r("index.html"))
 @test occursin("ARGENTINSK TANGO I BERGEN",r("index.html")) && occursin("Milongaer i Bergen",r("index.html"))   # {CITY}, [texts]
 @test occursin("<title>Tangokalender | Bergen</title>",r("index.html")) && occursin("Argentine tango in Bergen",r("en/index.html"))
 @test occursin("https://github.com/Tangokalender/bergen/issues/new?template=rett-arrangement.yml",r("arrangement/m-2026-10-16/index.html"))
 @test occursin("UID:m-2026-10-16@tango.example.no",r("kalender.ics")) && occursin("https://tango.example.no/bergen/en/arrangement/",r("en/rss.xml"))
 @test occursin("M.setView([60.39,5.32],13)",r("kart.html")) && r("og-image.png")=="png"
 @test JSON.parsefile(joinpath(out,"schema","tango-event.schema.json"))["\$id"]=="https://tango.example.no/bergen/schema/tango-event.schema.json"
 @test JSON.parsefile(joinpath(out,"schema","tango-event-submission.schema.json"))["\$id"]=="https://tango.example.no/bergen/schema/tango-event-submission.schema.json"
 # nothing from Oslo leaks into Bergen's site, except the time zone (Europe/Oslo is all of Norway) and the AI example text
 for f in files
  s=replace(read(f,String),"Europe/Oslo"=>"",r"Kulturhuset Fjord[^\n]*"=>"",r"\"city\": \"Oslo\""=>"",r"Storgata 9, Oslo"=>"")
  @test !occursin("Oslo",s) && !occursin("tangokalender.github.io",s)
 end
 TK._with_site(site) do
  @test TK._addrkey("Strandgaten 1, 5013 Bergen")=="strandgaten 1"                    # the site's city, not Oslo
  @test TK._geo_address(Dict("venue"=>Dict("address"=>"Strandgaten 1")))=="Strandgaten 1, Bergen"
  @test TK.events_from_form(TK.parse_issue_form(read(joinpath(@__DIR__,"fixtures","issues","weekly.md"),String));today=Date(2026,10,1))[1][1]["venue"]["city"]=="Bergen"
  calls=String[]; TK.geocode!(Dict{String,Any}(),ev;fetch=q->(push!(calls,q); nothing),pause=0.0,today=Date(2026,10,1))
  @test calls==["Strandgaten 1, Bergen"]
 end
 # CLI: --site=FILE, else ./site.toml, else the current site
 out2=joinpath(d,"_site2"); evdir=joinpath(d,"events"); save_event_tree(ev,evdir)
 @test redirect_stdout(()->TK.main(["site",evdir,out2,"--site=$toml","--venues=$(joinpath(d,"v.json"))"]),devnull)==0
 @test occursin("Tangokalender | Bergen",read(joinpath(out2,"index.html"),String))
 @test cd(()->redirect_stdout(()->TK.main(["site","events","_s"]),devnull),d)==0 && occursin("Bergen",read(joinpath(d,"_s","index.html"),String))
 @test redirect_stderr(()->TK.main(["site",evdir,out2,"--site=$bad"]),devnull)==2
end
