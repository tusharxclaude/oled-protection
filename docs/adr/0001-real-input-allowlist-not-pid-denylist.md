# Filter real input via a source allow-list, not an Amphetamine PID deny-list

The idle clock needs to ignore Amphetamine's synthetic cursor-jiggle while still responding to real mouse/keyboard input. We filter on `sourcePID == 0 && sourceStateID == 1` (real HID hardware input) rather than deny-listing events carrying Amphetamine's own PID, because process IDs are assigned per-launch and aren't stable across an app restart — a deny-list would silently stop working the moment Amphetamine (or any other cursor-jiggling tool) relaunches. Validated empirically against Amphetamine via `poc/eventtap-logger` (see SPEC.md's Idle Detection section).

## Considered Options

- **Deny-list Amphetamine's PID** — rejected: PIDs aren't stable across relaunch, and it doesn't generalize to other synthetic-input tools (`caffeinate`, etc.).
- **Allow-list on `sourcePID == 0`, cross-checked with `sourceStateID == 1`** — chosen: app-agnostic, no need to track any specific process's identity.
