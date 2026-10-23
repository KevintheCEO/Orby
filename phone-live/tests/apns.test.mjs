import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { generateKeyPairSync,verify } from 'node:crypto';
import { ApplePush } from '../relay/apns.mjs';

test('APNs uses a signed ES256 JWT, proper topic and exact ActivityKit state without secrets',async()=>{
  const keys=generateKeyPairSync('ec',{namedCurve:'prime256v1'});let captured,closed=false;
  const client=new EventEmitter();client.close=()=>{closed=true;};
  client.request=headers=>{
    const req=new EventEmitter();req.setEncoding=()=>{};req.setTimeout=()=>{};
    req.end=body=>{captured={headers,body:JSON.parse(body)};queueMicrotask(()=>{req.emit('response',{':status':200});req.emit('end');});};return req;
  };
  const push=new ApplePush({key:keys.privateKey.export({format:'pem',type:'pkcs8'}),keyId:'TESTKEY',teamId:'TESTTEAM',bundleId:'com.example.OrbyLive',connect:host=>{assert.equal(host,'https://api.sandbox.push.apple.com');return client;}});
  const state={provider:'Codex',phase:'review',text:'Permission requested',requestId:'request',revision:'abc',expiresAt:123,pendingCount:1,updatedAt:123};
  assert.equal((await push.send('a'.repeat(64),state)).status,'accepted');
  assert.equal(captured.headers['apns-topic'],'com.example.OrbyLive.push-type.liveactivity');
  assert.equal(captured.headers['apns-push-type'],'liveactivity');assert.equal(captured.headers['apns-priority'],'10');
  const jwt=captured.headers.authorization.slice(7),[h,p,s]=jwt.split('.');
  assert.equal(JSON.parse(Buffer.from(h,'base64url')).alg,'ES256');
  assert.equal(JSON.parse(Buffer.from(p,'base64url')).iss,'TESTTEAM');
  assert.ok(verify('sha256',Buffer.from(`${h}.${p}`),{key:keys.publicKey,dsaEncoding:'ieee-p1363'},Buffer.from(s,'base64url')));
  assert.deepEqual(captured.body.aps['content-state'],state);assert.equal(captured.body.aps.event,'update');assert.ok(closed);
  assert.ok(!JSON.stringify(captured.body).includes(jwt));
});
test('missing Apple keys is explicit and does not pretend to deliver',async()=>{
  const push=new ApplePush();assert.equal(push.configured,false);assert.deepEqual(await push.send('fake',{}),{status:'not-configured'});
});
