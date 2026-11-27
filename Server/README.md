# Serveur Real Pac-Man

L’API Swift/Vapor fournit le catalogue des parcours versionnés et enregistre les
résultats des promenades de manière durable et idempotente. En production, les
données sont stockées dans PostgreSQL via Fluent.

## Développement local

Installez Swift 6.3 (version testée : 6.3.3), Docker et Compose. Depuis `Server/` :

```sh
cp .env.example .env
docker compose up -d db
swift run RealPacmanServer migrate --yes
swift run RealPacmanServer serve --hostname 127.0.0.1 --port 8080
```

La version Debug de l’application exécutée dans le simulateur peut utiliser
`http://127.0.0.1:8080`. Un appareil physique nécessite une adresse HTTPS
accessible : sur le téléphone, localhost désigne le téléphone lui-même.
`GET /health` vérifie l’accès à la base de données. `GET /api/v1/routes` renvoie
la version la plus élevée de chaque parcours. Le parcours du Verney fourni avec
le serveur est un **brouillon**, en version 2, qui propose les modes Explore,
Timed, Ghosts et Timed + ghosts. Sa géométrie, sa provenance et son statut non
vérifié restent inchangés. La version 1 d’origine est conservée pour les résultats
enregistrés avant la mise à jour.

Les variables `DATABASE_URL`, `HOST` et `PORT` configurent le service.
`AUTO_MIGRATE=true` active les migrations au démarrage pour le développement
local. En production, exécutez les migrations explicitement avant le déploiement.
Gardez `.env` privé et choisissez un mot de passe de base de données robuste avant
le déploiement. Compose expose PostgreSQL uniquement sur l’interface de bouclage
de la machine hôte.

<a id="publishing-maps-from-map-builder"></a>

## Publication de cartes depuis Map Builder

Le bouton **Add to Game** de l’éditeur macOS publie le JSON d’une carte via cette
API. L’éditeur ne se connecte jamais directement à PostgreSQL et n’a pas besoin
du mot de passe de la base de données.

1. Déployez ou lancez cette version du serveur. Aucune migration supplémentaire
   n’est nécessaire pour cette fonctionnalité : les cartes utilisent la table
   existante `route_versions`, dont les versions sont immuables.
2. Créez un compte dans le jeu si vous n’en avez pas encore.
3. Dans Map Builder, ouvrez une carte, choisissez **Add to Game**, saisissez l’URL
   de base du serveur et connectez-vous. Si le compte n’est pas autorisé,
   l’éditeur affiche son UUID de joueur. Copiez-le.
4. Sur le serveur, définissez `MAP_PUBLISHER_IDS` avec cet UUID, puis redémarrez
   le serveur. Séparez les UUID par des virgules pour autoriser plusieurs comptes.
   Si la variable est vide ou absente, personne ne peut publier. Sur Render,
   ajoutez-la dans **Environment** du service API. L’autorisation repose sur les
   UUID des comptes existants, et non sur les noms d’utilisateur choisis.
5. Reconnectez-vous dans l’éditeur, vérifiez le serveur, la carte et sa version,
   puis cliquez sur **Add to Game**. Actualisez la liste des cartes dans le jeu
   pour voir la nouvelle carte.

Les deux routes d’administration exigent un jeton Bearer de joueur non expiré
et la présence de son UUID dans la liste des comptes autorisés :

- `GET /api/v1/admin/routes/:routeID` renvoie `{ id, latestVersion, publisher }`.
  `latestVersion` est absent ou nul si la carte est nouvelle.
- `POST /api/v1/admin/routes` accepte un seul objet JSON de carte, de 4 Mo maximum,
  valide sa géométrie et ses paramètres de jeu côté serveur, puis insère une
  version. La réponse est `201 { id, name, version, duplicate: false }` pour une
  nouvelle version, ou `200 { ..., duplicate: true }` pour une nouvelle tentative
  identique. Des données différentes avec le même ID et la même version, ou
  l’ajout d’une version inférieure à la dernière version publiée, renvoient `409`.

