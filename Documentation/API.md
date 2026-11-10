# Real Pac-Man client and API

The existing project was a menu/settings prototype with MapLibre 6.31 already added. The client now supports route storage, foreground GPS collection, resumable sessions, map packs, result uploads and local statistics. Existing user edits were retained as the starting point. No backend exists in this folder yet.

## Run

Open Real Pacman.xcodeproj. The deployment target remains iOS 26.5. In Settings enter an HTTPS server base URL without a query or fragment. Choose Play → Refresh parcours. Parc du Verney is available immediately as a bundled map draft. Download a route's offline map while connected, then start walking. Routes and progress live in Application Support/RealPacman/progress.json. MapLibre owns a separate persistent map database.

GPS must be fresh (within 10 seconds), horizontal accuracy must be 20 m or better, and pellets are collected within 15 m. Each pellet counts once per session. Jumps over 12 m/s are rejected. Gameplay pauses when leaving the gameplay screen or foreground; resume explicitly. These are basic collection filters, not server-side anti-cheat. Distance is an estimate from accepted fixes. Partial walks can be finished and appear in history.

Offline gameplay does not require networking once a route is saved. Detailed basemap rendering additionally requires completing its map download. Map downloads cover route/pellet bounds with padding, zooms 12–17; oversized areas are rejected. Downloads pause when the detail view closes, and can resume. A five minute timeout permits connection recovery. MapLibre's default attribution control remains visible. The server must provide an OSM-derived style and properly attributed tiles with permission for offline downloads; do not use the public OSM raster tile service for bulk downloads.

## Planned Vapor/PostgreSQL contract

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
- mode: currently "explore"; absent on legacy sessions
- syncedAt: absent for an unsynced result

Client score is derived by summing the collected pellets' versioned values (10 per pellet for legacy routes) and is not sent separately. Server must validate pellet membership and route/version, recompute score, and validate timestamps and distance. Treat client data as untrusted.

The Idempotency-Key header equals the session id. PostgreSQL must enforce uniqueness on that id. Persist within a transaction before returning 2xx. A replay of a previously accepted identical result must return 2xx without creating another result. Non-2xx responses keep the item queued. The client retries on launch, foreground activation, and manual sync. A response lost after server commit is safe only if the server implements this rule.

Suggested tables: routes, route_versions (geometry/style), pellets (route_version foreign key), results (unique client_session_id), result_pellets (unique result_id/pellet_id). Authentication, accounts, migrations, deployed server, server statistics and conflict policies remain to implement. Current statistics summarize this device's saved results.

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
- supportedModes: currently ["explore"]; future values timed, ghosts, timedGhosts
- estimatedMinutes: rough planning estimate, not a measured completion time
- fieldVerified: publication gate; false means inspectable map draft, not playable
- sourceURL, sourceDate: data provenance

Pellets now also encode value (1–1000); omitted values decode as 10.
coordinates stays in the envelope for old consumers, but graph-aware clients draw
each path separately. Never concatenate disconnected polyline coordinates for rendering.
New sessions snapshot the full graph, pellet values, version and Explore mode.
Old sessions without mode remain readable and represent the original Explore gameplay.

Validation rejects missing/duplicate IDs, disconnected networks, invalid endpoints,
invalid coordinates, outside-boundary nodes/pellets, and pellets over 2 m off a path.
A valid graph does not establish real-world access. fieldVerified must only be set
after human review. Supported future modes are not enabled by this client.

Published versions with the same ID override the bundled draft in the catalogue.
In-progress sessions still retain their original route snapshots. Download packs
are matched by route ID and version, and their region includes every path and boundary.
Station and USMB are catalogue candidates without invented playable geometry.

Recommended PostgreSQL additions: route_versions.description/boundary/start_junction_id/
supported_modes/estimated_minutes/field_verified/source; junctions and paths keyed
by route_version; paths.from/to foreign keys; pellets.value. Publish a version
transactionally only after graph and field-review checks.
