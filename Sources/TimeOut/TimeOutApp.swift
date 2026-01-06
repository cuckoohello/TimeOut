import SwiftUI

@main
struct TimeOutApp: App {
    // Connect access to AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // We still own the data models here, or move them to AppDelegate if needed.
    // Let's keep them here but pass to AppDelegate or accessing via singleton.
    // Actually, Cleaner to let App own them and pass to delegate? NO, Delegate is created by system.
    // Better: Helper class or shared state. 
    // Let's make BreakManager a shared object for now to easily access from AppDelegate.
    @StateObject var breakManager = BreakManager.shared
    @StateObject var overlayManager = OverlayWindowManager()

    var body: some Scene {
        MenuBarExtra("TimeOut", systemImage: "timer") {
            Button("Settings") {
                appDelegate.showSettings(manager: breakManager)
            }
            
            Divider()
            
            if case .working = breakManager.state {
                if breakManager.isPaused {
                     Button("Resume") {
                         breakManager.togglePause()
                     }
                     Text("Paused")
                } else {
                     Button("Pause") {
                         breakManager.togglePause()
                     }
                     Text("Next break: \(breakManager.nextBreakTime?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                }
            } else {
                 Button("Skip Break") {
                     breakManager.skipBreak()
                 }
            }
            
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: breakManager.state) { oldState, newState in
            if case .inBreak = newState {
                overlayManager.showOverlay(manager: breakManager)
            } else if case .working = newState {
                overlayManager.hideOverlay()
            }
        }
    }
}

// Ensure singleton access for BreakManager if needed, or just pass instance.
// Since we pass it in showSettings, we don't strictly need singleton, 
// BUT we need to ensure the SettingsView observes the SAME instance.

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .accessory policy allows the app to have windows and appear in the menu bar,
        // but not the Dock (usually). It also allows taking focus.
        NSApp.setActivationPolicy(.accessory)
    }

    func showSettings(manager: BreakManager) {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "TimeOut Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(manager: manager))
            settingsWindow = window
        }
        
        // Force app to front
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless() // Extra forceful
    }
}

extension BreakManager {
    // Quick singleton hack if we needed it, but we are passing instance.
    static let shared = BreakManager()
}


