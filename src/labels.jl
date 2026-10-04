"Site name shown in titles, the hero, feeds and calendar names."
const SITE_NAME="Tangokalender | Oslo"
# Display labels (Norwegian) for the English slugs used in event data. Shared by the renderer and the issue-form parser.
"Event types (tags) in display order; an event has one or more. `outdoor` (Utetango) combines with the others."
const TYPE_ORDER=["class","workshop","milonga","practica","festival","marathon","outdoor","other"]   # «Kurs · Milonga» reads in evening order
const _TYPES=Dict("milonga"=>"Milonga","practica"=>"Practica","class"=>"Kurs","workshop"=>"Workshop","festival"=>"Festival",
 "marathon"=>"Maraton","outdoor"=>"Utetango","other"=>"Annet")
_type_label(t)=get(_TYPES,t,titlecase(replace(t,'_'=>' ')))
"An event's types (`types` array), in `TYPE_ORDER`."
_types(e)=sort!([string(t) for t in something(get(e,"types",nothing),Any[])],by=t->something(findfirst(==(t),TYPE_ORDER),99))
"Display label for an event's types: «Kurs · Milonga»."
_types_label(e)=join(_type_label.(_types(e))," · ")
const _MUSIC=Dict("traditional"=>"Tradisjonell","alternative"=>"Alternativ / neo","live_orchestra"=>"Levende orkester")
_music_label(m)=get(_MUSIC,m,titlecase(replace(m,'_'=>' ')))
