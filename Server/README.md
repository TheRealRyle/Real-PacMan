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

To enable the additional PostgreSQL test, create a dedicated database whose name
ends in `_test`, then run:

```sh
POSTGRES_TEST_URL='postgres://user:password@127.0.0.1:5432/realpacman_test?tlsmode=disable' swift test
```

Use `tlsmode=disable` only for a local test database or an explicitly private
network. The PostgreSQL test applies migrations and seeds the canonical routes;
it removes its own synthetic result. Never point it at a live database.

Verified on 2026-11-26: all 13 backend test functions in three suites passed with
the PostgreSQL test enabled against PostgreSQL 17.12. The existing API/mode suites
still use isolated SQLite. The PostgreSQL test exercises migrations, concurrent
inserts, retry identity, conflicts and persistence across application instances.
Separately, the actual server executable ran with `--env production`, applied
migrations, and passed real HTTP checks. Its saved result survived restarting
both the API process and PostgreSQL. Missing production configuration was rejected.
The Linux image subsequently built and ran successfully on Render; see the hosted
verification below. The optional GitHub workflow remains local because the saved
GitHub credential lacks permission to publish workflows.

## Class-project HTTPS deployment on Render

The repository-root `render.yaml` creates one **free** Docker web service in
Frankfurt. It references the existing `RealPacmanGame-Postgres` database (PostgreSQL
18), without creating or upgrading a database. No paid resources are declared.
Render provides the public HTTPS address and certificate.

Free services have no pre-deploy command. `MIGRATE_ON_START=true` makes the
container entrypoint run `migrate --yes --env production` before opening the HTTP
listener. A failed migration stops startup. Keep this deployment to one instance;
paid multi-instance deployments should use a separate pre-deploy migration phase.
The entrypoint uses `exec` so the server receives shutdown signals directly.

Production requires `DATABASE_URL` and rejects `AUTO_MIGRATE=true`.
`DATABASE_TLS_MODE` defaults to `require`, with certificate and hostname
verification. The Blueprint explicitly selects `disable` for Render's private
same-region connection because internal database certificates are self-signed.
Never use that override for an external database URL. The phone uses HTTPS.
Database credentials are resolved by Render's `fromDatabase` reference and are
never committed to the repository. The Blueprint does not change the existing
database's inbound access rules.

After the deployment becomes live, verify its assigned URL:

```sh
python3 Scripts/verify_backend.py https://YOUR-SERVICE.onrender.com --state /tmp/realpacman-deploy-check.json
```

Restart the web service, then rerun the same command using the same state file.
It must report that the saved result survived restart. This writes a synthetic
Explore result and checks its canonical score, concurrent retries, conflicting
uploads and missing-key rejection. Keep its UUID to identify the test result.

Enter the assigned HTTPS base URL in the iPhone app's Settings, refresh parcours
and sync a saved result. Physical-device verification remains a separate check.
Automatic deploys and Blueprint auto-sync should remain disabled for the class
presentation; deploy reviewed commits explicitly.

Free databases expire after 30 days and have no automatic backups. This instance
reports expiration on December 26, 2026, after the November 30 presentation.
Free web services sleep after 15 minutes without inbound traffic and may take
about a minute to wake. Open `/health` before the presentation and allow time for
startup. This is a class-project deployment, not a long-term production service.

References: [Render Docker](https://render.com/docs/docker),
[Blueprint fields](https://render.com/docs/blueprint-spec),
[database connectivity](https://render.com/docs/postgresql-creating-connecting),
[free plan limits](https://render.com/docs/free).

## Hosted verification (2026-11-26)

Live API: https://real-pacman-api-o256.onrender.com

- Workspace: Ryle's workspace; free web service `srv-dc3unf2jnfac73avd2gg`.
- Existing free PostgreSQL 18.7 database: `dpg-dc3uikrl550s73flnj9g-a`.
- Source: `codex/class-project-backend`, runtime commit `66a4cc2`.
- Linux image built successfully; startup migrations and database health passed.
- Public HTTPS checks passed with normal certificate verification: catalogue,
  canonical score, concurrent retries, conflicting UUID and missing-key rejection.
- A second deployment of the same commit became live; the saved result was then
  accepted as a duplicate, confirming persistence across the redeployment.
- All 53 app/core tests in eight suites passed with the live integration URL,
  including actual GameStore download, failure/retry persistence, and all three
  timed/ghost mode uploads. The standalone GPS/persistence executable also passed.
- Read-only SQL confirmed exactly one stored route snapshot for each of versions
  1 and 2, and five synthetic test results. These are not player walks.
- Physical iPhone sync and outdoor/airplane-mode testing remain unverified.

In the installed app's Settings, set the server URL to the live API base URL
above (without `/api/v1`). Then refresh parcours and sync results.

## Player accounts

`POST /api/v1/auth/register` and `/auth/login` accept `{username, password}`.
Usernames are case-insensitive, 3–24 ASCII letters/digits/underscores. Passwords
must be 10–72 UTF-8 bytes and are hashed with bcrypt on the password thread pool.
Responses contain `{player: {id, username}, token, expiresAt}`; expiry uses numeric
seconds since 2001 to match the client. Tokens have 256 random bits, expire in
30 days and are stored only as SHA-256 digests in the database. Authentication
attempts are limited to ten per remote address per minute per server process.

Send `Authorization: Bearer TOKEN` for uploads, `GET /api/v1/results`,
`GET /api/v1/auth/me` and `POST /api/v1/auth/logout`. Logout revokes that token.
Result ownership comes exclusively from the authenticated user, never a submitted
player ID. Replays must belong to the same player. Legacy anonymous results stay
unassigned and cannot be claimed by uploading their UUID. The result-list endpoint
returns only the player's receipt IDs and canonical scores. Catalogue and health
remain public. The additive AddPlayerAccounts migration preserves earlier data.

The app exposes Player Account from Settings and Statistics. Sign-in credentials
are bound to the selected server and stored in device-only Keychain; passwords
are never saved. New walks snapshot their player and server locally. Account
switches cannot reassign them. Guest play remains offline; only the explicit
Upload my saved guest walks action assigns previously unsynced guest results.
Local statistics and achievements remain device history, not cloud restoration.
Offline sign-out clears the device credential immediately; server revocation is
best effort, and unreachable sessions expire naturally. Signing out does not
remove locally saved walks. Expired sessions require signing in again.

Class-project scope: username/password accounts have no password reset, email
verification or account deletion UI. Do not use a password you need elsewhere.
Server ownership checks protect access, but client movement still is not proof of
a physical walk or competitive anti-cheat. Free hosting/expiry limits still apply.

Validation: 15 backend tests across four suites passed, including PostgreSQL
migration/persistence, registration, bcrypt verification, duplicate usernames,
invalid login, ownership, private result lists, revocation and expired tokens.
54 app/core tests passed with local live integration enabled, including explicit
guest assignment and account switching, plus standalone GPS/persistence checks.
The iOS Simulator build passed. Optional CI workflow remains local/unpublished.
