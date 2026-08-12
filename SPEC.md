# OLED Guard — macOS App Spec (v1 / MVP)

Native macOS menu bar app to protect a 34" OLED ultrawide (Dell/Alienware AW3426DW) from burn-in without disrupting an always-active MS Teams session (kept awake via Amphetamine).

## Architecture

- **Form factor**: menu bar–only background agent (`LSUIElement`, no Dock icon). Not a Screen Saver (`.saver`) module — those run in a separate Space/lock context and can't manipulate other apps' windows.
- **Distribution**: direct, self-signed + notarized `.app`. Not App Store–compatible — required permissions (Accessibility, Input Monitoring) aren't sandbox-safe.
- **Permissions**: Accessibility (read/move/minimize windows) + Input Monitoring (event tap for idle clock). Requested via first-run onboarding flow that explains why each is needed.
- **Permission revoked mid-session**: blocking alert prompting re-grant; affected features pause until resolved.
- **Launch at login**: user choice, presented explicitly during onboarding (not silently defaulted).
- **Debug mode**: hidden, Option-click the menu bar icon → fast-forwarded timers for testing.

## Idle Detection (foundation for blackout)

- Custom idle clock, not the system's built-in idle timer (Amphetamine's "move mouse cursor" feature resets that on purpose).
- Listen-only `CGEventTap` observing all mouse/keyboard events.
- Filter out synthetic input by checking `kCGEventSourceUnixProcessID` per event — accept only events where it's `0` (real hardware); reject everything else. This is an allow-list, not a deny-list keyed to Amphetamine's PID specifically — PIDs are assigned per-launch and aren't stable across an app restart. Cross-check with `kCGEventSourceStateID` (`1` = `kCGEventSourceStateHIDSystemState` for real hardware, `0` = `kCGEventSourceStateCombinedSessionState` for `CGEventPost`-injected events) as a second, harder-to-spoof signal.
- **✅ RESOLVED via POC** (`poc/eventtap-logger/`, 2026-08-12): confirmed Amphetamine's cursor-jiggle events report `sourcePID=<Amphetamine's PID>, sourceStateID=0`; real mouse/keyboard input reports `sourcePID=0, sourceStateID=1`. The two are cleanly distinguishable — Amphetamine does not bypass the event tap via a lower-level API.

## Feature 1 — Idle Blackout

- Trigger: filtered idle clock exceeds threshold (configurable).
- Overlay: true black (`RGB 0,0,0`) full-screen window — zero photon emission, strictly better than any video loop.
- Scope: **user-selected OLED displays only** (manual toggle per display in prefs — no EDID-based auto-detection; macOS has no public "is this OLED" API, and a lookup table isn't worth maintaining for one monitor).
- Dismiss: any real (filtered) mouse/keyboard input → instant, no fade (OLED pixels switch near-instantly; a fade adds cost with no visual benefit).
- Exemption: **meetings only, not general media playback** — checks whether the default input device is actively captured (`kAudioDevicePropertyDeviceIsRunningSomewhere` via CoreAudio, a public API). Chosen over the originally-considered private `MediaRemote` framework because `MediaRemote` reports *any* media playback (e.g. a YouTube video), which is broader than "in a meeting." Mic-active is used as a proxy for "meeting in progress" rather than identifying the specific app.
  - **Assumption to verify**: meeting apps (Teams/Zoom/etc.) keep the input device open while locally muted, for near-instant unmute — if an app instead releases the device on mute, muted meetings won't be exempted. Untested against real Teams usage.
  - **Known gap**: only checks the system *default* input device — a meeting app using a non-default mic (headset selected only inside that app) won't be caught.
- No notification-driven wake (system/app notification sounds already alert you).

## Feature 2 — Auto-Minimize Static Windows

- Trigger: per-window "not interacted with" timer, default 30 min, **duration configurable**.
- Action: minimize (not dim — dimming needs a synced overlay + AX observer + click-through handling; minimize is a single AX action with nothing to desync). **Dim vs. minimize is itself configurable.**
- Scope: universal (all windows, not an allow-list) — but **OLED displays only**, same as blackout. Track each window's current display; re-evaluate if dragged mid-timer.
- Exemption: any app currently using mic or camera is exempt (app-level granularity — no reliable AX signal exists to identify "the call window" specifically within a multi-window app).
- Grace period: configurable countdown warning toast before minimizing, dismissible by interacting with that window. Default on.
- Restore: manual only (Dock click / Cmd+Tab) — no auto-restore on incoming notification/badge, since re-lighting the window defeats the purpose.

## Feature 3 — Manual Override

- Menu bar "Presenting Mode" toggle: pause both blackout and minimize for N hours or indefinitely.
- Global keyboard shortcut for instant kill.
- Exists regardless of how good the automatic signals (mic/camera, MediaRemote) get — guaranteed escape hatch for cases they miss (screen-share-only, clicker-driven decks, unrecognized call apps).

## Explicitly Cut (considered, rejected — keep for context)

| Idea | Why cut |
|---|---|
| Continuous window-position drift/nudge | Redundant — AW3426DW firmware already does always-on pixel shift, logo detection, pixel refresh at zero CPU/GPU cost |
| Full-screen video instead of black | Any video has non-zero average picture level; pure black is strictly better and simpler |
| EDID-based OLED auto-detection | No public "is OLED" API; lookup table of models not worth maintaining vs. a manual toggle |
| Dim (HazeOver/Isolator-style overlay) | Real technique (confirmed via HazeOver/Isolator prior art), but much more engineering than minimize for marginal benefit here |
| Mac App Store distribution | Incompatible with required Accessibility/Input Monitoring permissions |
| Auto-restore minimized windows on notification | Defeats the purpose of minimizing in the first place |

## Open Risks Requiring a POC

1. ~~**Amphetamine synthetic-input filtering**~~ — resolved, see Idle Detection section above.
2. **`MediaRemote` reliability** — private/undocumented framework; confirm it correctly reports now-playing state for your actual media sources (browser tabs, apps) and monitor for breakage across macOS updates.
