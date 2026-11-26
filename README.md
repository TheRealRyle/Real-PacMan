# Guide d’installation

Ce guide prépare l’installation sur l’iPhone de l’auteur pour la présentation du
30 novembre 2026. Cette distribution se fait directement avec Xcode : aucun envoi
sur l’App Store, aucune distribution TestFlight et aucun hébergement payant ne
sont nécessaires.

## Compilation et installation

Version 1.0, numéro de compilation 1 ; identifiant de l’application
`coconut-factory.Real-Pacman` ; version minimale : **iOS 26.5**.
Le schéma partagé Real Pacman utilise la configuration Debug pour l’exécution
(Run) et Release pour l’archivage et le profilage (Archive/Profile).
Les réglages locaux de l’équipe de signature sont conservés et ne sont pas inclus
dans les commits.

Branchez et déverrouillez l’iPhone, ouvrez Real Pacman.xcodeproj, puis sélectionnez
le schéma Real Pacman et l’iPhone physique comme destination. Dans Signing &
Capabilities, choisissez votre équipe et activez la signature automatique.
Laissez le mode développeur activé. Appuyez sur Cmd-R pour compiler et installer
l’application, puis débranchez le câble et ouvrez-la depuis l’écran d’accueil.
Gardez la même équipe et le même identifiant d’application lors des mises à jour
pour conserver la progression existante.

