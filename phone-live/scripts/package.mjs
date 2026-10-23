import { mkdirSync,mkdtempSync,cpSync,readdirSync,lstatSync,existsSync } from 'node:fs';
import { resolve,join,basename } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root=fileURLToPath(new URL('../',import.meta.url));
const staging=join(mkdtempSync(join(tmpdir(),'orby-live-package-')),'Orby-Live-Source');mkdirSync(staging);
const forbidden=/^(\.data|\.desktop-data|generated|node_modules|Personal|orby-connect|build|DerivedData|artifacts)$|\.(p8|p12|pfx|jks|keystore|mobileprovision|dpapi|sqlite|key|apk)$/i;
const allowed=['README.md','package.json','package-lock.json','.gitignore','.dockerignore','Dockerfile','Start-PhoneAccess.cmd','Stop-PhoneAccess.cmd','relay','hooks','scripts','ios','android','tests','docs','.github'];
for(const name of allowed){const p=resolve(root,name);if(existsSync(p))cpSync(p,join(staging,name),{recursive:true,filter:src=>!forbidden.test(basename(src))});}
const adjacent=resolve(root,'../work/central17-source'),windows=existsSync(adjacent)?adjacent:resolve(root,'windows');mkdirSync(join(staging,'windows'));for(const name of ['Phone-Link.cs','Phone-Link.ps1','Phone-Link.xaml'])cpSync(join(windows,name),join(staging,'windows',name));
function check(dir){for(const e of readdirSync(dir)){const p=join(dir,e);if(lstatSync(p).isSymbolicLink())throw new Error('Links are not allowed in source package');if(forbidden.test(e))throw new Error('Private or unrelated files in package');if(lstatSync(p).isDirectory())check(p);}}
check(staging);
const output=resolve(root,'../outputs/Orby-Live-Source.zip');mkdirSync(resolve(root,'../outputs'),{recursive:true});
const r=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command','Compress-Archive -LiteralPath $env:ORBY_SOURCE_STAGE -DestinationPath $env:ORBY_SOURCE_ZIP -Force'],{env:{...process.env,ORBY_SOURCE_STAGE:staging,ORBY_SOURCE_ZIP:output},encoding:'utf8'});
if(r.status!==0)throw new Error(r.stderr||'Packaging failed');
console.log(`Source-only package: ${output}\nNo credentials, personal water assets, desktop binaries or signed iPhone app included.`);
