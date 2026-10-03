const USAGE="""
tangokalender - build the tango calendar as one static HTML page

Usage:
  tangokalender [build] [INPUT] [OUTPUT]   validate, then render (default: events public/index.html)
  tangokalender site [INPUT] [DIR]         validate, then write the whole site to DIR (default: events _site):
                                           index.html (list), uke.html, kort.html, arrangement/<id>/ pages and .ics,
                                           kalender.ics, rss.xml, for-ki.html, llms.txt, schema/*.json
  tangokalender validate [INPUT]           validate only
  tangokalender from-issue BODY.md         apply a submitted issue form: new event(s) (form or «JSON»), or a correction («Arrangement-ID»)

INPUT is an events directory or a single JSON array file. Paths are relative to the current directory.

Options (build, site):
  --no-validate        render even if validation fails
  --title=TEXT         page title (default: "Tangokalender | Oslo")
  --subtitle=TEXT      page subtitle
  --submit-url=URL     target of the «Legg til arrangement» link (default: the repo's issue form; empty hides it)
  --correct-url=URL    base of each card's «Rett opp» link (default: the repo's correction form; empty hides it)

Options (from-issue):
  --root=DIR           events directory to write into (default: events)
  --issue-url=URL      recorded as the events' source_url
  --report=FILE        write a Norwegian markdown report (for the issue comment)
  --today=YYYY-MM-DD   reference date for "date has passed" checks (default: today)
  --outputs=FILE       append `pr_title=…` and `issue_title=…` (e.g. \$GITHUB_OUTPUT) on success

  -h, --help           show this help
"""
_md(s)=replace(string(s),'|'=>"\\|",'\n'=>' ','@'=>"@\u200b")
function _issue_report(events,files,errs)
 isempty(errs) || return "❌ Skjemaet har feil som må rettes før arrangementet kan legges til:\n\n"*join(("- "*_md(e) for e in errs),"\n")*
  "\n\nRediger saken (··· → Edit) og lagre, så prøver vi igjen automatisk."
 rows=join(("| $(_md(_date_label(e))) | $(_md(e["title"])) | $(_md(_venue(e)[1])) |" for e in events),"\n")
 "✅ Takk! Skjemaet ble lest uten feil. $(length(events)==1 ? "Dette arrangementet" : "Disse $(length(events)) arrangementene") blir foreslått lagt til:\n\n"*
  "| Dato | Tittel | Sted |\n|---|---|---|\n$rows\n\n<details><summary>Filer</summary>\n\n"*join(("- `$f`" for f in files),"\n")*
  "\n</details>\n\nEn redaktør ser over forslaget før det publiseres."
end
"Short date for titles: «2. okt»."
_short_day(e)=(d=Date(first(string(e["start"]),10)); "$(day(d)). $(_MO[month(d)])")
_one_line(s)=replace(string(s),r"\s+"=>" ")
"Short one-line summary for PR/issue titles: «Milonga X (2. okt)» or «Kurs Y (8 datoer fra 20. okt)»."
function _summary_title(events)
 t=_one_line(events[1]["title"])
 length(events)==1 ? "$t ($(_short_day(events[1])))" : "$t ($(length(events)) datoer fra $(_short_day(events[1])))"
end
_write_outputs(opts,pr,issue)=haskey(opts,"outputs") && open(io->(println(io,"pr_title=",pr); println(io,"issue_title=",issue)),opts["outputs"],"a")
function _finish(opts,report,errs)
 haskey(opts,"report") ? write(opts["report"],report*"\n") : println(report)
 isempty(errs) || println(stderr,report)
 isempty(errs) ? 0 : 1
end
function _from_issue(body_file,opts)
 root=get(opts,"root","events")
 today=haskey(opts,"today") ? Date(opts["today"]) : Dates.today()
 form=parse_issue_form(read(body_file,String))
 haskey(form,"Arrangement-ID") && return _from_correction(form,root,today,opts)
 events,errs=if haskey(form,"JSON")   # «Nytt arrangement (JSON fra KI)»
  ev,er=events_from_json(form["JSON"]; issue_url=get(opts,"issue-url",nothing), today)
  isempty(_checked(get(form,"Samtykke",""))) ? (empty(ev),[er;"«Samtykke» må krysses av."]) : (ev,er)
 else
  events_from_form(form; issue_url=get(opts,"issue-url",nothing), today)
 end
 paths=[event_path(e;root) for e in events]
 for p in paths; isfile(p) && push!(errs,"Arrangementet finnes allerede ($(relpath(p,root))). Bruk «Rett opp»-lenken på arrangementet for å endre det."); end
 files=isempty(errs) ? save_event_tree(events,root) : String[]
 isempty(errs) || (events=empty(events))
 for (f,m) in (isempty(files) ? Tuple{String,String}[] : validate_event_tree(root)); push!(errs,"$f: $m"); end
 isempty(errs) || (foreach(rm,files); events=empty(events); files=String[])
 code=_finish(opts,_issue_report(events,files,errs),errs)
 code==0 && (t=_summary_title(events); _write_outputs(opts,"Nytt arrangement: $t","Arrangement: $t"); foreach(println,files))
 code
