# Meeting exemption via CoreAudio mic-capture, not MediaRemote

SPEC.md originally proposed exempting blackout during "active media playback" using the private `MediaRemote` framework. We instead exempt only during meetings, detected via CoreAudio's `kAudioDevicePropertyDeviceIsRunningSomewhere` checked across all input devices (mic actively captured = meeting presumed in progress). `MediaRemote` reports any media playback — it would also exempt e.g. watching a video, which is broader than intended — and it's an undocumented private framework with no update guarantee. CoreAudio's device-running check is public and documented, and narrower to just "meeting," at the cost of being a proxy signal rather than a direct "in a Teams call" read.

## Considered Options

- **Private `MediaRemote` framework** (spec's original proposal) — rejected: too broad (any media playback counts), undocumented and could break across macOS updates.
- **CoreAudio mic-capture across all input devices** — chosen: public API, semantics narrower to "meeting," at the cost of being a proxy rather than app-specific detection.

## Consequences

Unverified assumption: whether meeting apps (Teams/Zoom/etc.) keep the input device open while locally muted. If an app instead releases the device on mute, muted meetings won't be exempted — open risk, see SPEC.md.
