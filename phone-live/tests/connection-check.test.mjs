import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID} from 'node:crypto';
import {Store} from '../relay/store.mjs';
import {createApp} from '../relay/app.mjs';
import {decisionText} from '../relay/desktop.mjs';
import {authenticator,registration,assertion,sha} from './webauthn-fixture.mjs';
let store,server,base,source,phone,check,sequence=0;let now=Date.now();const origin='https://phone-check.example.test',admin='connection-test-admin-'.repeat(3),instance=randomUUID(),key=authenticator();
async function call(path,token,body,method=body?'POST':'GET',requestOrigin=path.startsWith('/web/')?origin:null){const r=await fetch(base+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{}),...(requestOrigin?{Origin:requestOrigin}:{})},body:body?JSON.stringify(body):undefined});return {status:r.status,body:await r.json()};}
const sync=()=>call('/desktop/sync',source.token,{instance,sequence:++sequence,tasks:[],request:null,allowRequests:false,acks:[]});
before(async()=>{store=new Store(':memory:',randomBytes(32));server=createApp({store,adminKey:admin,browserOrigin:origin,clock:()=>now,push:{configured:false,async send(){return {};}}}).app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));base='http://127.0.0.1:'+server.address().port;source=(await call('/admin/desktop',admin,{name:'Connection test PC'})).body;await call('/desktop/session',source.token,{instance});await sync();const invite=(await call('/desktop/invite',source.token,{})).body,start=(await call('/web/pair/options',null,{invite:invite.invite,name:'Fixture phone'})).body;phone=(await call('/web/pair/verify',null,{id:start.id,response:registration(key,start.options,origin)})).body;await call('/desktop/phones/'+phone.deviceId+'/trust',source.token,{fingerprint:phone.fingerprint});});
after(async()=>{await new Promise(r=>server.close(r));store.close();});
test('only the PC can create a no-action check; it never enters the permission queue',async()=>{
 assert.equal((await call('/desktop/connection-check',phone.token,{})).status,401);
 assert.equal((await call('/desktop/connection-check',source.token,{},'POST',origin)).status,403);
 check=(await call('/desktop/connection-check',source.token,{})).body;const state=(await call('/web/state',phone.token)).body;
 assert.equal(state.connectionChecks[0].id,check.id);assert.equal(state.requests.length,0);assert.match(state.connectionChecks[0].reviewText,/No command will run/);assert.equal(store.all('d-request').length,0);
});
test('a diagnostic accepts only an exact verified denial, never delivers a native click, and needs PC acknowledgement',async()=>{
 const detail=(await call('/web/check/'+check.id,phone.token)).body,b={revision:detail.revision,decision:'deny',nonce:randomUUID(),expiresAt:detail.expiresAt};b.response=assertion(key,sha(decisionText(phone.deviceId,{id:check.id,revision:b.revision},b)).toString('base64url'),origin);
 assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,{...b,decision:'allow'})).status,400);
 assert.equal((await call('/web/request/'+check.id+'/decision',phone.token,b)).status,409);
 assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,200);
 assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,409);
 assert.equal((await sync()).body.decisions.length,0);assert.equal(store.all('d-request').length,0);
 assert.equal((await call('/desktop/connection-check/'+check.id,phone.token)).status,401);
 const reply=(await call('/desktop/connection-check/'+check.id,source.token)).body;assert.equal(reply.status,'decided');assert.equal(reply.signed.decision,'deny');
 assert.equal((await call('/desktop/connection-check/'+check.id+'/ack',phone.token,{result:'verified'})).status,401);
 assert.equal((await call('/desktop/connection-check/'+check.id+'/ack',source.token,{result:'verified'})).status,200);assert.equal((await call('/web/state',phone.token)).body.connectionChecks[0].status,'verified');
});
test('diagnostic signing rejects missing user verification, an offline PC, expiry and revocation',async()=>{
 check=(await call('/desktop/connection-check',source.token,{})).body;const d=(await call('/web/check/'+check.id,phone.token)).body,b={revision:d.revision,decision:'deny',nonce:randomUUID(),expiresAt:d.expiresAt};b.response=assertion(key,sha(decisionText(phone.deviceId,{id:check.id,revision:b.revision},b)).toString('base64url'),origin,{flags:1,counter:2});
 assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,403);now+=16000;assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,409);await sync();now+=601000;assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,409);await call('/desktop/phones/'+phone.deviceId,source.token,null,'DELETE');assert.equal((await call('/web/check/'+check.id+'/decision',phone.token,b)).status,401);
});
