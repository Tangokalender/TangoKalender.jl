# Table input: cells copied from Excel/Google Sheets/Numbers and pasted into the issue form «Nytt arrangement (fra tabell)»
# (.github/ISSUE_TEMPLATE/nytt-arrangement-tabell.yml). Pasted cells arrive as tab-separated text.
# Row 1: column headings (the same names as in the form). Row 2: the defaults (repeated information).
# Further rows: only what differs (typically Dato, DJ); a blank cell means "same as row 2", `-` clears an optional field.
# Each data row becomes one dated event; rows with the same title share a `series`.
# English headings are accepted as aliases («Title», «Date», «Organiser» …), and type/music values in any language.
const TABLE_COLUMNS=["Tittel","Type","Dato","Starttid","Sluttid","Sted","Adresse","Arrangør","DJ","Lærere","Pris (kr)",
 "Studentpris (kr)","Kurspris (kr)","Musikk","Flyer","Video","Lenke","Beskrivelse","Status","Tekstspråk","Tittel (andre språk)","Beskrivelse (andre språk)"]
const MAX_TABLE_ROWS=60
_colkey(s)=replace(lowercase(strip(s)),r"\s*\(kr\)\s*$"=>"",r"\s+"=>" ")
const _COLUMN_BY_KEY=merge(Dict(_colkey(c)=>c for c in TABLE_COLUMNS),
 Dict("arrangor"=>"Arrangør","laerere"=>"Lærere","lærer"=>"Lærere","pris"=>"Pris (kr)","studentpris"=>"Studentpris (kr)",
      "kurspris"=>"Kurspris (kr)","tid"=>"Starttid","start"=>"Starttid","slutt"=>"Sluttid","dato"=>"Dato","sted"=>"Sted",
      "språk"=>"Tekstspråk","sprak"=>"Tekstspråk","tekstsprak"=>"Tekstspråk","tittel (engelsk)"=>"Tittel (andre språk)","beskrivelse (engelsk)"=>"Beskrivelse (andre språk)",
      # English headings (the English legg-til page explains the Norwegian ones, but these work too)
      "title"=>"Tittel","date"=>"Dato","start time"=>"Starttid","end time"=>"Sluttid","end"=>"Sluttid","venue"=>"Sted","address"=>"Adresse",
      "organiser"=>"Arrangør","organizer"=>"Arrangør","teachers"=>"Lærere","price"=>"Pris (kr)","student price"=>"Studentpris (kr)",
      "class price"=>"Kurspris (kr)","music"=>"Musikk","link"=>"Lenke","description"=>"Beskrivelse","language"=>"Tekstspråk",
      "text language"=>"Tekstspråk","title (other language)"=>"Tittel (andre språk)","description (other language)"=>"Beskrivelse (andre språk)",
      "title (english)"=>"Tittel (andre språk)","description (english)"=>"Beskrivelse (andre språk)"))
"""
    parse_table(text) -> Vector{Vector{String}}

Rows of cells from pasted spreadsheet text. Tab-separated (what Excel and Google Sheets put on the clipboard) is
the normal case; semicolon- or comma-separated CSV is accepted when there are no tabs. Quoted cells may contain
separators and line breaks. A surrounding markdown code fence is ignored.
"""
function parse_table(text::AbstractString)
 t=replace(String(text),"\r\n"=>"\n",'\r'=>'\n')
 m=match(r"```[a-zA-Z]*\n(.*?)```"s,t); isnothing(m) || (t=m[1])
 t=strip(t,'\n')
 sep=occursin('\t',t) ? '\t' : count(==(';'),t)>=count(==(','),t) ? ';' : ','
 rows=Vector{String}[]; row=String[]; cell=IOBuffer(); inq=false; i=firstindex(t)
 while i<=lastindex(t)
  c=t[i]
  if inq
   if c=='"'
    j=nextind(t,i)
    if j<=lastindex(t) && t[j]=='"'; write(cell,'"'); i=j else inq=false end
   else write(cell,c) end
  elseif c=='"' && position(cell)==0; inq=true
  elseif c==sep; push!(row,strip(String(take!(cell))))
  elseif c=='\n'; push!(row,strip(String(take!(cell)))); push!(rows,row); row=String[]
  else write(cell,c) end
  i=nextind(t,i)
 end
 push!(row,strip(String(take!(cell)))); push!(rows,row)
 filter(r->any(!isempty,r),rows)
