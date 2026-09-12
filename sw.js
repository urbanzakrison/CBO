const CACHE='cbo-4.2.4';
const CORE=['./','./index.html','./manifest.json','./cbo-icon-192.png','./cbo-icon-512.png'];
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).catch(()=>{}));self.skipWaiting();});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))));self.clients.claim();});
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET') return;
  event.respondWith(fetch(event.request).then(res=>{const copy=res.clone();caches.open(CACHE).then(c=>c.put(event.request,copy)).catch(()=>{});return res;}).catch(()=>caches.match(event.request).then(r=>r||caches.match('./index.html'))));
});
self.addEventListener('push',event=>{
  let data={}; try{data=event.data?event.data.json():{}}catch(_){data={body:event.data?.text?.()||''}}
  const title=data.title||'🏆 Classic Boys Open';
  const options={body:data.body||'En ny CBO-omgång är publicerad.',icon:'./cbo-icon-192.png',badge:'./cbo-icon-192.png',data:{url:data.url||'./'},tag:data.tag||'cbo-winner',renotify:true};
  const tasks=[self.registration.showNotification(title,options)];
  if(String(data.tag||'').startsWith('cbo-clubhouse-') && 'setAppBadge' in self.navigator){
    tasks.push(self.navigator.setAppBadge(1).catch(()=>{}));
  }
  event.waitUntil(Promise.all(tasks));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close(); const target=new URL(event.notification.data?.url||'./',self.location.origin).href;
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{for(const c of list){if(c.url.startsWith(new URL('./',self.registration.scope).href)){c.focus();c.navigate(target);return;} } return clients.openWindow(target);}));
});
