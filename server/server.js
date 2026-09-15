/**
 * ============================================================
 *  RADIO TV AN'NY TANTSAHA — Serveur de diffusion audio maison
 *  ------------------------------------------------------------
 *  Aucune dépendance externe (pas d'Icecast, pas de Shoutcast,
 *  pas de npm install) : uniquement les modules natifs de Node.js.
 *
 *  Ce serveur fait 3 choses :
 *    1) Reçoit le flux audio envoyé par ffmpeg  -> POST/PUT /source
 *    2) Le redistribue en direct à tous les auditeurs -> GET /stream
 *    3) Sert la page du lecteur web -> GET /
 *
 *  Lancement :  node server.js
 * ============================================================
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// ---------------------- Configuration ----------------------
const PORT = process.env.PORT || 8000;
const SOURCE_PASSWORD = process.env.SOURCE_PASSWORD || 'tantsaha_source_2026';
const STATION_NAME = "Radio An'ny Tantsaha";
// Taille du "tampon de démarrage" gardé en mémoire pour que les nouveaux
// auditeurs entendent le son immédiatement au lieu d'un silence.
// ⚠️ Ne pas mettre trop gros : ce tampon est envoyé d'un coup à la connexion,
// donc plus il est gros, plus l'auditeur démarre "en retard" sur le direct.
// 40 Ko ≈ 1 seconde de MP3 à 320kbps : largement assez pour éviter un silence,
// sans ajouter de latence perceptible.
const BURST_BUFFER_MAX_BYTES = 40 * 1024;
const PUBLIC_DIR = path.join(__dirname, '..', 'public');

// ---------------------- État en mémoire ----------------------
let listeners = new Set();      // réponses HTTP des auditeurs connectés
let sourceReq = null;           // requête HTTP du diffuseur (ffmpeg) actif
let retireActiveSource = null;  // fonction qui désactive la diffusion de la source active
let isLive = false;
let liveSince = null;
let recentChunks = [];          // tampon "burst" pour les nouveaux auditeurs
let recentBytes = 0;
let currentTitle = '';

function log(...args) {
  console.log(`[${new Date().toLocaleTimeString()}]`, ...args);
}

// ---------------------- Gestion de la source (le diffuseur) ----------------------
// Supporte la "relève sans coupure" : si une nouvelle connexion source arrive
// pendant qu'une autre diffuse déjà, on ne la rejette plus (409) — on la
// laisse prendre le relais immédiatement, pendant que l'ancienne termine
// tranquillement en arrière-plan. Comme les auditeurs ne sont JAMAIS
// déconnectés pendant ce chevauchement (le flux continue sans interruption
// entre les deux sources), il n'y a plus aucune coupure perceptible tant
// que le script de diffusion démarre la nouvelle connexion un peu avant
// que l'ancienne n'atteigne sa limite de durée (-t) côté ffmpeg.
function handleSource(req, res, query) {
  if (query.get('key') !== SOURCE_PASSWORD) {
    res.writeHead(401, { 'Content-Type': 'text/plain' });
    res.end('Mot de passe de diffusion invalide.');
    log('Tentative de connexion refusée (mauvais mot de passe)');
    return;
  }

  const takingOver = !!sourceReq;
  const state = { retired: false };

  if (takingOver && retireActiveSource) {
    // Désactive IMMÉDIATEMENT la diffusion de l'ancienne source : elle
    // continue de recevoir des données (on la laisse se terminer
    // tranquillement) mais elles ne sont plus jamais rediffusées.
    // Sans cette ligne, les deux sources étaient envoyées en même temps
    // pendant tout le chevauchement, d'où le son superposé.
    retireActiveSource();
  }

  sourceReq = req; // cette connexion devient la source active
  retireActiveSource = () => { state.retired = true; };
  isLive = true;
  if (!liveSince) liveSince = Date.now();
  if (!takingOver) {
    recentChunks = [];
    recentBytes = 0;
  }
  if (req.socket) req.socket.setNoDelay(true);
  log(takingOver
    ? '🔁 Relève sans coupure — une nouvelle connexion prend le relais'
    : '🔴 Diffusion DÉMARRÉE — flux audio en direct');

  req.on('data', (chunk) => {
    if (state.retired) return; // cette source a été relevée : on ignore ses données
    recentChunks.push(chunk);
    recentBytes += chunk.length;
    while (recentBytes > BURST_BUFFER_MAX_BYTES && recentChunks.length > 1) {
      recentBytes -= recentChunks[0].length;
      recentChunks.shift();
    }
    for (const listenerRes of listeners) {
      listenerRes.write(chunk);
    }
  });

  const endThisSource = () => {
    if (state.retired) return; // déjà traité (Node peut émettre 'end' ET 'close')
    state.retired = true;
    if (sourceReq === req) {
      // C'était la source active (pas une ancienne connexion relevée) :
      // plus personne ne diffuse, on coupe proprement les auditeurs.
      sourceReq = null;
      retireActiveSource = null;
      isLive = false;
      liveSince = null;
      recentChunks = [];
      recentBytes = 0;
      currentTitle = '';
      log('⏹️  Diffusion ARRÊTÉE');
      for (const listenerRes of listeners) {
        try { listenerRes.end(); } catch (e) { /* déjà fermé */ }
      }
      listeners.clear();
    } else {
      log('🔚 Ancienne connexion (relevée) refermée proprement — diffusion toujours en cours');
    }
    if (!res.writableEnded) {
      try { res.end('OK'); } catch (e) { /* déjà fermé */ }
    }
  };
  req.on('end', endThisSource);
  req.on('close', endThisSource);
  req.on('error', endThisSource);
  res.on('error', endThisSource);

  // L'entête part tout de suite ; le corps de la réponse ne sera
  // envoyé (res.end) que lorsque la source se termine (voir endSource).
  res.writeHead(200, { 'Content-Type': 'text/plain' });
}

