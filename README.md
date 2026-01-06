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
