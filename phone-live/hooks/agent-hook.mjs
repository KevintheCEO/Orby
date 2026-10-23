// Command-hook adapter. stdout is reserved for the provider's JSON contract.
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { safeOrigin } from '../relay/security.mjs';

export async function runHook(event, config, {fetcher=fetch,sleep=ms=>new Promise(r=>setTimeout(r,ms)),deadline=Date.now()+115000}={}) {
  const origin=safeOrigin(config.origin,{development:config.development===true});
  if(!['Codex','Claude Code'].includes(config.provider))return {};
  const call=async(path,body,method=body?'POST':'GET')=>{
    const r=await fetcher(origin+path,{method,redirect:'error',headers:{authorization:`Bearer ${config.token}`,...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(5000)});
    if(!r.ok)throw new Error(`Relay ${r.status}`);return r.json();
  };
  const type=event.hook_event_name;
  if(type!=='PermissionRequest') {
    const phases={SessionStart:'ready',UserPromptSubmit:'working',PreToolUse:'tool',PostToolUse:'working',Stop:'ready',SessionEnd:'closed',Interrupt:'ready'};
    const phase=phases[type];if(!phase)return {};
    const text={ready:'Ready',working:'Working on your request',tool:'Using a tool',closed:'Session closed'}[phase];
    try{await call('/source/status',{provider:config.provider,phase,text});}catch{}
    return {};
  }
  if(config.permissionsEnabled!==true)return {};
  const input=event.tool_input;
  const serialized=JSON.stringify(input);
  // Never shorten an action then approve the unseen part. Sensitive/large actions stay local.
  if(!serialized||Buffer.byteLength(serialized)>8192||/-----BEGIN .*PRIVATE KEY|(?:sk-[a-zA-Z0-9_-]{20,})|(?:authorization\s*[:=]\s*["']?bearer\s+\S+)/i.test(serialized))return {};
  let request;
  try {
    request=await call('/source/request',{invocation:randomUUID(),provider:config.provider,session:String(event.session_id||'unknown'),tool:String(event.tool_name||'Unknown tool'),input});
    while(Date.now()<Math.min(deadline,request.expiresAt)) {
      const state=await call(`/source/request/${request.id}`);
      if(state.status==='decided') {
        const result=await call(`/source/request/${request.id}/consume`,{});
        if(result.revision!==request.revision||!['allow','deny'].includes(result.decision))break;
        return {hookSpecificOutput:{hookEventName:'PermissionRequest',decision:{behavior:result.decision,...(result.decision==='deny'?{message:'Denied on the paired phone.'}:{})}}};
      }
      if(state.status!=='pending')break;
      await sleep(1000);
    }
  }catch{}
  if(request)try{await call(`/source/request/${request.id}`,undefined,'DELETE');}catch{}
  return {};
}

if(process.argv[1]&&new URL(import.meta.url).pathname.toLowerCase().endsWith(process.argv[1].replaceAll('\\','/').split('/').pop().toLowerCase())) {
  try {
    const chunks=[];let size=0;
    for await(const chunk of process.stdin){size+=chunk.length;if(size>20000)throw new Error('Hook payload too large');chunks.push(chunk);}
    const config=JSON.parse(readFileSync(process.argv[2],'utf8'));
    const output=await runHook(JSON.parse(Buffer.concat(chunks).toString('utf8')),config);
    process.stdout.write(JSON.stringify(output));
  }catch{process.stdout.write('{}');}
}
