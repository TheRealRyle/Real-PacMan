# UI motion

The `ui-animation-rules` skill defines the motion preferences for this app. Use native SwiftUI equivalents of its web examples.

`ArcadeEntrance` starts at scale 0.97 and opacity 0, then eases to full size and opacity over 250 ms. Entrances stay local to each element, preserve their staggered delays, and cancel when the element disappears. Reduce Motion shows content immediately.

`ArcadeButtonFace` uses uniform 0.97 scale with a 150 ms ease-out for both press and release. It owns the compression state so fast taps remain visible, with a minimum 90 ms feedback window. It uses transforms without changing layout, and does not squash, shift, or overshoot. Gameplay controls use the same button style.

`ArcadeActionButton` sends an activation signal through the environment. This guarantees feedback on a fast tap or accessibility activation even when a scroll view does not deliver a visible touch-down state. An accepted action waits 60 ms before executing. Reduce Motion skips transforms and the delay.

Pending actions ignore repeated activation, cancel on disappearance, and cancel when the scene becomes inactive. Native Button semantics remain responsible for hit testing, scroll cancellation, disabled controls and accessibility. No competing drag or tap gestures are added.

The delayed control is used by menu navigation, custom back buttons, level arrows and result sync. Gameplay pause/resume and finish controls act immediately; confirmation dialogs retain system buttons.

The parcours carousel uses a native horizontal `ScrollView` with view-aligned snapping and horizontal bounce enabled. Native scrolling owns release velocity, progressive edge resistance and spring-back. There is no separate selection-triggered pop animation. Arrow navigation uses a 0.5-second spring with no bounce. Scroll transitions scale cards no smaller than 0.97 and skip transforms with Reduce Motion enabled.

Navigation uses the system's directional push/pop transitions. The current app has no password form, accordion, tooltip group, theme switch or custom drag gesture; apply those skill rules when those features are introduced.

Gameplay uses a street basemap with native map gestures, compass, scale, remaining-pellet dots and the location accuracy indicator. The location button follows the player; the map button restores the parcours overview. Camera animations respect Reduce Motion. Draft status stays visible, and a failed or stalled street-map load falls back to the saved layout with a retry control.

The mode chooser also offers a demo with four native, repeating arrow buttons.
These use the same 0.97 press scale and 150 ms ease-out as other arcade buttons.
The demo uses a simulated player without requesting location access. Pause and
Restart remain available beside the direction controls, with vertical reflow when
space is limited. The screen labels its points as practice scores and keeps them
out of saved walks and Statistics.

When reviewing on-device, check fast taps, a held press, release after dragging away, disabled level arrows, carousel flicks and overscroll at both ends, forward/back navigation, and Reduce Motion.


Completing the final pellet automatically replaces gameplay with a score screen,
for real walks and demos. Real results remain queued durably; demo scores remain
in memory. Partial walks also show their saved score when finished manually.

Settings → Map Zoom controls the follow camera from 16 (wider) to 19 (closer).
The midpoint and default is the original 17.5 zoom. Pinch/overview remain available;
Follow restores the chosen setting. Real and demo play share this preference.

The nearest remaining pellet has an edge arrow and distance when it is outside
the unobscured map viewport. The marker uses MapLibre's screen projection, so
its position and angle update with camera rotation, pan, zoom and player movement.
It disappears when that pellet becomes visible or all pellets are collected.
This is a direct-distance cue, not a walking itinerary; stay on public paths.

In real play, tapping Follow again switches from location follow to heading follow,
so the map and edge cue rotate with the device heading. Further taps toggle back
to location follow. The direction pad remains north-up in demos. Physical heading
accuracy and GPS collection still require on-device verification.

The gameplay HUD uses a shared navy dashboard in real and demo play, with yellow
score highlights, a pellet progress bar, live/paused status and distance travelled.
The map sits in a rounded frame above the dashboard; compact cyan-on-navy map
controls and a matching route banner preserve map visibility and attribution.
Navigation uses a dark bar. Controls retain their existing actions and 0.97 press
feedback, and the dashboard uses Dynamic Type with reflow for its status row.

