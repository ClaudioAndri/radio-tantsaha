// ============================================================
//  Service Worker — Radio TV An'ny Tantsaha
//  Rôle : rendre le lecteur installable et disponible plus vite.
//  IMPORTANT : ne met JAMAIS en cache /stream, /status ou /source
//  car c'est du contenu live — il doit toujours venir du réseau.
// ============================================================

const CACHE_NAME = 'tantsaha-shell-v1';
const LIVE_PATHS = ['/stream', '/status', '/source'];

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Jamais d'interception pour le flux live, le statut, ou la source
  if (LIVE_PATHS.some((p) => url.pathname.startsWith(p))) {
    return;
  }
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      try {
        const fresh = await fetch(event.request);
        cache.put(event.request, fresh.clone());
        return fresh;
      } catch (err) {
        const cached = await cache.match(event.request);
        return cached || Response.error();
      }
    })
  );
});
