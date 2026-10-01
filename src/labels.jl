# Display labels (Norwegian) for the English slugs used in event data. Shared by the renderer and the issue-form parser.
const _WEEKDAYS=Dict("Monday"=>"mandag","Tuesday"=>"tirsdag","Wednesday"=>"onsdag","Thursday"=>"torsdag","Friday"=>"fredag","Saturday"=>"lørdag","Sunday"=>"søndag")
const _TYPES=Dict("milonga"=>"Milonga","practica"=>"Practica","festival"=>"Festival","marathon"=>"Maraton","class"=>"Kurs","workshop"=>"Workshop",
 "class_and_social"=>"Kurs og milonga","class_and_practica"=>"Kurs og practica","other"=>"Annet")
_type_label(t)=get(_TYPES,t,titlecase(replace(t,'_'=>' ')))
const _MUSIC=Dict("traditional"=>"Tradisjonell","alternative"=>"Alternativ / neo","live_orchestra"=>"Levende orkester")
_music_label(m)=get(_MUSIC,m,titlecase(replace(m,'_'=>' ')))
