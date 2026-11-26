# Real Pac-Man client and API

The existing project was a menu/settings prototype with MapLibre 6.31 already added. The client now supports route storage, foreground GPS collection, resumable sessions, map packs, result uploads and local statistics. Existing user edits were retained as the starting point. The local Vapor/PostgreSQL backend is in `Server/`; see its setup instructions.

## Run

Open Real Pacman.xcodeproj. The deployment target remains iOS 26.5. In Settings enter an HTTPS server base URL without a query or fragment. Debug simulator builds offer a local development server button for `http://127.0.0.1:8080`. Existing connection preferences are retained; select the development server explicitly before refreshing or syncing. Only loopback HTTP is accepted in Debug; Release requires HTTPS. Start the backend using `Server/README.md`, then refresh parcours. Choose Play → Refresh parcours. Parc du Verney is available immediately as a bundled map draft. Download a route's offline map while connected, then start walking. Routes and progress live in Application Support/RealPacman/progress.json. MapLibre owns a separate persistent map database.

GPS must be fresh (within 10 seconds), horizontal accuracy must be 20 m or better, and pellets are collected within 8 m. Each pellet counts once per session. Jumps over 12 m/s are rejected. Gameplay pauses when leaving the gameplay screen or foreground; resume explicitly. These are basic collection filters, not server-side anti-cheat. Distance is an estimate from accepted fixes. Partial walks can be finished and appear in history.

Offline gameplay does not require networking once a route is saved. Detailed basemap rendering additionally requires completing its map download. Map downloads cover route/pellet bounds with padding, zooms 12–17; oversized areas are rejected. Downloads pause when the detail view closes, and can resume. A five minute timeout permits connection recovery. MapLibre's default attribution control remains visible. The server must provide an OSM-derived style and properly attributed tiles with permission for offline downloads; do not use the public OSM raster tile service for bulk downloads.

## Vapor/PostgreSQL contract

All JSON uses Swift Codable keys. UUIDs are strings. Dates use the default JSONEncoder representation: seconds since 2001-01-01T00:00:00Z. Change both client/server together if adopting ISO 8601.

GET /api/v1/routes returns an array (not an envelope):

[
  {
    "id": "F230196D-145A-4419-9130-3CB7CCBD420A",
    "name": "Example walking route",
    "version": 1,
    "coordinates": [
      {"latitude": 48.85, "longitude": 2.35},
      {"latitude": 48.851, "longitude": 2.35}
    ],
    "pellets": [
      {
        "id": "B55A3386-9441-4C36-BB90-E7414A1BA2B5",
        "coordinate": {"latitude": 48.85, "longitude": 2.35}
      }
    ],
    "mapStyleURL": "https://your-map-provider.example/osm-style.json"
  }
]

Coordinates are latitude/longitude objects, not GeoJSON arrays. IDs must remain stable. Route versions must change whenever geometry, pellets, or style change. A session snapshots the route so a refresh cannot change an ongoing game.

POST /api/v1/results receives a GameSession:
- id: stable client session UUID
- route: complete route snapshot as above
- startedAt, finishedAt: numeric dates
- collectedPelletIDs: array of pellet UUID strings
- distanceMeters: Double
- mode: "explore", "timed", "ghosts" or "timedGhosts"; absent on legacy Explore sessions
- syncedAt: absent for an unsynced result

Client score is derived by summing the collected pellets' versioned values (10 per pellet for legacy routes) and is not sent separately. Server must validate pellet membership and route/version, recompute score, and validate timestamps and distance. Treat client data as untrusted.

The Idempotency-Key header equals the session id. PostgreSQL must enforce uniqueness on that id. Persist within a transaction before returning 2xx. A replay of a previously accepted identical result must return 2xx without creating another result. Non-2xx responses keep the item queued. The client retries on launch, foreground activation, and manual sync. A response lost after server commit is safe only if the server implements this rule.

The backend stores immutable route_versions as canonical JSON and results keyed by client session UUID, with a foreign key to the exact route version. Migrations seed the bundled draft. Authentication, accounts, deployed hosting and server statistics remain to implement. Current statistics summarize this device's saved results. See Server/README.md for storage and validation details.

## Verification

The app builds with xcodebuild against the iOS Simulator SDK without signing.
Tests/GameStoreChecks.swift is a standalone regression executable compiled alongside GameStore and the route/session models. It exercises inaccurate/stale GPS rejection, duplicate collection, persistence/reload, paused restoration, idempotent finishing, and queue durability.

Still requires physical-device GPS, real tile provider/offline airplane-mode, server integration, error/retry integration and UI accessibility checks. Achievements and ghosts remain stretch goals.

## Parcours graph extension (Gameplay-1)

The existing route envelope remains compatible. New routes can include an optional
`parcours` object; see the actual bundled example at
`Real Pacman/ParcoursData/verney-draft.json`.

