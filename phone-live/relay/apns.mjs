import http2 from 'node:http2';
import { createPrivateKey, sign } from 'node:crypto';

export class ApplePush {
  constructor(config = {}) { this.config = config; this.lastTimestamp=new Map(); }
  get configured() { const c=this.config; return !!(c.key && c.keyId && c.teamId && c.bundleId); }
  async send(deviceToken, state) {
    if (!this.configured) return { status:'not-configured' };
    const c=this.config;
    // ActivityKit orders updates by timestamp. Serialize same-second changes so
    // a quick approval cannot leave the older pending state on the lock screen.
    const previous=this.lastTimestamp.get(deviceToken)||0;
    if(Math.floor(Date.now()/1000)<=previous)await new Promise(r=>setTimeout(r,Math.max(1,(previous+1)*1000-Date.now())));
    const now=Math.floor(Date.now()/1000);this.lastTimestamp.set(deviceToken,now);
    const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
    const input=`${enc({alg:'ES256',kid:c.keyId})}.${enc({iss:c.teamId,iat:now})}`;
    const signature=sign('sha256',Buffer.from(input),{key:createPrivateKey(c.key),dsaEncoding:'ieee-p1363'}).toString('base64url');
    const payload={aps:{timestamp:now,event:'update','content-state':state,'stale-date':now+150}};
    // Permission requests are time-sensitive. Routine status updates are lower priority.
    if(state.requestId) payload.aps.alert={title:`${state.provider} needs your review`,body:'Open the request to see the exact action.'};
    const client=(c.connect||http2.connect)(c.production?'https://api.push.apple.com':'https://api.sandbox.push.apple.com');
    return new Promise((resolve,reject)=>{
      let settled=false; const done=(err,result)=>{if(settled)return;settled=true;client.close();err?reject(err):resolve(result);};
      client.on('error',e=>done(e));
      const req=client.request({':method':'POST',':path':`/3/device/${deviceToken}`,authorization:`bearer ${input}.${signature}`,'apns-topic':`${c.bundleId}.push-type.liveactivity`,'apns-push-type':'liveactivity','apns-priority':state.requestId?'10':'5','apns-expiration':String(now+120),'apns-collapse-id':'orby-live-state'});
      let status,body=''; req.on('response',h=>status=Number(h[':status']));req.setEncoding('utf8');req.on('data',b=>body+=b);
      req.on('end',()=>done(null,{status:status===200?'accepted':'rejected',code:status,reason:body.slice(0,200)}));
      req.on('error',e=>done(e));req.setTimeout(8000,()=>{req.close();done(new Error('Apple push timed out'));});
      req.end(JSON.stringify(payload));
    });
  }
}
