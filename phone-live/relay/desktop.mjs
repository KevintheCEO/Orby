import { z } from 'zod';
import { randomUUID, createPublicKey, verify } from 'node:crypto';
import { digest, token, fail } from './security.mjs';
import QRCode from 'qrcode';

const id=z.string().uuid(),hash=z.string().regex(/^[a-f0-9]{64}$/);
const provider=z.enum(['ChatGPT','Claude','Gemini']);
const task=z.object({id:z.string().min(1).max(240),provider,state:z.enum(['working','attention','idle','error']),title:z.string().max(240),detail:z.string().max(600)}).strict();
const request=z.object({id,nativeId:z.string().min(1).max(200),provider:z.literal('ChatGPT'),reviewText:z.string().min(1).max(8000),revision:hash}).strict();
const ack=z.object({id,result:z.enum(['submitted','resolved','stale','uncertain'])}).strict();
const sync=z.object({instance:id,sequence:z.number().int().nonnegative(),tasks:z.array(task).max(64),request:request.nullable(),allowRequests:z.boolean(),acks:z.array(ack).max(16)}).strict();
export const fingerprint=key=>digest(Buffer.from(key,'base64')).slice(0,12).toUpperCase();
export function phoneKey(raw){
 const key=Buffer.from(raw,'base64');fail(key.length===65&&key[0]===4,400,'Invalid phone signing key');
 try{return createPublicKey({key:{kty:'EC',crv:'P-256',x:key.subarray(1,33).toString('base64url'),y:key.subarray(33).toString('base64url')},format:'jwk'});}catch{fail(false,400,'Invalid phone signing key');}
}
export function decisionText(deviceId,r,b){return `OrbyPhone.v1\n${deviceId}\n${r.id}\n${r.revision}\n${b.decision}\n${b.nonce}\n${b.expiresAt}`;}

