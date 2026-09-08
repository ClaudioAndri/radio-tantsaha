# Radio TV An'ny Tantsaha — Serveur de diffusion 100% maison

Ici, **plus aucun logiciel tiers de streaming** (pas d'Icecast, pas de Shoutcast) : le serveur qui reçoit et redistribue le son est un script Node.js écrit pour ce projet, `server/server.js`. Tu le contrôles entièrement.

```
[Ton PC de diffusion]  --(câble audio virtuel)-->  [ffmpeg]  --(HTTP PUT)-->  [server.js (notre serveur)]  --(HTTP)-->  [Navigateur des auditeurs]
```

Le serveur fait 3 choses, et rien d'autre :
1. Il accepte une connexion "source" (ton ffmpeg) sur `/source` et lit le flux audio au fur et à mesure.
2. Il retransmet chaque petit morceau reçu à tous les auditeurs connectés sur `/stream`.
3. Il sert la page du lecteur web (`public/index.html`) sur `/`.

---

## Ce dont tu as besoin

| Outil | Rôle | Où l'avoir |
|---|---|---|
| **Node.js** (v18+) | fait tourner `server.js` | https://nodejs.org |
| **ffmpeg** | capture le son et l'envoie au serveur | https://ffmpeg.org/download.html |
| **Câble audio virtuel** | fait sortir le son "système" comme une entrée micro | VB-Cable (Windows) / BlackHole (macOS) / sink virtuel (Linux) |

Aucune installation de base de données, aucun `npm install` : `server.js` n'utilise que les modules natifs de Node.

---

## Étape 1 — Démarrer le serveur

Dans le dossier du projet :

```bash
node server/server.js
```

Tu dois voir :
```
✅ Serveur "Radio TV An'ny Tantsaha" prêt
   Lecteur web  : http://localhost:8000/
   Entrée source: http://localhost:8000/source?key=tantsaha_source_2026
   Flux auditeur: http://localhost:8000/stream
   Statut JSON  : http://localhost:8000/status
```

Ouvre `http://localhost:8000/` dans ton navigateur : tu dois voir le lecteur (le bouton "soleil" affichera "Hors ligne" tant que rien n'est diffusé — c'est normal).

⚠️ Change `SOURCE_PASSWORD` dans `server/server.js` (ou passe-le en variable d'environnement `SOURCE_PASSWORD=...`) avant toute mise en ligne publique.

---

## Étape 2 — Installer le câble audio virtuel

C'est ce qui permet de "capturer" ce que joue ton PC pour l'envoyer au serveur.

- **Windows** → [VB-Audio Virtual Cable](https://vb-audio.com/Cable/) (gratuit)
- **macOS** → [BlackHole 2ch](https://existential.audio/blackhole/) (gratuit)
- **Linux** → `pactl load-module module-null-sink sink_name=virtual-cable`

Mets ensuite ce câble virtuel comme sortie audio par défaut de ton PC (ou route ton logiciel de diffusion vers lui) : le son ne sort plus par les haut-parleurs, il passe "dans le câble", prêt à être capté par ffmpeg.

---

## Étape 3 — Lancer la diffusion (ffmpeg → notre serveur)

Le serveur doit déjà tourner (étape 1). Ensuite :

1. Ouvre `broadcast/diffuser-windows.bat` (ou `diffuser-mac-linux.sh`) et vérifie :
   - `INPUT_DEVICE` : nom exact de ton câble virtuel
     - Windows : `ffmpeg -list_devices true -f dshow -i dummy`
     - Linux : `pactl list sources short`
   - `SOURCE_PASSWORD` : le même que dans `server.js`
2. Lance le script (double-clic, ou `chmod +x diffuser-mac-linux.sh && ./diffuser-mac-linux.sh` sur Mac/Linux).
3. Dans le terminal du serveur (étape 1), tu dois voir apparaître :
   ```
   🔴 Diffusion DÉMARRÉE — flux audio en direct
   ```

Retourne sur `http://localhost:8000/`, clique sur le soleil : tu t'écoutes en direct, via ton propre serveur.

### Comment ça marche techniquement
ffmpeg envoie le flux MP3 en `HTTP PUT` (avec transfert "chunked", donc sans taille connue à l'avance) vers `/source?key=...`. Notre serveur lit ces morceaux au fil de l'eau avec l'API `http` native de Node, et les recopie immédiatement dans la réponse HTTP de chaque auditeur connecté sur `/stream` — un `<audio>` HTML lit ça comme un flux continu, exactement comme il lirait un fichier MP3.

---

## Étape 4 — Passer en ligne, sans écrire une ligne de commande

Si tu n'es pas à l'aise avec les VPS et les lignes de commande, la solution la plus simple est **Render.com** : c'est gratuit (aucune carte bancaire requise), ça se connecte directement à GitHub, et il détecte automatiquement comment démarrer ce projet grâce à `package.json` — tu n'as rien à configurer.

1. Crée un compte sur **github.com** et dépose-y le dossier `tantsaha-radio` (bouton "uploading an existing file", glisser-déposer).
2. Crée un compte sur **render.com**, connecte-toi avec GitHub en un clic.
3. Clique "New +" → "Web Service", choisis ton repository `tantsaha-radio`.
4. Render déploie automatiquement (`node server/server.js` est déjà indiqué dans `package.json`). Après 1-2 minutes, tu obtiens un lien du style `https://tantsaha-radio.onrender.com`.
5. Sur **ton PC de diffusion**, dans `broadcast/diffuser-windows.bat` (ou `-mac-linux.sh`), remplace `SERVER_HOST=localhost` par `SERVER_HOST=tantsaha-radio.onrender.com` (sans le `https://`), et lance le script.
6. Partage le lien `https://tantsaha-radio.onrender.com` à tes auditeurs.

⚠️ **Deux limites à connaître sur le plan gratuit de Render** (vérifiées en septembre 2026) :
- Le service s'endort après 15 minutes sans aucune requête, et met 30 à 60 secondes à se réveiller à la prochaine visite. Tant que tu diffuses (le flux ffmpeg envoie des requêtes en continu), il reste éveillé.
- Le plan gratuit inclut 750 heures de fonctionnement par mois — largement suffisant pour une radio qui n'émet pas 24h/24, mais pas pour un flux permanent H24. Pour du "toujours allumé", il faut passer au plan payant (~7$/mois).

Cette étape ne remplace pas l'étape 3 : le script `diffuser-*` doit toujours tourner sur **ton** ordinateur, celui qui joue réellement la musique — c'est la seule partie qui ne peut jamais aller dans le cloud, car c'est la seule machine qui a accès à ton vrai son.

### Avec un VPS classique (si tu préfères garder le contrôle total)

1. Loue un petit **VPS** Linux (OVH, Contabo, DigitalOcean, ~5$/mois).
2. Installe Node.js dessus, copie le dossier `server/` (et `public/`), lance `node server/server.js` (idéalement avec `pm2` ou un service systemd pour qu'il redémarre tout seul).
3. Ouvre le port **8000** dans le pare-feu du VPS.
4. Sur **ton PC de diffusion**, dans le script de l'étape 3, remplace :
   ```
   SERVER_HOST=IP_OU_DOMAINE_DE_TON_VPS
   ```
   → ton PC envoie alors son flux vers le VPS, même si toi tu restes chez toi.
5. Tes auditeurs ouvrent simplement `http://IP_OU_DOMAINE_DE_TON_VPS:8000/` — c'est le serveur qui sert directement la page ET le flux, pas besoin d'hébergement séparé.

### Pour aller plus loin (optionnel)
- **HTTPS** : mets un reverse-proxy Nginx/Caddy devant le port 8000 pour avoir un certificat SSL et un vrai nom de domaine.
- **pm2** : `npm i -g pm2 && pm2 start server/server.js --name tantsaha-radio` pour qu'il redémarre automatiquement si le serveur reboote ou plante.
- **Plusieurs auditeurs en même temps** : le serveur gère déjà ça nativement (chaque auditeur = une connexion HTTP indépendante dans le `Set` `listeners`), pas de configuration supplémentaire nécessaire jusqu'à quelques centaines d'auditeurs simultanés.

---

## Lecture en arrière-plan (mobile, onglet minimisé, écran verrouillé)

Le lecteur intègre maintenant :
- **Media Session API** : le titre de la radio et des boutons play/pause apparaissent sur l'écran verrouillé et dans les notifications média (Android et iOS), comme pour Spotify ou YouTube Music.
- **Reconnexion automatique** : si le flux est coupé (mise en arrière-plan prolongée, changement de réseau...), le lecteur retente la connexion tout seul, jusqu'à 8 fois, sans que l'auditeur ait à rappuyer sur le bouton.
- **Application installable (PWA)** : sur mobile, l'auditeur peut faire "Ajouter à l'écran d'accueil" — l'app s'ouvre alors comme une vraie application, ce qui améliore encore la fiabilité de la lecture en arrière-plan (surtout sur iOS).

Rien à configurer : ces 3 fichiers s'en occupent — `public/manifest.json`, `public/sw.js` (service worker), et `public/icons/`.

⚠️ Une limite reste incontournable, quel que soit le support : si l'utilisateur **ferme complètement l'onglet** (ou tue l'app), la lecture s'arrête — aucune techno web ne peut faire jouer du son après la fermeture réelle de la page.

---

## Dépannage rapide

| Problème | Piste |
|---|---|
| "Impossible de se connecter" sur le lecteur | Le serveur (`node server.js`) ou le script de diffusion n'est pas lancé |
| `409 Une diffusion est déjà en cours` | Arrête l'ancien processus ffmpeg (ou redémarre `server.js`) avant d'en relancer un |
| `401 Mot de passe invalide` | `SOURCE_PASSWORD` ne correspond pas entre `server.js` et le script `diffuser-*` |
| ffmpeg ne trouve pas le périphérique | Corrige `INPUT_DEVICE` avec le nom exact retourné par la commande de listing (étape 3) |
| Léger silence puis coupure au tout début de la lecture | Normal une fraction de seconde le temps que le tampon "burst" se remplisse ; augmente `BURST_BUFFER_MAX_BYTES` dans `server.js` si besoin |
