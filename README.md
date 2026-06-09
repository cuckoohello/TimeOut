# TimeOut for macOS

[中文文档](README.zh-CN.md)

A polished native macOS menu bar break reminder built with SwiftUI + AppKit, inspired by the classic Time Out app. TimeOut helps reduce eye strain, fatigue, and prolonged sitting by scheduling micro and normal breaks with smart rules, multi-screen overlays, notifications, statistics, and English / Chinese UI.

## Features

- **Micro & Normal Breaks**: Configure short frequent micro breaks and longer normal breaks independently.
- **Menu Bar Countdown**: Optionally show a live countdown next to the menu bar icon.
- **Multi-Screen Overlay**: Shows a break overlay across all connected displays with smooth fade animations.
- **Break Themes**: Choose Timer, Breathing, Eye Rest, Stretch, or Custom Text themes for each break type.
- **Preparation Window**: Get a short warning before a break starts, with a one-click “Start Now” action.
- **Postpone & Skip Controls**: Postpone breaks by 1 / 5 / 15 minutes or skip them when needed.
- **Smart Rules**: Avoid disruptive breaks while another app is full screen, excluded apps are active, or outside your schedule.
- **Active Schedule**: Restrict reminders to configured hours, with weekday-only and cross-midnight support.
- **Natural Break Detection**: Resets timers when you are idle, away, sleeping, or returning from system inactivity.
- **Notifications & Sounds**: Optional system notifications before / during / after breaks, plus sound cues.
- **Daily Statistics**: Track completed, skipped, postponed, rule-postponed, and natural breaks for today.
- **Skip / Postpone Limits**: Keep breaks meaningful by limiting repeated skips or postpones.
- **English / Chinese UI**: Switch language in Settings → General → Language; the app also auto-detects system language on first launch.
- **Launch at Login**: Option to auto-start TimeOut when you log in.

## Build & Package

**Requirements:** macOS 14.0+ (Sonoma), Swift 5.9+

### Quick Start

```bash
# Build and run directly
make run

# Or use Swift Package Manager
swift run
```

### Create .app Bundle

```bash
# Package the app for the current architecture (creates TimeOut-arm64.app or TimeOut-x86_64.app)
make package

# Install to /Applications as TimeOut.app (without architecture suffix)
make install

# Build for a specific architecture
make package ARCH=arm64
make package ARCH=x86_64
```

### All Available Commands

```bash
make help       # Show all available commands
make build      # Build release binary
make package    # Create .app bundle
make install    # Install to /Applications/TimeOut.app
make run        # Build and run
make test       # Run tests
make clean      # Remove build artifacts
```

## Settings

Open the menu bar icon and choose **Settings…**.

- **Breaks**: Enable / disable Micro and Normal breaks, configure intervals, durations, idle reset thresholds, and themes.
- **Rules**: Configure active schedule, full-screen behavior, and excluded foreground apps.
- **Alerts**: Configure notifications, sounds, and skip / postpone limits.
- **Stats**: View today’s break activity summary.
- **General**: Toggle menu bar countdown, launch at login, and language.

## Development

Open the folder in Xcode and press Run, or use `swift run` for quick testing.

## Releases

### Download Latest Release

Visit the [Releases page](https://github.com/cuckoohello/TimeOut/releases) to download the latest version.

### Creating a New Release

Releases are automatically built and published via GitHub Actions when you push a version tag:

```bash
# 1. Update version in Makefile (optional)
# 2. Commit your changes
git add .
git commit -m "chore: bump version to 1.0.0"

# 3. Create and push a version tag
git tag v1.0.0
git push origin v1.0.0

# 4. GitHub Actions will automatically:
#    - Build the app
#    - Create a ZIP archive
#    - Publish to GitHub Releases
```

### Manual Release Build

```bash
make release    # Creates both .app bundle and .zip archive
make zip        # Creates only .zip archive from existing .app
```
