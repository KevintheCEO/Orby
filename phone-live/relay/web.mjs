import {z} from 'zod';
import {randomUUID,createHash} from 'node:crypto';
import {generateRegistrationOptions,verifyRegistrationResponse,verifyAuthenticationResponse} from '@simplewebauthn/server';
import {convertCOSEtoPKCS} from '@simplewebauthn/server/helpers';
import {fileURLToPath} from 'node:url';
import {digest,token,fail} from './security.mjs';
import {fingerprint,decisionText} from './desktop.mjs';

export function mountPhoneWeb(app,{store,desktop,origin,clock=Date.now}){
 if(!origin)return;
 const site=new URL(origin);fail(site.protocol==='https:'||['localhost','127.0.0.1','[::1]'].includes(site.hostname),500,'Phone web access requires HTTPS');
 const rpID=site.hostname;
 const wrap=fn=>(req,res,next)=>Promise.resolve().then(()=>{if(req.method==='GET'){fail(req.headers.origin===origin||req.headers['sec-fetch-site']==='same-origin',403,'Open the phone app on its own address');}else fail(req.headers.origin===origin,403,'Unexpected phone origin');return fn(req,res);}).catch(next);
 const phone=req=>{const p=desktop.mobile(req);fail(p.mode==='web',403,'Use the native phone client for this device');return p;};
 const topLevel=response=>{try{const raw=Buffer.from(response.response.clientDataJSON,'base64url');fail(raw.length<=4096,403,'Passkey client data is too large');const c=JSON.parse(raw.toString('utf8'));fail(c&&typeof c==='object'&&(c.crossOrigin===undefined||c.crossOrigin===false),403,'Open Orby directly in Safari');}catch{fail(false,403,'Invalid passkey client context');}};
 const asset=fileURLToPath(new URL('../web/',import.meta.url));
 app.get(['/iphone','/iphone/'],(_req,res)=>res.redirect(302,'/iphone/home.html'));
 app.use('/iphone',(req,res,next)=>{res.set({'Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; manifest-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Permissions-Policy':'publickey-credentials-create=(self), publickey-credentials-get=(self)'});next();});
 for(const [path,file,type] of [['home.html','home.html','text/html'],['phone.js','phone.js','text/javascript'],['phone.css','phone.css','text/css'],['manifest.webmanifest','manifest.webmanifest','application/manifest+json'],['icon.svg','icon.svg','image/svg+xml'],['icon.png','icon.png','image/png']])app.get('/iphone/'+path,(_req,res)=>res.type(type).sendFile(asset+file));
 app.post('/web/pair/options',wrap(async(req,res)=>{
  const b=z.object({invite:z.string().min(32).max(100),name:z.string().min(1).max(60)}).strict().parse(req.body);desktop.prune();
  const invite=store.get('d-invite',digest(b.invite));fail(invite&&invite.expires>clock(),401,'Invitation expired or used');
  fail(store.all('d-phone').filter(p=>p.sourceId===invite.sourceId).length<4,409,'Revoke an old phone first');
  for(const old of store.all('d-web-reg').filter(r=>r.inviteHash===invite.hash))store.remove('d-web-reg',old.id);
  const id=randomUUID(),options=await generateRegistrationOptions({rpName:'Orby Phone',rpID,userName:b.name,userID:Buffer.from(randomUUID()),attestationType:'none',supportedAlgorithmIDs:[-7],authenticatorSelection:{residentKey:'preferred',userVerification:'required',authenticatorAttachment:'platform'}});
  store.put('d-web-reg',id,{id,inviteHash:invite.hash,sourceId:invite.sourceId,name:b.name,challenge:options.challenge,expires:Math.min(invite.expires,clock()+240000)});res.json({id,options});
 }));
 app.post('/web/pair/verify',wrap(async(req,res)=>{
  const b=z.object({id:z.string().uuid(),response:z.unknown()}).strict().parse(req.body),registration=store.get('d-web-reg',b.id);fail(registration&&registration.expires>clock(),401,'Pairing attempt expired');
  topLevel(b.response);let result;try{result=await verifyRegistrationResponse({response:b.response,expectedChallenge:registration.challenge,expectedOrigin:origin,expectedRPID:rpID,requireUserVerification:true});}catch{fail(false,403,'Phone passkey did not verify');}
  fail(result.verified&&result.registrationInfo?.userVerified,403,'Phone screen-lock verification is required');
  const fresh=store.get('d-web-reg',b.id),invite=store.get('d-invite',registration.inviteHash);fail(fresh&&fresh.expires>clock()&&invite&&invite.expires>clock(),409,'Invitation expired or used');
  fail(store.all('d-phone').filter(p=>p.sourceId===registration.sourceId).length<4,409,'Revoke an old phone first');
  const credential=result.registrationInfo.credential,raw=Buffer.from(convertCOSEtoPKCS(credential.publicKey));fail(raw.length===65&&raw[0]===4,403,'A P256 passkey is required');
  const secret=token(),p={id:randomUUID(),sourceId:registration.sourceId,name:registration.name,mode:'web',publicKey:raw.toString('base64'),hash:digest(secret),created:clock(),active:false,credential:{id:credential.id,publicKey:Buffer.from(credential.publicKey).toString('base64'),counter:credential.counter,transports:credential.transports||[]}};
  store.remove('d-web-reg',b.id);store.remove('d-invite',registration.inviteHash);store.put('d-phone',p.id,p);res.status(201).json({token:secret,deviceId:p.id,fingerprint:fingerprint(p.publicKey)});
 }));
 app.get('/web/state',wrap((req,res)=>{const p=desktop.mobile(req,false);fail(p.mode==='web',403,'Wrong phone client');res.json(p.active?{...desktop.snapshot(p.sourceId),active:true}:{connected:false,active:false,tasks:[],requests:[],message:'Confirm the matching fingerprint in Orby on your PC'});}));
 app.get('/web/request/:id',wrap((req,res)=>{const p=phone(req),state=desktop.snapshot(p.sourceId),r=store.get('d-request',req.params.id);fail(r&&r.sourceId===p.sourceId,404,'Request not found');res.json({id:r.id,reviewText:r.reviewText,revision:r.revision,provider:r.provider,status:state.connected?r.status:'offline',expiresAt:Math.floor(r.expires/1000),credentialId:p.credential.id});}));
 app.post('/web/request/:id/decision',wrap(async(req,res)=>{
  const p=phone(req),b=z.object({revision:z.string().regex(/^[a-f0-9]{64}$/),decision:z.enum(['allow','deny']),nonce:z.string().uuid(),expiresAt:z.number().int(),response:z.unknown()}).strict().parse(req.body);
  function current(){desktop.prune();const r=store.get('d-request',req.params.id),link=store.get('d-link',p.sourceId),fresh=store.get('d-phone',p.id);fail(fresh?.active&&r&&r.sourceId===p.sourceId&&desktop.online(link)&&link.allowRequests&&r.instance===link.instance&&r.id===link.requestId&&r.status==='pending'&&r.revision===b.revision&&r.expires>clock()&&b.expiresAt===Math.floor(r.expires/1000),409,'PC or request is no longer current');fail(digest(r.reviewText)===r.revision,409,'Request text changed');return r;}
  let r=current();topLevel(b.response);const challenge=createHash('sha256').update(decisionText(p.id,r,b)).digest('base64url');let result;
  try{result=await verifyAuthenticationResponse({response:b.response,expectedChallenge:challenge,expectedOrigin:origin,expectedRPID:rpID,requireUserVerification:true,credential:{...p.credential,publicKey:new Uint8Array(Buffer.from(p.credential.publicKey,'base64'))}});}catch{fail(false,403,'Screen-lock signature did not verify');}
  fail(result.verified,403,'Phone passkey did not verify');r=current();fail(!store.get('d-nonce',p.id+':'+b.nonce),409,'Decision replay');store.put('d-nonce',p.id+':'+b.nonce,{id:p.id+':'+b.nonce,at:clock()});
  const response=b.response.response;store.put('d-request',r.id,{...r,status:'decided',signed:{revision:b.revision,decision:b.decision,nonce:b.nonce,expiresAt:b.expiresAt,deviceId:p.id,method:'webauthn',signature:Buffer.from(response.signature,'base64url').toString('base64'),clientDataJSON:response.clientDataJSON,authenticatorData:response.authenticatorData}});
  const fresh=store.get('d-phone',p.id);store.put('d-phone',p.id,{...fresh,credential:{...fresh.credential,counter:result.authenticationInfo.newCounter}});await desktop.publish(p.sourceId);res.json({recorded:true});
 }));
 app.delete('/web/pair',wrap((req,res)=>{const p=desktop.mobile(req,false);fail(p.mode==='web',403,'Wrong phone client');store.remove('d-phone',p.id);for(const r of store.all('d-request').filter(r=>r.signed?.deviceId===p.id&&r.status==='decided'))store.put('d-request',r.id,{...r,status:'cancelled',signed:undefined});res.json({revoked:true});}));
}
