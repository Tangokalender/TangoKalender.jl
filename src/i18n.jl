# Languages: Norwegian (nb, primary, served at /), English (en, UK spelling, /en/) and Spanish (es, rioplatense, /es/).
# The language being rendered is a ScopedValue: public renderers take `lang=` and run inside `_with_lang`, so the
# helpers below (labels, dates, `_t`) need no extra argument. Outside any renderer it is "nb" (forms, bot messages).
# Every UI string lives in `_T` with all three languages; the long prose pages add theirs with `_strings!`.
using Base.ScopedValues: ScopedValue, with
const LANGS=("nb","en","es")
const LANG=ScopedValue("nb")
_lang()=LANG[]
"Run `f()` with `lang` as the current language (checked)."
function _with_lang(f,lang)
 string(lang) in LANGS || throw(ArgumentError("unknown language $lang (expected one of $(join(LANGS,", ")))"))
 with(f,LANG=>string(lang))
end
"Path prefix of a language's tree: \"\" for nb, \"en/\" and \"es/\"."
_prefix(l=_lang())=l=="nb" ? "" : "$l/"
"Absolute URL of `rel` (relative to a language root, \"\" = the calendar) in language `l`."
_lang_url(rel,l=_lang())=site_url()*"/"*_prefix(l)*rel
"Two-letter code shown in the language switcher (country-style, as on the flags)."
const LANG_CODE=Dict("nb"=>"NO","en"=>"EN","es"=>"ES")
const LANG_NAME=Dict("nb"=>"Norsk","en"=>"English","es"=>"Español")
const OG_LOCALE=Dict("nb"=>"nb_NO","en"=>"en_GB","es"=>"es_AR")
"BCP 47 tag for sorting in the browser (`localeCompare`)."
const JS_LOCALE=Dict("nb"=>"nb","en"=>"en-GB","es"=>"es-AR")

const _T=Dict{String,NamedTuple{(:nb,:en,:es),NTuple{3,String}}}()
"Add strings `key => (nb, en, es)`; a key may only be defined once."
function _strings!(pairs...)
 for (k,(nb,en,es)) in pairs
  haskey(_T,k) && error("duplicate UI string key $k")
  _T[k]=(nb=nb,en=en,es=es)
 end
end
"""
    _t(key, args...) -> String

The UI string `key` in the current language: the site's own text (`[texts]` in site.toml) if it has one, else the
package's. `{city}`/`{CITY}` become the site's city (as is / upper case); `{1}`, `{2}` … are replaced by `args`.
"""
function _t(key,args...)
 s=get(get(SITE[].texts,_lang(),Dict{String,String}()),key,getfield(_T[key],Symbol(_lang())))
 occursin("{city}",s) && (s=replace(s,"{city}"=>site_city()))
 occursin("{CITY}",s) && (s=replace(s,"{CITY}"=>uppercase(site_city())))
 for (i,a) in enumerate(args); s=replace(s,"{$i}"=>string(a)); end
 s
end

# Event types and music styles (the data values are English slugs; Norwegian labels are `_TYPES`/`_MUSIC` in labels.jl,
# which the Norwegian issue forms also parse).
const _TYPES_I18N=Dict(
 "en"=>Dict("milonga"=>"Milonga","practica"=>"Practica","class"=>"Class","workshop"=>"Workshop","festival"=>"Festival",
  "marathon"=>"Marathon","outdoor"=>"Open-air","other"=>"Other"),
 "es"=>Dict("milonga"=>"Milonga","practica"=>"Práctica","class"=>"Clase","workshop"=>"Seminario","festival"=>"Festival",
  "marathon"=>"Maratón","outdoor"=>"Al aire libre","other"=>"Otro"))
const _MUSIC_I18N=Dict(
 "en"=>Dict("traditional"=>"Traditional","alternative"=>"Alternative / neo","live_orchestra"=>"Live orchestra"),
 "es"=>Dict("traditional"=>"Tradicional","alternative"=>"Alternativa / neo","live_orchestra"=>"Orquesta en vivo"))