The saved zoom also controls the initial gameplay view around the parcours start,
including when GPS is unavailable or the player is away from the parcours. The
whole-parcours fit is an explicit map-button action in gameplay. Native GPS-follow
startup reapplies the selected zoom after tracking begins and its first valid fix;
manual gestures remain available. Route-detail maps retain their overview framing.

Stage two adds a mode chooser for Explore, Timed, Ghosts and Timed + Ghosts on
supported parcours, with walking and demo entry points for each. The mode HUD
shows the active countdown and/or remaining lives. Virtual ghosts are visible on
both the street map and saved-layout fallback. Timeout, final-life loss and final
pellet collection lead to the score screen; history records the selected mode and
outcome. Clocks run only in active non-Explore gameplay and reset their tick origin
on resume, treating intervals over 60 seconds as a discontinuity.

New ghost runs spawn enemies on legal paths roughly 40–70 metres from the start,
with an initial collision grace period. Ghosts re-plan toward the player's latest
position each tick and can reverse mid-path. Street-map markers use large pink,
cyan and orange ghost sprites. A pink edge arrow shows the nearest ghost's distance
and direction when it is outside the unobscured viewport; it follows map rotation.
The route banner also reports the active ghost count. Resumed runs retain their
saved positions; restarting a demo or starting a new run uses the nearby spawns.

Losing a life triggers a 360 ms horizontal shake, a brief red tint, a “Life lost”
notice and the hit sound. The three-heart health display animates the lost heart
upward into an empty outline. Reduce Motion removes translation and scaling and
softens the tint while retaining the notice, fading heart and VoiceOver announcement.
Feedback observes lives above the gameplay/score switch, so the final hit still
plays immediately without delaying the score screen. Restoring or restarting a
run does not trigger damage feedback.

Parcours selection cards own their offline-map download controls and status.
Download Parcours starts from the card, with progress and Pause/Resume controls;
completion replaces the action with a green “Downloaded · Ready Offline” badge.
Opening selection checks persistent packs, awaiting the SDK's initially unknown
state before showing completion. Downloads are matched by route ID and version,
and the saved layout is distinguished from downloaded street-map resources.
Walk details retain their preview/start controls; downloads live on selection.

Home includes an Achievements button. Its trophy cabinet shows eight badges with
requirements, progress, earned dates and distinct locked/unlocked states. A navy
and gold summary counts unlocked badges; adaptive cards reflow on larger displays.
The score screen shows achievements newly earned on a real run. Buttons and
entrances use the shared motion rules. See Achievements.md for the actual rules.

The player is a 40-point yellow arcade character with a navy outline, white outer
ring and a mouth facing movement. Demo arrows set its bearing; real maps use
valid walking GPS course, falling back to movement of at least three metres.
At rest it retains direction, and camera rotation is subtracted from the bearing.
The native GPS location view draws a soft blue accuracy halo scaled in map metres;
demo play has no accuracy halo. The saved-layout fallback draws the same vector
asset at 32 points. There is no looping pulse or position/rotation animation.

Newly earned achievements appear on the score screen with a gold medallion, halo,
large badge title, gold particles and a short fanfare. The shared 0.97 entrance
settles before a finite 900 ms medal burst; controls remain interactive. Multiple
unlocks share one reveal and show the additional badges beneath the featured one.
The reveal and sound run once per presentation, cancel pending playback when
leaving or backgrounding, and do not replay on returning from the trophy cabinet.
Reduce Motion keeps the static medal/glow and omits movement, rotation and particles.

A full parcours clear leads with an animated trophy medallion, finite gold burst,
large victory title and a score that counts up over 850 ms before settling. The
pellet bar fills over 650 ms and the summary shows distance, active time when
recorded, and remaining hearts for ghost modes. Real and practice clears share
the presentation; practice scores remain separate. The final score is announced
directly to VoiceOver, and Reduce Motion shows it immediately with a static trophy.
Done/Play Again stay pinned beneath the scrollable results and remain usable
throughout the celebration. Failed or stopped runs use distinct outcome icons
and static scores. A successful clear shares one fanfare/announcement with newly
earned badges. Pending celebration cancels on departure/backgrounding and does
not replay when returning from the trophy cabinet.
