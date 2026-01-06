import Cocoa
import SwiftUI

@MainActor
class OverlayWindowManager: ObservableObject {
    var overlayWindow: NSWindow?
    
    func showOverlay(manager: BreakManager) {
        if overlayWindow == nil {
            let window = NSWindow(
                contentRect: NSScreen.main?.frame ?? .zero,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating // Stays on top
            // To cover everything including menu bar (sometimes requires .screenSaver level)
            window.level = .screenSaver 
            
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            
            // Allow interactions
            window.ignoresMouseEvents = false
            
            window.contentView = NSHostingView(rootView: OverlayView(manager: manager))
            
            self.overlayWindow = window
        }
        
        // Update frame in case of screen changes (simple MVP)
        if let screen = NSScreen.main {
            overlayWindow?.setFrame(screen.frame, display: true)
        }
        
        overlayWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideOverlay() {
        overlayWindow?.orderOut(nil)
    }
}
