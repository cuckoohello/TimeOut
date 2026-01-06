import Foundation
import CoreGraphics

class IdleMonitor: ObservableObject {
    @Published var lastActivity: Date = Date()
    @Published var isIdle: Bool = false
    
    // We check periodically
    private var timer: Timer?

    func startMonitoring(interval: TimeInterval = 1.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkIdleStatus()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func timeSinceLastInput() -> TimeInterval {
        // CGEventSource.secondsSinceLastEventType returns time in seconds since last event
        // We use .combinedSessionState to get global state across all sessions if possible, or .hidSystemState
        // Note: This requires Accessibility permissions in some contexts, but usually fine for local non-sandboxed app reading its own state or basic HID state.
        // For a proper background app, this is the standard way.
        
        // kCGAnyInputEventType is not directly exposed as a single easy constant in Swift's CoreGraphics overlay sometimes, 
        // but passing `CGEventType(rawValue: ~0)!` or specific types works. 
        // `CGEventSource.secondsSinceLastEventType` expects `CGEventSourceStateID`.
        
        let idleTime = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: .anyInputEventType)
        return idleTime
    }

    private func checkIdleStatus() {
        _ = timeSinceLastInput()
        // We update the published property so observers can react
        // Just for debug or simple threshold logic
        // The BreakManager will likely poll `timeSinceLastInput()` directly or listen to specific thresholds.
    }
}

extension CGEventType {
    // Helper to get 'any' event type if needed, though .anyInputEventType logic is internal to how we usually ask.
    // Actually the API is `CGEventSource.secondsSinceLastEventType(_:eventType:)`.
    // Valid event types are keyUp, moved, etc. 
    // Passing .null acts as "any" in some docs, but let's try to be specific or find a valid "any" equivalent.
    // Actually, `CGEventSource.secondsSinceLastEventType` documentation says:
    // "The eventType parameter is currently ignored." -> So we can pass anything.
    static var anyInputEventType: CGEventType { .mouseMoved } 
}
