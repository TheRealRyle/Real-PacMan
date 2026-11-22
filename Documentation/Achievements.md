# Achievements

Home → Achievements opens eight badges with requirements, progress, locked/earned
states and first-earned dates. Completing or stopping a real run evaluates new
unlocks, which appear on its score screen with a link to the achievement page.

| Badge | Requirement |
| --- | --- |
| First Outing | Save one real run, including a manually stopped run. |
| Clean Sweep | Finish a parcours with every pellet. |
| Encore! | Finish three full runs. Replays of the same parcours count. |
| Pocketful of Pellets | Collect 50 pellets across saved runs; partial runs count. |
| Quick Clear | Complete one run in at most 30 minutes from start to finish. |
| Double Feature | Complete two non-overlapping runs within 90 minutes from the first start to the second finish. Replays count. |
| Untouchable | Complete Ghosts or Timed + Ghosts with all three hearts. |
| Beat the Clock | Complete Timed or Timed + Ghosts with strictly positive time remaining. |

Quick Clear and Double Feature use wall-clock time, including pauses and breaks.
Beat the Clock uses the mode's active-play timer. Full clears require all actual
pellets and a completed outcome (or no outcome for compatible legacy results).
Failures, partial runs and unfinished sessions cannot satisfy a full-clear badge.
Only valid pellet IDs count toward the pellet total.

AchievementTracker derives progress and earliest unlock dates from durable local
results; there is no second save file or archive migration. Existing history
backfills automatically, result IDs are deduplicated, and sync does not re-award
badges. New unlock celebrations are transient and reset on a new run. DemoSession
does not write real results and cannot earn badges. Badges are local to this
device's saved history; account-wide restoration is not implemented.

All eight are attainable using the bundled parcours and replays. Tests exercise
all-eight unlocks on that route, partial/duplicate/overlapping results, exact time
boundaries, lost hearts, failed outcomes, legacy history, actual GameStore GPS
completion, demo exclusion and persistence after GameStore reload.
