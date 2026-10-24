'use strict';
const $=id=>document.getElementById(id),msg=text=>{$('notice').textContent=text;};
let saved;try{saved=JSON.parse(localStorage.getItem('orby.phone.v1')||'null');}catch{saved=null;}
let polling=false,review=null,busy=false,auth=null,networkFresh=false,phoneTestReview=null,phoneTestAuth=null;
const incoming=new URLSearchParams(location.hash.slice(1)).get('invite');let requestedReview=new URLSearchParams(location.hash.slice(1)).get('request'),requestedTest=new URLSearchParams(location.hash.slice(1)).get('test');if(incoming&&/^[A-Za-z0-9_-]{32,100}$/.test(incoming))$('invite').value=incoming;if(location.hash)history.replaceState(null,'',location.pathname);
const b64=buffer=>{let s='';for(const v of new Uint8Array(buffer))s+=String.fromCharCode(v);return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');};
const raw=s=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-s.length%4)%4)),c=>c.charCodeAt(0));
const sha=async text=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)));
const hash=async text=>Array.from(await sha(text),x=>x.toString(16).padStart(2,'0')).join('');
async function api(path,body,method=body?'POST':'GET',credential=saved?.token){const r=await fetch(path,{method,credentials:'omit',redirect:'error',cache:'no-store',signal:AbortSignal.timeout(10000),headers:{...(credential?{Authorization:'Bearer '+credential}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});let result;try{result=await r.json();}catch{throw Error('Phone service unavailable. Refresh before trying again.');}if(!r.ok){if(r.status===401&&credential&&credential===saved?.token){localStorage.removeItem('orby.phone.v1');saved=null;closeReview();shell();$('connection').textContent='Not paired';}throw Error(result.error||'Request unavailable');}return result;}
function credentialJSON(c,registration){const r=c.response;return {id:c.id,rawId:b64(c.rawId),type:c.type,authenticatorAttachment:c.authenticatorAttachment,clientExtensionResults:c.getClientExtensionResults(),response:registration?{clientDataJSON:b64(r.clientDataJSON),attestationObject:b64(r.attestationObject),transports:r.getTransports?r.getTransports():['internal']}:{clientDataJSON:b64(r.clientDataJSON),authenticatorData:b64(r.authenticatorData),signature:b64(r.signature),userHandle:r.userHandle?b64(r.userHandle):null}};}
function shell(){if(!saved){OrbyUI.clear();closePhoneTest();}$('pair').hidden=!!saved;$('paired').hidden=!saved;$('fingerprint').textContent=saved?.fingerprint||'';}
function orb(provider,state){const face=document.createElement('div');face.className='orb '+provider.toLowerCase()+(state==='attention'?' attention':'');face.setAttribute('aria-hidden','true');face.append(document.createElement('i'),document.createElement('i'));return face;}
function text(tag,value,className=''){const n=document.createElement(tag);n.textContent=value;n.className=className;return n;}
async function refresh(){
 if(!saved||polling||document.hidden)return;polling=true;
 try{
  const state=await api('/web/state');
  if(/^[A-F0-9]{12}$/.test(state.fingerprint)&&state.fingerprint!==saved.fingerprint){saved.fingerprint=state.fingerprint;localStorage.setItem('orby.phone.v1',JSON.stringify(saved));shell();}
  networkFresh=state.connected;$('connection').textContent=state.connected?'PC online':state.active?'PC offline':'Confirm on PC';$('connection').classList.toggle('online',state.connected);
  msg(state.message==='PC connected'?'':state.message||'');OrbyUI.render(state);
  if(state.active)void updatePushControls();
  if(requestedReview&&!busy){const id=requestedReview;requestedReview=null;if(/^[0-9a-f-]{36}$/i.test(id))await openReview(id);}
  if(requestedTest&&!busy){const id=requestedTest;requestedTest=null;if(/^[0-9a-f-]{36}$/i.test(id))await openPhoneTest(id);}if(phoneTestReview&&!busy)await loadPhoneTest(phoneTestReview.id).catch(e=>{closePhoneTest();msg(e.message);});if(review&&!busy)await loadReview(review.id);
 }catch(e){networkFresh=false;OrbyUI.clear();$('connection').textContent='Offline';$('connection').classList.remove('online');msg(e.message);if(review){review.status='offline';$('review-status').textContent='Request unavailable. Reconnect and refresh before answering.';}}
 finally{polling=false;buttons();phoneTestButtons();}
}
$('connect').onclick=async()=>{if(!window.PublicKeyCredential||!navigator.credentials){msg('Use current Safari on an iPhone with a screen lock and passkeys enabled.');return;}$('connect').disabled=true;try{const start=await api('/web/pair/options',{invite:$('invite').value.trim(),name:$('name').value.trim()},'POST',null),o=start.options;const publicKey={...o,challenge:raw(o.challenge),user:{...o.user,id:raw(o.user.id)},excludeCredentials:(o.excludeCredentials||[]).map(c=>({...c,id:raw(c.id)}))};const c=await navigator.credentials.create({publicKey});const result=await api('/web/pair/verify',{id:start.id,response:credentialJSON(c,true)},'POST',null);saved=result;localStorage.setItem('orby.phone.v1',JSON.stringify(saved));$('invite').value='';shell();msg('Compare this fingerprint with the PC, then choose Trust phone there.');await refresh();}catch(e){msg(e.name==='NotAllowedError'?'Passkey creation was cancelled or unavailable. No phone was trusted.':e.message);}finally{$('connect').disabled=false;}};
async function loadReview(id){const next=await api('/web/request/'+encodeURIComponent(id));next.kind=next.kind||'permission';if(!/^[0-9a-f-]{36}$/i.test(next.id)||await hash(next.reviewText)!==next.revision)throw Error('The request text did not match its fingerprint.');if(!review||review.id!==next.id||review.revision!==next.revision){$('read').checked=false;$('answer-text').value='';$('answer-choices').replaceChildren();for(const [index,label] of (next.choices||[]).entries()){const row=document.createElement('label'),input=document.createElement('input');input.type='radio';input.name='question-answer';input.value=String(index);input.onchange=()=>{$('answer-text').value='';buttons();};row.append(input,text('span',label));$('answer-choices').append(row);}}review=next;$('question-response').hidden=next.kind!=='question';$('custom-reply').hidden=!next.canReply;$('custom-unavailable').hidden=next.canReply;$('allow').hidden=next.kind!=='permission';$('deny').hidden=next.kind!=='permission';$('stop-task').hidden=next.kind!=='stop';$('exact').textContent=next.reviewText;const labels={decided:'Recorded. Waiting for the PC acknowledgement.',resolved:'PC resolved the prompt. This does not confirm the action executed.',submitted:'PC submitted the response. Check the PC for the result.',cancelled:'Request cancelled.',expired:'Request expired.',offline:'PC offline.',stale:'Windows could not send this response. The question may have changed. Check the PC before trying again.',uncertain:'PC could not confirm the response. Check the PC.'};$('review-status').textContent=labels[next.status]||'Review this one request before it expires.';buttons();}
async function openReview(id){try{await loadReview(id);$('review').showModal();}catch(e){review=null;msg(e.message);}}
function buttons(){const active=!!review&&review.status==='pending'&&review.expiresAt>Date.now()/1000&&networkFresh&&!busy;$('allow').disabled=!active||!$('read').checked;$('deny').disabled=!active;$('stop-task').disabled=!active||!$('read').checked;$('send-answer').disabled=!active||!$('read').checked||!($('answer-text').value.trim()||document.querySelector('#answer-choices input:checked'));}
function closeReview(){auth?.abort();auth=null;review=null;$('read').checked=false;$('review').close();}
$('close').onclick=closeReview;$('review').addEventListener('cancel',closeReview);$('read').onchange=buttons;
async function decide(decision,answer){if(!review||busy)return;const r=review;busy=true;buttons();try{if(r.expiresAt<=Date.now()/1000)throw Error('The request expired.');const nonce=crypto.randomUUID(),canonical=['OrbyPhone.v1',saved.deviceId,r.id,r.revision,decision,nonce,String(r.expiresAt)].join('\n');auth=new AbortController();const c=await navigator.credentials.get({signal:auth.signal,publicKey:{challenge:await sha(canonical),rpId:location.hostname,allowCredentials:[{type:'public-key',id:raw(r.credentialId)}],userVerification:'required',timeout:60000}});if(!review||review.id!==r.id||r.expiresAt<=Date.now()/1000)throw Error('Review closed or expired. Nothing sent.');await api('/web/request/'+r.id+'/decision',{revision:r.revision,decision,...(answer!==undefined?{answer}:{}),nonce,expiresAt:r.expiresAt,response:credentialJSON(c,false)});$('read').checked=false;review.status='decided';$('review-status').textContent='Recorded. Waiting for the PC acknowledgement.';await refresh();}catch(e){$('review-status').textContent=e.name==='NotAllowedError'||e.name==='AbortError'?'Phone confirmation cancelled. No new decision was sent.':e.message;}finally{busy=false;auth=null;buttons();}}
$('allow').onclick=()=>decide('allow');$('deny').onclick=()=>decide('deny');$('refresh').onclick=refresh;
$('disconnect').onclick=async()=>{try{await api('/web/pair',null,'DELETE');localStorage.removeItem('orby.phone.v1');saved=null;closeReview();shell();$('connection').textContent='Offline';msg('Phone disconnected.');}catch(e){msg(e.message);}};
document.addEventListener('visibilitychange',()=>{if(document.hidden){$('read').checked=false;$('phone-test-read').checked=false;networkFresh=false;buttons();phoneTestButtons();}else refresh();});window.addEventListener('online',refresh);window.addEventListener('offline',()=>{networkFresh=false;buttons();phoneTestButtons();OrbyUI.clear();$('connection').textContent='Offline';msg('Phone offline. No current task or permission status.');});OrbyUI.setCallbacks({review:openReview,check:confirmConnectionCheck,busy:()=>busy,test:openPhoneTest});setInterval(refresh,3000);setInterval(()=>{buttons();phoneTestButtons();},1000);shell();refresh();

async function confirmConnectionCheck(id){
 if(busy||!saved)return;busy=true;buttons();
 try{
  const c=await api('/web/check/'+encodeURIComponent(id));
  if(c.id!==id||c.status!=='pending'||c.expiresAt<=Date.now()/1000||await hash(c.reviewText)!==c.revision)throw Error('Connection test expired or changed.');
  const nonce=crypto.randomUUID(),decision='deny',canonical=['OrbyPhone.v1',saved.deviceId,c.id,c.revision,decision,nonce,String(c.expiresAt)].join('\n');
  const credential=await navigator.credentials.get({publicKey:{challenge:await sha(canonical),rpId:location.hostname,allowCredentials:[{type:'public-key',id:raw(c.credentialId)}],userVerification:'required',timeout:60000}});
  await api('/web/check/'+id+'/decision',{revision:c.revision,decision,nonce,expiresAt:c.expiresAt,response:credentialJSON(credential,false)});
  msg('Test denial signed. Waiting for Windows verification. No action was requested.');
 }catch(e){msg(e.name==='NotAllowedError'?'Test confirmation cancelled.':e.message);}
 finally{busy=false;buttons();await refresh();}
}

let pushCheckedAt=0,pushBusy=false,pushWasEnabled=null;
const swReady='serviceWorker' in navigator?navigator.serviceWorker.register('/iphone/sw.js',{scope:'/iphone/'}).then(()=>navigator.serviceWorker.ready):Promise.resolve(null);
swReady.catch(()=>{});
navigator.serviceWorker?.addEventListener('message',event=>{if(event.data?.type==='orby-test'&&event.data.id){requestedTest=event.data.id;void refresh();return;}if(event.data?.type==='orby-request'&&event.data.id){requestedReview=event.data.id;void refresh();}});
async function updatePushControls(force=false){
 if(pushBusy||!saved||!force&&Date.now()-pushCheckedAt<30000)return;pushCheckedAt=Date.now();
 try{const p=await api('/web/push/config');$('push-label').textContent='Phone alerts · '+(p.enabled?'On':'Set up');if(p.enabled&&pushWasEnabled!==true)$('notifications').open=false;else if(!p.enabled&&pushWasEnabled===null)$('notifications').open=true;pushWasEnabled=p.enabled;$('test-push').hidden=!p.enabled;$('disable-push').hidden=!p.enabled;$('enable-push').textContent=p.enabled?'Save notification settings':'Enable notifications';if(!pushBusy){$('away-only').checked=p.settings.awayOnly;$('activity-alerts').checked=p.settings.activity;}
 const standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
 $('push-status').textContent=!p.available?'Notifications are being prepared.':p.enabled?'Notifications enabled. Tap a request alert to review and answer it.':!standalone&&/iPhone|iPad|iPod/.test(navigator.userAgent)?'Use Share → Add to Home Screen, open the Orby icon and connect there, then enable notifications.':'Enable alerts for unanswered requests and project updates.';
 }catch(e){$('push-status').textContent=e.message;}
}
$('enable-push').onclick=async()=>{
 if(pushBusy)return;pushBusy=true;
 try{if(!('Notification' in window)||!('PushManager' in window))throw Error('Open Orby from its iPhone Home Screen icon to enable notifications.');
 const permission=await Notification.requestPermission();if(permission!=='granted')throw Error('Notifications were not allowed. You can change this in iPhone Settings.');
 const registration=await swReady;if(!registration)throw Error('Phone notification worker unavailable. Refresh this app.');
 const config=await api('/web/push/config');if(!config.available)throw Error('Notification delivery is not configured.');
 const subscription=await registration.pushManager.getSubscription()||await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:raw(config.publicKey)});
 await api('/web/push/subscribe',{subscription:subscription.toJSON(),awayOnly:$('away-only').checked,activity:$('activity-alerts').checked});pushCheckedAt=0;
 }catch(e){$('push-status').textContent=e.message;msg(e.message);}finally{pushBusy=false;await updatePushControls(true);}
};
$('test-push').onclick=async()=>{try{const r=await api('/web/push/test',{delaySeconds:10});msg(r.status==='queued'?'Test scheduled in ten seconds. Lock your iPhone now to check the notification.':r.status==='accepted'?'Test notification accepted for delivery. Check your iPhone banner or Lock Screen.':'The notification was not accepted: '+r.status);}catch(e){msg(e.message);}};
$('disable-push').onclick=async()=>{try{await api('/web/push/subscribe',null,'DELETE');const r=await swReady;const s=await r?.pushManager.getSubscription();await s?.unsubscribe();await updatePushControls(true);}catch(e){msg(e.message);}};