end
function _correction_report(updates,files,changed,errs,comment)
 isempty(errs) || return "❌ Rettelsen har feil som må rettes:\n\n"*join(("- "*_md(e) for e in errs),"\n")*
  "\n\nRediger saken (··· → Edit) og lagre, så prøver vi igjen automatisk."
 rows=join(("| $(_md(l)) | $(_md(isempty(a) ? "–" : a)) | $(_md(isempty(b) ? "–" : b)) |" for (l,a,b) in changed),"\n")
 dates=join((_md(_date_label(x)) for (_,x) in updates),", ")
 quote_=isempty(strip(comment)) ? "" : "\n\n**Kommentar:**\n"*join(("> "*_md(l) for l in split(strip(comment),'\n')),"\n")
 "✅ Takk! Rettelsen ble lest uten feil. Disse endringene blir foreslått:\n\n| Felt | Før | Etter |\n|---|---|---|\n$rows\n\n"*
  "Gjelder $(length(updates)==1 ? "én dato" : "$(length(updates)) datoer"): $dates$quote_\n\n<details><summary>Filer</summary>\n\n"*
  join(("- `$f`" for f in files),"\n")*"\n</details>\n\nEn redaktør ser over forslaget før det publiseres."
end
function _from_correction(form,root,today,opts)
 updates,errs,changed=apply_correction(form,root;today)
 backup=Dict(f=>read(f) for (f,_) in updates); written=String[]
 if isempty(errs)
  for (old,x) in updates
   new=event_path(x;root)
   normpath(new)!=normpath(old) && isfile(new) && (push!(errs,"Det finnes allerede et arrangement på $(relpath(new,root))."); break)
  end
 end
 if isempty(errs)
  for (old,x) in updates
   new=event_path(x;root); normpath(new)==normpath(old) || rm(old)
   push!(written,save_events(x,new))
  end
  for (f,m) in validate_event_tree(root); push!(errs,"$f: $m"); end
  if !isempty(errs)   # roll back
   foreach(f->isfile(f) && rm(f),written); for (f,b) in backup; mkpath(dirname(f)); write(f,b); end
   written=String[]
  end
 end
 isempty(errs) || (updates=empty(updates))
 code=_finish(opts,_correction_report(updates,written,changed,errs,get(form,"Kommentar","")),errs)
 if code==0
  x=updates[1][2]; n=length(updates)
  t="$(_one_line(x["title"])) ($(_short_day(x))$(n>1 ? " og $(n-1) senere" : ""))"
  _write_outputs(opts,"Rettelse: $t","Rettelse: $t"); foreach(println,written)
 end
 code
end
_report(problems)=(for (f,m) in problems; println(stderr,"$f: $m"); end; isempty(problems) || println(stderr,"$(length(problems)) problem(s)"))
"""
    main(args) -> exit code

Command-line entry point (`julia -m TangoKalender ...` or the installed `tangokalender` app).
Returns 0 on success, 1 on validation errors, 2 on usage errors.
"""
function (@main)(args)
 args=String.(args)
 any(in(("-h","--help")),args) && (print(USAGE); return 0)
 cmd=!isempty(args) && args[1] in ("build","site","validate","from-issue") ? popfirst!(args) : "build"
 pos=filter(!startswith("--"),args); opts=Dict{String,String}(); novalidate=false
 for a in filter(startswith("--"),args)
  k,v=occursin('=',a) ? split(a[3:end],'=';limit=2) : (a[3:end],"")
  if cmd in ("build","site") && k=="no-validate" && isempty(v); novalidate=true
  elseif cmd in ("build","site") && k in ("title","subtitle"); opts[k]=v
  elseif cmd in ("build","site") && k=="submit-url"; opts["submit_url"]=v
  elseif cmd in ("build","site") && k=="correct-url"; opts["correct_url"]=v
  elseif cmd=="from-issue" && k in ("root","issue-url","report","today","outputs") && !isempty(v); opts[k]=v
  else println(stderr,"unknown option $a\n"); print(stderr,USAGE); return 2 end
 end
 maxpos=cmd in ("validate","from-issue") ? 1 : 2
 length(pos)>maxpos && (println(stderr,"too many arguments\n"); print(stderr,USAGE); return 2)
 if cmd=="from-issue"
  isempty(pos) && (println(stderr,"from-issue needs an issue body file\n"); print(stderr,USAGE); return 2)
  return _from_issue(pos[1],opts)
 end
 input=get(pos,1,"events")
 problems=validate_event_tree(input)
 if cmd=="validate"
  _report(problems); isempty(problems) && println("OK: $input"); return isempty(problems) ? 0 : 1
 end
 if !isempty(problems)
  _report(problems); novalidate || return 1
 end
 if cmd=="site"
  dir=get(pos,2,"_site"); files=write_site(dir,load_events(input);(Symbol(k)=>v for (k,v) in opts)...)
  println("Wrote $(length(files)) files to $dir"); return 0
 end
 output=get(pos,2,joinpath("public","index.html"))
 render_events_file(input,output;(Symbol(k)=>v for (k,v) in opts)...); println("Wrote $output")
 0
end
