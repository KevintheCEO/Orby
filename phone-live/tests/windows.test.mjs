import {test} from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign,randomUUID} from 'node:crypto';
import {mkdtempSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {digest} from '../relay/security.mjs';
import {decisionText} from '../relay/desktop.mjs';
import {authenticator,assertion,sha} from './webauthn-fixture.mjs';
let source=fileURLToPath(new URL('../../work/central17-source',import.meta.url));if(!existsSync(source))source=fileURLToPath(new URL('../windows',import.meta.url));
test('Windows verifies real phone signatures and binds native response to the current exact prompt',{skip:process.platform!=='win32'||!existsSync(source)},()=>{
 const dir=mkdtempSync(join(tmpdir(),'orby-phone-fixture-'));
 try{const keys=generateKeyPairSync('ec',{namedCurve:'prime256v1'}),j=keys.publicKey.export({format:'jwk'}),review='ChatGPT\nTest permission\n\nHarmless fixture only';const f={key:Buffer.concat([Buffer.from([4]),Buffer.from(j.x,'base64url'),Buffer.from(j.y,'base64url')]).toString('base64'),deviceId:randomUUID(),requestId:randomUUID(),review,revision:digest(review),decision:'allow',nonce:randomUUID(),expiresAt:Math.floor(Date.now()/1000)+120};const canonical=decisionText(f.deviceId,{id:f.requestId,revision:f.revision},f);f.signature=sign('sha256',Buffer.from(canonical),keys.privateKey).toString('base64');const web=authenticator(),challenge=sha(canonical).toString('base64url');f.webOrigin='https://phone.example.test';f.webKey=web.raw;f.web=assertion(web,challenge,f.webOrigin).response;f.webNoUV=assertion(web,challenge,f.webOrigin,{flags:1}).response;f.webCrossOrigin=assertion(web,challenge,f.webOrigin,{crossOrigin:true}).response;const path=join(dir,'fixture.json');writeFileSync(path,JSON.stringify(f));const r=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-File',fileURLToPath(new URL('../scripts/Test-WindowsLink.ps1',import.meta.url)),'-Fixture',path,'-SourceRoot',source],{encoding:'utf8',timeout:45000});assert.equal(r.status,0,r.stderr||r.stdout);assert.match(r.stdout,/PASS: \d+ Windows checks/);}finally{rmSync(dir,{recursive:true,force:true});}
});
