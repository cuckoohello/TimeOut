import Cocoa
import SwiftUI

@MainActor
class OverlayWindowManager: ObservableObject {
    private var overlayWindows: [NSWindow] = []
    
    func showOverlay(manager: BreakManager) {
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
    
    func hideOverlay() {
        let windows = overlayWindows
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
        }
    }

    private func rebuildWindowsIfNeeded(manager: BreakManager) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        if overlayWindows.count != screens.count {
            overlayWindows.forEach { $0.close() }
            overlayWindows = screens.map { screen in
                makeWindow(for: screen, manager: manager)
            }
        }

        for (window, screen) in zip(overlayWindows, screens) {
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(rootView: OverlayView(manager: manager))
        }
    }

    private func makeWindow(for screen: NSScreen, manager: BreakManager) -> NSWindow {
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
}
