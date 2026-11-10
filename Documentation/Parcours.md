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

The vector preview is fully local and shows separate paths, the park boundary,
proposed pellets and proposed start. There is no network request for this preview.
The draft cannot start GPS gameplay or trigger a basemap download.

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
publication flag, not an anti-cheat guarantee. Review all payloads server-side too.

MapLibre renders individual graph edges and sizes offline map regions around
all geometry. Offline storage startup is awaited before deciding a pack is absent,
avoiding duplicate packs after relaunch. An unfinished pack can be resumed.

The bundled draft carries an OpenFreeMap Liberty style URL for future review;
it is not fetched by the draft preview. Before publishing it for online/offline
use, configure request identification/concurrency/download budgets to meet
https://openfreemap.org/tos/ and retain attribution. Current provider terms limit
offline packs to 3,000 tiles or 50 MB and four parallel requests, with an app User-Agent.
This branch does not claim to enforce that provider policy or enable draft downloads.
Do not change fieldVerified to bypass that remaining integration work.

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
compatibility, server override, draft start protection and versioned scoring.
The Xcode app is separately built against the iOS Simulator SDK.

No screen sharing or computer-control session was started for this branch.
Physical-device GPS, offline basemap downloads and backend integration remain
follow-up checks.
