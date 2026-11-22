# Gameplay-1 — parcours foundation

## What existed

MapLibre 6.31 and the arcade selection UI; a linear route JSON model; local GPS
collection; JSON session/result persistence; a result upload queue; MapLibre map
pack downloads. The Vapor API now lives in Server/; its PostgreSQL runtime still needs host setup.

## What this branch adds

Play → choose/download parcours → choose mode → inspect → start for published
routes. The selection card offers Download Parcours, progress, Pause/Resume and a
Downloaded · Ready Offline badge. Status comes from MapLibre's persistent pack
for that route ID and version, so an older pack does not mark an updated parcours
as downloaded. The bundled layout alone does not mark the street map downloaded.
Explore, Timed, Ghosts and Timed + ghosts are selectable on the version-two
Verney draft, in both walking and GPS-free practice sessions.

The three planned locations appear in the existing bouncy carousel:
- Parc du Verney, Chambéry: a bundled, inspectable map draft.
- Chambéry Station: named location; layout not yet prepared.
- USMB, Le Bourget-du-Lac: named location; layout not yet prepared.

Choose **DEMO · ARROW CONTROLS** on the mode screen to practice without GPS.
The player begins at the proposed start, with four cardinal-direction buttons.
Each tap moves five metres; holding an arrow repeats. Movement is free, including
off the path network. Nearby pellets use the same 8 m collection radius as a walk.
Pause stops movement; Restart resets the demo. Completing all pellets stops the
session until restarted. Leaving the screen or backgrounding the app pauses it.

DemoSession is independent of GameStore and lives only in memory. Demo points
never enter Statistics, saved walk progress or the upload queue, and an existing
walk can remain saved while a demo runs. The demo map disables native GPS and
uses the yellow player character without an accuracy halo. It stays north-up so arrows match the map;
camera follow, overview and saved-layout fallback work with the simulated player.

The vector preview is fully local and shows separate paths, the park boundary,
proposed pellets and proposed start. There is no network request for this preview.
Explore now uses the street basemap during gameplay, including for the draft.
The saved vector layout remains the fallback when the street map fails to load
or has not loaded after 15 seconds. Catalogue previews remain fully local.

## Verney: evidence versus proposed game content

Location confirmation: https://www.chambery.fr/382-parcs-et-jardins-chamberiens.htm
Park boundary: https://www.openstreetmap.org/way/37562187
Geographic source: OSM API extract fetched 2026-11-10.
Data attribution: © OpenStreetMap contributors, ODbL 1.0,
https://www.openstreetmap.org/copyright

Documentation/Geodata contains the park boundary and a filtered copy of the
source walking ways/nodes used for the prototype. The filtered extract preserves
OSM IDs, tags and timestamps. It is geographic data, separate from the app code.

The importer:
- includes mapped footways, pedestrian ways and paths inside the park polygon;
- excludes area outlines, crossings, sidewalks, and paths/nodes tagged no/private/destination;
- retains the largest connected component instead of drawing artificial connections;
- proposes a southernmost network node as the starting point;
- places proposed pellets on included paths, roughly 22 m apart spatially;
- uses deterministic IDs so repeated imports of this snapshot are identical.

The resulting draft has 145 nodes, 167 short path segments, 25 proposed pellets,
and about 1.5 km of total path network. This is NOT a prescribed 1.5 km itinerary:
players choose the collection order and may retrace paths. The duration estimate
is network length / 60 m per minute, rounded up; it is not field measured.

These are mapped paths, not verified current pedestrian access. Gates, obstacles,
temporary closures, accessibility, start suitability and GPS/pellet spacing have
not been checked on foot. fieldVerified is deliberately false.

Regenerate the bundled prototype:
python3 Scripts/import_verney_parcours.py Documentation/Geodata/verney-boundary.osm Documentation/Geodata/verney-paths.osm

## Architecture

Keep GameRoute as the server/cache envelope, add optional ParcoursDefinition as
the versioned graph. Junction IDs establish connectivity; path polylines retain
the true geometry. coordinates remains a legacy fallback. Pellet values default
to 10 when reading older payloads. Existing progress and queued results stay readable.

