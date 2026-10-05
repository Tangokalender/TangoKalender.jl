// Runs the date script inside an embedded SVG (today_svg/week_svg) at a fixed instant and prints which
// <g data-date> group it shows. Usage: node svgday.js FILE.svg 2026-10-11T22:30:00Z
const fs=require('fs'); const svg=fs.readFileSync(process.argv[2],'utf8'); const NOW=process.argv[3];
const script=svg.match(/<script><!\[CDATA\[([\s\S]*?)\]\]><\/script>/)[1];
const groups=[...svg.matchAll(/<g data-date="([^"]+)"[^>]*display="(inline|none)"/g)].map(m=>{const a={'data-date':m[1],display:m[2]};return {getAttribute:k=>a[k],setAttribute:(k,v)=>{a[k]=v}}});
const RealDate=Date; global.Date=class extends RealDate{constructor(...a){super(...(a.length?a:[NOW]))}};
global.document={querySelectorAll:()=>groups,querySelector:s=>groups.find(g=>s.includes('"'+g.getAttribute('data-date')+'"')||s.includes('='+g.getAttribute('data-date')+']'))||null};
eval(script);
console.log(groups.filter(g=>g.getAttribute('display')!=='none').map(g=>g.getAttribute('data-date')).join(','));