// A separate opt-in desktop protocol. This does not reactivate the withdrawn MCP app.
export function mountDesktop(app,{store,adminKey,push,clock=Date.now,browserOrigin=null}){
 const wrap=fn=>(req,res,next)=>Promise.resolve().then(()=>fn(req,res)).catch(next);
 const bearer=req=>{const value=req.headers.authorization||'';fail(value.startsWith('Bearer '),401,'Authentication required');return digest(value.slice(7));};
 const source=req=>{const s=store.all('d-source').find(x=>x.hash===bearer(req));fail(s,401,'Invalid PC credential');return s;};
 const mobile=(req,active=true)=>{const p=store.all('d-phone').find(x=>x.hash===bearer(req));fail(p,401,'Invalid phone credential');fail(!active||p.active,403,'Confirm this phone on the PC first');return p;};
 function prune(){
  for(const r of store.all('d-request')){if(r.expires<=clock()&&['pending','decided'].includes(r.status))store.put('d-request',r.id,{...r,status:'expired',signed:undefined});if(r.created<clock()-86400000)store.remove('d-request',r.id);}
  for(const i of store.all('d-invite'))if(i.expires<=clock())store.remove('d-invite',i.hash);
  for(const p of store.all('d-phone'))if(!p.active&&p.created<clock()-600000)store.remove('d-phone',p.id);
  for(const n of store.all('d-nonce'))if(n.at<clock()-86400000)store.remove('d-nonce',n.id);
  for(const r of store.all('d-web-reg'))if(r.expires<=clock())store.remove('d-web-reg',r.id);
 }
 const online=link=>!!link&&clock()-link.at<15000;
 function snapshot(sourceId){
  prune();const link=store.get('d-link',sourceId),connected=online(link);
  const requests=connected?store.all('d-request').filter(r=>r.sourceId===sourceId&&r.instance===link.instance&&r.status==='pending'):[];
  return {connected,updatedAt:link?Math.floor(link.at/1000):0,tasks:connected?link.tasks:[],requests:requests.map(r=>({id:r.id,provider:r.provider,revision:r.revision,expiresAt:Math.floor(r.expires/1000),status:r.status})),message:connected?'PC connected':'PC offline or feed out of date'};
 }
 const deliveries=new Map();
 async function publish(sourceId){
  const state=snapshot(sourceId),r=state.requests[0],t=state.tasks.find(t=>t.state==='working');
  // APNs sees generic state only. Task titles and exact request text stay off the lock-screen push.
  const content={provider:r?.provider||t?.provider||'Orby',phase:!state.connected?'closed':r?'review':t?'working':'ready',text:!state.connected?'PC offline':r?'Permission requested':t?'Working on your PC':'All quiet',requestId:r?.id||'',revision:r?.revision||'',expiresAt:r?.expiresAt||0,pendingCount:state.requests.length,updatedAt:Math.floor(clock()/1000)};
  for(const p of store.all('d-phone').filter(p=>p.sourceId===sourceId&&p.active&&p.activityToken)){
   const key=[content.phase,content.provider,content.requestId,content.revision].join(':');const last=deliveries.get(p.id);if(last?.key===key&&clock()-last.at<60000)continue;
   // Apple delivery must never stall a PC heartbeat or permission acknowledgement.
   const pending=(last?.pending||Promise.resolve()).then(async()=>{const current=store.get('d-phone',p.id);if(!current?.active||current.activityToken!==p.activityToken)return;try{const result=await push.send(p.activityToken,content);const fresh=store.get('d-phone',p.id);if(fresh?.active&&fresh.activityToken===p.activityToken)store.put('d-phone',p.id,{...fresh,delivery:result.status,activityToken:result.code===410?null:p.activityToken});}catch{/* Push is separate from feed delivery. */}}).catch(()=>{});
   deliveries.set(p.id,{key,at:clock(),pending});
  }
  return state;
 }
 app.post('/admin/desktop',wrap((req,res)=>{
  fail(bearer(req)===digest(adminKey),401,'Invalid administrator credential');const name=z.string().min(1).max(80).parse(req.body.name),secret=token(),sourceId=randomUUID();
  store.put('d-source',sourceId,{id:sourceId,name,hash:digest(secret)});res.status(201).json({id:sourceId,token:secret});
 }));
 app.post('/desktop/invite',wrap(async(req,res)=>{const s=source(req),invite=token();for(const old of store.all('d-invite').filter(i=>i.sourceId===s.id))store.remove('d-invite',old.hash);store.put('d-invite',digest(invite),{hash:digest(invite),sourceId:s.id,expires:clock()+300000});const phoneUrl=browserOrigin?browserOrigin+'/iphone/#invite='+invite:null;const qr=phoneUrl?await QRCode.toDataURL(phoneUrl,{width:280,margin:3,errorCorrectionLevel:'M'}):null;res.json({invite,expiresAt:Math.floor((clock()+300000)/1000),phoneUrl,qr});}));
 app.post('/desktop/session',wrap((req,res)=>{const s=source(req),instance=id.parse(req.body.instance);fail(!(s.retired||[]).includes(instance),409,'Retired PC instance');if(s.instance!==instance){for(const r of store.all('d-request').filter(r=>r.sourceId===s.id&&['pending','decided'].includes(r.status)))store.put('d-request',r.id,{...r,status:'cancelled',signed:undefined});store.remove('d-link',s.id);store.put('d-source',s.id,{...s,instance,retired:[...(s.retired||[]),...(s.instance?[s.instance]:[])].slice(-128)});}res.json({connected:true});}));
 app.post('/mobile/pair',wrap((req,res)=>{
  const b=z.object({invite:z.string().min(32).max(100),name:z.string().min(1).max(60),publicKey:z.string().max(120)}).strict().parse(req.body);phoneKey(b.publicKey);prune();
  const i=store.get('d-invite',digest(b.invite));fail(i&&i.expires>clock(),401,'Invitation expired or used');store.remove('d-invite',i.hash);
  fail(store.all('d-phone').filter(p=>p.sourceId===i.sourceId).length<4,409,'Revoke an old phone before adding another');
  const secret=token(),p={id:randomUUID(),sourceId:i.sourceId,name:b.name,publicKey:b.publicKey,hash:digest(secret),created:clock(),active:false};store.put('d-phone',p.id,p);
  res.status(201).json({token:secret,deviceId:p.id,fingerprint:fingerprint(p.publicKey),computer:store.get('d-source',p.sourceId).name});
 }));
 app.get('/desktop/phones',wrap((req,res)=>{const s=source(req);prune();res.json({phones:store.all('d-phone').filter(p=>p.sourceId===s.id).map(p=>({id:p.id,name:p.name,publicKey:p.publicKey,fingerprint:fingerprint(p.publicKey),active:p.active}))});}));
 app.post('/desktop/phones/:id/trust',wrap((req,res)=>{const s=source(req),p=store.get('d-phone',req.params.id);fail(p&&p.sourceId===s.id,404,'Phone not found');fail(req.body.fingerprint===fingerprint(p.publicKey),409,'Phone key changed');store.put('d-phone',p.id,{...p,active:true});res.json({trusted:true});}));
 app.delete('/desktop/phones/:id',wrap((req,res)=>{const s=source(req),p=store.get('d-phone',req.params.id);fail(p&&p.sourceId===s.id,404,'Phone not found');store.remove('d-phone',p.id);for(const r of store.all('d-request').filter(r=>r.sourceId===s.id&&r.signed?.deviceId===p.id&&r.status==='decided'))store.put('d-request',r.id,{...r,status:'cancelled',signed:undefined});res.json({revoked:true});}));
 app.delete('/mobile/pair',wrap((req,res)=>{const p=mobile(req,false);store.remove('d-phone',p.id);res.json({revoked:true});}));
 app.get('/mobile/state',wrap((req,res)=>{const p=mobile(req,false);res.json(p.active?{...snapshot(p.sourceId),deviceId:p.id,active:true}:{connected:false,active:false,deviceId:p.id,tasks:[],requests:[],updatedAt:0,message:'Compare the phone fingerprint, then confirm this phone on the PC'});}));
 app.get('/mobile/request/:id',wrap((req,res)=>{const p=mobile(req),s=snapshot(p.sourceId),r=store.get('d-request',req.params.id);fail(r&&r.sourceId===p.sourceId,404,'Request not found');res.json({id:r.id,provider:r.provider,reviewText:r.reviewText,revision:r.revision,status:s.connected?r.status:'offline',expiresAt:Math.floor(r.expires/1000)});}));
 app.post('/mobile/request/:id/decision',wrap(async(req,res)=>{
  const p=mobile(req);fail(p.mode!=='web',403,'Use passkey review for this phone');const b=z.object({revision:hash,decision:z.enum(['allow','deny']),nonce:id,expiresAt:z.number().int(),signature:z.string().min(80).max(120)}).strict().parse(req.body);prune();
  const link=store.get('d-link',p.sourceId),r=store.get('d-request',req.params.id);fail(r&&r.sourceId===p.sourceId,404,'Request not found');
  fail(online(link)&&link.allowRequests&&r.instance===link.instance&&r.id===link.requestId&&r.status==='pending'&&r.revision===b.revision&&r.expires>clock()&&b.expiresAt===Math.floor(r.expires/1000),409,'PC or request is no longer current');
  fail(digest(r.reviewText)===b.revision,409,'Request text changed');
  fail(verify('sha256',Buffer.from(decisionText(p.id,r,b)),phoneKey(p.publicKey),Buffer.from(b.signature,'base64')),403,'Phone signature did not verify');
  fail(!store.get('d-nonce',p.id+':'+b.nonce),409,'Decision replay');store.put('d-nonce',p.id+':'+b.nonce,{id:p.id+':'+b.nonce,at:clock()});
  store.put('d-request',r.id,{...r,status:'decided',signed:{...b,deviceId:p.id}});await publish(p.sourceId);res.json({recorded:true});
 }));
 app.post('/mobile/activity',wrap(async(req,res)=>{const p=mobile(req),value=z.string().regex(/^[a-fA-F0-9]{32,1024}$/).parse(req.body.token);store.put('d-phone',p.id,{...p,activityToken:value});await publish(p.sourceId);res.json({registered:true});}));
 app.post('/desktop/sync',wrap(async(req,res)=>{
  const s=source(req),b=sync.parse(req.body);prune();const old=store.get('d-link',s.id);
  fail(s.instance===b.instance,409,'Connect the current PC session first');
  fail(!old||old.instance!==b.instance||b.sequence>old.sequence,409,'Old PC snapshot');
  for(const a of b.acks){const r=store.get('d-request',a.id);if(r&&r.sourceId===s.id&&r.instance===b.instance&&r.status==='decided')store.put('d-request',r.id,{...r,status:a.result,signed:undefined});}
  // A completed click acknowledgement survives the prompt disappearing in this same snapshot.
  for(const r of store.all('d-request').filter(r=>r.sourceId===s.id&&['pending','decided'].includes(r.status))){if(r.instance!==b.instance||!b.allowRequests||r.id!==b.request?.id)store.put('d-request',r.id,{...r,status:'cancelled',signed:undefined});}
  if(b.request&&b.allowRequests){
   const r=b.request;fail(digest(r.reviewText)===r.revision,400,'Request text digest mismatch');const known=store.get('d-request',r.id);
   fail(!known||(known.sourceId===s.id&&known.instance===b.instance&&known.revision===r.revision&&known.nativeId===r.nativeId),409,'Request identity reused');
   if(!known)store.put('d-request',r.id,{...r,sourceId:s.id,instance:b.instance,status:'pending',created:clock(),expires:clock()+120000});
  }
  const link={...b,requestId:b.allowRequests?b.request?.id||'':'',at:clock()};delete link.request;delete link.acks;store.put('d-link',s.id,link);
  const decisions=store.all('d-request').filter(r=>r.sourceId===s.id&&r.instance===b.instance&&r.id===link.requestId&&r.status==='decided').map(r=>({id:r.id,nativeId:r.nativeId,revision:r.revision,...r.signed}));
  const state=await publish(s.id);res.json({connected:true,requests:store.all('d-request').filter(r=>r.sourceId===s.id&&r.instance===b.instance&&r.id===link.requestId).map(r=>({id:r.id,expiresAt:Math.floor(r.expires/1000),status:r.status})),decisions,phoneCount:store.all('d-phone').filter(p=>p.sourceId===s.id&&p.active).length,state});
 }));
 return {snapshot,prune,mobile,online,publish};
}