The bundled catalogue is a development seed, not a substitute for the server.
Server definitions with the same stable IDs take precedence. Field review is a
map review status. Review all payloads server-side too.

MapLibre renders individual graph edges and sizes offline map regions around
all geometry. Offline storage startup is awaited before deciding a pack is absent,
avoiding duplicate packs after relaunch. An unfinished pack can be resumed.

The bundled draft carries an OpenFreeMap Liberty style URL, used by the gameplay
street map; it is not fetched by the catalogue preview. MapLibre requests identify
the app with a versioned User-Agent and use at most four connections per host.
The map retains its built-in provider/data attribution. Walking downloads use a
padded region at zooms 12–17, reject invalid/oversized areas and reject estimated
tile coverage over 3,000 before creating a pack. The app uses four connections and
an identifying User-Agent; see https://openfreemap.org/tos/. Draft maps can now be
downloaded from selection, while fieldVerified remains false and the on-foot
review label remains visible. Downloads pause on departure/backgrounding and can
be resumed. Completed packs remain stored by the map SDK across app launches.

The gameplay map supports native pan, pinch zoom, compass and scale. Yellow dots
mark remaining pellets, a blue flag marks the proposed start, and a yellow arcade
character marks the player with a blue GPS accuracy halo. Controls restore the whole parcours
or follow the player at walking scale. The first GPS fix automatically enables
following only when it is within 500 m of the parcours. Panning interrupts native
following; the location button restores it. Camera requests are handled separately
from pellet updates, so collecting a pellet does not reset the camera. Reduce Motion
disables animated camera changes. A draft label remains visible during online play.

## Next practical steps

1. Review Verney's mapped network and remove unsuitable segments; choose and check
   an actual start, walk the area, and tune pellets using observed GPS accuracy.
2. Verify map completeness across supported zoom settings in airplane mode before
   publishing the parcours; review source counts and budgets when adding styles.
3. Validate the GPS start experience and on-device mode behavior.
4. Exercise PostgreSQL migrations and deploy the API behind HTTPS and authentication.
5. Prepare and field-check the station and USMB networks using the same schema.
6. Field-test Timed and Ghosts balancing; achievements follow later.

## Verification

python3 Scripts/test_parcours.py runs Swift Testing on the actual core app sources
inside a temporary Swift package. Tests cover the real bundled graph, invalid
references/disconnection/outside pellets/invalid values, old JSON and saved-session
compatibility, server override, draft Explore collection and versioned scoring.
The Xcode app is separately built against the iOS Simulator SDK.

Demo checks also cover five-metre cardinal movement, repeat collection prevention,
pause/resume, completion/restart, the bundled starting point, and preserving the
real walk file and result queue. The simulator build includes the demo entry,
street-map player marker, direction pad and completed-demo state.

Physical-device GPS and offline basemap downloads remain follow-up checks.
Local API integration has been exercised; PostgreSQL still needs runtime verification.


Gameplay polish: both real and demo sessions automatically show the score screen
on final collection. Collection now uses a shared eight-metre radius. Settings
provide follow zoom 16–19, with original 17.5 as the midpoint/default. A projected
edge marker points to the nearest remaining offscreen pellet and shows its direct
distance, updating as the map rotates, moves or zooms. The marker does not prescribe
a route across obstacles. Gameplay tests cover collection thresholds, automatic
completion/result handoff, nearest remaining selection and edge geometry.

## Stage 2 modes

Timed runs use the parcours estimated duration (at least one minute) as an active-play countdown. Ghost modes spawn up to three virtual enemies on the authoritative path network. They chase at 0.9 m/s and remain on mapped paths. The player has three lives, an initial grace period, and eight seconds of immunity after a hit within eight metres. Combined mode applies both constraints. Physical running is never required.

All-pellet collection, timeout, losing the final life, or manually stopping lead to the score screen with the appropriate outcome. Pausing, leaving gameplay and backgrounding stop the clock and ghosts. Active elapsed time, lives and ghost state are saved with real sessions; practice remains local and separate from Statistics.

Version two advertises all four modes. Older cached catalogue entries cannot replace a newer bundled version; active sessions retain their original snapshots. The server migration keeps version one for existing saved results and adds version two without rewriting it. New result payloads carry optional rules metadata; old Explore results without that field remain supported.
