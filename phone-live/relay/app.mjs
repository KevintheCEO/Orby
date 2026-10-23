import express from 'express';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';
import { digest, token, fail } from './security.mjs';
import { mountDesktop } from './desktop.mjs';

const provider=z.enum(['Codex','Claude Code']);
const auth=z.string().min(32).max(100);
const stateSchema=z.object({provider,phase:z.enum(['working','tool','ready','closed']),text:z.string().max(100)}).strict();
const permissionSchema=z.object({invocation:z.string().uuid(),provider,session:z.string().min(1).max(200),tool:z.string().min(1).max(100),input:z.unknown()}).strict();
export function createApp({store,adminKey,push,clock=Date.now}) {
  const app=express(); app.disable('x-powered-by'); app.use(express.json({limit:'80kb'}));
  app.use((req,res,next)=>{ res.set('Cache-Control','no-store'); if(req.headers.origin) return res.status(403).json({error:'Browser requests are not supported'});next(); });
  const wrap=fn=>(req,res,next)=>Promise.resolve().then(()=>fn(req,res)).catch(next);
  const bearer=req=>{const s=req.headers.authorization||'';fail(s.startsWith('Bearer '),401,'Authentication required');return s.slice(7);};
  const source=req=>{const hash=digest(bearer(req)),s=store.all('source').find(x=>x.hash===hash);fail(s,401,'Invalid source credential');return s;};
  const phone=req=>{const hash=digest(bearer(req)),p=store.all('phone').find(x=>x.hash===hash);fail(p,401,'Invalid phone credential');return p;};
  const prune=()=>{for(const r of store.all('request')){if(r.expires<=clock()&&r.status==='pending') store.put('request',r.id,{...r,status:'expired'});if(r.created<clock()-86400000)store.remove('request',r.id);}for(const i of store.all('invite'))if(i.expires<clock())store.remove('invite',i.hash);};
  function snapshot(sourceId) {
    prune(); const pending=store.all('request').filter(r=>r.sourceId===sourceId&&r.status==='pending').sort((a,b)=>a.created-b.created),r=pending[0];
    const s=store.get('source',sourceId);
    const recent=s?.activity&&s.activity.at>clock()-150000?s.activity:null;
    return {provider:r?.provider||recent?.provider||'Orby Live',phase:r?'review':recent?.phase||'ready',text:r?'Permission requested':recent?.text||'No current activity',requestId:r?.id||'',revision:r?.revision||'',expiresAt:r?Math.floor(r.expires/1000):0,pendingCount:pending.length,updatedAt:Math.floor(clock()/1000)};
  }
  const queues=new Map();
  const routineAt=new Map();
  async function deliver(sourceId) {
    const state=snapshot(sourceId);
    for(const p of store.all('phone').filter(p=>p.sourceId===sourceId&&p.activityToken)) {
      try {const result=await push.send(p.activityToken,state);store.put('phone',p.id,{...p,delivery:result,deliveryAt:clock(),activityToken:result.code===410?null:p.activityToken});}
      catch {store.put('phone',p.id,{...p,delivery:{status:'failed'},deliveryAt:clock()});}
    }
    return state;
  }
  function publish(sourceId,{routine=false}={}) {
    // Coalesce bursts of tool events; permission changes bypass the routine limit.
    if(routine&&clock()-(routineAt.get(sourceId)||0)<15000)return Promise.resolve(snapshot(sourceId));
    if(routine)routineAt.set(sourceId,clock());
    const previous=queues.get(sourceId)||Promise.resolve();
    const next=previous.catch(()=>{}).then(()=>deliver(sourceId));queues.set(sourceId,next);
    next.finally(()=>{if(queues.get(sourceId)===next)queues.delete(sourceId);}).catch(()=>{});
    return next;
  }
  app.get('/health',(_req,res)=>res.json({service:'Orby Live',nativePhone:true,pushConfigured:push.configured}));
  app.post('/admin/source',wrap((req,res)=>{
    fail(digest(bearer(req))===digest(adminKey),401,'Invalid administrator credential');
    const name=z.string().min(1).max(80).parse(req.body.name),id=randomUUID(),secret=token();
    store.put('source',id,{id,name,hash:digest(secret)});res.status(201).json({id,token:secret});
  }));
  app.post('/source/invite',wrap((req,res)=>{
    const s=source(req),secret=token(),hash=digest(secret);
    store.put('invite',hash,{hash,sourceId:s.id,expires:clock()+300000});res.json({invite:secret,expiresAt:clock()+300000});
  }));
  app.post('/phone/pair',wrap((req,res)=>{
    const secret=auth.parse(req.body.invite),i=store.get('invite',digest(secret));fail(i&&i.expires>clock(),401,'Invitation is invalid or expired');
    store.remove('invite',i.hash);
    // A new pairing revokes the previous phone, rather than leaving a forgotten approver active.
    for(const p of store.all('phone').filter(p=>p.sourceId===i.sourceId))store.remove('phone',p.id);
    const credential=token(),id=randomUUID();store.put('phone',id,{id,sourceId:i.sourceId,hash:digest(credential)});
    res.json({token:credential,name:store.get('source',i.sourceId).name});
  }));
  app.delete('/phone/pair',wrap((req,res)=>{const p=phone(req);store.remove('phone',p.id);res.json({revoked:true});}));
  app.post('/phone/activity',wrap(async(req,res)=>{
    const p=phone(req),value=z.string().regex(/^[a-fA-F0-9]{32,1024}$/).parse(req.body.token);
    store.put('phone',p.id,{...p,activityToken:value});res.json({state:await publish(p.sourceId)});
  }));
  app.get('/phone/state',wrap((req,res)=>{const p=phone(req);res.json(snapshot(p.sourceId));}));
  app.get('/phone/request/:id',wrap((req,res)=>{
    const p=phone(req);prune();const r=store.get('request',req.params.id);fail(r&&r.sourceId===p.sourceId,404,'Request not found');
    res.json({id:r.id,revision:r.revision,provider:r.provider,tool:r.tool,input:r.input,inputText:JSON.stringify(r.input,null,2),status:r.status,expiresAt:Math.floor(r.expires/1000)});
  }));
  app.post('/phone/request/:id/decision',wrap(async(req,res)=>{
    const p=phone(req),body=z.object({revision:z.string().length(64),decision:z.enum(['allow','deny'])}).strict().parse(req.body);
    prune();const r=store.get('request',req.params.id);fail(r&&r.sourceId===p.sourceId,404,'Request not found');
    fail(r.status==='pending'&&r.expires>clock()&&r.revision===body.revision,409,'Request is no longer pending; refresh before deciding');
    store.put('request',r.id,{...r,status:'decided',decision:body.decision});await publish(p.sourceId);res.json({recorded:true});
  }));
  app.post('/source/status',wrap(async(req,res)=>{const s=source(req),a=stateSchema.parse(req.body);store.put('source',s.id,{...s,activity:{...a,at:clock()}});res.json({state:await publish(s.id,{routine:a.phase!=='ready'&&a.phase!=='closed'})});}));
  app.post('/source/request',wrap(async(req,res)=>{
    const s=source(req),b=permissionSchema.parse(req.body),details=JSON.stringify(b.input);fail(details&&Buffer.byteLength(details)<=8192,413,'Request too large; use the local approval prompt');
    fail(!store.all('request').some(r=>r.sourceId===s.id&&r.invocation===b.invocation),409,'Invocation already registered');
    const id=randomUUID(),revision=digest(JSON.stringify(b)),r={...b,id,sourceId:s.id,revision,created:clock(),expires:clock()+120000,status:'pending'};
    store.put('request',id,r);await publish(s.id);res.status(201).json({id,revision,expiresAt:r.expires});
  }));
  app.get('/source/request/:id',wrap((req,res)=>{const s=source(req);prune();const r=store.get('request',req.params.id);fail(r&&r.sourceId===s.id,404,'Request not found');res.json({status:r.status});}));
  app.post('/source/request/:id/consume',wrap((req,res)=>{
    const s=source(req);prune();const r=store.get('request',req.params.id);fail(r&&r.sourceId===s.id,404,'Request not found');
    fail(r.status==='decided'&&r.expires>clock(),409,'No current unconsumed decision');
    store.put('request',r.id,{...r,status:'returned'});res.json({decision:r.decision,revision:r.revision});
  }));
  app.delete('/source/request/:id',wrap(async(req,res)=>{const s=source(req),r=store.get('request',req.params.id);fail(r&&r.sourceId===s.id,404,'Request not found');store.put('request',r.id,{...r,status:'cancelled',decision:undefined});await publish(s.id);res.json({cancelled:true});}));
  const desktop=mountDesktop(app,{store,adminKey,push,clock});
  app.use((err,_req,res,_next)=>res.status(err instanceof z.ZodError?400:err.status||500).json({error:err instanceof z.ZodError?'Invalid request fields':err.status?err.message:'Internal service error'}));
  return {app,snapshot,publish,prune:()=>{prune();desktop.prune();}};
}
