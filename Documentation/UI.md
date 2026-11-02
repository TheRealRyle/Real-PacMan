# Arcade button feedback

ArcadeButtonFace owns the compression state rather than rendering the native isPressed flag directly. Touch-down begins compression, and release waits until a minimum 90 ms visible compression window before a low-damping spring rebound.

ArcadeActionButton also sends an activation signal through the environment. This guarantees feedback on a fast tap or accessibility activation even when a scroll view does not deliver a visible touch-down state. An accepted action waits 360 ms so the squash/rebound appears before navigation. Reduce Motion skips transforms and the delay.

Pending actions ignore repeated activation, cancel on disappearance, and cancel when the scene becomes inactive. Native Button semantics remain responsible for hit testing, scroll cancellation, disabled controls and accessibility. No competing drag or tap gestures are added.

The same delayed control is used by menu navigation, custom back buttons, level arrows and result sync. Native confirmation dialogs retain system buttons.

Validation: simulator SDK build; simulator launch and Settings/back navigation. Check fast taps, a held press, release after dragging away, disabled level arrows, and Reduce Motion when reviewing the animation on-device.
