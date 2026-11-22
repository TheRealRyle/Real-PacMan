# Gameplay-1 — parcours foundation

## What existed

MapLibre 6.31 and the arcade selection UI; a linear route JSON model; local GPS
collection; JSON session/result persistence; a result upload queue; MapLibre map
pack downloads. No running Vapor/PostgreSQL service is present in this repository.

## What this branch adds

Play → choose parcours → choose mode → inspect/download → start for published
routes. Explore is implemented. Timed, Ghosts and Timed + ghosts are shown as
future modes, not selectable features.

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
uses a separate blue player marker. It stays north-up so arrows match the map;
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
The map retains its built-in provider/data attribution. Offline pack limits still
need enforcement before enabling draft downloads: see https://openfreemap.org/tos/.
Draft downloads remain disabled and fieldVerified remains false.

The gameplay map supports native pan, pinch zoom, compass and scale. Yellow dots
mark remaining pellets, a blue flag marks the proposed start, and the native blue
location dot shows the player and GPS accuracy. Controls restore the whole parcours
or follow the player at walking scale. The first GPS fix automatically enables
following only when it is within 500 m of the parcours. Panning interrupts native
following; the location button restores it. Camera requests are handled separately
from pellet updates, so collecting a pellet does not reset the camera. Reduce Motion
disables animated camera changes. A draft label remains visible during online play.

## Next practical steps

1. Review Verney's mapped network and remove unsuitable segments; choose and check
   an actual start, walk the area, and tune pellets using observed GPS accuracy.
2. Finalize the tile provider configuration and enforce its offline download limits;
   verify map completeness in airplane mode before publishing the parcours.
3. Add an explicit GPS start gate and Explore HUD/result completion polish.
4. Implement Vapor/PostgreSQL catalogue/version storage and result validation.
5. Prepare and field-check the station and USMB networks using the same schema.
6. Add timed rules; ghosts/achievements follow later.

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

No screen sharing or computer-control session was started for this branch.
Physical-device GPS, offline basemap downloads and backend integration remain
follow-up checks.


Gameplay polish: both real and demo sessions automatically show the score screen
on final collection. Collection now uses a shared eight-metre radius. Settings
provide follow zoom 16–19, with original 17.5 as the midpoint/default. A projected
edge marker points to the nearest remaining offscreen pellet and shows its direct
distance, updating as the map rotates, moves or zooms. The marker does not prescribe
a route across obstacles. Gameplay tests cover collection thresholds, automatic
completion/result handoff, nearest remaining selection and edge geometry.
