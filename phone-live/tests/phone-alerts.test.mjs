import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {Store} from '../relay/store.mjs';
import {createApp} from '../relay/app.mjs';
import {WebPushDelivery} from '../relay/web-push.mjs';
import {digest} from '../relay/security.mjs';
import {decisionText} from '../relay/desktop.mjs';
import {authenticator,registration,assertion,sha} from './webauthn-fixture.mjs';
async function fixture(run){
 let now=Date.now(),sequence=0;const origin='https://phone.example.test',admin='test-admin-'.repeat(5),store=new Store(':memory:',randomBytes(32)),sent=[];let sender=async(s,p,o)=>{sent.push({subscription:s,payload:JSON.parse(p),options:o});};
 const delivery=new WebPushDelivery({store,origin,clock:()=>now,send:(...a)=>sender(...a)}),server=createApp({store,adminKey:admin,browserOrigin:origin,webPush:delivery,clock:()=>now,push:{configured:false,async send(){return {};}}}).app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const base='http://127.0.0.1:'+server.address().port;
 async function call(path,token,body,method=body?'POST':'GET'){const r=await fetch(base+path,{method,headers:{...(path.startsWith('/web/')?{Origin:origin}:{}),...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});return {status:r.status,body:await r.json()};}
 const source=(await call('/admin/desktop',admin,{name:'Fixture PC'})).body,instance=randomUUID();await call('/desktop/session',source.token,{instance});
 const sync=(request=null,away=false,tasks=[],reviewWaiting=false)=>call('/desktop/sync',source.token,{instance,sequence:++sequence,tasks,request,allowRequests:true,reviewWaiting,acks:[],presence:{away,idleSeconds:away?100:0}});await sync();
 const key=authenticator(),invite=(await call('/desktop/invite',source.token,{})).body,start=(await call('/web/pair/options',null,{invite:invite.invite,name:'Test phone'})).body,phone=(await call('/web/pair/verify',null,{id:start.id,response:registration(key,start.options,origin)})).body;
 await call('/desktop/phones/'+phone.deviceId+'/trust',source.token,{fingerprint:phone.fingerprint});
 const subscription={endpoint:'https://web.push.apple.com/synthetic-test',expirationTime:null,keys:{p256dh:Buffer.from(key.raw,'base64').toString('base64url'),auth:randomBytes(16).toString('base64url')}};
 const subscribe=()=>call('/web/push/subscribe',phone.token,{subscription,awayOnly:true,activity:true});
 const flush=()=>Promise.all([...delivery.queues.values()].map(q=>q.promise));
 const request=(kind='question')=>{const reviewText='ChatGPT\nSynthetic private question XYZ_PRIVATE\n\n0: First\n1: Second';return {id:randomUUID(),nativeId:randomUUID(),provider:'ChatGPT',kind,reviewText,revision:digest(reviewText),choices:kind==='question'?['First','Second']:[],canReply:kind==='question',handoff:true};};
 async function sign(r,decision,answer){const d=(await call('/web/request/'+r.id,phone.token)).body,b={revision:r.revision,decision,nonce:randomUUID(),expiresAt:d.expiresAt,...(answer!==undefined?{answer}:{})};b.response=assertion(key,sha(decisionText(phone.deviceId,r,b)).toString('base64url'),origin,{counter:0});return b;}
 try{await run({store,origin,key,phone,source,sent,call,sync,subscription,subscribe,flush,request,sign,advance:ms=>now+=ms,setSender:fn=>sender=fn});}finally{await new Promise(r=>server.close(r));store.close();}
}
test('notification subscriptions require the trusted phone and reject internal or unapproved destinations',()=>fixture(async f=>{
 assert.equal((await f.call('/web/push/subscribe',f.source.token,{subscription:f.subscription,awayOnly:true,activity:true})).status,401);
 for(const endpoint of ['http://127.0.0.1/private','https://localhost/test','https://web.push.apple.com.evil.test/test','https://web.push.apple.com:444/test'])assert.equal((await f.call('/web/push/subscribe',f.phone.token,{subscription:{...f.subscription,endpoint},awayOnly:true,activity:true})).status,400);
 assert.equal((await f.subscribe()).status,200);assert.equal((await f.call('/web/push/config',f.phone.token)).body.enabled,true);
}));
test('project notifications wait for PC absence, are deduplicated, and expose no transcript or action text',()=>fixture(async f=>{
 await f.subscribe();const tasks=[{id:'task',provider:'ChatGPT',state:'working',title:'Secret project name',detail:'Private message text'}];
 await f.sync(null,false,tasks);await f.flush();assert.equal(f.sent.length,0);
 await f.sync(null,true,tasks);await f.flush();assert.equal(f.sent.length,1);assert.equal(f.sent[0].payload.web_push,8030);assert.doesNotMatch(JSON.stringify(f.sent[0].payload),/Secret project|Private message/);
 await f.sync(null,true,tasks);await f.flush();assert.equal(f.sent.length,1);
 const state=(await f.call('/web/state',f.phone.token)).body;assert.equal(state.summary.projects[0].project,'Secret project name');assert.equal(state.summary.projects[0].step,'Working');
}));
test('a timed handoff can alert even if PC input is recent, but foreground Orby suppresses duplicate alerts',()=>fixture(async f=>{
 await f.subscribe();await f.call('/web/state',f.phone.token);const r=f.request();await f.sync(r,false);await f.flush();assert.equal(f.sent.length,0);
 f.advance(9000);await f.sync(r,false);await f.flush();assert.equal(f.sent.length,1);assert.equal(f.sent[0].payload.requestId,r.id);assert.doesNotMatch(JSON.stringify(f.sent[0].payload),/XYZ_PRIVATE|Synthetic private/);assert(f.sent[0].options.TTL<=120);
}));
test('dead subscriptions are removed and slow delivery cannot restore a revoked phone',()=>fixture(async f=>{
 await f.subscribe();f.setSender(async()=>{throw {statusCode:410};});await f.sync(f.request(),true);await f.flush();assert.equal(f.store.get('d-phone',f.phone.deviceId).pushSubscription,undefined);
 await f.subscribe();let finish;f.setSender(()=>new Promise(r=>finish=r));await f.sync(f.request(),true);await new Promise(r=>setImmediate(r));assert.equal(typeof finish,'function');await f.call('/desktop/phones/'+f.phone.deviceId,f.source.token,null,'DELETE');finish();await f.flush();assert.equal(f.store.get('d-phone',f.phone.deviceId),null);
}));
test('question choices and dictated responses are signed exactly and cannot act as permission approvals',()=>fixture(async f=>{
 let r=f.request();await f.sync(r);assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,await f.sign(r,'allow'))).status,400);
 const choice=await f.sign(r,'choice:1');assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,choice)).status,200);assert.equal((await f.sync(r)).body.decisions[0].decision,'choice:1');
 r=f.request();await f.sync(r);const answer='A dictated response ✓',b=await f.sign(r,'reply:'+digest(answer),answer);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,{...b,answer:'Changed after signing'})).status,400);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,b)).status,200);assert.equal((await f.sync(r)).body.decisions[0].answer,answer);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,b)).status,409);
}));
test('expired handoff links open a freshly verified version of the same question, never reuse an old signature',()=>fixture(async f=>{
 const r=f.request();await f.sync(r);const old=await f.sign(r,'choice:0');f.advance(121000);const next={...r,id:randomUUID()};await f.sync(next);
 const current=(await f.call('/web/request/'+r.id,f.phone.token)).body;assert.equal(current.id,next.id);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,old)).status,409);
}));
test('Stop is a separate explicit action and is never advertised as an approval notification',()=>fixture(async f=>{
 await f.subscribe();const r={...f.request('stop'),handoff:false};await f.sync(r,true);await f.flush();assert.equal(f.sent.length,0);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,await f.sign(r,'allow'))).status,400);
 assert.equal((await f.call('/web/request/'+r.id+'/decision',f.phone.token,await f.sign(r,'stop'))).status,200);assert.equal((await f.sync(r)).body.decisions[0].decision,'stop');
}));
test('service worker always shows a visible alert and a tap only opens the exact review; it never approves',async()=>{
 const events={},shown=[],opened=[],pending=[];let calls=0;
 const sandbox={URL,Date,self:{location:{origin:'https://phone.example.test'},addEventListener:(name,fn)=>events[name]=fn,registration:{showNotification:async(title,o)=>shown.push({title,...o})},clients:{matchAll:async()=>[],openWindow:async url=>opened.push(url)}},fetch:()=>{calls++;throw Error('No background approval is allowed');}};
 vm.runInNewContext(readFileSync(new URL('../web/sw.js',import.meta.url),'utf8'),sandbox);
 const id=randomUUID();events.push({data:{json:()=>({kind:'request',requestId:id,expiresAt:Date.now()/1000+60,notification:{title:'Review request',body:'Open Orby'}})},waitUntil:p=>pending.push(p)});await Promise.all(pending);
 assert.equal(shown.length,1);events.notificationclick({notification:{data:{requestId:id},close(){}},waitUntil:p=>pending.push(p)});await Promise.all(pending);assert.equal(opened[0],'https://phone.example.test/iphone/home.html#request='+id);assert.equal(calls,0);
});


test('PC question countdown suppresses premature activity alerts and only its handoff sends an actionable notification',()=>fixture(async f=>{
 await f.subscribe();const tasks=[{id:'question-task',provider:'ChatGPT',state:'working',title:'Private question context',detail:'Waiting'}];
 await f.sync(null,true,tasks,true);await f.flush();assert.equal(f.sent.length,0);
 const state=(await f.call('/web/state',f.phone.token)).body;assert.equal(state.summary.reviewWaiting,true);assert.equal(state.requests.length,0);
 f.advance(301000);const r=f.request();await f.sync(r,true,tasks,true);await f.flush();assert.equal(f.sent.length,1);assert.equal(f.sent[0].payload.kind,'request');assert.equal(f.sent[0].payload.requestId,r.id);
}));
test('attention without an actionable phone question never masquerades as a project-running alert',()=>fixture(async f=>{
 await f.subscribe();await f.sync(null,true,[{id:'attention-task',provider:'ChatGPT',state:'attention',title:'Question',detail:'Waiting for input'}]);await f.flush();assert.equal(f.sent.length,0);
}));
