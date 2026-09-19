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

## Étape 2 — Installer un câble audio virtuel

C'est ce qui permet de capter la sortie audio de **RadioBOSS** (ou de n'importe quel logiciel) pour l'envoyer au serveur, sans toucher au son du reste du PC.

- **Windows** → [VB-Audio Virtual Cable](https://vb-audio.com/Cable/) (gratuit, plus simple et plus fiable que VoiceMeeter pour ce besoin précis)
- **macOS** → [BlackHole 2ch](https://existential.audio/blackhole/) (gratuit)
- **Linux** → `pactl load-module module-null-sink sink_name=virtual-cable`

**Important** : n'installe pas VoiceMeeter et ne change pas la sortie audio de Windows entière. Va plutôt dans les **paramètres audio de RadioBOSS lui-même** (Settings → Options → Player/Output selon la version) et choisis **"CABLE Input (VB-Audio Virtual Cable)"** comme périphérique de sortie. Comme ça, seul le son de RadioBOSS part dans le câble — le reste de ton PC continue de sonner normalement sur tes vrais haut-parleurs.

---

## Étape 3 — Choisir le périphérique et lancer la diffusion

1. Double-clique sur **`broadcast/choisir-peripherique.bat`** : il détecte automatiquement tous les périphériques audio disponibles, les affiche dans une liste numérotée (le câble virtuel est repéré automatiquement avec une étoile ★), et enregistre ton choix.
2. Vérifie dans `broadcast/diffuser-windows.bat` que `SOURCE_PASSWORD` correspond bien à celui du serveur (`tantsaha_source_2026` par défaut, déjà pré-rempli).
3. Double-clique sur **`broadcast/diffuser-windows.bat`** pour lancer la diffusion.
4. Dans les logs du serveur (Render, onglet "Logs"), tu dois voir apparaître :
   ```
   🔴 Diffusion DÉMARRÉE — flux audio en direct
   ```

Ouvre ton lien Render, clique sur le soleil : tu entends RadioBOSS en direct.

Pour changer de périphérique plus tard (si tu branches un nouveau micro, changes de logiciel, etc.), relance simplement `choisir-peripherique.bat` — pas besoin de modifier quoi que ce soit à la main.

### Alternative : RadioBOSS en connexion directe (sans câble ni ffmpeg)

RadioBOSS a aussi un système de diffusion Icecast intégré (Settings → Options → Broadcast) qui peut se connecter **directement** à notre serveur, sans passer par un câble virtuel ni ffmpeg :

| Champ | Valeur |
|---|---|
| Type de serveur | Icecast |
| Adresse serveur | `radio-tantsaha.onrender.com` (sans `https://`) |
| Port | `443` |
| SSL/TLS | Activé |
| Point de montage | `/source` |
| Nom d'utilisateur | `source` (ou vide) |
| Mot de passe | `tantsaha_source_2026` |
| Format / Bitrate / Fréquence | MP3 / 320 kbps / 48000 Hz |

⚠️ Non testé en conditions réelles — certains encodeurs Icecast ne supportent pas le SSL/TLS, nécessaire ici car Render n'expose que du HTTPS. Si RadioBOSS affiche une erreur de connexion, reste simplement sur la méthode câble virtuel + ffmpeg ci-dessus, qui elle est garantie de fonctionner.

### Comment ça marche techniquement
ffmpeg envoie le flux MP3 en `HTTP PUT` (avec transfert "chunked", donc sans taille connue à l'avance) vers `/source?key=...` (ou via authentification Icecast standard si RadioBOSS s'y connecte directement). Notre serveur lit ces morceaux au fil de l'eau avec l'API `http` native de Node, et les recopie immédiatement dans la réponse HTTP de chaque auditeur connecté sur `/stream` — un `<audio>` HTML lit ça comme un flux continu, exactement comme il lirait un fichier MP3.

---

## Étape 4 — Passer en ligne, sans écrire une ligne de commande

Si tu n'es pas à l'aise avec les VPS et les lignes de commande, la solution la plus simple est **Render.com** : c'est gratuit (aucune carte bancaire requise), ça se connecte directement à GitHub, et il détecte automatiquement comment démarrer ce projet grâce à `package.json` — tu n'as rien à configurer.

1. Crée un compte sur **github.com** et dépose-y le dossier `tantsaha-radio` (bouton "uploading an existing file", glisser-déposer).
2. Crée un compte sur **render.com**, connecte-toi avec GitHub en un clic.
3. Clique "New +" → "Web Service", choisis ton repository `tantsaha-radio`.
4. Render déploie automatiquement (`node server/server.js` est déjà indiqué dans `package.json`). Après 1-2 minutes, tu obtiens un lien du style `https://tantsaha-radio.onrender.com`.
5. Sur **ton PC de diffusion**, dans `broadcast/diffuser-windows.bat` (ou `-mac-linux.sh`), remplace `SERVER_URL=http://localhost:8000` par `SERVER_URL=https://tantsaha-radio.onrender.com` — attention, avec Render il faut `https://` (pas `http://`) et **pas de numéro de port** : Render n'expose que l'adresse web standard, jamais `:8000` directement. Lance ensuite le script.
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
   SERVER_URL=http://IP_OU_DOMAINE_DE_TON_VPS:8000
   ```
   → ton PC envoie alors son flux vers le VPS, même si toi tu restes chez toi.
5. Tes auditeurs ouvrent simplement `http://IP_OU_DOMAINE_DE_TON_VPS:8000/` — c'est le serveur qui sert directement la page ET le flux, pas besoin d'hébergement séparé.

### Pour aller plus loin (optionnel)
- **HTTPS** : mets un reverse-proxy Nginx/Caddy devant le port 8000 pour avoir un certificat SSL et un vrai nom de domaine.
- **pm2** : `npm i -g pm2 && pm2 start server/server.js --name tantsaha-radio` pour qu'il redémarre automatiquement si le serveur reboote ou plante.
- **Plusieurs auditeurs en même temps** : le serveur gère déjà ça nativement (chaque auditeur = une connexion HTTP indépendante dans le `Set` `listeners`), pas de configuration supplémentaire nécessaire jusqu'à quelques centaines d'auditeurs simultanés.

---

## Lecture automatique et réglages sonores

- **Lecture automatique à l'ouverture** : le lecteur essaie de démarrer le son dès que la page se charge. La plupart des navigateurs bloquent cependant le son tant que l'auditeur n'a pas interagi une première fois avec le site (règle universelle des navigateurs, pas une limite de notre lecteur) — dans ce cas, il retombe simplement sur "appuie sur le soleil", sans message d'erreur.
- **Réglages sonores** (bouton "Réglages sonores" sous le lecteur), personnels à chaque auditeur (stockés seulement dans son navigateur, n'affectent jamais les autres ni le flux d'origine) :
  - **Appliquer un son optimisé** : un bouton qui règle tout en un clic (filtres, égaliseur, loudness, largeur stéréo) vers des valeurs équilibrées — modifiable à la main juste après.
  - **Volume** : de 0 à 150 % (au-delà de 100 %, c'est une amplification numérique — utile si la source est enregistrée trop bas, mais peut légèrement déformer le son si poussé trop fort).
  - **Filtres de protection** : coupe-bas (retire le grondement sourd en dessous de la fréquence choisie) et coupe-haut (adoucit la stridence au-dessus de la fréquence choisie) — les deux sont réglables, désactivés par défaut (valeurs quasi transparentes).
  - **Égaliseur paramétrique 3 bandes** (Graves / Médiums / Aigus) : contrairement à un égaliseur classique à fréquences fixes, ici la fréquence ET le gain de chaque bande sont réglables indépendamment (ex : décider que "les graves" commencent à 100 Hz plutôt qu'à 200 Hz).
  - **Largeur stéréo** : élargit ou resserre l'image stéréo (0% = mono, 100% = normal, jusqu'à 200% = son plus large et enveloppant), via une vraie matrice mid/side construite avec l'API audio du navigateur — l'objectif est un rendu plus riche et immersif, sans utiliser de technologie propriétaire sous licence (Dolby et équivalents restent des marques déposées, non intégrées ici).
  - **Loudness broadcast** : compresseur qui resserre la dynamique pour un son plus constant, comme sur les radios FM classiques (les passages faibles remontent, les pics sont contenus).

## Zéro coupure perceptible : connexions qui se chevauchent

Le serveur accepte une **relève sans coupure**. Concrètement :

- Le script de diffusion lance une **nouvelle** connexion ffmpeg (en arrière-plan) toutes les 260 secondes, **avant** que la précédente (limitée à 300s) ne se termine — il y a donc 40 secondes où les deux tournent en même temps.
- Le serveur bascule instantanément vers la nouvelle connexion dès qu'elle arrive, et laisse l'ancienne se terminer tranquillement en arrière-plan (ses données sont simplement ignorées, pas rediffusées — donc pas de son superposé).
- **Les auditeurs ne sont jamais déconnectés pendant cette transition** — leur connexion HTTP reste ouverte en continu, alimentée sans interruption par l'une ou l'autre source.

Comme plusieurs `ffmpeg` tournent volontairement en parallèle avec cette méthode, utilise **`broadcast/stop-diffusion.bat`** (Windows) pour tout arrêter proprement d'un coup — sur Mac/Linux, un simple `Ctrl+C` suffit (le script s'occupe de tuer tous les processus en arrière-plan).

⚠️ **Point en observation** : avec VoiceMeeter, ce chevauchement (deux `ffmpeg` lisant le même périphérique audio virtuel pendant 40s) peut faire dériver la latence de plusieurs dizaines de secondes au fil des cycles. À surveiller — une version alternative en connexions séquentielles (sans chevauchement, latence stable mais ~1s de blanc toutes les 5 min) est prête si besoin d'y revenir.

## Empêcher la mise en veille de Render (auto-ping)

Le serveur s'auto-ping maintenant tout seul toutes les 10 minutes quand il tourne sur Render (rien à configurer — ça s'active automatiquement grâce à une variable que Render fournit, et ça ne fait rien en local). Ça évite le "spin down" du plan gratuit après 15 minutes sans visiteur, et donc le délai de 30-60 secondes que subirait un auditeur en rouvrant le lien après un moment sans activité.

⚠️ **Important : ceci ne concerne que la mise en veille par inactivité.** Ça ne règle pas d'éventuelles coupures qui surviennent *pendant* une diffusion déjà active (comme celle observée après ~6 minutes de test) — ces coupures-là viennent d'une limite de durée sur les connexions longues, pas d'inactivité, et sont gérées séparément par la reconnexion automatique du script `diffuser-*` (voir plus haut).

Pour une garantie encore plus solide (redondance, au cas où l'auto-ping interne manquerait un cycle après un redéploiement par exemple), tu peux en complément inscrire ton lien sur un service de ping externe et gratuit comme **UptimeRobot** (uptimerobot.com) ou **cron-job.org** : crée un moniteur HTTP pointant vers `https://ton-app.onrender.com/ping`, intervalle 5 minutes. Aucune carte bancaire, 2 minutes de configuration.

## Qualité audio et reconnexion automatique

- **Qualité du flux** : 320 kbps / 48 kHz (qualité quasi-CD), réglé dans les scripts `broadcast/diffuser-*`. Pour changer, modifie `-b:a` (débit) et `-ar` (fréquence d'échantillonnage) dans ces fichiers. Un débit plus élevé consomme plus de données réseau, autant pour toi (émission) que pour tes auditeurs (réception) — 320 kbps convient bien pour du wifi/4G normal, mais pense-y si certains auditeurs ont une connexion très limitée.
- **Reconnexion illimitée, des deux côtés** :
  - Si le **serveur** coupe la diffusion (redémarrage, coupure réseau chez toi...), le script de diffusion retente automatiquement toutes les 3 secondes, indéfiniment, jusqu'à ce que tu fermes la fenêtre toi-même.
  - Si le **lecteur d'un auditeur** perd la connexion, il retente lui aussi automatiquement (délai croissant jusqu'à 15 secondes entre les tentatives) et reprend la lecture tout seul dès que le direct revient — sans que l'auditeur ait besoin de ré-appuyer sur le bouton.

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
| `Error number -10053` / `Conversion failed!` dans ffmpeg, avec une adresse du style `.../:8000/source` | `SERVER_URL` contient une erreur (port `:8000` en trop avec Render, ou `/` en trop à la fin). Avec Render : `https://ton-app.onrender.com` exactement, sans port, sans `/` final |
