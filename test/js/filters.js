// Runs a page's own inline <script> against its rows with a minimal DOM stand-in and a fixed "now".
// Usage: node filters.js PAGE.html YYYY-MM-DD [#hash] [?search]
// → JSON {initial:{rows:[[date,type,eid]…], groups, search, tabs, checked, q, when}, default, counts:{when:[dates]},
//          groups:{when:[…]}, reset, afterReset:{search,checked}, weeks:{…}}   (weeks only on the week page)
// Only class names are simulated here; test/js/browser.js checks what a real browser actually shows.
const fs=require('fs'); const html=fs.readFileSync(process.argv[2],'utf8'); const NOW=process.argv[3]; const HASH=process.argv[4]||''; const SEARCH=process.argv[5]||'';
const script=html.match(/<script>([\s\S]*)<\/script>/)[1];
const strip=s=>s.replace(/<[^>]*>/g,'');
function classList(init){const c=new Set(init.split(/\s+/).filter(Boolean));return {toggle:(k,on)=>{(on===undefined?!c.has(k):on)?c.add(k):c.delete(k)},has:k=>c.has(k),add:k=>c.add(k)}}
function attrs(s){const d={};for(const a of s.matchAll(/data-([a-z]+)="([^"]*)"/g))d[a[1]]=a[2];return d}
const rows=[...html.matchAll(/<article class="([^"]*\bev\b[^"]*)"([^>]*)>([\s\S]*?)<\/article>/g)].map(m=>{
  const t=(m[3].match(/<h[23]>([\s\S]*?)<\/h[23]>/)||[,''])[1];
  return {dataset:attrs(m[2]),classList:classList(m[1]),querySelector:()=>({textContent:strip(t)})};});
const groups=[...html.matchAll(/<(?:section|div) class="(group[^"]*)"([^>]*)>/g)].map(m=>({dataset:attrs(m[2]),classList:classList(m[1])}));
const cols=groups.filter(g=>g.classList.has('col'));
const weeks=[...html.matchAll(/<section class="(week[^"]*)" id="([^"]*)"([^>]*)>/g)].map(m=>({id:m[2],dataset:attrs(m[3]),classList:classList(m[1])}));
const boxes=[...html.matchAll(/<input type="checkbox" name="(type|music)" value="([^"]*)">/g)].map(m=>({name:m[1],value:m[2],checked:false,addEventListener(){}}));
const tabs=[...html.matchAll(/<nav class="tabs"[\s\S]*?<\/nav>/g)].flatMap(n=>[...n[0].matchAll(/<a href="([^"]*)"/g)]).map(m=>{const a={dataset:{},_href:m[1],getAttribute:()=>a._href,setAttribute:(k,v)=>{a._href=v}};return a});
const ctl=()=>({value:'',addEventListener(){},style:{}});
const ids=['q','when','sort','count','empty','reset','sharefilter','prevw','nextw','todayw','weeklabel'];
const el={}; for(const i of ids) if(html.includes(`id="${i}"`)) el['#'+i]=ctl();
if(html.includes('id="events"')) el['#events']={appendChild(){}};
const RealDate=Date; global.Date=class extends RealDate{constructor(...a){super(...(a.length?a:[NOW+'T12:00:00']))};static UTC(...a){return RealDate.UTC(...a)}};
global.location={hash:HASH,search:SEARCH,pathname:'/p.html'};
global.history={replaceState:(a,b,u)=>{const m=u.match(/^([^?#]*)(\?[^#]*)?(#.*)?$/);location.pathname=m[1]||location.pathname;location.search=m[2]||'';location.hash=m[3]||''}};
global.window={addEventListener(){}};
const sel={'.ev':rows,'.group':groups,'.week':weeks,'.col':cols,'input[name=type]':boxes.filter(b=>b.name==='type'),'input[name=music]':boxes.filter(b=>b.name==='music'),'.tabs a':tabs};
global.document={addEventListener(t,f){if(t==='keydown')global.keydown=f},documentElement:{classList:classList('')},querySelectorAll:s=>sel[s]||[],querySelector:s=>el[s]||null};
eval(script);
const visible=()=>rows.filter(c=>!c.classList.has('hidden')).map(c=>c.dataset.date);
const visGroups=()=>groups.filter(g=>!g.classList.has('hidden')&&!g.classList.has('noev')).map(g=>g.dataset.group);
const out={initial:{rows:rows.filter(c=>!c.classList.has('hidden')).map(c=>[c.dataset.date,c.dataset.type,c.dataset.eid]),groups:visGroups(),search:location.search,
  tabs:tabs.map(a=>a.getAttribute('href')),checked:boxes.filter(b=>b.checked).map(b=>b.name+':'+b.value),q:el['#q']?el['#q'].value:null,when:el['#when']?el['#when'].value:null},
  default:el['#when']?el['#when'].value:null,counts:{},groups:{}};
for(const w of (el['#when']?['upcoming','all','today','week','month','recurring']:['any'])){if(el['#when'])el['#when'].value=w; window.apply(); out.counts[w]=visible(); out.groups[w]=visGroups();}
if(el['#reset']){if(el['#when'])el['#when'].value='all'; el['#reset'].onclick(); out.reset=el['#when']?el['#when'].value:null; out.afterReset={search:location.search,checked:boxes.filter(b=>b.checked).length}}
if(weeks.length){const cur=()=>weeks.find(w=>!w.classList.has('off')).dataset.week; out.weeks={hash:cur()};
  el['#todayw'].onclick(); out.weeks.default=cur(); out.weeks.label=el['#weeklabel'].textContent; out.weeks.today=cols.filter(c=>c.classList.has('today')).map(c=>c.dataset.group);
  el['#nextw'].onclick(); out.weeks.next=cur(); el['#prevw'].onclick(); el['#prevw'].onclick(); out.weeks.prev=cur(); out.weeks.anchor=location.hash; out.weeks.prevDisabledAtStart=!!el['#prevw'].disabled;
  el['#todayw'].onclick(); global.keydown({key:'ArrowRight',target:{tagName:'BODY'}}); out.weeks.keyRight=cur(); global.keydown({key:'ArrowRight',target:{tagName:'INPUT'}}); out.weeks.keyInInput=cur()}
console.log(JSON.stringify(out));