- description, boundary (open polygon ring), startJunctionID
- junctions: stable string id and coordinate
- paths: stable string id, from/to junction ids, coordinate polyline, optional osmWayID
- supportedModes: advertised capabilities; Verney version two supports all four modes
- estimatedMinutes: rough planning estimate, not a measured completion time
- fieldVerified: map review status; drafts support Explore with the bundled layout
- sourceURL, sourceDate: data provenance

Pellets now also encode value (1–1000); omitted values decode as 10.
coordinates stays in the envelope for old consumers, but graph-aware clients draw
each path separately. Never concatenate disconnected polyline coordinates for rendering.
New sessions snapshot the full graph, pellet values, version and Explore mode.
Old sessions without mode remain readable and represent the original Explore gameplay.

Validation rejects missing/duplicate IDs, disconnected networks, invalid endpoints,
invalid coordinates, outside-boundary nodes/pellets, and pellets over 2 m off a path.
A valid graph does not establish real-world access. fieldVerified must only be set
after human review. The client enables only modes advertised by the selected route version.

Published versions with the same ID override the bundled draft in the catalogue.
In-progress sessions still retain their original route snapshots. Download packs
are matched by route ID and version, and their region includes every path and boundary.
Station and USMB are catalogue candidates without invented playable geometry.

Recommended PostgreSQL additions: route_versions.description/boundary/start_junction_id/
supported_modes/estimated_minutes/field_verified/source; junctions and paths keyed
by route_version; paths.from/to foreign keys; pellets.value. Publish a version
transactionally only after graph and field-review checks.

## Client/server integration verification

Run `REALPACMAN_INTEGRATION_URL=http://127.0.0.1:8080 python3 Scripts/test_parcours.py` against a running local backend to exercise the actual app GameStore: download and validate the canonical parcours, finish a walk, retain queued results after an HTTP failure, sync and restore the accepted result, replay an identical upload, and reject a conflicting session UUID. Without that environment variable the live test is skipped; endpoint and gameplay checks still run. This test creates temporary client progress and a new test result on the selected server. Use a development server.

The backend currently exposes a local prototype API without player authentication. It stores versioned route snapshots and server-calculated results. Public hosting, accounts and per-player access are separate work; this setup is intended to run on loopback during development. Demo scores never enter the upload queue.

## Verified integration outcome

The combined simulator build passed. All 24 app/core tests (including the enabled live GameStore HTTP test) and the standalone GPS/persistence checks passed. All seven backend HTTP/database tests passed using SQLite, including concurrent retries. The live client test verified canonical route download, failed-upload queue durability, successful sync/reload, identical replay and conflicting UUID rejection. A separate non-Debug endpoint check confirmed all HTTP URLs are rejected. Settings and the updated demo map were opened in the iPhone17 simulator. Physical GPS/heading and PostgreSQL runtime are not verified on this host; Docker/PostgreSQL are not installed. The explicitly named IntegrationServer uses temporary in-memory storage and is for testing only.

## Stage 2 mode results

GameSession.mode now supports explore, timed, ghosts and timedGhosts on route versions advertising those modes. The optional rules object records activeElapsed, timeLimitSeconds, livesRemaining, collisionCooldownUntil, ghosts and outcome. Each ghost records id, pathID, distanceAlongPath, isReversed and coordinate. Outcomes are completed, timedOut, caught and stopped. The server validates these fields against canonical mode capabilities and timing, then calculates points from canonical collected pellets. Metadata is client-reported game state, not proof of physical movement or protection against cheating. Legacy Explore uploads omit rules and keep their original retry identity.

Stage-two verification: the simulator build passed; 34 app/core test functions in seven suites passed, including live uploads for timed, ghosts and timedGhosts, plus the existing GPS/persistence checks. Twelve backend HTTP/database test functions passed against isolated SQLite. The combined-mode demo was checked in the simulator for its countdown, three lives, ghost markers and paused state. Physical GPS/heading and PostgreSQL runtime still require device/host testing. The isolated stage-two test listener uses port 8082; an older listener on 8080 must be restarted with the updated server before accepting new-mode results.

## Production deployment preparation (2026-11-26)

The server now includes a Docker image definition, a free Render HTTPS Blueprint referencing the existing PostgreSQL database, and GitHub checks for PostgreSQL and the Linux image.
Production startup requires an explicit database URL and explicit migrations before serving (at container startup on the free plan). All 13 backend tests passed with the PostgreSQL integration test
enabled against PostgreSQL 17.12. Actual production-environment HTTP uploads and
retries passed locally; data survived restarting both the API and database.
These checks supersede the earlier PostgreSQL-runtime limitation above.

Public deployment, public HTTPS verification, Linux image execution and physical
iPhone-to-hosted-server sync remain pending. See `Server/README.md` for the
deployment procedure and verification script. Accounts and player authorization
remain separate work; HTTPS hosting does not add player identity.
