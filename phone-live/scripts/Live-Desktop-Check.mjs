import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {randomUUID,generateKeyPairSync,sign} from 'node:crypto';
import assert from 'node:assert/strict';
import {digest} from '../relay/security.mjs';
import {decisionText} from '../relay/desktop.mjs';
const privateDirectory=fileURLToPath(new URL('../.desktop-data',import.meta.url));
const origin=JSON.parse(readFileSync(privateDirectory+'/running.json','utf8').replace(/^\uFEFF/,'')).Origin;
const helper=process.argv[2];if(!helper)throw new Error('Pass the tested Windows Phone-Link.cs path');
const child=spawn('powershell.exe',['-NoProfile','-NonInteractive','-File',fileURLToPath(new URL('./PC-TestPipe.ps1',import.meta.url)),'-Helper',helper,'-PrivateDirectory',privateDirectory],{stdio:['pipe','pipe','pipe']});
let pending;const lines=createInterface({input:child.stdout});lines.on('line',line=>{if(pending){const p=pending;pending=undefined;try{const r=JSON.parse(line);if(r.pipeError)p.reject(new Error(r.pipeError));else p.resolve(r);}catch{p.reject(new Error('Invalid PC test response'));}}});
async function pc(path,body,method=body?'POST':'GET'){assert.equal(pending,undefined);return new Promise((resolve,reject)=>{const timer=setTimeout(()=>{pending=undefined;reject(new Error('PC HTTPS test timed out'));},20000);pending={resolve:r=>{clearTimeout(timer);resolve(r);},reject:e=>{clearTimeout(timer);reject(e);}};child.stdin.write(JSON.stringify({path,body,method})+'\n');});}
async function mobile(path,credential,body,method=body?'POST':'GET'){const r=await fetch(origin+path,{method,headers:{...(credential?{Authorization:'Bearer '+credential}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,redirect:'error',signal:AbortSignal.timeout(15000)});assert(r.ok,'Phone HTTPS endpoint failed: '+r.status);return r.json();}
const instance=randomUUID();let sequence=0,phone;
const sync=(request=null,allowRequests=false,acks=[],tasks=[])=>pc('/desktop/sync',{instance,sequence:++sequence,request,allowRequests,acks,tasks});
try{
 assert.equal((await pc('/desktop/phones')).phones.length,0,'Live check only runs before real phones are paired');
 await pc('/desktop/session',{instance});const invitation=await pc('/desktop/invite',{});
 const keys=generateKeyPairSync('ec',{namedCurve:'prime256v1'}),j=keys.publicKey.export({format:'jwk'});const publicKey=Buffer.concat([Buffer.from([4]),Buffer.from(j.x,'base64url'),Buffer.from(j.y,'base64url')]).toString('base64');
 phone=await mobile('/mobile/pair',null,{invite:invitation.invite,name:'Synthetic connection check',publicKey});
 assert.equal((await mobile('/mobile/state',phone.token)).active,false);
 await pc('/desktop/phones/'+phone.deviceId+'/trust',{fingerprint:phone.fingerprint});
 const reviewText='ChatGPT\nConnection test only\n\nSynthetic permission; no real action is executed';const request={id:randomUUID(),nativeId:'synthetic-native-'+randomUUID(),provider:'ChatGPT',reviewText,revision:digest(reviewText)};
 await sync(request,true,[],['ChatGPT','Claude','Gemini'].map(provider=>({id:provider,provider,title:'Synthetic connection check',detail:'Not a real task',state:'working'})));
 const feed=await mobile('/mobile/state',phone.token);assert.equal(feed.tasks.length,3);
 const detail=await mobile('/mobile/request/'+request.id,phone.token);assert.equal(detail.reviewText,reviewText);
 const b={revision:request.revision,decision:'deny',nonce:randomUUID(),expiresAt:detail.expiresAt};b.signature=sign('sha256',Buffer.from(decisionText(phone.deviceId,request,b)),keys.privateKey).toString('base64');
 await mobile('/mobile/request/'+request.id+'/decision',phone.token,b);const reply=await sync(request,true);assert.equal(reply.decisions[0].decision,'deny');
 await sync(null,false,[{id:request.id,result:'resolved'}]);assert.equal((await mobile('/mobile/request/'+request.id,phone.token)).status,'resolved');
 console.log('PASS: public HTTPS PC client and simulated phone paired, shared all three task contexts, returned one signed denial and received PC acknowledgement. No native phone or real permission was used.');
}finally{
 if(phone)await pc('/desktop/phones/'+phone.deviceId,null,'DELETE').catch(()=>{});
 await sync().catch(()=>{});child.stdin.end();lines.close();
}
