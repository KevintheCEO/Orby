'use strict';
self.addEventListener('install',event=>event.waitUntil(self.skipWaiting()));
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('push',event=>{
 let packet={};try{packet=event.data?.json()||{};}catch{}
 const id=/^[0-9a-f-]{36}$/i.test(packet.requestId||'')?packet.requestId:'',expired=packet.expiresAt&&packet.expiresAt<=Date.now()/1000;
 const n=packet.notification||{};
 // Every push displays a notification. No silent worker polling or approval.
 event.waitUntil(self.registration.showNotification(expired?'Orby update expired':String(n.title||'Orby update').slice(0,90),{body:expired?'Open Orby to check the current status.':String(n.body||'Open Orby for the current project and requests.').slice(0,240),icon:'/iphone/icon.png',badge:'/iphone/icon.png',tag:String(n.tag||'orby-update').slice(0,100),data:{requestId:expired?'':id}}));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();const raw=event.notification.data?.requestId||'',id=/^[0-9a-f-]{36}$/i.test(raw)?raw:'';
 const url=new URL('/iphone/home.html',self.location.origin);if(id)url.hash='request='+id;
 event.waitUntil((async()=>{const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});for(const client of windows){const u=new URL(client.url);if(u.origin===self.location.origin&&u.pathname.startsWith('/iphone/')){client.postMessage({type:'orby-request',id});return client.focus();}}return self.clients.openWindow(url.href);})());
});
