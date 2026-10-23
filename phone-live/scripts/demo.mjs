// Intentional test event, never an executable AI command or a real approval.
import { readFileSync } from 'node:fs';
const config=JSON.parse(readFileSync(new URL('../generated/codex-private.json',import.meta.url),'utf8'));
const r=await fetch(config.origin+'/source/status',{method:'POST',headers:{authorization:`Bearer ${config.token}`,'content-type':'application/json'},body:JSON.stringify({provider:'Codex',phase:'working',text:'Demo: checking the phone connection'})});
console.log(r.ok?'Demo state recorded. Apple delivery still needs a signed app and configured push credentials.':`Relay returned ${r.status}`);
