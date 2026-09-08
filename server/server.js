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
const fs = require('fs');
const path = require('path');

// ---------------------- Configuration ----------------------
const PORT = process.env.PORT || 8000;
const SOURCE_PASSWORD = process.env.SOURCE_PASSWORD || 'tantsaha_source_2026';
const STATION_NAME = "Radio TV An'ny Tantsaha";
// Taille du "tampon de démarrage" gardé en mémoire pour que les nouveaux
// auditeurs entendent le son immédiatement au lieu d'un silence.
const BURST_BUFFER_MAX_BYTES = 400 * 1024; // ~ quelques secondes de MP3 128kbps
const PUBLIC_DIR = path.join(__dirname, '..', 'public');

// ---------------------- État en mémoire ----------------------
let listeners = new Set();      // réponses HTTP des auditeurs connectés
let sourceReq = null;           // requête HTTP du diffuseur (ffmpeg) actif
let isLive = false;
let liveSince = null;
let recentChunks = [];          // tampon "burst" pour les nouveaux auditeurs
let recentBytes = 0;
let currentTitle = '';

function log(...args) {
  console.log(`[${new Date().toLocaleTimeString()}]`, ...args);
}

// ---------------------- Gestion de la source (le diffuseur) ----------------------
function handleSource(req, res, query) {
  if (query.get('key') !== SOURCE_PASSWORD) {
    res.writeHead(401, { 'Content-Type': 'text/plain' });
    res.end('Mot de passe de diffusion invalide.');
    log('Tentative de connexion refusée (mauvais mot de passe)');
    return;
  }

  if (sourceReq) {
    res.writeHead(409, { 'Content-Type': 'text/plain' });
    res.end('Une diffusion est déjà en cours sur ce serveur.');
    log('Connexion source refusée : déjà en direct');
    return;
  }

  sourceReq = req;
  isLive = true;
  liveSince = Date.now();
  recentChunks = [];
  recentBytes = 0;
  log('🔴 Diffusion DÉMARRÉE — flux audio en direct');

  // Le serveur garde cette requête ouverte tant que ffmpeg envoie des données.
  req.on('data', (chunk) => {
    // Alimente le tampon de démarrage (ring buffer)
    recentChunks.push(chunk);
    recentBytes += chunk.length;
    while (recentBytes > BURST_BUFFER_MAX_BYTES && recentChunks.length > 1) {
      recentBytes -= recentChunks[0].length;
      recentChunks.shift();
    }
    // Redistribue immédiatement le morceau à chaque auditeur connecté
    for (const listenerRes of listeners) {
      // si un auditeur est trop lent (backpressure), on ne bloque pas les autres
      if (!listenerRes.write(chunk)) {
        // écriture mise en file, Node gérera tout seul le drain
      }
    }
  });

  const endSource = () => {
    if (sourceReq === req) {
      sourceReq = null;
      isLive = false;
      liveSince = null;
      recentChunks = [];
      recentBytes = 0;
      currentTitle = '';
      log('⏹️  Diffusion ARRÊTÉE');
    }
    // Ferme proprement la réponse HTTP vers ffmpeg/curl, sinon la connexion
    // reste ouverte indéfiniment en attente d'une fin de réponse.
    if (!res.writableEnded) {
      try { res.end('OK'); } catch (e) { /* déjà fermé */ }
    }
  };
  req.on('end', endSource);
  req.on('close', endSource);
  req.on('error', endSource);
  res.on('error', endSource);

  // L'entête part tout de suite ; le corps de la réponse ne sera
  // envoyé (res.end) que lorsque la source se termine (voir endSource).
  res.writeHead(200, { 'Content-Type': 'text/plain' });
}

// ---------------------- Gestion d'un auditeur ----------------------
function handleListener(req, res) {
  res.writeHead(200, {
    'Content-Type': 'audio/mpeg',
    'Transfer-Encoding': 'chunked',
    'Cache-Control': 'no-cache, no-store',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
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

  if (req.method === 'GET' && url.pathname === '/status') {
    return handleStatus(res);
  }

  if (req.method === 'GET') {
    return serveStatic(url.pathname, res);
  }

  res.writeHead(405, { 'Content-Type': 'text/plain' });
  res.end('Méthode non autorisée');
});

server.listen(PORT, () => {
  log(`✅ Serveur "${STATION_NAME}" prêt`);
  log(`   Lecteur web  : http://localhost:${PORT}/`);
  log(`   Entrée source: http://localhost:${PORT}/source?key=${SOURCE_PASSWORD}`);
  log(`   Flux auditeur: http://localhost:${PORT}/stream`);
  log(`   Statut JSON  : http://localhost:${PORT}/status`);
});
