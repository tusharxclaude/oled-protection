# OLED Guard

Menu bar app that protects an OLED display from burn-in by blacking it out when idle, without disrupting an active meeting.

## Language

**Blackout**:
The true-black, full-screen overlay shown on a user-selected OLED display once it's been idle past the idle threshold. Dismissed instantly by real input or a meeting starting.
_Avoid_: screensaver, dim, overlay (when the overlay itself, not the act of showing it, is meant — see BlackoutController's role)

**Idle threshold**:
The configurable duration of no real input after which a display becomes eligible for blackout.
_Avoid_: timeout, idle timer (the system's built-in idle timer is explicitly not used — see SPEC.md Idle Detection)

**Real input**:
Mouse or keyboard input verified as hardware-sourced (not synthetic, e.g. Amphetamine's cursor-jiggle) via CGEventTap source-PID/source-state checks. Resets the idle clock and dismisses an active blackout.
_Avoid_: user input, activity (too broad — includes synthetic input, which real input explicitly excludes)

**Meeting exemption**:
The condition that suppresses blackout because a meeting is presumed in progress, approximated by any input-capable audio device being actively captured. Not "media is playing" — a narrower condition, chosen deliberately (see SPEC.md Feature 1).
_Avoid_: media exemption, mic check (the exemption is the domain condition; mic-active is just its current signal)

**Blackout Policy**:
The decision of whether blackout should currently be showing, given idle interval, idle threshold, pause state, and meeting exemption. A pure decision, independent of which displays exist or how the overlay is drawn.
_Avoid_: blackout logic, tick (tick is the poll loop that evaluates the policy, not the policy itself)

**Blackout Pause**:
A persistent override that suppresses the Blackout Policy from showing blackout on any display, until explicitly turned off. Distinct from dismissing an active blackout — pause also prevents the *next* one from triggering.
_Avoid_: pause (ambiguous alone — always say "Blackout Pause"), snooze

**Dismiss**:
Ending an already-showing blackout for that one instance — via real input, the meeting exemption, or the Escape key — without affecting whether blackout can trigger again afterward.
_Avoid_: exit, close, hide (hide is the overlay window's mechanic, not the domain action)