# Dates. Times are 24 h in every language.
const _DATES=Dict(
 "nb"=>(wd=["mandag","tirsdag","onsdag","torsdag","fredag","lørdag","søndag"],wd3=["man","tir","ons","tor","fre","lør","søn"],
  mo=["jan","feb","mar","apr","mai","jun","jul","aug","sep","okt","nov","des"],
  month=["januar","februar","mars","april","mai","juni","juli","august","september","oktober","november","desember"]),
 "en"=>(wd=["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"],wd3=["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
  mo=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
  month=["January","February","March","April","May","June","July","August","September","October","November","December"]),
 "es"=>(wd=["lunes","martes","miércoles","jueves","viernes","sábado","domingo"],wd3=["lun","mar","mié","jue","vie","sáb","dom"],
  mo=["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"],
  month=["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"]))
_dn()=_DATES[_lang()]
_wd(d)=_dn().wd[dayofweek(d)]
_wd3(d)=_dn().wd3[dayofweek(d)]
"Day and short month: «9. okt» / «9 Oct» / «9 oct»."
_dm(d)=_lang()=="nb" ? "$(day(d)). $(_dn().mo[month(d)])" : "$(day(d)) $(_dn().mo[month(d)])"
"«fredag 9. okt» / «Friday 9 Oct» / «viernes 9 oct»."
_day(d)="$(_wd(d)) $(_dm(d))"
"«fredag 9. oktober» / «Friday 9 October» / «viernes 9 de octubre»."
_longday(d)=(n=_dn(); l=_lang(); l=="nb" ? "$(n.wd[dayofweek(d)]) $(day(d)). $(n.month[month(d)])" :
 l=="es" ? "$(n.wd[dayofweek(d)]) $(day(d)) de $(n.month[month(d)])" : "$(n.wd[dayofweek(d)]) $(day(d)) $(n.month[month(d)])")
"Date range within a week: «5.–11. okt» / «5–11 Oct», or «28. sep – 4. okt» across months."
_range(a,b)=month(a)==month(b) ? (_lang()=="nb" ? "$(day(a)).–$(_dm(b))" : "$(day(a))–$(_dm(b))") : "$(_dm(a)) – $(_dm(b))"
"Week heading «Uke 41 · 5.–11. okt» for the week starting Monday `mon`."
_weeklabel(mon)=_t("week.label",week(mon),_range(mon,mon+Day(6)))

# Event text: `title`/`description` are in the event's `lang` (default nb); `translations` may hold the others.
"Language of an event's own `title`/`description`."
_textlang(e)=(l=get(e,"lang",nothing); l isa AbstractString && l in LANGS ? String(l) : "nb")
function _translation(e,l,k)
 tr=get(e,"translations",nothing); tr isa AbstractDict || return ""
 x=get(tr,l,nothing); x isa AbstractDict || return ""
 v=get(x,k,nothing); isnothing(v) ? "" : strip(string(v))
end
_textin(e,l,k)=l==_textlang(e) ? strip(string(something(get(e,k,nothing),""))) : _translation(e,l,k)
"""
    _text(e, key) -> (text, language)

`title` or `description` for the current page language: the page language, then (on Spanish pages) English, then the
original; any language that has the text if those are empty. `language` says which one it is.
"""
function _text(e,k)
 l=_lang(); ol=_textlang(e)
 for c in unique([l; l=="es" ? ["en"] : String[]; ol; collect(LANGS)])
  t=_textin(e,c,k); isempty(t) || return (String(t),c)
 end
 ("",l)
end
"All language versions of an event's text (for the search index)."
_alltext(e,k)=join(unique(filter(!isempty,[_textin(e,l,k) for l in LANGS]))," ")
"Plain title in the page language (fallback as `_text`)."
_title(e)=(t=first(_text(e,"title")); isempty(t) ? _t("untitled") : t)
"` lang=\"en\"` when text in language `l` is shown on a page in another language."
_langattr(l)=l==_lang() ? "" : " lang=\"$l\""
"Muted note «(på engelsk)» after text that is not in the page language."
_langnote(l)=l==_lang() ? "" : " <small class=\"tnote\">($(_t("textlang.$l")))</small>"

# Language switcher, alternates and the auto-redirect.
const _FLAGS=Dict(
 "nb"=>"<symbol id=\"flag-nb\" viewBox=\"0 0 22 16\" preserveAspectRatio=\"none\"><rect width=\"22\" height=\"16\" fill=\"#ba0c2f\"/><path d=\"M6 0h4v16H6zM0 6h22v4H0z\" fill=\"#fff\"/><path d=\"M7 0h2v16H7zM0 7h22v2H0z\" fill=\"#00205b\"/></symbol>",
 "en"=>"<symbol id=\"flag-en\" viewBox=\"0 0 60 30\" preserveAspectRatio=\"none\"><rect width=\"60\" height=\"30\" fill=\"#012169\"/><path d=\"M0 0l60 30M60 0L0 30\" stroke=\"#fff\" stroke-width=\"6\"/><path d=\"M0 0l60 30M60 0L0 30\" stroke=\"#c8102e\" stroke-width=\"2.4\"/><path d=\"M30 0v30M0 15h60\" stroke=\"#fff\" stroke-width=\"10\"/><path d=\"M30 0v30M0 15h60\" stroke=\"#c8102e\" stroke-width=\"6\"/></symbol>",
 "es"=>"<symbol id=\"flag-es\" viewBox=\"0 0 30 20\" preserveAspectRatio=\"none\"><rect width=\"30\" height=\"20\" fill=\"#74acdf\"/><rect y=\"6.67\" width=\"30\" height=\"6.66\" fill=\"#fff\"/><circle cx=\"15\" cy=\"10\" r=\"2.3\" fill=\"#f6b40e\"/></symbol>")
_flag(l)="<svg class=\"flag\" aria-hidden=\"true\" focusable=\"false\"><use href=\"#flag-$l\"/></svg>"
const _LANG_CSS=""".langs{display:flex;gap:6px;flex-wrap:wrap}.langs a{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;border:1px solid #ffffff40;color:#f7dce5;text-decoration:none;font-weight:800;font-size:.78rem;letter-spacing:.03em}.langs a.on{background:white;color:var(--wine);border-color:white}.hero .langs a{margin-right:0}.flag{width:18px;height:12px;border-radius:2px;box-shadow:0 0 0 1px #0000002e;flex:none}.topbar{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap}.tnote{color:var(--muted);font-weight:400;font-size:.78em}"""
_up(depth)="../"^(depth+(_lang()=="nb" ? 0 : 1))
"""
    _langnav(rel; depth=0) -> String

`NO · EN · ES` links (with SVG flags from the page sprite) to page `rel` in each language. `depth` is how many
directories below its language root the current page is (`arrangement/<id>/` = 2). Links are relative, so the site
also works from a local folder.
"""
function _langnav(rel; depth=0)
 up=_up(depth)
 items=join(("<a href=\"$(let h=up*_prefix(l)*rel; isempty(h) ? "./" : h end)\" data-lang=\"$l\" hreflang=\"$l\" lang=\"$l\" title=\"$(LANG_NAME[l])\"$(l==_lang() ? " class=\"on\" aria-current=\"true\"" : "")>$(LANG_CODE[l])$(_flag(l))</a>" for l in LANGS),"")
 "<nav class=\"langs\" aria-label=\"$(_t("nav.lang"))\">$items</nav>"
end
"`<link rel=alternate hreflang>` for all languages plus x-default (Norwegian), and the canonical URL."
_alternates(rel)="<link rel=\"canonical\" href=\"$(_lang_url(rel))\">"*join(("<link rel=\"alternate\" hreflang=\"$l\" href=\"$(_lang_url(rel,l))\">" for l in LANGS),"")*
 "<link rel=\"alternate\" hreflang=\"x-default\" href=\"$(_lang_url(rel,"nb"))\">"
"""
Head script for every page. Clicking a language link stores the choice (`localStorage.lang`) and carries the
current filters (`?…`) and week (`#uke-…`) along. On Norwegian pages only, a visitor without a stored choice whose
browser prefers English or Spanish (or none of nb/nn/no/da/sv/en/es) is sent to the same page in /en/ or /es/.
Explicit /en/ and /es/ URLs are never redirected, nor are crawlers and headless browsers.
"""
_lang_js(rel; depth=0)="<script>(function(){var P='$(_lang())',R='$(rel)',U='$(_up(depth))';"*raw"""document.addEventListener('click',function(e){var a=e.target&&e.target.closest&&e.target.closest('a[data-lang]');if(!a)return;try{localStorage.setItem('lang',a.getAttribute('data-lang'))}catch(x){}a.setAttribute('href',a.getAttribute('href').split(/[?#]/)[0]+location.search+location.hash)});
if(P!=='nb'||/bot|crawl|spider|slurp|headless|lighthouse/i.test(navigator.userAgent||''))return;var s=null,w=null;try{s=localStorage.getItem('lang')}catch(x){}if(s==='nb'||s==='en'||s==='es')w=s;
if(!w){var ls=navigator.languages&&navigator.languages.length?navigator.languages:[navigator.language||''];for(var i=0;i<ls.length&&!w;i++){var c=String(ls[i]).toLowerCase().split('-')[0];if(/^(nb|nn|no|da|sv)$/.test(c))w='nb';else if(c==='en'||c==='es')w=c}w=w||'en'}
if(w!=='nb')location.replace(U+w+'/'+R+location.search+location.hash)})();</script>"""

_strings!(
 "nav.lang"=>("Språk","Language","Idioma"),
 "textlang.nb"=>("på norsk","in Norwegian","en noruego"),
 "textlang.en"=>("på engelsk","in English","en inglés"),
 "textlang.es"=>("på spansk","in Spanish","en español"),
 "untitled"=>("Uten tittel","Untitled","Sin título"),
 "week.label"=>("Uke {1} · {2}","Week {1} · {2}","Semana {1} · {2}"),
 # calendar views
 "site.tagline"=>("ARGENTINSK TANGO I {CITY}","ARGENTINE TANGO IN {CITY}","TANGO ARGENTINO EN {CITY}"),
 "site.subtitle"=>("Milongaer, practicaer, kurs og festivaler","Milongas, practicas, classes and festivals","Milongas, prácticas, clases y festivales"),
 "site.description"=>("Argentinsk tango i {city}: milongaer, practicaer, kurs og festivaler","Argentine tango in {city}: milongas, practicas, classes and festivals","Tango argentino en {city}: milongas, prácticas, clases y festivales"),
 "view.compact"=>("Liste","List","Lista"),"view.week"=>("Uke","Week","Semana"),"view.cards"=>("Kort","Cards","Tarjetas"),
 "nav.views"=>("Visning","View","Vista"),
 "add"=>("Legg til arrangement","Add an event","Sumá un evento"),
 "about"=>("Om kalenderen","About the calendar","Sobre el calendario"),
 "embed"=>("Bygg inn","Embed","Insertar"),
 "subscribe"=>("Abonner på kalenderen","Subscribe to the calendar","Suscribite al calendario"),
 "subscribe.short"=>("Abonner (.ics)","Subscribe (.ics)","Suscribirse (.ics)"),
 "generated"=>("Generert","Generated","Generado"),
 "check"=>("Kontroller alltid detaljer hos arrangøren.","Always check the details with the organiser.","Confirmá siempre los detalles con quien organiza."),
 "calendar"=>("Kalenderen","The calendar","El calendario"),
 "calendar.full"=>("Hele kalenderen","Full calendar","Calendario completo"),
 "back"=>("← Til kalenderen","← Back to the calendar","← Volver al calendario"),
 "copylink"=>("Kopier lenke","Copy link","Copiar enlace"),
 "copied"=>("Lenke kopiert ✓","Link copied ✓","Enlace copiado ✓"),
 "copyprompt"=>("Kopier lenken:","Copy the link:","Copiá el enlace:"),
 "reset"=>("Nullstill","Reset","Restablecer"),
 "nomatch"=>("Ingen treff","No matches","Sin resultados"),
 "count.of"=>(" av "," of "," de "),"count.events"=>(" arrangementer"," events"," eventos"),
 "search"=>("Søk","Search","Buscar"),
 "search.placeholder"=>("Sted, DJ, arrangør …","Venue, DJ, organiser …","Lugar, DJ, organización …"),
 "search.title"=>("Flere ord: alle må stemme","Several words: all must match","Varias palabras: tienen que coincidir todas"),
 "filter"=>("Filter","Filters","Filtros"),
 "when"=>("Tidspunkt","When","Cuándo"),
 "when.upcoming"=>("Kommende","Upcoming","Próximos"),"when.all"=>("Alle (også tidligere)","All (including past)","Todos (también pasados)"),
 "when.today"=>("I dag","Today","Hoy"),"when.week"=>("Neste 7 dager","Next 7 days","Próximos 7 días"),
 "when.month"=>("Neste 30 dager","Next 30 days","Próximos 30 días"),"when.recurring"=>("Faste aktiviteter","Regular activities","Actividades fijas"),
 "sort"=>("Sortering","Sort","Orden"),"sort.asc"=>("Tidligste først","Earliest first","Más cercanos primero"),
 "sort.desc"=>("Seneste først","Latest first","Más lejanos primero"),"sort.title"=>("Alfabetisk","Alphabetical","Alfabético"),
 "type"=>("Type","Type","Tipo"),"music"=>("Musikk","Music","Música"),
 "week.prev"=>("Forrige uke","Previous week","Semana anterior"),"week.prev.short"=>("Forrige","Previous","Anterior"),
 "week.next"=>("Neste uke","Next week","Semana siguiente"),"week.next.short"=>("Neste","Next","Siguiente"),
 "week.today"=>("I dag","Today","Hoy"),
 "dayn"=>("dag {1} av {2}","day {1} of {2}","día {1} de {2}"),
 "cancelled"=>("Avlyst","Cancelled","Cancelado"),
 "venue"=>("Sted","Venue","Lugar"),"price"=>("Pris","Price","Precio"),"teachers"=>("Lærere","Teachers","Profesores"),
 "organizer"=>("Arrangør","Organiser","Organiza"),
 "allday"=>("hele dagen","all day","todo el día"),"ongoing"=>("pågår","ongoing","en curso"),"from"=>("fra {1}","from {1}","desde {1}"),
 "price.none"=>("Pris ikke oppgitt","Price not given","Precio no indicado"),
 "price.student"=>("student","students","estudiantes"),"price.class"=>("kurs","class","clase"),
 "venue.none"=>("Sted ikke oppgitt","Venue not given","Lugar no indicado"),
 "moreinfo"=>("Mer info ↗","More info ↗","Más info ↗"),
 "correct"=>("Rett opp ↗","Suggest a correction ↗","Proponer una corrección ↗"),
 "correct.aria"=>("Rett opp: {1}","Suggest a correction: {1}","Proponer una corrección: {1}"),
 "published"=>("Publisert","Published","Publicado"),"notgiven"=>("Ikke oppgitt","Not given","No indicado"),
 "source"=>("Kilde","Source","Fuente"),
 "embed.upcoming"=>("Kommende arrangementer","Upcoming events","Próximos eventos"),
 "embed.all"=>("Se hele kalenderen →","See the full calendar →","Ver el calendario completo →"),
 # event page
 "map"=>("Kart ↗","Map ↗","Mapa ↗"),
 "addcal"=>("Legg i kalender (.ics)","Add to calendar (.ics)","Agregar al calendario (.ics)"),
 "share"=>("Del lenke","Share link","Compartir enlace"),
 "series.more"=>("Flere datoer i denne serien","More dates in this series","Más fechas de esta serie"),
 "ev.when"=>("Når","When","Cuándo"),"ev.where"=>("Hvor","Where","Dónde"),
 "ev.cancelled"=>("Arrangementet er avlyst – sjekk med arrangøren.","This event has been cancelled – check with the organiser.","El evento se canceló; consultá con quien lo organiza."),
 "ev.past"=>("Dette arrangementet har vært.","This event has already taken place.","Este evento ya pasó."),
 "ev.checked"=>("Sist kontrollert","Last checked","Última verificación"),
 "moreinfo.plain"=>("Mer info","More info","Más info"),
 # SVG embeds
 "svg.today"=>("I dag · {1}","Today · {1}","Hoy · {1}"),
 "svg.open"=>("Åpne {1}","Open {1}","Abrir {1}"),
 "svg.opencal"=>("Åpne kalenderen","Open the calendar","Abrir el calendario"),
 "svg.openweek"=>("Åpne ukevisningen","Open the week view","Abrir la vista semanal"),
 "svg.stale"=>("Programmet er ikke oppdatert","This programme is out of date","El programa no está actualizado"),
 "svg.stale.link"=>("Se det oppdaterte programmet i kalenderen →","See the current programme in the calendar →","Ver el programa actualizado en el calendario →"),
 "svg.none"=>("Ingen arrangementer i dag – se hele kalenderen →","No events today – see the full calendar →","Hoy no hay eventos – ver el calendario completo →"),
 "svg.seeall"=>("Se hele kalenderen","See the full calendar","Ver el calendario completo"),
 "svg.updated"=>("oppdatert {1}","updated {1}","actualizado {1}"),
 "svg.cancelled"=>("avlyst","cancelled","cancelado"),
 "svg.today.title"=>("{1} – dagens program","{1} – today's programme","{1} – programa de hoy"),
 "svg.today.desc"=>("Tangoarrangementer i {city} i dag.","Tango events in {city} today.","Eventos de tango en {city} hoy."),
 "svg.week.title"=>("{1} – ukens program","{1} – this week's programme","{1} – programa de la semana"),
 "svg.week.desc"=>("Tangoarrangementer i {city} denne uken.","Tango events in {city} this week.","Eventos de tango en {city} esta semana."),
 # feeds
 "cancelled.caps"=>("AVLYST","CANCELLED","CANCELADO"),
 "term.series"=>("serie","series","serie"),
)
