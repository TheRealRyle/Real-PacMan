# Guide d’installation

## Prérequis

- Un Mac avec Xcode et le SDK iOS 26.5 ou une version ultérieure.
- Une connexion Internet pour récupérer le projet et ses dépendances.
- Pour une installation sur iPhone : iOS 26.5 ou une version ultérieure, un compte
  Apple et un câble permettant de connecter l’iPhone au Mac.

## Récupérer le projet

Clonez le dépôt, puis ouvrez le projet dans Xcode :

```sh
git clone https://github.com/TheRealRyle/Real-PacMan.git
cd Real-PacMan
git switch stage-4
open "Real Pacman.xcodeproj"
```

Si vous disposez déjà du projet, ouvrez directement `Real Pacman.xcodeproj`.
Laissez Xcode terminer le téléchargement des dépendances, notamment MapLibre.

## Installer sur un iPhone

1. Branchez l’iPhone au Mac et déverrouillez-le.
2. Acceptez « Faire confiance à cet ordinateur » si cette demande apparaît.
3. Dans Xcode, ouvrez Window → Devices and Simulators ou Device Hub, selon votre
   version, et sélectionnez l’iPhone pour effectuer le jumelage.
4. Sur l’iPhone, activez Réglages → Confidentialité et sécurité → Mode développeur.
   Redémarrez l’appareil si nécessaire et confirmez l’activation.
5. Dans Xcode, sélectionnez le projet dans la barre latérale, puis la cible
   **Real Pacman** et l’onglet **Signing & Capabilities**.
6. Cochez **Automatically manage signing** et sélectionnez votre équipe dans
   **Team**. Pour ajouter votre compte Apple, utilisez Xcode → Settings → Accounts.
7. Sélectionnez le schéma **Real Pacman**, puis votre iPhone comme destination
   d’exécution dans la barre supérieure.
8. Appuyez sur **Cmd-R** pour compiler, installer et lancer l’application.
9. Débranchez le câble et ouvrez l’application depuis l’écran d’accueil pour
   vérifier l’installation.

Si l’iPhone affiche « Développeur non approuvé », ouvrez Réglages → Général →
VPN et gestion de l’appareil, sélectionnez votre profil de développeur et
accordez-lui votre confiance.

Avec une équipe personnelle gratuite (**Personal Team**), le profil de
provisionnement expire après sept jours. Reconnectez alors l’iPhone et relancez
l’installation avec Cmd-R.
[Informations Apple sur les équipes personnelles](https://developer.apple.com/help/account/basics/about-your-developer-account)

## Lancer dans le simulateur

1. Dans Xcode, sélectionnez le schéma **Real Pacman**.
2. Choisissez un simulateur iPhone avec iOS 26.5 ou une version ultérieure.
3. Appuyez sur **Cmd-R**.

Pour utiliser le clavier de votre Mac avec la même disposition, activez dans le
menu du simulateur **I/O → Keyboard → Use the Same Keyboard Language as macOS**.

## Configuration après l’installation

1. Ouvrez **Settings** dans l’application.
2. Vérifiez que le champ **Route server** contient :

   ```text
   https://real-pacman-api-o256.onrender.com
   ```

3. Ouvrez **Player Account** pour créer un compte ou vous connecter si vous
   souhaitez synchroniser vos résultats.
4. Ouvrez **Play**, puis **Refresh parcours** pour actualiser les parcours.
5. Pour jouer hors ligne, téléchargez la carte du parcours et attendez que son état
   indique **Downloaded · Ready offline**.
6. Lors du premier lancement d’une marche, autorisez l’accès à la localisation
   pendant l’utilisation et activez la position exacte pour collecter les pastilles.

Le serveur peut mettre environ une minute à répondre après une période
d’inactivité. Attendez son réveil, puis réessayez si nécessaire.

## Mettre à jour l’application

Récupérez les dernières modifications de votre branche, puis relancez
l’installation avec Cmd-R dans Xcode. Utilisez la même équipe de signature et le
même identifiant d’application (`coconut-factory.Real-Pacman`) pour conserver la
progression existante.
