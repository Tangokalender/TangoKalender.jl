// Runs a page's language script (the first <script> in <head>, see _lang_js in src/i18n.jl) with a fake browser.
// Usage: node lang.js PAGE.html LANGUAGES STORED USERAGENT [?search#hash]
//   LANGUAGES: comma-separated navigator.languages ("" = none); STORED: localStorage.lang ("" = unset, "THROW" = blocked)
// → JSON {redirect: URL passed to location.replace or null, click: {href, stored} after clicking the EN link}
const fs=require('fs'); const [page,langs,stored,ua,loc='']=process.argv.slice(2);
const html=fs.readFileSync(page,'utf8'); const script=html.match(/<head>[\s\S]*?<script>([\s\S]*?)<\/script>/)[1];
const m=loc.match(/^([^#]*)(#.*)?$/);
let store=stored==='THROW'?null:(stored?{lang:stored}:{}),redirect=null,listener=null;
global.localStorage={getItem:k=>{if(!store)throw new Error('blocked');return k in store?store[k]:null},setItem:(k,v)=>{if(!store)throw new Error('blocked');store[k]=v}};
Object.defineProperty(globalThis,'navigator',{value:{languages:langs?langs.split(','):[],language:'',userAgent:ua},configurable:true});   // Node ≥ 21 has its own navigator
global.location={search:m[1]||'',hash:m[2]||'',replace:u=>{redirect=u}};
global.document={addEventListener:(t,f)=>{if(t==='click')listener=f}};
eval(script);
const hrefs=[...html.matchAll(/<a href="([^"]*)" data-lang="([a-z]+)"/g)].map(x=>({href:x[1],lang:x[2]}));
let click=null; const en=hrefs.find(h=>h.lang==='en');
if(en&&listener){const a={href:en.href,getAttribute:k=>k==='href'?a.href:'en',setAttribute:(k,v)=>{a.href=v}};
  listener({target:{closest:()=>a}}); click={href:a.href,stored:store?store.lang:null}}
console.log(JSON.stringify({redirect,click}));