Les nouvelles cartes apparaissent immédiatement dans le tableau public renvoyé
par `GET /api/v1/routes`, sans modification du format du catalogue côté jeu.
Pour une mise à jour, conservez l’ID et augmentez la version. Les versions déjà
publiées et leurs résultats ne sont jamais réécrits. Une carte invalide renvoie
`422`, une authentification absente ou expirée `401`, et un compte sans droit de
publication `403`. La mise en cache HTTP est désactivée pour les réponses du
catalogue et de l’administration. Le serveur journalise l’ID du joueur, l’ID de
la carte et sa version, sans identifiants de connexion ni contenu de la carte.

L’éditeur mémorise uniquement l’URL du serveur ; les mots de passe et jetons
restent en mémoire. Il utilise HTTPS, autorise également HTTP sur l’interface de
bouclage en Debug, refuse les redirections et vérifie que la confirmation du
serveur correspond à la carte présentée avant l’envoi.

## Format et validation des résultats

`POST /api/v1/results` accepte le JSON `GameSession` du client, avec un en-tête
`Idempotency-Key` égal à son UUID. Les dates sont exprimées en secondes depuis
le 1er janvier 2001, conformément au comportement par défaut de `JSONEncoder`.
`mode` peut être absent des anciennes sessions Explore ; les valeurs actuelles
sont `explore`, `timed`, `ghosts` et `timedGhosts`. `finishedAt` est obligatoire
pour un résultat envoyé. Les promenades incomplètes et les résultats sans aucune
pastille collectée sont acceptés.

Le serveur charge sa propre version immuable du parcours et exige que la copie
transmise corresponde à cette version. Les ID des pastilles doivent être uniques
et appartenir à ce parcours. Les scores sont recalculés à partir des valeurs
canoniques des pastilles. Les dates doivent être dans l’ordre et ne peuvent pas
être dans le futur au-delà d’une tolérance de cinq minutes de décalage d’horloge.
La distance doit être finie, positive ou nulle, et compatible avec le temps écoulé
et la limite de 12 m/s du client, en tenant compte des dix secondes de fraîcheur
autorisées pour la première position GPS et d’une marge de 20 m.

Les nouvelles sessions peuvent inclure les métadonnées `rules` : `activeElapsed`,
`timeLimitSeconds` facultatif, `livesRemaining`, `collisionCooldownUntil`, `ghosts`
et `outcome` (`completed`, `timedOut`, `caught`, `stopped`). Chaque fantôme contient
`id`, `pathID`, `distanceAlongPath`, `isReversed` et une coordonnée. Le temps actif
exclut les pauses et doit rester compatible avec le temps réel écoulé et la marge
de fraîcheur du client.

Les limites des modes chronométrés proviennent de la durée estimée du parcours
canonique, avec un minimum de 60 secondes. Pour les anciens parcours, elles sont
calculées à partir de la distance divisée par 1,2 m/s. Ce calcul accepte une
tolérance de 1 % ou d’une seconde, car le client utilise les distances de
CoreLocation. Les modes avec fantômes exigent un à trois fantômes, chacun avec
un ID unique et placé sur un chemin canonique. Les modes sans fantômes ne
peuvent pas signaler de collisions ni de vies perdues. Le résultat final doit
être cohérent avec les pastilles collectées, le chronomètre et les vies restantes.
Ces contrôles vérifient la cohérence structurelle ; ils ne rejouent pas l’IA des
fantômes et ne prouvent pas le déplacement physique du joueur.

`rules` est obligatoire pour les trois nouveaux modes, qui doivent également
être annoncés dans la version canonique du parcours. Les anciens résultats
Explore sans règles restent acceptés et conservent leur représentation canonique
antérieure pour les nouvelles tentatives d’envoi. Les règles sont incluses dans
les nouvelles comparaisons d’idempotence : modifier le temps écoulé, les vies ou
le résultat final lors d’une nouvelle tentative renvoie `409`.
La migration additive `SeedStageTwoVerney` insère la version 2 ; la migration
`SeedVerney` lit la version d’origine conservée dans `verney-v1.json`.

Un résultat enregistré renvoie `200` avec `{id, score, duplicate: false}`.
Renvoyer le même résultat, indépendamment de l’ordre des ID des pastilles,
renvoie `200` avec `duplicate: true`. Réutiliser son UUID pour un autre résultat
renvoie `409`. Une version inconnue, une copie de parcours modifiée, des pastilles
n’appartenant pas au parcours ou des champs invalides renvoient `422`. Une clé
d’idempotence absente ou différente de l’UUID renvoie `400`.
La clé primaire de la base empêche les insertions concurrentes en double. Après
l’échec d’une insertion, le résultat déjà accepté est recherché en dehors de la
transaction annulée.

