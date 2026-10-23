import webpush from 'web-push';
import {createHash} from 'node:crypto';
import {z} from 'zod';
import {fail} from './security.mjs';

const hosts=new Set(['web.push.apple.com','fcm.googleapis.com','updates.push.services.mozilla.com']);
export const subscriptionSchema=z.object({endpoint:z.string().max(4096),expirationTime:z.number().nullable().optional(),keys:z.object({p256dh:z.string().max(100),auth:z.string().max(32)}).strict()}).strict().superRefine((s,c)=>{
 try{const u=new URL(s.endpoint),key=Buffer.from(s.keys.p256dh,'base64url'),auth=Buffer.from(s.keys.auth,'base64url');if(u.protocol!=='https:'||u.username||u.password||u.port||u.hash||!hosts.has(u.hostname)||u.pathname.length<2||key.length!==65||key[0]!==4||auth.length!==16)throw Error();}catch{c.addIssue({code:'custom',message:'Unsupported notification subscription'});}
});
export class WebPushDelivery{
 constructor({store,origin,send=(...args)=>webpush.sendNotification(...args),clock=Date.now}){
  this.store=store;this.origin=origin;this.send=send;this.clock=clock;this.queues=new Map();
  this.keys=store.get('web-push-key','v1')||store.put('web-push-key','v1',webpush.generateVAPIDKeys());
 }
 get publicKey(){return this.keys.publicKey;}
 packet(kind,id,expiresAt,requestKind){
  const request=kind==='request',test=kind==='test';
  const title=test?'Orby notification test':request?requestKind==='question'?'Orby is waiting for your answer':'Orby needs your review':'Orby project update';
  const body=test?'Notifications are connected. Tap to open Orby.':request?requestKind==='question'?'A question on your PC is still unanswered. Tap to reply.':'A task on your PC needs permission. Tap to review the exact action.':'Work is running on your PC. Tap for the project and current step.';
  const path='/iphone/home.html'+(request?'#request='+id:''),tag=request?'orby-request-'+id:'orby-'+kind;
  return {web_push:8030,notification:{title,body,navigate:this.origin+path,tag,silent:false},kind,requestId:request?id:'',expiresAt};
 }
 async deliver(p,payload){
  const current=this.store.get('d-phone',p.id);if(!current?.active||current.pushOrigin&&current.pushOrigin!==this.origin||current.pushSubscription?.endpoint!==p.pushSubscription?.endpoint)return {status:'cancelled'};
  const ttl=Math.max(0,Math.min(120,payload.expiresAt-Math.floor(this.clock()/1000)));if(ttl===0)return {status:'expired'};
  try{await this.send(p.pushSubscription,JSON.stringify(payload),{vapidDetails:{subject:this.origin,publicKey:this.keys.publicKey,privateKey:this.keys.privateKey},TTL:ttl,urgency:payload.kind==='activity'?'normal':'high',topic:createHash('sha256').update(payload.notification.tag).digest('base64url').slice(0,32),timeout:8000});return {status:'accepted'};}
  catch(e){const fresh=this.store.get('d-phone',p.id);if([404,410].includes(e.statusCode)&&fresh?.pushSubscription?.endpoint===p.pushSubscription.endpoint)this.store.put('d-phone',p.id,{...fresh,pushSubscription:undefined});return {status:'failed',code:e.statusCode||0};}
 }
 notify({sourceId,state,link}){
  if(!state.connected)return;
  for(const p of this.store.all('d-phone').filter(p=>p.sourceId===sourceId&&p.active&&p.mode==='web'&&p.pushSubscription)){
   const request=state.requests.find(r=>r.kind!=='stop');
   if(p.pushSettings?.awayOnly!==false&&link?.presence?.away!==true&&!request?.handoff)continue;
   if(this.clock()-(p.foregroundAt||0)<8000)continue;
   const working=state.tasks.filter(t=>t.state==='working'||t.state==='attention');
   const kind=request?'request':working.length&&p.pushSettings?.activity!==false?'activity':null;if(!kind)continue;
   const key=request?'request:'+(this.store.get('d-request',request.id)?.nativeId||request.id)+':'+request.revision:'activity:'+working.map(t=>t.provider+':'+t.id).sort().join('|');
   if(p.lastPushKey===key||this.queues.get(p.id)?.key===key)continue;
   if(p.lastPushAttempt?.key===key&&this.clock()-p.lastPushAttempt.at<30000)continue;
   if(kind==='activity'&&this.clock()-(p.lastActivityPush||0)<120000)continue;
   const payload=this.packet(kind,request?.id||'',request?.expiresAt||Math.floor(this.clock()/1000)+120,request?.kind);
   const old=this.queues.get(p.id)?.promise||Promise.resolve();
   const promise=old.catch(()=>{}).then(async()=>{
    const fresh=this.store.get('d-phone',p.id),current=this.store.get('d-link',sourceId);
    if(!fresh?.active||!current||this.clock()-current.at>=15000||fresh.pushSettings?.awayOnly!==false&&current.presence?.away!==true&&!request?.handoff||this.clock()-(fresh.foregroundAt||0)<8000)return;
    if(kind==='request'){const r=this.store.get('d-request',request.id);if(!r||r.status!=='pending'||r.revision!==request.revision||current.requestId!==r.id)return;}
    if(kind==='activity'&&!current.tasks.some(t=>t.state==='working'||t.state==='attention'))return;
    this.store.put('d-phone',p.id,{...fresh,lastPushAttempt:{key,at:this.clock()}});
    const result=await this.deliver(fresh,payload),after=this.store.get('d-phone',p.id);
    if(after&&result.status==='accepted')this.store.put('d-phone',p.id,{...after,lastPushKey:key,...(kind==='activity'?{lastActivityPush:this.clock()}:{})});
   }).catch(()=>{});this.queues.set(p.id,{key,promise});promise.finally(()=>{if(this.queues.get(p.id)?.promise===promise)this.queues.delete(p.id);});
  }
 }
}
export function mountWebPush(app,{store,desktop,delivery,wrap,phone,clock=Date.now}){
 app.get('/web/push/config',wrap((req,res)=>{const p=phone(req);res.json({available:!!delivery,publicKey:delivery?.publicKey||'',enabled:!!p.pushSubscription&&p.pushOrigin===delivery?.origin,settings:p.pushSettings||{awayOnly:true,activity:true}});}));
 app.post('/web/push/subscribe',wrap((req,res)=>{
  fail(delivery,503,'Notifications are not configured');const p=phone(req),b=z.object({subscription:subscriptionSchema,awayOnly:z.boolean(),activity:z.boolean()}).strict().parse(req.body);
  fail(!store.all('d-phone').some(other=>other.id!==p.id&&other.pushSubscription?.endpoint===b.subscription.endpoint),409,'This notification subscription belongs to another phone');
  store.put('d-phone',p.id,{...p,pushSubscription:b.subscription,pushOrigin:delivery.origin,pushSettings:{awayOnly:b.awayOnly,activity:b.activity},lastPushKey:undefined});res.json({enabled:true});
 }));
 app.delete('/web/push/subscribe',wrap((req,res)=>{const p=phone(req);store.put('d-phone',p.id,{...p,pushSubscription:undefined});res.json({enabled:false});}));
 app.post('/web/push/test',wrap(async(req,res)=>{
  const p=phone(req);fail(delivery&&p.pushSubscription,409,'Enable notifications first');fail(clock()-(p.lastPushTest||0)>10000,429,'Wait a moment before another test');store.put('d-phone',p.id,{...p,lastPushTest:clock()});
  const delay=z.object({delaySeconds:z.number().int().min(0).max(10).default(0)}).strict().parse(req.body||{}).delaySeconds;
  if(delay){const timer=setTimeout(()=>{delivery.deliver(p,delivery.packet('test','',Math.floor(clock()/1000)+120)).catch(()=>{});},delay*1000);timer.unref();res.json({status:'queued',delaySeconds:delay});return;}
  const result=await delivery.deliver(p,delivery.packet('test','',Math.floor(clock()/1000)+120));res.json(result);
 }));
}