$('answer-text').oninput=()=>{for(const radio of $('answer-choices').querySelectorAll('input'))radio.checked=false;buttons();};
$('send-answer').onclick=async()=>{if(!review||review.kind!=='question'||!$('read').checked)return;const answer=$('answer-text').value;if(answer.trim()){if(!review.canReply)return;await decide('reply:'+await hash(answer),answer);}else{const choice=$('answer-choices').querySelector('input:checked');if(choice)await decide('choice:'+choice.value);}};

$('stop-task').onclick=()=>{if(review?.kind==='stop'&&$('read').checked)void decide('stop');};



async function loadPhoneTest(id){
 const next=await api('/web/phone-test/'+encodeURIComponent(id));if(!/^[0-9a-f-]{36}$/i.test(next.id)||next.id!==id||await hash(next.reviewText)!==next.revision)throw Error('Phone test text did not match its fingerprint.');
 if(!phoneTestReview||phoneTestReview.id!==next.id||phoneTestReview.revision!==next.revision){$('phone-test-read').checked=false;$('phone-test-choices').replaceChildren();for(const [i,label]of(next.choices||[]).entries()){const row=document.createElement('label'),radio=document.createElement('input');radio.type='radio';radio.name='phone-test-choice';radio.value=String(i);radio.onchange=phoneTestButtons;row.append(radio,text('span',label));$('phone-test-choices').append(row);}}
 phoneTestReview=next;$('phone-test-exact').textContent=next.reviewText;$('phone-test-status').textContent=next.status==='verified'?'Windows verified your reply. Test passed. No action ran.':next.status==='failed'?'Windows could not verify the reply.':next.status==='decided'?'Reply recorded. Waiting for Windows verification.':'Choose one test reply, then confirm with your passkey.';phoneTestButtons();
}
async function openPhoneTest(id){try{await loadPhoneTest(id);if(!$('phone-test').open)$('phone-test').showModal();}catch(e){phoneTestReview=null;msg(e.message);}}
function phoneTestButtons(){$('send-phone-test').disabled=!phoneTestReview||phoneTestReview.status!=='pending'||phoneTestReview.expiresAt<=Date.now()/1000||!networkFresh||busy||!$('phone-test-read').checked||!document.querySelector('#phone-test-choices input:checked');}
function closePhoneTest(){phoneTestAuth?.abort();phoneTestAuth=null;phoneTestReview=null;$('phone-test-read').checked=false;if($('phone-test').open)$('phone-test').close();}
$('close-phone-test').onclick=closePhoneTest;$('phone-test').addEventListener('cancel',closePhoneTest);$('phone-test-read').onchange=phoneTestButtons;
$('send-phone-test').onclick=async()=>{
 if(!phoneTestReview||busy||$('send-phone-test').disabled)return;const t=phoneTestReview,radio=document.querySelector('#phone-test-choices input:checked');if(!radio)return;busy=true;buttons();phoneTestButtons();
 try{if(t.expiresAt<=Date.now()/1000)throw Error('Phone test expired.');const decision='choice:'+radio.value,nonce=crypto.randomUUID(),canonical=['OrbyPhone.v1',saved.deviceId,t.id,t.revision,decision,nonce,String(t.expiresAt)].join('\n');phoneTestAuth=new AbortController();const credential=await navigator.credentials.get({signal:phoneTestAuth.signal,publicKey:{challenge:await sha(canonical),rpId:location.hostname,allowCredentials:[{type:'public-key',id:raw(t.credentialId)}],userVerification:'required',timeout:60000}});if(!phoneTestReview||phoneTestReview.id!==t.id||t.expiresAt<=Date.now()/1000)throw Error('Phone test closed or expired.');await api('/web/phone-test/'+t.id+'/decision',{revision:t.revision,decision,nonce,expiresAt:t.expiresAt,response:credentialJSON(credential,false)});phoneTestReview.status='decided';$('phone-test-read').checked=false;$('phone-test-status').textContent='Reply recorded. Waiting for Windows verification. No action will run.';
 }catch(e){$('phone-test-status').textContent=e.name==='NotAllowedError'||e.name==='AbortError'?'Confirmation cancelled. No test reply was sent.':e.message;}
 finally{busy=false;phoneTestAuth=null;buttons();phoneTestButtons();}
};

window.addEventListener('hashchange',()=>{const params=new URLSearchParams(location.hash.slice(1));requestedTest=params.get('test');requestedReview=params.get('request');if(location.hash)history.replaceState(null,'',location.pathname);void refresh();});
