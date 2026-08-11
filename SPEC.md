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
- Filter out synthetic input by checking `kCGEventSourceUnixProcessID` per event — real hardware events report PID 0/self; injected events report the injecting process's PID (same mechanism WindowServer itself uses to gate synthetic events).
- **⚠️ OPEN — needs POC before relying on it**: build a throwaway CLI event-tap logger, trigger Amphetamine's cursor-jiggle, confirm its events are attributable and filterable. Unconfirmed risk: Amphetamine may use a lower-level API (e.g. `CGWarpMouseCursorPosition`) that bypasses the event tap entirely.

## Feature 1 — Idle Blackout

- Trigger: filtered idle clock exceeds threshold (configurable).
- Overlay: true black (`RGB 0,0,0`) full-screen window — zero photon emission, strictly better than any video loop.
- Scope: **user-selected OLED displays only** (manual toggle per display in prefs — no EDID-based auto-detection; macOS has no public "is this OLED" API, and a lookup table isn't worth maintaining for one monitor).
- Dismiss: any real (filtered) mouse/keyboard input → instant, no fade (OLED pixels switch near-instantly; a fade adds cost with no visual benefit).
- Exemption: active media playback (via private `MediaRemote` framework — undocumented, no Apple guarantee across OS updates, same risk category as the PID-filtering approach).
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

1. **Amphetamine synthetic-input filtering** — validate `kCGEventSourceUnixProcessID` approach actually catches Amphetamine's injected events before building the idle clock on top of it.
2. **`MediaRemote` reliability** — private/undocumented framework; confirm it correctly reports now-playing state for your actual media sources (browser tabs, apps) and monitor for breakage across macOS updates.
