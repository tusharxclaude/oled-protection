# Build via SwiftPM + manual .app bundle assembly, not an Xcode project

OLEDGuard is built as a SwiftPM executable target with a `build.sh` script that manually assembles the `.app` bundle (`Info.plist` + ad-hoc `codesign --sign -`), rather than an Xcode project. This kept development entirely in file edits and shell commands instead of screenshot-driven Xcode GUI automation. Consequence discovered during testing: ad-hoc signing gives the app a different identity on every rebuild, which can silently invalidate a previously-granted Input Monitoring TCC permission — `CGEvent.tapCreate` then succeeds but the tap never delivers events, with no error surfaced anywhere. This is why Escape-key dismiss (`BlackoutWindow`, standard AppKit `keyDown`) was deliberately built independent of the CGEventTap entirely — a permission-independent fallback that exists specifically because this failure mode does.

## Considered Options

- **Xcode project** — more typical for a menu bar app, and a stable Team ID / Developer ID signing identity would avoid the TCC churn — deferred to keep early iteration screenshot-free; worth revisiting before real distribution, since notarization needs a real signing identity anyway.
- **SwiftPM + manual bundle script** (chosen) — fast, tool-light iteration, but reintroduces the Input Monitoring permission prompt on every rebuild during development.

## Consequences

Every dev rebuild may require re-granting Input Monitoring in System Settings. Before shipping, this should move to a stable signing identity (self-signed cert kept in Keychain, or eventually a real Developer ID) so the grant persists — ad-hoc signing is fine for local iteration but not the long-term plan.
