import {randomUUID,createHash} from 'node:crypto';
import {z} from 'zod';
import {verifyAuthenticationResponse} from '@simplewebauthn/server';
import {decisionText} from './desktop.mjs';
import {digest,fail} from './security.mjs';

// Diagnostic records are separate from permission requests and are never sent
// to the Windows approval worker. A test denial cannot authorize any tool.
export function mountConnectionChecks(app,{store,desktop,origin,clock,wrap,phone,topLevel}){
 const pcWrap=fn=>(req,res,next)=>Promise.resolve().then(()=>fn(req,res)).catch(next);
 function prune(){for(const c of store.all('d-check'))if(c.expires<clock())store.remove('d-check',c.id);}
 function current(id,sourceId){prune();const c=store.get('d-check',id),l=store.get('d-link',sourceId);fail(c&&c.sourceId===sourceId&&desktop.online(l)&&c.instance===l.instance,409,'Connection test expired or PC offline');return c;}
 app.post('/desktop/connection-check',pcWrap((req,res)=>{
  const s=desktop.source(req),l=store.get('d-link',s.id);fail(desktop.online(l),409,'PC feed is offline');
  fail(store.all('d-phone').some(p=>p.sourceId===s.id&&p.active&&p.mode==='web'),409,'Confirm a browser phone first');prune();
  for(const c of store.all('d-check').filter(c=>c.sourceId===s.id))store.remove('d-check',c.id);
  const reviewText='Orby connection test only.\n\nDeny this test to check the phone passkey and Windows signature verification. No command will run. No app, internet, file or computer access will be granted or changed.';
  const c={id:randomUUID(),sourceId:s.id,instance:l.instance,reviewText,revision:digest(reviewText),status:'pending',expires:clock()+120000};store.put('d-check',c.id,c);res.status(201).json({id:c.id,expiresAt:Math.floor(c.expires/1000)});
 }));
 app.get('/desktop/connection-check/:id',pcWrap((req,res)=>{const s=desktop.source(req),c=current(req.params.id,s.id);res.json({id:c.id,revision:c.revision,status:c.status,signed:c.signed||null});}));
 app.post('/desktop/connection-check/:id/ack',pcWrap((req,res)=>{const s=desktop.source(req),c=current(req.params.id,s.id),b=z.object({result:z.enum(['verified','failed'])}).strict().parse(req.body);fail(c.status==='decided'&&c.signed,409,'No signed test is waiting');store.put('d-check',c.id,{...c,status:b.result,signed:undefined});res.json({recorded:true});}));
 app.get('/web/check/:id',wrap((req,res)=>{const p=phone(req),c=current(req.params.id,p.sourceId);res.json({id:c.id,revision:c.revision,reviewText:c.reviewText,status:c.status,expiresAt:Math.floor(c.expires/1000),credentialId:p.credential.id});}));
 app.post('/web/check/:id/decision',wrap(async(req,res)=>{
  const p=phone(req),b=z.object({revision:z.string().regex(/^[a-f0-9]{64}$/),decision:z.literal('deny'),nonce:z.string().uuid(),expiresAt:z.number().int(),response:z.unknown()}).strict().parse(req.body);
  function pending(){const c=current(req.params.id,p.sourceId),fresh=store.get('d-phone',p.id);fail(fresh?.active&&c.status==='pending'&&b.revision===c.revision&&b.expiresAt===Math.floor(c.expires/1000)&&digest(c.reviewText)===c.revision,409,'Connection test is no longer current');return c;}
  let c=pending();topLevel(b.response);let verified;
  try{verified=await verifyAuthenticationResponse({response:b.response,expectedOrigin:origin,expectedRPID:new URL(origin).hostname,expectedChallenge:createHash('sha256').update(decisionText(p.id,c,b)).digest('base64url'),requireUserVerification:true,credential:{...p.credential,publicKey:new Uint8Array(Buffer.from(p.credential.publicKey,'base64'))}});}catch{fail(false,403,'Phone screen-lock signature did not verify');}
  fail(verified.verified,403,'Phone signature did not verify');c=pending();
  const r=b.response.response;store.put('d-check',c.id,{...c,status:'decided',signed:{id:c.id,deviceId:p.id,revision:c.revision,decision:'deny',nonce:b.nonce,expiresAt:b.expiresAt,method:'webauthn',signature:Buffer.from(r.signature,'base64url').toString('base64'),clientDataJSON:r.clientDataJSON,authenticatorData:r.authenticatorData}});
  const fresh=store.get('d-phone',p.id);store.put('d-phone',p.id,{...fresh,credential:{...fresh.credential,counter:verified.authenticationInfo.newCounter}});res.json({recorded:true});
 }));
 return sourceId=>{prune();const l=store.get('d-link',sourceId);return desktop.online(l)?store.all('d-check').filter(c=>c.sourceId===sourceId&&c.instance===l.instance).map(c=>({id:c.id,reviewText:c.reviewText,status:c.status})):[];};
}
