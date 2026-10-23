import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Store } from './store.mjs';
import { ApplePush } from './apns.mjs';
import { createApp } from './app.mjs';
import { token, safeOrigin } from './security.mjs';
import { WebPushDelivery } from './web-push.mjs';

const root=fileURLToPath(new URL('../',import.meta.url)),dir=resolve(process.env.DATA_DIR||resolve(root,'.data'));mkdirSync(dir,{recursive:true});
function secret(name,generate){const p=resolve(dir,name);if(!existsSync(p))writeFileSync(p,generate(),{mode:0o600});return readFileSync(p,'utf8').trim();}
const origin=safeOrigin(process.env.PUBLIC_ORIGIN||'http://127.0.0.1:4319',{development:process.env.NODE_ENV!=='production'});
const admin=process.env.ADMIN_TOKEN||secret('admin.key',token),key=Buffer.from(process.env.STORAGE_KEY||secret('storage.key',()=>randomBytes(32).toString('hex')),'hex');
const push=new ApplePush({key:process.env.APNS_KEY_PATH?readFileSync(process.env.APNS_KEY_PATH,'utf8'):null,keyId:process.env.APNS_KEY_ID,teamId:process.env.APPLE_TEAM_ID,bundleId:process.env.APP_BUNDLE_ID,production:process.env.APNS_ENV==='production'});
const store=new Store(resolve(dir,'live.sqlite'),key),webPush=new WebPushDelivery({store,origin}),{app,prune}=createApp({store,adminKey:admin,push,browserOrigin:origin,webPush});
const bind=process.env.BIND_ADDRESS||'127.0.0.1';if(!['127.0.0.1','0.0.0.0'].includes(bind))throw new Error('Invalid bind address');
const server=app.listen(Number(process.env.PORT||4319),bind,()=>console.log(`Orby Live relay: ${origin}\nHome Screen web notifications: available after phone permission and subscription; device delivery needs testing\nNative Live Activity push: ${push.configured?'configured; delivery still needs device testing':'not configured; native background Live Activities unavailable'}\nDesktop linking is opt-in. The withdrawn MCP connector is not used.`));
const timer=setInterval(prune,60000);timer.unref();
for(const event of ['SIGINT','SIGTERM'])process.on(event,()=>{clearInterval(timer);server.close(()=>{store.close();process.exit(0);});});