Les versions des parcours sont des enregistrements immuables contenant leur JSON
canonique complet ; le graphe n’est pas réparti entre des tables modifiables.
Chaque résultat référence la ligne correspondant à sa version exacte. Toute
publication de modification doit insérer une nouvelle version. Aucune route
d’écriture des définitions de parcours n’est accessible sans authentification.

## Tests

```sh
swift test
swift run IntegrationServer
```

Les tests et `IntegrationServer` utilisent des bases SQLite isolées en mémoire,
avec les mêmes migrations, routes API et validations. `IntegrationServer` écoute
sur le port 8080 de l’interface de bouclage pour permettre les tests du véritable
client iOS sans Docker. C’est un outil de test, pas une solution de stockage de
remplacement en production : un redémarrage supprime ses résultats.
`RealPacmanServer` utilise toujours PostgreSQL en production. La validation propre
à PostgreSQL nécessite également la base Compose et l’exécutable de production ;
la réussite des tests SQLite ne suffit pas à la démontrer.

Pour activer le test PostgreSQL supplémentaire, créez une base dédiée dont le nom
se termine par `_test`, puis lancez :

```sh
POSTGRES_TEST_URL='postgres://user:password@127.0.0.1:5432/realpacman_test?tlsmode=disable' swift test
```

Utilisez `tlsmode=disable` uniquement pour une base de test locale ou un réseau
explicitement privé. Le test PostgreSQL applique les migrations, insère les
parcours canoniques et supprime son propre résultat synthétique. Ne le lancez
jamais sur une base de production.

Vérification du 26 novembre 2026 : les 13 fonctions de test du serveur, réparties
en trois suites, ont réussi avec le test PostgreSQL activé sur PostgreSQL 17.12.
Les suites API et modes utilisent toujours des bases SQLite isolées. Le test
PostgreSQL couvre les migrations, insertions concurrentes, nouvelles tentatives,
conflits et conservation des données entre plusieurs instances de l’application.
L’exécutable du serveur a également été lancé avec `--env production`, a appliqué
les migrations et a réussi les vérifications HTTP. Le résultat enregistré a
survécu au redémarrage de l’API et de PostgreSQL. L’absence de configuration de
production a bien été rejetée.

L’image Linux a ensuite été construite et exécutée sur Render ; les détails
figurent ci-dessous. Le workflow GitHub facultatif reste local, car les
identifiants GitHub enregistrés ne permettent pas de publier des workflows.

## Déploiement HTTPS sur Render pour le projet de cours

Le fichier `render.yaml`, à la racine du dépôt, crée un service web Docker
**gratuit** à Francfort. Il référence la base existante `RealPacmanGame-Postgres`
(PostgreSQL 18), sans créer de base ni modifier son offre. Aucune ressource
payante n’est déclarée. Render fournit l’adresse HTTPS publique et son certificat.

Les services gratuits ne disposent pas de commande préalable au déploiement.
Avec `MIGRATE_ON_START=true`, le point d’entrée du conteneur exécute
`migrate --yes --env production` avant d’ouvrir le serveur HTTP. L’échec d’une
migration empêche le démarrage. Conservez une seule instance pour ce déploiement ;
un déploiement payant à plusieurs instances doit prévoir une étape de migration
séparée avant le déploiement. Le point d’entrée utilise `exec` pour que le serveur
reçoive directement les signaux d’arrêt.

La production exige `DATABASE_URL` et refuse `AUTO_MIGRATE=true`.
`DATABASE_TLS_MODE` vaut `require` par défaut, avec vérification du certificat et
du nom d’hôte. Le Blueprint sélectionne explicitement `disable` pour la connexion
privée dans la même région Render, car les certificats internes de la base sont
autosignés. N’utilisez jamais cette exception pour une URL de base de données
externe. Le téléphone communique en HTTPS. Render fournit les identifiants via
la référence `fromDatabase` ; ils ne sont jamais enregistrés dans le dépôt.
Le Blueprint ne modifie pas les règles d’accès entrant de la base existante.

