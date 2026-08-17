# Claude Usage Tracker

A certificate-free macOS desktop tile for Claude usage. It sits just above the wallpaper, uses native Liquid Glass on macOS 26, and shows capacity remaining for the 5-hour, weekly all-models, and model-specific limits.

![Design direction: the macOS Batteries widget, expressed with Claude limits.](https://img.shields.io/badge/macOS-native-1d1d1f)

## Install

Claude Code must already be signed in:

```sh
claude auth status
```

Then run:

```sh
cd /Users/davidesposito/Repos/ClaudeUsageTracker
./scripts/install-desktop.sh
```

The installer builds locally, applies an ad-hoc signature that needs no certificate, installs the app to `~/Applications/Claude Usage Tracker.app`, and opens it. No Xcode project, Apple Developer account, provisioning profile, or paid certificate is needed.

To install somewhere else, pass the destination directory:

```sh
./scripts/install-desktop.sh /Applications
```

## Use it

- Drag anywhere on the tile to reposition it. Its position is remembered.
- Hover a dial to temporarily reveal its exact percentage remaining.
- Right-click the tile to refresh or quit.
- Use the gauge icon in the menu bar to hide/show the tile, refresh it, move it back to the top-right, enable **Launch at Login**, or quit.
- Hover over the tile to reveal its refresh control.

The tile polls every 180 seconds. Reset countdowns update locally every 30 seconds without additional network requests.

## How it works

- Reads the existing `Claude Code-credentials` item using Apple's `/usr/bin/security` helper.
- Calls `https://api.anthropic.com/api/oauth/usage` with Claude Code's OAuth token and current CLI version.
- Sends the token only to Anthropic. It is never logged, copied to disk, or included in the usage cache.
- Stores only percentages and reset timestamps in local `UserDefaults` so the last successful reading remains visible during transient failures.
- Uses a borderless AppKit panel at desktop window level, outside WidgetKit and its signing requirements.
- Uses AppKit's native `NSGlassEffectView` clear style on macOS 26 and falls back to an adaptive material on older supported macOS versions.

The personal OAuth endpoint is not a documented public API and may change. The decoder supports both the current `limits` response and the older usage-window fields.

## Develop and test

This is a standard Swift package:

```sh
swift run ClaudeUsageTrackerDesktop
swift test
```
