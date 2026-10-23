import { readFileSync,writeFileSync,mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { safeOrigin } from '../relay/security.mjs';

const root=fileURLToPath(new URL('../',import.meta.url));
const origin=safeOrigin(process.env.PUBLIC_ORIGIN||'http://127.0.0.1:4319',{development:process.env.NODE_ENV!=='production'});
const admin=process.env.ADMIN_TOKEN||readFileSync(resolve(root,'.data/admin.key'),'utf8').trim();
async function call(path,body,credential){const r=await fetch(`http://127.0.0.1:${process.env.PORT||4319}${path}`,{method:'POST',headers:{authorization:`Bearer ${credential}`,'content-type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(5000)});if(!r.ok)throw new Error(`Setup failed (${r.status})`);return r.json();}
const s=await call('/admin/source',{name:'My AI sessions'},admin);
const invitation=await call('/source/invite',{},s.token);
const dir=resolve(root,'generated');mkdirSync(dir,{recursive:true});
for(const [name,provider] of [['codex','Codex'],['claude','Claude Code']]) {
  const config=resolve(dir,`${name}-private.json`);
  writeFileSync(config,JSON.stringify({origin,token:s.token,provider,permissionsEnabled:false,development:origin.startsWith('http:')},null,2),{mode:0o600});
  const command=`node "${resolve(root,'hooks/agent-hook.mjs')}" "${config}"`;
  const events=['SessionStart','UserPromptSubmit','PreToolUse','PostToolUse','PermissionRequest','Stop','SessionEnd'];
  const hooks=Object.fromEntries(events.map(event=>[event,[{hooks:[{type:'command',command,timeout:event==='PermissionRequest'?130:8}]}]]));
  writeFileSync(resolve(dir,`${name}-hooks-REVIEW.json`),JSON.stringify({hooks},null,2));
}
console.log(`Private hook examples saved to generated/. They have NOT been installed or enabled.\nPermission answering is OFF until you complete real iPhone tests.\nOpen the signed iPhone app and paste:\n${origin}\nInvitation (expires in 5 minutes): ${invitation.invite}\nDo not send generated/ or .data/ to anyone.`);
