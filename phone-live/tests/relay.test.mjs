import { test,after,before } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes,randomUUID } from 'node:crypto';
import { readFileSync,mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Store } from '../relay/store.mjs';
import { createApp } from '../relay/app.mjs';
import { runHook } from '../hooks/agent-hook.mjs';

let server,base,store,now=Date.now(),source,phone,invitation;
const admin='administrator'.repeat(4),key=randomBytes(32),pushes=[];
const dir=mkdtempSync(join(tmpdir(),'orby-live-test-')),db=join(dir,'live.sqlite');
async function call(path,credential,body,method=body?'POST':'GET') {
  const response=await fetch(base+path,{method,headers:{...(credential?{authorization:`Bearer ${credential}`} :{}),...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});
  return {code:response.status,body:await response.json()};
}
const event=()=>({invocation:randomUUID(),provider:'Codex',session:'test-session',tool:'Bash',input:{command:'echo permission-test-only'}});
before(async()=>{
  store=new Store(db,key);
  const api=createApp({store,adminKey:admin,clock:()=>now,push:{configured:true,async send(token,state){pushes.push({token,state});return {status:'accepted'};}}});
  server=api.app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));base=`http://127.0.0.1:${server.address().port}`;
});
after(async()=>{await new Promise(r=>server.close(r));store.close();});
test('public endpoint contains no credentials and admin creation requires a secret',async()=>{
  assert.equal((await call('/health')).body.pushConfigured,true);
  assert.equal((await call('/admin/source',null,{name:'attacker'})).code,401);
  source=(await call('/admin/source',admin,{name:'Test AI'})).body;
  assert.ok(source.token.length>=32);
});
test('single-use native phone invitation and strict role separation',async()=>{
  invitation=(await call('/source/invite',source.token,{})).body.invite;
  phone=(await call('/phone/pair',null,{invite:invitation})).body;
  assert.equal((await call('/phone/pair',null,{invite:invitation})).code,401);
  assert.equal((await call('/phone/state',source.token)).code,401);
  assert.equal((await call('/source/request',phone.token,event())).code,401);
});
test('request details are exact and the lock-screen payload contains no private input',async()=>{
  await call('/phone/activity',phone.token,{token:'a'.repeat(64)});
  const b=event();b.input.command='echo private-test-content';
  const r=await call('/source/request',source.token,b);assert.equal(r.code,201);
  const d=await call(`/phone/request/${r.body.id}`,phone.token);assert.deepEqual(d.body.input,b.input);
  const latest=JSON.stringify(pushes.at(-1));assert.ok(!latest.includes('private-test-content'));assert.ok(!latest.includes(phone.token));
  await call(`/source/request/${r.body.id}`,source.token,undefined,'DELETE');
});
test('phone can decide only current revision, and source consumes the decision once',async()=>{
  const r=(await call('/source/request',source.token,event())).body;
  assert.equal((await call(`/phone/request/${r.id}/decision`,source.token,{revision:r.revision,decision:'allow'})).code,401);
  assert.equal((await call(`/phone/request/${r.id}/decision`,phone.token,{revision:'0'.repeat(64),decision:'allow'})).code,409);
  assert.equal((await call(`/phone/request/${r.id}/decision`,phone.token,{revision:r.revision,decision:'allow'})).code,200);
  assert.equal((await call(`/phone/request/${r.id}/decision`,phone.token,{revision:r.revision,decision:'allow'})).code,409);
  assert.equal((await call(`/source/request/${r.id}/consume`,source.token,{})).body.decision,'allow');
  assert.equal((await call(`/source/request/${r.id}/consume`,source.token,{})).code,409);
});
test('expiration, cancellation and invocation replay never grant approval',async()=>{
  const e=event(),r=(await call('/source/request',source.token,e)).body;
  assert.equal((await call('/source/request',source.token,e)).code,409);
  now+=121000;
  assert.equal((await call(`/phone/request/${r.id}/decision`,phone.token,{revision:r.revision,decision:'allow'})).code,409);
  const c=(await call('/source/request',source.token,event())).body;
  await call(`/source/request/${c.id}`,source.token,undefined,'DELETE');
  assert.equal((await call(`/phone/request/${c.id}/decision`,phone.token,{revision:c.revision,decision:'allow'})).code,409);
});
test('concurrent requests queue and routine status cannot hide a pending request',async()=>{
  const a=(await call('/source/request',source.token,event())).body;
  now+=1;const b=(await call('/source/request',source.token,event())).body;
  await call('/source/status',source.token,{provider:'Claude Code',phase:'ready',text:'Ready'});
  const s=(await call('/phone/state',phone.token)).body;assert.equal(s.requestId,a.id);assert.equal(s.pendingCount,2);
  await call(`/source/request/${a.id}`,source.token,undefined,'DELETE');
  assert.equal((await call('/phone/state',phone.token)).body.requestId,b.id);
  await call(`/source/request/${b.id}`,source.token,undefined,'DELETE');
});
test('a different AI source and phone cannot read or decide this source requests',async()=>{
  const s2=(await call('/admin/source',admin,{name:'Other AI'})).body;
  const i2=(await call('/source/invite',s2.token,{})).body;
  const p2=(await call('/phone/pair',null,{invite:i2.invite})).body;
  const r=(await call('/source/request',source.token,event())).body;
  assert.equal((await call(`/phone/request/${r.id}`,p2.token)).code,404);
  assert.equal((await call(`/source/request/${r.id}/consume`,s2.token,{})).code,404);
  await call(`/source/request/${r.id}`,source.token,undefined,'DELETE');
});
test('native-only API rejects browser origins and malformed/oversize actions',async()=>{
  const r=await fetch(base+'/phone/state',{headers:{origin:'https://evil.example',authorization:`Bearer ${phone.token}`}});assert.equal(r.status,403);
  const b=event();b.input={command:'x'.repeat(9000)};
  assert.equal((await call('/source/request',source.token,b)).code,413);
  assert.equal((await call('/source/status',source.token,{provider:'Gemini',phase:'ready',text:'Ready'})).code,400);
});
test('database stores details and credentials encrypted',()=>{
  store.db.exec('PRAGMA wal_checkpoint(FULL)');
  const data=readFileSync(db).toString('utf8');
  assert.ok(!data.includes('private-test-content'));assert.ok(!data.includes(source.token));assert.ok(!data.includes('permission-test-only'));
});
test('hook receives real phone decision through HTTP and emits provider allow contract',async()=>{
  const config={origin:base,token:source.token,provider:'Codex',development:true,permissionsEnabled:true};
  const output=await runHook({hook_event_name:'PermissionRequest',session_id:'hook-session',tool_name:'Bash',tool_input:{command:'echo test-only'}},config,{sleep:async()=>{
    const s=(await call('/phone/state',phone.token)).body;
    await call(`/phone/request/${s.requestId}/decision`,phone.token,{revision:s.revision,decision:'allow'});
  }});
  assert.deepEqual(output,{hookSpecificOutput:{hookEventName:'PermissionRequest',decision:{behavior:'allow'}}});
});
test('Claude Code deny uses compatible decision output',async()=>{
  const config={origin:base,token:source.token,provider:'Claude Code',development:true,permissionsEnabled:true};
  const output=await runHook({hook_event_name:'PermissionRequest',session_id:'claude-session',tool_name:'Bash',tool_input:{command:'echo test-only'}},config,{sleep:async()=>{
    const s=(await call('/phone/state',phone.token)).body;
    await call(`/phone/request/${s.requestId}/decision`,phone.token,{revision:s.revision,decision:'deny'});
  }});
  assert.equal(output.hookSpecificOutput.decision.behavior,'deny');
});
test('hook is opt-in; timeout, relay failure and sensitive inputs return no decision',async()=>{
  const e={hook_event_name:'PermissionRequest',session_id:'s',tool_name:'Bash',tool_input:{command:'echo harmless'}};
  const config={origin:base,token:source.token,provider:'Codex',development:true};
  assert.deepEqual(await runHook(e,config),{});
  config.permissionsEnabled=true;
  assert.deepEqual(await runHook(e,config,{deadline:Date.now()-1}),{});
  assert.deepEqual(await runHook(e,config,{fetcher:async()=>{throw new Error('offline');}}),{});
  assert.deepEqual(await runHook({...e,tool_input:{command:'-----BEGIN PRIVATE KEY-----'}},config),{});
});
test('re-pairing revokes old phone; disconnect revokes the new phone',async()=>{
  const invite=(await call('/source/invite',source.token,{})).body;
  const next=(await call('/phone/pair',null,{invite:invite.invite})).body;
  assert.equal((await call('/phone/state',phone.token)).code,401);
  assert.equal((await call('/phone/pair',next.token,undefined,'DELETE')).code,200);
  assert.equal((await call('/phone/state',next.token)).code,401);
});
