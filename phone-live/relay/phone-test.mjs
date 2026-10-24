import {randomUUID,createHash} from 'node:crypto';
import {z} from 'zod';
import {verifyAuthenticationResponse} from '@simplewebauthn/server';
import {digest,fail} from './security.mjs';
import {decisionText} from './desktop.mjs';

// Tests have their own records and endpoints. They never enter the PC request
// queue, carry a native control ID, or produce a command/permission decision.
export function mountPhoneTests(app,{store,desktop,origin,clock,wrap,phone,topLevel,delivery}){
 const pcWrap=fn=>(req,res,next)=>Promise.resolve().then(()=>fn(req,res)).catch(next);
 const choices=['Allow once — test only','Deny access — test only','Stop a task — test only','Open an app — test only','Allow network access — test only'];
 function prune(){for(const t of store.all('d-phone-test'))if(t.expires<=clock())store.remove('d-phone-test',t.id);}
 function current(id,sourceId){prune();const t=store.get('d-phone-test',id),l=store.get('d-link',sourceId);fail(t&&t.sourceId===sourceId&&desktop.online(l)&&t.instance===l.instance,409,'Phone test expired or PC offline');return t;}
 app.post('/desktop/phone-test',pcWrap((req,res)=>{
  const s=desktop.source(req),link=store.get('d-link',s.id),{delaySeconds}=z.object({delaySeconds:z.number().int().min(0).max(15).default(8)}).strict().parse(req.body||{});
  fail(desktop.online(link),409,'PC feed is offline');const phones=store.all('d-phone').filter(p=>p.sourceId===s.id&&p.active&&p.mode==='web');fail(phones.length,409,'Confirm a phone first');
  const previous=store.all('d-phone-test').find(t=>t.sourceId===s.id&&t.created>clock()-15000);fail(!previous,429,'Wait a moment before starting another test');
  const reviewText='PHONE-ONLY POLL — NO ACTION WILL RUN\n\nWhich phone response would you like to test?\n\n'+choices.map((c,i)=>(i+1)+'. '+c).join('\n')+'\n\nThis poll is sent directly to your phone for testing, without the normal five-minute PC countdown. Every choice only records your reply. No app opens, task stops, network permission changes, or phone locks/resets. Confirm this one test response with your passkey.';
  const t={id:randomUUID(),sourceId:s.id,instance:link.instance,reviewText,revision:digest(reviewText),choices,status:'pending',created:clock(),expires:clock()+600000,delivery:[]};store.put('d-phone-test',t.id,t);
  const targets=phones.filter(p=>p.pushSubscription&&p.pushOrigin===origin);
  const send=async()=>{const test=store.get('d-phone-test',t.id),live=store.get('d-link',s.id);if(!test||test.status!=='pending'||test.expires<=clock()||!desktop.online(live)||live.instance!==t.instance)return;const result=[];for(const p of targets){try{const payload={kind:'phone-test',testId:t.id,expiresAt:Math.floor(t.expires/1000),notification:{title:'Orby phone test · Your choice',body:'Allow, deny or choose another test response. No action will run. Tap to open the poll.',navigate:origin+'/iphone/home.html#test='+t.id,tag:'orby-phone-test-'+t.id}};result.push({deviceId:p.id,...await delivery.deliver(p,payload)});}catch{result.push({deviceId:p.id,status:'failed'});}}const fresh=store.get('d-phone-test',t.id);if(fresh)store.put('d-phone-test',t.id,{...fresh,delivery:result});};
  if(delivery&&targets.length){const timer=setTimeout(()=>{send().catch(()=>{});},delaySeconds*1000);timer.unref();}
  res.status(201).json({id:t.id,expiresAt:Math.floor(t.expires/1000),notification:delivery&&targets.length?'queued':'not-enabled',delaySeconds,actionsWillRun:false});
 }));
 app.get('/desktop/phone-test/:id',pcWrap((req,res)=>{const s=desktop.source(req),t=current(req.params.id,s.id);res.json({id:t.id,revision:t.revision,status:t.status,choices:t.choices,answer:t.answer??null,signed:t.signed||null,delivery:t.delivery});}));
 app.post('/desktop/phone-test/:id/ack',pcWrap((req,res)=>{const s=desktop.source(req),t=current(req.params.id,s.id),b=z.object({result:z.enum(['verified','failed'])}).strict().parse(req.body);fail(t.status==='decided'&&t.signed,409,'No signed test response is waiting');store.put('d-phone-test',t.id,{...t,status:b.result,signed:undefined});res.json({recorded:true,actionsWillRun:false});}));
 app.get('/web/phone-test/:id',wrap((req,res)=>{const p=phone(req),t=current(req.params.id,p.sourceId);res.json({id:t.id,reviewText:t.reviewText,revision:t.revision,status:t.status,choices:t.choices,answer:t.answer??null,expiresAt:Math.floor(t.expires/1000),credentialId:p.credential.id});}));
 app.post('/web/phone-test/:id/decision',wrap(async(req,res)=>{
  const p=phone(req),b=z.object({revision:z.string().regex(/^[a-f0-9]{64}$/),decision:z.string().regex(/^choice:[0-4]$/),nonce:z.string().uuid(),expiresAt:z.number().int(),response:z.unknown()}).strict().parse(req.body);
  function pending(){const t=current(req.params.id,p.sourceId),fresh=store.get('d-phone',p.id);fail(fresh?.active&&t.status==='pending'&&t.revision===b.revision&&digest(t.reviewText)===b.revision&&Math.floor(t.expires/1000)===b.expiresAt,409,'Phone test changed or was already answered');return t;}
  let t=pending();topLevel(b.response);let result;
  try{result=await verifyAuthenticationResponse({response:b.response,expectedOrigin:origin,expectedRPID:new URL(origin).hostname,expectedChallenge:createHash('sha256').update(decisionText(p.id,t,b)).digest('base64url'),requireUserVerification:true,credential:{...p.credential,publicKey:new Uint8Array(Buffer.from(p.credential.publicKey,'base64'))}});}catch{fail(false,403,'Phone test passkey did not verify');}fail(result.verified,403,'Phone test signature did not verify');t=pending();
  const r=b.response.response;store.put('d-phone-test',t.id,{...t,status:'decided',answer:Number(b.decision.slice(7)),signed:{id:t.id,deviceId:p.id,revision:t.revision,decision:b.decision,nonce:b.nonce,expiresAt:b.expiresAt,method:'webauthn',signature:Buffer.from(r.signature,'base64url').toString('base64'),clientDataJSON:r.clientDataJSON,authenticatorData:r.authenticatorData}});const fresh=store.get('d-phone',p.id);store.put('d-phone',p.id,{...fresh,credential:{...fresh.credential,counter:result.authenticationInfo.newCounter}});res.json({recorded:true,actionsWillRun:false});
 }));
 return sourceId=>{prune();const l=store.get('d-link',sourceId);return desktop.online(l)?store.all('d-phone-test').filter(t=>t.sourceId===sourceId&&t.instance===l.instance).map(t=>({id:t.id,status:t.status})):[];};
}
