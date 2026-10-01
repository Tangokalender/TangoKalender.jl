const USAGE="""
tangokalender - build the tango calendar as one static HTML page

Usage:
  tangokalender [build] [INPUT] [OUTPUT]   validate, then render (default: events public/index.html)
  tangokalender validate [INPUT]           validate only
  tangokalender migrate V1.json [DIR]      convert a v1 event array to the events tree (default: events)
  tangokalender from-issue BODY.md         turn a submitted issue-form body into event files

INPUT is an events directory or a single JSON array file. Paths are relative to the current directory.

Options (build):
  --no-validate        render even if validation fails
  --title=TEXT         page title (default: "Oslo Tango")
  --subtitle=TEXT      page subtitle

Options (from-issue):
  --root=DIR           events directory to write into (default: events)
  --issue-url=URL      recorded as the events' source_url
  --report=FILE        write a Norwegian markdown report (for the issue comment)
  --today=YYYY-MM-DD   reference date for "date has passed" checks (default: today)

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
function _from_issue(body_file,opts)
 root=get(opts,"root","events")
 today=haskey(opts,"today") ? Date(opts["today"]) : Dates.today()
 events,errs=events_from_form(parse_issue_form(read(body_file,String)); issue_url=get(opts,"issue-url",nothing), today)
 paths=[event_path(e;root) for e in events]
 for p in paths; isfile(p) && push!(errs,"Arrangementet finnes allerede ($(relpath(p,root))). Endringer i eksisterende arrangementer gjøres i en pull request."); end
 files=isempty(errs) ? save_event_tree(events,root) : String[]
 isempty(errs) || (events=empty(events))
 for (f,m) in (isempty(files) ? Tuple{String,String}[] : validate_event_tree(root)); push!(errs,"$f: $m"); end
 isempty(errs) || (foreach(rm,files); events=empty(events); files=String[])
 report=_issue_report(events,files,errs)
 haskey(opts,"report") ? write(opts["report"],report*"\n") : println(report)
 isempty(errs) ? (foreach(println,files); 0) : (println(stderr,report); 1)
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
 cmd=!isempty(args) && args[1] in ("build","validate","migrate","from-issue") ? popfirst!(args) : "build"
 pos=filter(!startswith("--"),args); opts=Dict{String,String}(); novalidate=false
 for a in filter(startswith("--"),args)
  k,v=occursin('=',a) ? split(a[3:end],'=';limit=2) : (a[3:end],"")
  if cmd=="build" && k=="no-validate" && isempty(v); novalidate=true
  elseif cmd=="build" && k in ("title","subtitle"); opts[k]=v
  elseif cmd=="from-issue" && k in ("root","issue-url","report","today") && !isempty(v); opts[k]=v
  else println(stderr,"unknown option $a\n"); print(stderr,USAGE); return 2 end
 end
 maxpos=cmd in ("validate","from-issue") ? 1 : 2
 length(pos)>maxpos && (println(stderr,"too many arguments\n"); print(stderr,USAGE); return 2)
 if cmd=="from-issue"
  isempty(pos) && (println(stderr,"from-issue needs an issue body file\n"); print(stderr,USAGE); return 2)
  return _from_issue(pos[1],opts)
 end
 if cmd=="migrate"
  isempty(pos) && (println(stderr,"migrate needs a v1 JSON file\n"); print(stderr,USAGE); return 2)
  root=get(pos,2,"events"); files=save_event_tree(upgrade_events(load_events(pos[1])),root)
  println("Wrote $(length(files)) files to $root"); return 0
 end
 input=get(pos,1,"events")
 problems=validate_event_tree(input)
 if cmd=="validate"
  _report(problems); isempty(problems) && println("OK: $input"); return isempty(problems) ? 0 : 1
 end
 if !isempty(problems)
  _report(problems); novalidate || return 1
 end
 output=get(pos,2,joinpath("public","index.html"))
 render_events_file(input,output;(Symbol(k)=>v for (k,v) in opts)...); println("Wrote $output")
 0
end