Une fois le déploiement actif, vérifiez l’URL attribuée :

```sh
python3 Scripts/verify_backend.py https://YOUR-SERVICE.onrender.com --state /tmp/realpacman-deploy-check.json
```

Redémarrez le service web, puis relancez la même commande avec le même fichier
d’état. Elle doit confirmer que le résultat enregistré a survécu au redémarrage.
Ce test écrit un résultat Explore synthétique et contrôle son score canonique,
les nouvelles tentatives concurrentes, les envois contradictoires et le rejet
d’une clé manquante. Conservez son UUID pour identifier ce résultat de test.

Dans les réglages de l’application iPhone, saisissez l’URL HTTPS de base attribuée,
actualisez les parcours et synchronisez un résultat enregistré. La vérification
sur appareil physique reste une étape distincte. Pour la présentation du projet,
laissez les déploiements automatiques et la synchronisation automatique du
Blueprint désactivés ; déployez explicitement les commits relus.

Les bases gratuites expirent après 30 jours et n’ont pas de sauvegardes
automatiques. L’expiration indiquée pour cette instance est le 26 décembre 2026,
après la présentation du 30 novembre. Les services web gratuits se mettent en
veille après 15 minutes sans trafic entrant et peuvent prendre environ une
minute pour redémarrer. Ouvrez `/health` avant la présentation et prévoyez ce
délai. Ce déploiement convient au projet de cours, pas à une exploitation durable
en production.

