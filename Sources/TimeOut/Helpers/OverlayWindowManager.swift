import Cocoa
import SwiftUI

@MainActor
class OverlayWindowManager: ObservableObject {
    private var overlayWindows: [NSWindow] = []
    private var compactWindow: NSWindow?

    func showOverlay(manager: BreakManager) {
        let displayMode = currentDisplayMode(from: manager)

        // Clean up windows from the opposite mode
        if displayMode == .fullscreen {
            compactWindow?.orderOut(nil)
            compactWindow = nil
        } else {
            overlayWindows.forEach { $0.orderOut(nil) }
            overlayWindows = []
        }

        switch displayMode {
        case .fullscreen:
            showFullscreenOverlay(manager: manager)
        case .compact:
            showCompactOverlay(manager: manager)
        }
    }

    func hideOverlay() {
        let windows = overlayWindows + [compactWindow].compactMap { $0 }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in windows {
                window.animator().alphaValue = 0
            }
        } completionHandler: {
            for window in windows {
                window.orderOut(nil)
            }
            Task { @MainActor in
                self.compactWindow = nil
            }
        }
    }

    // MARK: - Fullscreen

    private func showFullscreenOverlay(manager: BreakManager) {
        rebuildWindowsIfNeeded(manager: manager)

        for window in overlayWindows {
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func rebuildWindowsIfNeeded(manager: BreakManager) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        if overlayWindows.count != screens.count {
            overlayWindows.forEach { $0.close() }
            overlayWindows = screens.map { screen in
                makeFullscreenWindow(for: screen, manager: manager)
            }
        }

        for (window, screen) in zip(overlayWindows, screens) {
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(rootView: OverlayView(manager: manager))
        }
    }

    private func makeFullscreenWindow(for screen: NSScreen, manager: BreakManager) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.contentView = NSHostingView(rootView: OverlayView(manager: manager))
        return window
    }

    // MARK: - Compact

    private func showCompactOverlay(manager: BreakManager) {
        if compactWindow == nil {
            compactWindow = makeCompactWindow(manager: manager)
        }

        guard let window = compactWindow else { return }

        positionCompactWindow(window)
        window.contentView = NSHostingView(rootView: CompactOverlayView(manager: manager))

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeCompactWindow(manager: BreakManager) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.hasShadow = false
        window.contentView = NSHostingView(rootView: CompactOverlayView(manager: manager))
        return window
    }

    private func positionCompactWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.visibleFrame

        window.layoutIfNeeded()
        let windowSize = window.frame.size

        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.maxY - windowSize.height - 20
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Helpers

    private func currentDisplayMode(from manager: BreakManager) -> BreakDisplayMode {
        switch manager.state {
        case .preparing(let config), .inBreak(let config):
            return config.displayMode
        default:
            return .fullscreen
        }
    }
}