Avec une équipe personnelle gratuite (Personal Team), le profil de provisionnement
expire sept jours après son émission. Recompilez et réinstallez l’application peu
avant le 30 novembre, puis vérifiez qu’elle démarre sans câble. Cette durée est
indépendante du jeton de connexion du joueur, valable 30 jours, et de l’expiration
de la base de données le 26 décembre.
[Limites des équipes personnelles selon Apple](https://developer.apple.com/help/account/basics/about-your-developer-account)

L’archive de vérification est **non signée** et ne peut pas être installée telle
quelle. Pour compiler et vérifier une archive sans modifier les identifiants de
signature :

```sh
bash Scripts/verify_release.sh
```

Le résultat est placé par défaut dans
`/private/tmp/RealPacman-Release/RealPacman-1.0.xcarchive`.
L’archive vérifiée pendant cette préparation se trouve dans
`/private/tmp/RealPacman-1.0.xcarchive`.
Pour examiner cette archive existante sans recompiler :

```sh
bash Scripts/verify_release.sh /private/tmp/RealPacman-1.0.xcarchive --verify-only
```

Utilisez Product → Archive avec votre équipe si vous avez besoin d’une archive
signée. Aucun fichier IPA installable ni aucun envoi sur l’App Store n’a été produit.

## Icône et captures d’écran

La source universelle AppIcon est une image PNG RVB opaque de 1024 × 1024 pixels,
reprenant le personnage jaune et les chemins cyan sur fond bleu marine. Les coins
arrondis ne sont pas intégrés à l’image. Xcode génère les tailles adaptées aux
appareils et les apparences système. Pour la régénérer depuis la racine du dépôt :

```sh
swift Scripts/generate_app_icon.swift
```

Sept captures réelles du simulateur iPhone 17 Pro sont disponibles dans
`Screenshots/Release-1.0/` : accueil, sélection des parcours et état hors ligne,
choix du mode, démonstration du mode Explore, succès, confidentialité et connexion
du joueur. Les écrans des modes et de confidentialité défilent ; les captures
montrent leur première partie. La partie est identifiée comme une **démonstration**
et ne prouve pas un test en extérieur. Les succès utilisent l’historique de test
préexistant du simulateur. Les champs du compte sont vides. La barre d’état affiche
9 h 41 et une batterie pleine. Les anciennes captures du dossier parent sont
conservées. Ces images servent à la présentation et ne constituent pas un dossier
de soumission à l’App Store. Refaites-les si l’interface change.

## Données et confidentialité

La page Settings → Privacy & Data est accessible hors ligne. Le fichier
PrivacyInfo.xcprivacy de l’application déclare l’absence de suivi, l’accès aux
préférences UserDefaults propres à l’application (`CA92.1`), ainsi que les
identifiants des joueurs, les données de jeu, la localisation déduite des parcours
et des pastilles, et les autres données de compte liées au joueur et nécessaires
au fonctionnement. MapLibre fournit également son propre manifeste de
confidentialité pour son SDK.
[Guide Apple sur les manifestes de confidentialité](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

| Données | Sur l’appareil | Partage avec le serveur par défaut |
| --- | --- | --- |
| Positions GPS en direct | Collecte des pastilles et positionnement pendant la partie | Aucun tracé brut des déplacements |
| Parcours, pastilles, distance, horaires, mode et fantômes virtuels | Reprise hors ligne et historique | Envoi authentifié ; peut révéler le lieu et le moment de la partie |
| Nom d’utilisateur et identifiant du joueur | Identité du joueur connecté | Attribution des résultats au compte |
| Mot de passe | Saisi uniquement, jamais enregistré | Transmis par HTTPS pour hachage ou vérification ; seul le hachage bcrypt est conservé |
| Jeton de connexion | Trousseau Keychain propre à l’appareil, jusqu’à 30 jours | Authentification ; seule son empreinte est conservée sur le serveur |
| Préférences, succès et cartes téléchargées | Stockage local | Préférences et état des succès non envoyés |

OpenFreeMap fournit les cartes en ligne ; les requêtes révèlent à son infrastructure
les zones affichées et des métadonnées réseau. L’application ne contient ni
publicité ni SDK d’analyse d’audience. Render peut conserver des journaux techniques ;
les politiques des prestataires décrivent leurs propres traitements. Cet inventaire
n’est ni une déclaration de confidentialité soumise à l’App Store, ni une
certification des prestataires.
[Confidentialité OpenFreeMap](https://openfreemap.org/privacy/),
[Confidentialité Render](https://render.com/privacy)

La déconnexion ne supprime ni l’historique des marches ni les résultats sur le
serveur. L’application ne propose pas de suppression de compte ni de récupération
du mot de passe : demandez directement à l’auteur du projet pour supprimer des
données du serveur. La désinstallation supprime les données du conteneur de
l’application, mais le trousseau Keychain peut subsister : déconnectez-vous d’abord.
L’expiration de la base de données gratuite ne remplace pas une sauvegarde.

## Vérifications avant la présentation

- Installez la dernière version et lancez-la sans connexion au Mac.
- Vérifiez l’adresse du serveur : `https://real-pacman-api-o256.onrender.com`.
- Ouvrez `/health` une ou deux minutes avant la démonstration pour réveiller
  l’hébergement gratuit.
- Connectez-vous à l’avance si vous présentez la synchronisation ; un redémarrage
  normal de l’application conserve le jeton.
- Téléchargez la carte du Verney, vérifiez son état téléchargé et testez une partie
  en mode avion.
- Vérifiez le GPS sur l’iPhone en extérieur avant la présentation. Ce point reste
  non vérifié ici ; le parcours du Verney est encore un brouillon non validé sur
  le terrain.
- En intérieur, utilisez la démonstration sans GPS. Ses résultats ne sont pas envoyés.
- Gardez les captures d’écran disponibles comme solution de secours.

## Vérifications effectuées et dernière étape sur l’iPhone

La compilation Debug pour le simulateur et l’archive Release non signée pour iPhone
ont réussi. Les contrôles de l’archive couvrent l’icône, les manifestes de
confidentialité de l’application et du SDK, le texte expliquant l’usage de la
localisation au premier plan et l’absence d’exceptions ATS dans la configuration
Release. Sept captures ont été réalisées et examinées visuellement ; la navigation
vers la confidentialité a été vérifiée dans le simulateur. L’iPhone physique était
indiqué comme indisponible : l’installation signée et le lancement sur l’appareil
restent donc à vérifier en le connectant à Xcode. Aucune publication publique n’a
été demandée ni effectuée.
