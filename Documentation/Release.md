# Class presentation release — November 30, 2026

Distribution is direct installation on the author's iPhone through Xcode. No App
Store submission, TestFlight distribution or paid hosting is needed for this plan.

## Build and install

Version 1.0, build 1; bundle ID `coconut-factory.Real-Pacman`; minimum iOS **26.5**.
The shared Real Pacman scheme uses Debug for Run and Release for Archive/Profile.
Existing local signing-team settings are preserved and are not committed.

Connect and unlock the iPhone, open Real Pacman.xcodeproj, select the Real Pacman
scheme and the physical iPhone destination. In Signing & Capabilities select your
team with automatic signing enabled. Keep Developer Mode enabled. Press Cmd-R to
install; then disconnect the cable and open the app from the Home Screen. Use the
same team and bundle ID to update the existing install and preserve progress.

With a free Personal Team, provisioning expires seven days after issuance.
Rebuild/install shortly before November 30 and verify launch without the cable.
This is independent of the 30-day player token and December 26 database expiry.
[Apple's Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account)

The verification archive is **unsigned** and cannot be installed as-is. Build and
check one without changing signing credentials:

```sh
bash Scripts/verify_release.sh
```

The default output is `/private/tmp/RealPacman-Release/RealPacman-1.0.xcarchive`.
The archive verified during this task is `/private/tmp/RealPacman-1.0.xcarchive`.
To inspect that existing archive without rebuilding:

```sh
bash Scripts/verify_release.sh /private/tmp/RealPacman-1.0.xcarchive --verify-only
```

Use Product → Archive with your team if you need a signed archive. No installable
IPA or App Store upload has been produced.

## Icon and screenshots

The universal AppIcon source is an opaque RGB 1024 × 1024 PNG based on the existing
yellow player and cyan path palette, without baked-in rounded corners. Xcode
generates device sizes and system appearance treatments. Regenerate from the repo
root with `swift Scripts/generate_app_icon.swift`.

Seven real iPhone 17 Pro simulator captures are in `Screenshots/Release-1.0/`:
Home, parcours/offline status, mode selection, Explore demo gameplay, achievements,
privacy details and player sign-in. The mode/privacy screens are scrollable; each
capture shows the first portion. Gameplay is labelled **demo**, not evidence of
outdoor testing. Achievements use pre-existing simulator test history. Account
fields are empty. The status bar is normalized to 9:41 and full battery. Old
screenshots in the parent directory are preserved. These are presentation assets,
not an App Store submission. Re-capture if the UI changes.

## Privacy inventory

Settings → Privacy & Data is available offline. The app's PrivacyInfo.xcprivacy
declares no tracking, app-only UserDefaults access (`CA92.1`), and account-linked
player IDs, gameplay content, route/pellet-derived location and other account data
used for functionality. MapLibre also includes its own SDK privacy manifest.
[Apple's manifest guidance](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

| Data | On device | Shared with the default server |
| --- | --- | --- |
| Live GPS fixes | Active gameplay collection / positioning | No raw movement trace |
| Route, pellets, distance, times, mode, virtual ghosts | Offline resume and history | Authenticated uploads; can reveal where/when played |
| Username and player ID | Signed-in identity | Account ownership |
| Password | Entered only; never saved | HTTPS hash/verification; bcrypt hash stored |
| Sign-in token | Device-only Keychain, up to 30 days | Authentication; only its digest stored |
| Preferences, achievements, map downloads | Local storage | Preferences/achievement state not uploaded |

OpenFreeMap supplies online maps; requests reveal map areas and network metadata
to its infrastructure. The app includes no ads or analytics SDK. Render may keep
operational logs; provider policies describe their own processing. This inventory
is not a submitted App Store privacy label or certification of providers.
[OpenFreeMap privacy](https://openfreemap.org/privacy/),
[Render privacy](https://render.com/privacy)

Signing out does not delete walk history or server results. There is no in-app
account deletion/password recovery; ask the project author directly for server
data removal. Uninstall removes app-container data but Keychain may persist, so
sign out first. Free database expiry is not a backup strategy.

## Presentation checklist

- Install the latest build and launch it disconnected from the Mac.
- Confirm server URL `https://real-pacman-api-o256.onrender.com`.
- Open `/health` a minute or two before the demo to wake free hosting.
- Sign in beforehand if showing sync; ordinary app restarts retain the token.
- Download Verney's map, verify downloaded status and test airplane-mode play.
- Check physical GPS outdoors before presenting. This remains unverified here;
  Verney is still a field-unverified draft.
- Use the GPS-free demo indoors. Demo results are not uploaded.
- Keep the screenshots as a fallback.

## Verification and remaining device step

Debug simulator build and unsigned device Release archive passed. Archive checks
cover the icon, app/SDK manifests, foreground-only location explanation and absence
of Release ATS exceptions. Seven screenshots were captured and visually reviewed;
privacy navigation was verified in Simulator. The physical iPhone was listed as
unavailable, so signed installation and device launch remain to be checked by
connecting it to Xcode. No public publication was requested or performed.