// ---------------------- Gestion d'un auditeur ----------------------
function handleListener(req, res) {
  // Désactive l'algorithme de Nagle : sans ça, le système d'exploitation
  // peut retarder l'envoi de petits paquets de quelques dizaines à
  // quelques centaines de ms en attendant d'en accumuler plus.
  if (req.socket) req.socket.setNoDelay(true);

  res.writeHead(200, {
    'Content-Type': 'audio/mpeg',
    'Transfer-Encoding': 'chunked',
    'Cache-Control': 'no-cache, no-store',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
    // Empêche un éventuel proxy intermédiaire (type Nginx) de mettre en
    // tampon la réponse avant de la relayer, ce qui ajouterait de la latence
    'X-Accel-Buffering': 'no',
  });

  // Envoie tout de suite le tampon récent pour éviter un silence au début
  for (const chunk of recentChunks) res.write(chunk);

  listeners.add(res);
  log(`👂 Nouvel auditeur connecté (total : ${listeners.size})`);

  const cleanup = () => {
    if (listeners.delete(res)) {
      log(`👋 Auditeur déconnecté (total : ${listeners.size})`);
    }
  };
  req.on('close', cleanup);
  res.on('error', cleanup);
}

// ---------------------- Statut JSON (pour le lecteur web) ----------------------
function handleStatus(res) {
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify({
    station: STATION_NAME,
    live: isLive,
    listeners: listeners.size,
    liveSince,
    title: currentTitle,
  }));
}

// ---------------------- Petit serveur de fichiers statiques ----------------------
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.json': 'application/manifest+json',
  '.ico': 'image/x-icon',
};

function serveStatic(reqPath, res) {
  let filePath = reqPath === '/' ? '/index.html' : reqPath;
  filePath = path.join(PUBLIC_DIR, filePath);

  // sécurité basique : empêche de sortir du dossier public/
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403); res.end('Interdit'); return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Page non trouvée');
      return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
}

// ---------------------- Serveur HTTP principal ----------------------
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return;
  }

  if ((req.method === 'PUT' || req.method === 'POST') && url.pathname === '/source') {
    return handleSource(req, res, url.searchParams);
  }

  if (req.method === 'GET' && url.pathname === '/stream') {
    return handleListener(req, res);
  }

  if (req.method === 'GET' && url.pathname === '/ping') {
    res.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' });
    res.end('pong');
    return;
  }

  if (req.method === 'GET' && url.pathname === '/status') {
    return handleStatus(res);
  }

  if (req.method === 'GET') {
    return serveStatic(url.pathname, res);
  }

  res.writeHead(405, { 'Content-Type': 'text/plain' });
  res.end('Méthode non autorisée');
});

// ---------------------------------------------------------------
// Auto-ping anti-veille : Render (plan gratuit) met le service en
// pause après 15 min sans requête entrante. On s'auto-appelle toutes
// les 10 minutes (donc toujours avant les 15 min fatidiques) pour
// que ça n'arrive jamais. Ne fait rien en local : RENDER_EXTERNAL_URL
// n'existe que sur Render, fourni automatiquement par la plateforme.
// ⚠️ Ceci évite la mise en veille par inactivité — ce n'est PAS lié
// aux coupures qui peuvent survenir PENDANT une diffusion active
// (celles-ci sont gérées par la reconnexion automatique du script
// de diffusion, voir broadcast/diffuser-*).
// ---------------------------------------------------------------
const PING_INTERVAL_MS = 10 * 60 * 1000;

function selfPing() {
  const externalUrl = process.env.RENDER_EXTERNAL_URL;
  if (!externalUrl) return;
  const target = externalUrl.replace(/\/+$/, '') + '/ping';
  https.get(target, (res) => {
    log(`🔄 Ping anti-veille envoyé (code ${res.statusCode})`);
    res.resume();
  }).on('error', (err) => {
    log('⚠️  Échec du ping anti-veille :', err.message);
  });
}

if (process.env.RENDER_EXTERNAL_URL) {
  setInterval(selfPing, PING_INTERVAL_MS);
  log(`🔄 Auto-ping activé (toutes les ${PING_INTERVAL_MS / 60000} min) pour éviter la mise en veille Render`);
}

server.listen(PORT, () => {
  log(`✅ Serveur "${STATION_NAME}" prêt`);
  log(`   Lecteur web  : http://localhost:${PORT}/`);
  log(`   Entrée source: http://localhost:${PORT}/source?key=${SOURCE_PASSWORD}`);
  log(`   Flux auditeur: http://localhost:${PORT}/stream`);
  log(`   Statut JSON  : http://localhost:${PORT}/status`);
});