Références : [Docker sur Render](https://render.com/docs/docker),
[champs des Blueprints](https://render.com/docs/blueprint-spec),
[connexion à PostgreSQL](https://render.com/docs/postgresql-creating-connecting),
[limites de l’offre gratuite](https://render.com/docs/free).

## Vérification du service hébergé — 26 novembre 2026

API en ligne : [real-pacman-api-o256.onrender.com](https://real-pacman-api-o256.onrender.com)

- Espace de travail : Ryle’s workspace ; service web gratuit `srv-dc3unf2jnfac73avd2gg`.
- Base PostgreSQL 18.7 gratuite existante : `dpg-dc3uikrl550s73flnj9g-a`.
- Source : `codex/class-project-backend`, commit exécuté `66a4cc2`.
- Construction de l’image Linux réussie ; migrations au démarrage et contrôle de
  disponibilité de la base réussis.
- Vérifications HTTPS publiques réussies avec validation normale du certificat :
  catalogue, score canonique, nouvelles tentatives concurrentes, UUID
  contradictoire et rejet d’une clé manquante.
- Un second déploiement du même commit est devenu actif. Le résultat déjà
  enregistré a ensuite été reconnu comme doublon, confirmant sa conservation.
- Les 53 tests de l’application et du cœur métier, répartis en huit suites, ont
  réussi avec l’URL d’intégration hébergée : téléchargement réel par `GameStore`,
  persistance après échec et nouvelle tentative, et envoi des résultats des trois
  modes chronométrés ou avec fantômes. L’exécutable autonome de vérification GPS
  et de persistance a également réussi.
- Des requêtes SQL en lecture seule ont confirmé une seule copie de parcours pour
  chacune des versions 1 et 2, ainsi que cinq résultats synthétiques. Il ne s’agit
  pas de promenades de joueurs.
- La synchronisation sur iPhone physique et les tests en extérieur ou en mode
  avion ne sont pas encore vérifiés.

Dans les réglages de l’application installée, définissez l’URL du serveur avec
l’adresse de base de l’API ci-dessus, sans `/api/v1`. Actualisez ensuite les
parcours et synchronisez les résultats.

## Comptes joueurs

`POST /api/v1/auth/register` et `/auth/login` acceptent `{username, password}`.
Les noms d’utilisateur sont insensibles à la casse et comportent de 3 à 24 lettres
ASCII, chiffres ou traits de soulignement. Les mots de passe doivent contenir de
10 à 72 octets UTF-8 ; ils sont hachés avec bcrypt dans le groupe de threads dédié
aux mots de passe. Les réponses contiennent
`{player: {id, username}, token, expiresAt}`. L’expiration est exprimée en secondes
depuis le 1er janvier 2001, comme côté client. Les jetons contiennent 256 bits
aléatoires, expirent après 30 jours et sont stockés uniquement sous forme
d’empreintes SHA-256 dans la base. Les tentatives d’authentification sont limitées
à dix par adresse distante et par minute, pour chaque processus serveur.

Envoyez `Authorization: Bearer TOKEN` pour les envois de résultats,
`GET /api/v1/results`, `GET /api/v1/auth/me` et `POST /api/v1/auth/logout`.
La déconnexion révoque le jeton concerné. Le propriétaire d’un résultat provient
exclusivement du compte authentifié, jamais d’un ID de joueur fourni dans le
contenu envoyé. Une nouvelle tentative doit appartenir au même joueur. Les
anciens résultats anonymes restent sans propriétaire et ne peuvent pas être
récupérés par un compte en renvoyant leur UUID. La liste des résultats ne renvoie
que les ID des confirmations et les scores canoniques du joueur. Le catalogue
et le contrôle de disponibilité restent publics. La migration additive
`AddPlayerAccounts` préserve les données antérieures.

L’application propose **Player Account** depuis **Settings** et **Statistics**.
Les identifiants de session sont associés au serveur choisi et conservés dans
le trousseau de l’appareil uniquement ; les mots de passe ne sont jamais
mémorisés. Chaque nouvelle promenade conserve localement son joueur et son
serveur. Un changement de compte ne peut pas les réattribuer. Le mode invité
reste utilisable hors ligne ; seule l’action explicite **Upload my saved guest
walks** attribue au compte les résultats invités qui n’ont pas encore été
synchronisés. Les statistiques et succès locaux restent l’historique de
l’appareil, et ne constituent pas une restauration depuis le cloud.

La déconnexion hors ligne supprime immédiatement les identifiants de session sur
l’appareil. La révocation côté serveur est tentée sans garantie de succès si le
serveur est injoignable ; les sessions restantes expirent naturellement.
La déconnexion ne supprime pas les promenades enregistrées localement. Une session
expirée nécessite une nouvelle connexion.

Périmètre du projet de cours : les comptes par nom d’utilisateur et mot de passe
ne proposent pas de réinitialisation du mot de passe, de vérification par e-mail
ni d’interface de suppression de compte. N’utilisez pas un mot de passe employé
ailleurs. Les contrôles de propriété du serveur protègent l’accès, mais les
déplacements signalés par le client ne prouvent pas une promenade réelle et ne
constituent pas un dispositif anti-triche compétitif. Les limites de l’hébergement
gratuit et sa date d’expiration restent applicables.

Validation : 15 tests du serveur, répartis en quatre suites, ont réussi, notamment
les migrations et la persistance PostgreSQL, l’inscription, la vérification bcrypt,
les noms d’utilisateur en double, les connexions invalides, la propriété des
résultats, les listes privées, la révocation et les jetons expirés.
Les 54 tests de l’application et du cœur métier ont réussi avec l’intégration
locale activée, y compris l’attribution explicite des résultats invités et les
changements de compte, ainsi que les contrôles autonomes GPS et de persistance.
La compilation pour le simulateur iOS a réussi. Le workflow CI facultatif reste
local et non publié.

### Vérification des comptes hébergés — 26 novembre 2026

Le commit `f4e28e8` de stage3 a été déployé sur le service HTTPS gratuit existant.
La migration `AddPlayerAccounts` a réussi sur PostgreSQL 18.7 hébergé. Les
vérifications HTTPS d’inscription, d’envoi authentifié, de nouvelles tentatives,
de scores et de rejets ont réussi. L’accès anonyme à la liste des résultats a
renvoyé `401`. Les 54 tests du véritable client et du cœur métier ont réussi avec
l’intégration hébergée activée, notamment l’attribution explicite des résultats
invités et l’isolation des envois entre comptes.

Des requêtes SQL en lecture seule ont confirmé des résultats appartenant aux
joueurs, tandis que les anciennes lignes anonymes restaient sans propriétaire.
Les tests créent des comptes et résultats synthétiques. La vérification visuelle
facultative du simulateur n’était pas disponible, faute de fenêtre accessible ;
la compilation pour le simulateur a toutefois réussi.
