// Runs the page's own inline <script> against its cards with a minimal DOM stand-in and a fixed "now".
// Usage: node filters.js PAGE.html YYYY-MM-DD  → JSON {default, counts:{when:[ids…]}, reset}
const fs=require('fs'); const html=fs.readFileSync(process.argv[2],'utf8'); const NOW=process.argv[3];
const script=html.match(/<script>([\s\S]*)<\/script>/)[1];
const cards=[...html.matchAll(/<article class="([^"]*)"([^>]*)>[\s\S]*?<h2>([^<]*)<\/h2>/g)].map(m=>{
  const ds={}; for(const a of m[2].matchAll(/data-([a-z]+)="([^"]*)"/g)) ds[a[1]]=a[2];
  const cls=new Set(m[1].split(' '));
  return {dataset:ds,classList:{toggle:(c,on)=>on?cls.add(c):cls.delete(c),has:c=>cls.has(c)},querySelector:()=>({textContent:m[3]})};});
const ctl=()=>({value:'',addEventListener(){},style:{}});
const el={'#q':ctl(),'#type':ctl(),'#music':ctl(),'#when':ctl(),'#sort':ctl(),'#count':ctl(),'#empty':ctl(),'#events':{appendChild(){}}};
el['#when'].value=(html.match(/<option value="([a-z]+)" selected>/)||[])[1]||''; el['#sort'].value='asc';
const RealDate=Date; global.Date=class extends RealDate{constructor(...a){super(...(a.length?a:[NOW+'T12:00:00']))}};
global.document={querySelectorAll:()=>cards,querySelector:s=>el[s]}; global.reset={};
const visible=()=>cards.filter(c=>!c.classList.has('hidden')).map(c=>c.dataset.date);
eval(script);
const out={default:el['#when'].value,counts:{}};
for(const w of ['upcoming','all','today','week','month','recurring']){el['#when'].value=w; eval('apply()'); out.counts[w]=visible();}
el['#when'].value='all'; reset.onclick(); out.reset=el['#when'].value;
console.log(JSON.stringify(out));
