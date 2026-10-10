# Maps (Leaflet + OpenStreetMap tiles, loaded automatically): one marker on event pages, and the «Kart» view
# (kart.html) with one marker per venue for the events the filters show. Positions come from venues.json (src/geo.jl);
# rows carry them as data-lat/data-lon, so the map follows the same filters and URL as the list.
const LEAFLET_VERSION="1.9.4"
const LEAFLET_HEAD="<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/leaflet/$LEAFLET_VERSION/leaflet.css\" integrity=\"sha512-Zcn6bjR/8RZbLEpLIeOwNtzREBAJnUKESxces60Mpoj+2okopSAcSUIUOseddDm0cxnGQzxIR7vJgsLZbdLE3w==\" crossorigin=\"anonymous\" referrerpolicy=\"no-referrer\">"*
 "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/leaflet/$LEAFLET_VERSION/leaflet.js\" integrity=\"sha512-BwHfrr4c9kmRkLw6iXFdzcdWV/PGkVgiIyIWLLlTSXzWQzxuSg4DiQUCpauz/EWjgk5TYQqX/kvn9pG1NpYfqg==\" crossorigin=\"anonymous\" referrerpolicy=\"no-referrer\"></script>"
const _MAP_CSS=""".map{height:62vh;min-height:320px;border:1px solid var(--line);border-radius:18px;margin:0 0 8px;isolation:isolate;background:#e8e2da}.map.small{height:300px;min-height:0;margin:0}.mp{margin:6px 0 0;padding-left:1.1em;max-height:240px;overflow:auto}.mp li{margin:4px 0}#nomap{color:var(--muted);font-size:.85rem;margin:0 0 18px;min-height:1em}@media(max-width:760px){.map{height:52vh}}"""
# Shared by both maps: tiles, attribution and the marker style (the calendar's wine colour, no marker images).
const _MAP_BASE=raw"""var TILES='https://tile.openstreetmap.org/{z}/{x}/{y}.png',ATTR='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',PIN={radius:9,color:'#fff',weight:2,fillColor:'#872b49',fillOpacity:.92};"""
"""
Script for the «Kart» view, appended to the page script: `mapMarkers(rows)` groups the visible rows by position (one
marker per venue, popup with day, time and linked title); `_JS` calls `window.onfiltered(visibleRows)` after every
filter change. Without Leaflet (blocked CDN, tests) the marker data is still computed (`window.__markers`).
"""
const _MAP_JS_RAW=_MAP_BASE*raw"""(function(){var el=document.getElementById('map');if(!el)return;var M=null,layer=null,nomap=document.getElementById('nomap'),ESC=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function mapMarkers(rows){var by={},order=[],no=new Set();rows.forEach(r=>{var d=r.dataset;if(!d.lat){no.add(d.eid);return}var k=d.lat+','+d.lon;if(!by[k]){by[k]={lat:+d.lat,lon:+d.lon,venue:d.venue,items:[]};order.push(k)}var h=r.querySelector('h3'),a=r.querySelector('h3 a'),t=r.querySelector('.time');by[k].items.push({eid:d.eid,date:d.date,day:d.dl,time:t?t.textContent:'',title:h?h.textContent:'',href:a&&a.getAttribute?a.getAttribute('href')||'':''})});return {markers:order.map(k=>by[k]),without:no.size}}
function draw(v){var r=mapMarkers(v);window.__markers=r;if(nomap)nomap.textContent=r.without?T.nomap.replace('{1}',r.without):'';if(typeof L==='undefined')return;
if(!M){M=L.map(el,{scrollWheelZoom:false});L.tileLayer(TILES,{maxZoom:19,attribution:ATTR}).addTo(M)}if(layer)layer.remove();layer=L.layerGroup().addTo(M);
var pts=r.markers.map(m=>{L.circleMarker([m.lat,m.lon],PIN).bindPopup('<b>'+ESC(m.venue)+'</b><ul class="mp">'+m.items.map(i=>'<li>'+ESC(i.day)+' · '+ESC(i.time)+'<br>'+(i.href?'<a href="'+ESC(i.href)+'">'+ESC(i.title)+'</a>':ESC(i.title))+'</li>').join('')+'</ul>',{maxWidth:280}).addTo(layer);return [m.lat,m.lon]});
if(pts.length)M.fitBounds(pts,{padding:[36,36],maxZoom:15});else M.setView(__MAPVIEW__)}
window.mapMarkers=mapMarkers;window.onfiltered=draw;draw([...document.querySelectorAll('.ev')].filter(r=>!r.classList.contains('hidden')))})();"""
"The «Kart» view script with the site's default map view (`map_center`, `map_zoom` in site.toml)."
_map_js()=(c=SITE[].map_center; replace(_MAP_JS_RAW,"__MAPVIEW__"=>"[$(c[1]),$(c[2])],$(SITE[].map_zoom)"))
"Map card for an event page, or \"\" when the venue has no precise position."
function _event_map(e)
 c=venue_coords(e); isnothing(c) && return ""
 (vname,_)=_venue(e)
 "<section class=\"card\"><h2>$(_t("map.title"))</h2><div id=\"evmap\" class=\"map small\" data-lat=\"$(round(c[1];digits=6))\" data-lon=\"$(round(c[2];digits=6))\" data-venue=\"$(_esc(vname))\" role=\"img\" aria-label=\"$(_esc(_t("map.aria",vname)))\"></div></section>"*
 "<script>"*_MAP_BASE*raw"""(function(){var e=document.getElementById('evmap');if(!e||typeof L==='undefined')return;var p=[+e.dataset.lat,+e.dataset.lon],m=L.map(e,{scrollWheelZoom:false}).setView(p,16);L.tileLayer(TILES,{maxZoom:19,attribution:ATTR}).addTo(m);L.circleMarker(p,PIN).bindTooltip(e.dataset.venue,{permanent:true,direction:'top',offset:[0,-8]}).addTo(m)})();</script>"""
end
_strings!(
 "view.map"=>("Kart","Map","Mapa"),
 "map.title"=>("Kart","Map","Mapa"),
 "map.aria"=>("Kart som viser {1}","Map showing {1}","Mapa con {1}"),
 "map.view.aria"=>("Kart over arrangementene som vises","Map of the events shown","Mapa de los eventos que se muestran"),
 "map.none"=>("{1} arrangementer uten kartposisjon – se listen under.","{1} events without a map position – see the list below.","{1} eventos sin ubicación en el mapa: mirá la lista de abajo."),
)
