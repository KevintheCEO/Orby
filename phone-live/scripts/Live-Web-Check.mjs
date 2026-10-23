import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {digest} from '../relay/security.mjs';
import {decisionText} from '../relay/desktop.mjs';
import {authenticator,registration,assertion,sha} from '../tests/webauthn-fixture.mjs';
const privateDirectory=fileURLToPath(new URL('../.desktop-data',import.meta.url));
const origin=JSON.parse(readFileSync(privateDirectory+'/running.json','utf8').replace(/^\uFEFF/,'')).Origin;
const helper=process.argv[2];if(!helper)throw Error('Pass the tested Windows Phone-Link.cs path');
const child=spawn('powershell.exe',['-NoProfile','-NonInteractive','-File',fileURLToPath(new URL('./PC-TestPipe.ps1',import.meta.url)),'-Helper',helper,'-PrivateDirectory',privateDirectory],{stdio:['pipe','pipe','pipe']});
let pending;const lines=createInterface({input:child.stdout});lines.on('line',line=>{if(pending){const p=pending;pending=undefined;try{const r=JSON.parse(line);if(r.pipeError)p.reject(Error(r.pipeError));else p.resolve(r);}catch{p.reject(Error('Invalid PC response'));}}});
function pipe(body){assert.equal(pending,undefined);return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{pending=undefined;reject(Error('PC HTTPS test timed out'));},20000);pending={resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}};child.stdin.write(JSON.stringify(body)+'\n');});}
const pc=(path,body,method=body?'POST':'GET')=>pipe({path,body,method});
async function web(path,credential,body){const r=await fetch(origin+path,{method:body?'POST':'GET',headers:{Origin:origin,...(credential?{Authorization:'Bearer '+credential}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,redirect:'error',signal:AbortSignal.timeout(15000)});assert(r.ok,'Phone HTTPS endpoint failed: '+r.status);return r.json();}
const instance=randomUUID(),key=authenticator();let sequence=0,phone;
const sync=(request=null,allowRequests=false,acks=[],tasks=[])=>pc('/desktop/sync',{instance,sequence:++sequence,request,allowRequests,acks,tasks});
try{
 assert.equal((await pc('/desktop/phones')).phones.length,0,'Run before real phones are paired');
 const page=await fetch(origin+'/iphone/home.html',{signal:AbortSignal.timeout(15000)});assert(page.ok);assert.match(page.headers.get('content-security-policy'),/frame-ancestors 'none'/);
 await pc('/desktop/session',{instance});const invite=await pc('/desktop/invite',{});assert.match(invite.qr,/^data:image\/png;base64,/);assert.equal(invite.phoneUrl,origin+'/iphone/#invite='+invite.invite);
 const start=await web('/web/pair/options',null,{invite:invite.invite,name:'Synthetic web connection check'});phone=await web('/web/pair/verify',null,{id:start.id,response:registration(key,start.options,origin)});
 assert.equal((await web('/web/state',phone.token)).active,false);await pc('/desktop/phones/'+phone.deviceId+'/trust',{fingerprint:phone.fingerprint});
 const reviewText='ChatGPT\nConnection test only\n\nSynthetic permission. No real action is executed.',request={id:randomUUID(),nativeId:'synthetic-web-'+randomUUID(),provider:'ChatGPT',reviewText,revision:digest(reviewText)};
 await sync(request,true,[],['ChatGPT','Claude','Gemini'].map(provider=>({id:provider,provider,title:'Synthetic connection check',detail:'Not a real task',state:'working'})));assert.equal((await web('/web/state',phone.token)).tasks.length,3);
 const detail=await web('/web/request/'+request.id,phone.token);assert.equal(detail.reviewText,reviewText);const b={revision:request.revision,decision:'deny',nonce:randomUUID(),expiresAt:detail.expiresAt};b.response=assertion(key,sha(decisionText(phone.deviceId,request,b)).toString('base64url'),origin);
 await web('/web/request/'+request.id+'/decision',phone.token,b);const delivered=(await sync(request,true)).decisions[0];assert.equal(delivered.method,'webauthn');assert.equal((await pipe({operation:'verifyWeb',publicKey:key.raw,decision:delivered})).verified,true);
 assert.equal((await pipe({operation:'verifyWeb',publicKey:key.raw,decision:{...delivered,decision:'allow'}})).verified,false);
 await sync(null,false,[{id:request.id,result:'resolved'}]);assert.equal((await web('/web/request/'+request.id,phone.token)).status,'resolved');
 console.log('PASS: public HTTPS QR/passkey pairing, pending isolation, three task providers, exact signed denial, independent Windows signature verification and acknowledgement. Synthetic authenticator only; no real permission clicked.');
}finally{if(phone)await pc('/desktop/phones/'+phone.deviceId,null,'DELETE').catch(()=>{});await sync().catch(()=>{});child.stdin.end();lines.close();}
