# Real Pac-Man server

The Swift/Vapor API serves the versioned parcours catalogue and accepts durable,
idempotent walk results. Production storage is PostgreSQL through Fluent.

## Local development

Install a Swift 6.3 toolchain (tested with 6.3.3) and Docker with Compose. From `Server/`:

```sh
cp .env.example .env
docker compose up -d db
swift run RealPacmanServer migrate --yes
swift run RealPacmanServer serve --hostname 127.0.0.1 --port 8080
```

The app's Debug simulator build can use `http://127.0.0.1:8080`. Physical devices
need a reachable HTTPS endpoint; the phone's localhost is the phone itself.
`GET /health` checks database access. `GET /api/v1/routes` returns the current
highest version for each route. This is the bundled Verney **draft**, version 2,
which enables Explore, Timed, Ghosts and Timed + ghosts. Its geometry, provenance
and unverified status are unchanged. The original version 1 snapshot remains
stored and playable for results recorded before the upgrade.

`DATABASE_URL`, `HOST` and `PORT` configure the service. `AUTO_MIGRATE=true` enables
startup migrations for local development. Run migrations explicitly before a
production deployment instead. Keep `.env` private and choose a strong database
password before deploying. Compose exposes PostgreSQL only on host loopback.

## Result contract

`POST /api/v1/results` accepts the existing client GameSession JSON, with an
`Idempotency-Key` header equal to its UUID. Dates are numeric seconds since
2001-01-01, matching the client's default JSONEncoder. `mode` may be absent on
legacy Explore sessions; current values are `explore`, `timed`, `ghosts` and
`timedGhosts`. `finishedAt` is required for an
uploaded result. Zero collected pellets and partially completed walks are valid.

The server loads its own immutable route/version and requires the submitted
snapshot to match it. Pellet IDs must be unique and belong to that version.
Scores are recomputed from canonical pellet values. Dates must be ordered and
not in the future beyond five minutes of clock skew. Distance must be finite,
nonnegative and compatible with the elapsed time at the client's 12 m/s ceiling,
including its ten-second initial-fix freshness allowance and a 20 m margin.

New sessions include optional `rules` metadata: `activeElapsed`, optional
`timeLimitSeconds`, `livesRemaining`, `collisionCooldownUntil`, `ghosts`, and
`outcome` (`completed`, `timedOut`, `caught`, `stopped`). Ghost entries contain
`id`, `pathID`, `distanceAlongPath`, `isReversed` and a coordinate. Active time
excludes pauses and must fit within wall time plus the client's freshness window.
Timed limits come from canonical route estimated minutes (minimum 60 seconds),
or route distance / 1.2 m/s for legacy geometry. The geometry fallback allows 1%
or one second of numeric tolerance because the app uses CoreLocation distances.
Ghost modes require one to three uniquely identified ghosts on canonical path IDs.
No-ghost modes cannot report collisions or lost lives. Terminal outcomes must
agree with completion, timer and lives. These are structural consistency checks,
not server-side replay of ghost AI or proof of physical movement.

Rules are required for the three new modes, and the canonical route version must
advertise that mode. Existing Explore results without rules remain accepted and
retain their pre-upgrade canonical retry representation. Rules are included in
new idempotency comparisons; changing elapsed time, lives or outcome on a retry
returns `409`. The additive `SeedStageTwoVerney` migration inserts version 2;
the original `SeedVerney` migration now reads the preserved `verney-v1.json`.

A committed result returns `200` with `{id, score, duplicate: false}`. Replaying
the same semantic result (regardless of pellet-ID ordering) returns `200` and
`duplicate: true`. Reusing its UUID for another result returns `409`. Unknown
versions, altered snapshots, bad pellet membership and invalid result fields
return `422`; a missing/mismatched idempotency key returns `400`. The database
primary key prevents concurrent duplicate inserts; a failed insert transaction
rechecks the accepted result outside the rolled-back transaction.

Route versions are immutable application records stored as complete canonical
JSON, rather than splitting the graph across mutable tables. Results reference
their exact route-version row. Future route publishing must insert a new version;
there is deliberately no unauthenticated write endpoint for route definitions.

## Tests

```sh
swift test
swift run IntegrationServer
```

Tests and `IntegrationServer` use isolated in-memory SQLite storage against the
same migrations, API handlers and validation. The latter listens on loopback port
8080 so actual iOS-client integration checks can run without Docker. It is a test
harness, not a production persistence fallback: restarting it discards results.
Production `RealPacmanServer` always uses PostgreSQL. PostgreSQL-specific runtime
validation additionally requires running the Compose database and the production
executable; successful SQLite checks alone do not establish that validation.

Verified here: both executables compile, all twelve HTTP/database test functions
pass (including parameterized invalid-upload and mode cases), and the test HTTP listener answers
`GET /health`. Docker and PostgreSQL are not installed in this workspace's host,
so the production PostgreSQL connection and migrations have not been exercised
against a running PostgreSQL instance.

## Deployment boundary

This is an unauthenticated development backend. Result UUIDs provide retry
identity, not player identity. Do not expose it as a trusted competitive service:
client-reported collection cannot prove a physical walk. Before public release,
add authentication, per-player authorization, rate limits, deployment TLS,
monitoring, backups and a defined account/statistics API. Demo sessions never
reach this API. The request-body limit is four megabytes; map tiles remain with the
configured map provider rather than passing through this server.
