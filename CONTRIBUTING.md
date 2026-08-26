# Contributing to OLED Guard

Thanks for considering a contribution.

## Reporting bugs / requesting features

Open a [GitHub issue](https://github.com/tusharxclaude/oled-protection/issues). Include your macOS version, display setup (which display is OLED, whether it's the built-in panel or external), and steps to reproduce for bugs.

## Development setup

Requires macOS 13+ and Xcode.

```bash
git clone https://github.com/tusharxclaude/oled-protection.git
cd oled-protection/OLEDGuard
swift build
swift test
```

`./build.sh` produces a runnable `OLEDGuard.app` for manual testing.

## Making changes

1. Fork the repo and create a branch off `main`.
2. Keep changes focused — a PR should do one thing.
3. Add or update tests under `OLEDGuard/Tests/OLEDGuardTests` for any behavior change.
4. Make sure `swift build` and `swift test` pass (CI runs both on every PR).
5. Open a pull request describing the change and why it's needed.

## Design context

Before proposing a significant change, skim [SPEC.md](SPEC.md) (feature spec, including ideas that were deliberately cut and why) and [CONTEXT.md](CONTEXT.md) (domain vocabulary) — several design choices (e.g. why blackout uses pure black instead of a video loop, why the meeting exemption checks mic-active rather than any media playback) were made deliberately and are documented there. The [docs/adr/](docs/adr) directory has additional architecture decision records for less obvious implementation choices.

## Code style

Follow the conventions already in the codebase (see `OLEDGuard/Sources/OLEDGuard/`) — dependency injection via initializer defaults for testability, and comments only where they explain a non-obvious *why*.