end
"""
    events_from_table(text; issue_url=nothing, today=Dates.today()) -> (events, errors)

Events from pasted spreadsheet cells (see the file header). Every row is checked exactly like the ordinary form
(`events_from_form`), so field rules and Norwegian messages are the same; errors are prefixed with the row number.
"""
function events_from_table(text::AbstractString; issue_url=nothing, today::Date=Dates.today())
 errs=String[]; fail()=(JSON.Object{String,Any}[],errs)
 rows=parse_table(text)
 length(rows)<2 && (push!(errs,"Tabellen må ha en rad med kolonnenavn og minst én rad med et arrangement."); return fail())
 head=rows[1]; cols=String[]
 for h in head
  c=get(_COLUMN_BY_KEY,_colkey(h),nothing)
  isnothing(c) && !isempty(strip(h)) && push!(errs,"Ukjent kolonne «$h». Gyldige kolonner: $(join(TABLE_COLUMNS,", ")).")
  push!(cols,something(c,""))
 end
 for c in unique(filter(!isempty,cols)); count(==(c),cols)>1 && push!(errs,"Kolonnen «$c» finnes flere ganger."); end
 data=rows[2:end]; length(data)>MAX_TABLE_ROWS && push!(errs,"Høyst $MAX_TABLE_ROWS rader per innsending (fikk $(length(data))).")
 isempty(errs) || return fail()
 cell(r,k)=k<=length(r) ? r[k] : ""
 defaults=Dict(c=>cell(data[1],k) for (k,c) in enumerate(cols) if !isempty(c))
 events=JSON.Object{String,Any}[]
 for (n,r) in enumerate(data)
  rowno=n+1   # spreadsheet row number (row 1 = headings, row 2 = first data row)
  vals=copy(defaults)
  if n>1
   for (k,c) in enumerate(cols)
    isempty(c) && continue; v=cell(r,k)
    isempty(v) && continue
    vals[c]= v=="-" ? "" : v
   end
  end
  f=Dict{String,String}(c=>v for (c,v) in vals if c!="Status" && c!="Musikk")
  mus=get(vals,"Musikk","")
  isempty(mus) || (f["Musikk"]=join(("- [X] "*strip(m) for m in split(mus,r"[,;]") if !isempty(strip(m))),"\n"))
  f["Gjentas"]="Nei"; f["Samtykke"]="- [X] ok"   # consent is ticked once in the issue form
  ev,er=events_from_form(f; issue_url, today)
  append!(errs,("Rad $rowno: $m" for m in er))
  st=lowercase(strip(get(vals,"Status","")))
  if !isempty(st) && !(st in ("avlyst","cancelled","cancelado","gjennomføres","scheduled"))
   push!(errs,"Rad $rowno: ukjent «Status» «$(vals["Status"])» (bruk «Avlyst» eller la feltet stå tomt).")
  end
  for e in ev
   st in ("avlyst","cancelled","cancelado") && (e["status"]="cancelled")
   e["source"]="Innsendt via tabell"; push!(events,e)
  end
 end
 isempty(errs) || return fail()
 ids=[e["id"] for e in events]
 for id in unique(ids); count(==(id),ids)>1 && push!(errs,"To rader gir samme arrangement og dato ($id)."); end
 isempty(errs) || return fail()
 slugs=[_slug(e["title"]) for e in events]
 for (e,s) in zip(events,slugs); count(==(s),slugs)>1 && (e["series"]=s); end
 for e in events, m in validate_event(e); push!(errs,"$(e["id"]): $m"); end
 isempty(errs) ? (sort!(events,by=e->e["start"]),errs) : fail()
end
"Template for the table route: semicolon CSV with a UTF-8 BOM, so Excel in Norwegian locale opens it with æøå intact."
function table_template_csv()
 rows=[TABLE_COLUMNS,
  ["Milonga Eksempel","Milonga","2027-01-08","20:00","23:30","Kulturhuset","Storgata 1, 0155 Oslo","Tangoklubben","DJ A","","150","100","","Tradisjonell","","","https://example.org/milonga","Milonga hver fredag.","","Norsk","","Milonga every Friday."],
  ["","","2027-01-15","","","","","","DJ B","","","","","","","","","","","","",""],
  ["","","2027-01-22","","","","","","","","","","","","","","","","Avlyst","","",""]]
 q(c)=occursin(r"[;\"\n]",c) ? "\""*replace(c,"\""=>"\"\"")*"\"" : c
 "﻿"*join((join(q.(r),";") for r in rows),"\r\n")*"\r\n"
end
