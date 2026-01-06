# TimeOut for macOS

A native macOS break reminder app built with SwiftUI, inspired by the classic Time Out app. It helps you prevent eye strain and fatigue by reminding you to take regular breaks.

## Features
- **Flexible Break Types**: Supports "Micro" breaks (short, frequent) and "Normal" breaks (long, infrequent).
- **Full Screen Overlay**: Gently dims your screen to encourage you to step away.
- **Smart Idle Detection**: Automatically resets timers if you leave your computer naturally, avoiding unnecessary interruptions.
- **Customizable**: Configure durations and intervals to suit your workflow.
- **Menu Bar Control**: Quick access to pause, resume, or skip breaks.
- **Launch at Login**: Option to auto-start the app when you log in.

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
# Package the app (creates TimeOut.app)
make package

# Install to /Applications
make install
```

### All Available Commands
```bash
make help       # Show all available commands
make build      # Build release binary
make package    # Create .app bundle
make install    # Install to /Applications
make run        # Build and run
make test       # Run tests
make clean      # Remove build artifacts
```

### Manual Development
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

