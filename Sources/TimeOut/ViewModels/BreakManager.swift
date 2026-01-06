import Foundation
import Combine

enum BreakState: Equatable {
    case working
    case inBreak(BreakConfiguration)
    case idle
}

@MainActor
class BreakManager: ObservableObject {
    @Published var state: BreakState = .working
    @Published var nextBreakTime: Date?
    @Published var activeBreakProgress: Double = 0.0 // 0.0 to 1.0
    @Published var timeRemainingFormatted: String = ""
    @Published var isPaused: Bool = false

    // Configurations
    @Published var microBreak: BreakConfiguration = .defaultMicro
    @Published var normalBreak: BreakConfiguration = .defaultNormal

    private var timer: Timer?
    private let idleMonitor = IdleMonitor()
    
    // Internal trackers
    private var lastMicroBreakTime: Date = Date()
    private var lastNormalBreakTime: Date = Date()
    
    // For the current break
    private var currentBreakEndTime: Date?

    init() {
        idleMonitor.startMonitoring()
        startLoop()
        scheduleNextBreaks()
    }

    private func startLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }
    
    private func scheduleNextBreaks() {
        updateStatusString(now: Date())
    }

    private func tick() {
        let now = Date()
        
        if isPaused {
            // Shift the last break times forward so the interval doesn't grow
            // Effectively freezing the "time since last break"
            lastMicroBreakTime = lastMicroBreakTime.addingTimeInterval(1)
            lastNormalBreakTime = lastNormalBreakTime.addingTimeInterval(1)
            return
        }

        let idleSeconds = idleMonitor.timeSinceLastInput()

        // 1. Check for Idle Reset (Smart Break)
        // If we are working and user is idle for long enough, we can reset the timers (Natural Break).
        if case .working = state {
            checkIdleReset(idleSeconds: idleSeconds, now: now)
            
            // Check if it's time for a break
            checkTriggers(now: now)
            
            // Update UI for next break
            updateStatusString(now: now)
        } else if case .inBreak(let config) = state {
             // 2. We are in a break. Update progress.
             updateBreakProgress(now: now, config: config)
        }
    }
    
    func togglePause() {
        isPaused.toggle()
        // Force update status string so UI reflects "Paused" or new time
        if !isPaused {
            updateStatusString(now: Date())
        }
    }
    
    private func checkIdleReset(idleSeconds: TimeInterval, now: Date) {
        // If idle for longer than the break's reset threshold, we assume they took a break naturally.
        // We reset the "last break time" to NOW (so the countdown starts fresh when they come back).
        
        // Micro break logic
        if microBreak.resetOnIdle && idleSeconds >= microBreak.idleThreshold {
             // Effectively, we just had a break.
             // Only reset if we are NOT already planning a break incorrectly? 
             // Actually, if we are idle, we just push the next break out.
             lastMicroBreakTime = now
        }

        // Normal break logic
        if normalBreak.resetOnIdle && idleSeconds >= normalBreak.idleThreshold {
             lastNormalBreakTime = now
        }
    }

    private func checkTriggers(now: Date) {
        // Decide which break to take. Normal takes precedence?
        // Let's check Normal first.
        let timeSinceNormal = now.timeIntervalSince(lastNormalBreakTime)
        if normalBreak.isEnabled && timeSinceNormal >= normalBreak.interval {
            startBreak(normalBreak)
            return
        }

        let timeSinceMicro = now.timeIntervalSince(lastMicroBreakTime)
        if microBreak.isEnabled && timeSinceMicro >= microBreak.interval {
            startBreak(microBreak)
            return
        }
    }

    private func startBreak(_ config: BreakConfiguration) {
        state = .inBreak(config)
        currentBreakEndTime = Date().addingTimeInterval(config.duration)
        // We will show the overlay via the view being observed
    }

    private func updateBreakProgress(now: Date, config: BreakConfiguration) {
        guard let end = currentBreakEndTime else {
            endBreak() // Should not happen
            return
        }
        
        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 {
            endBreak()
        } else {
            let total = config.duration
            activeBreakProgress = 1.0 - (remaining / total)
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            timeRemainingFormatted = formatter.string(from: remaining) ?? ""
        }
    }

    func endBreak() {
        // Reset timers
        let now = Date()
        if case .inBreak(let config) = state {
            if config.id == textToId(microBreak.id) { // Hacky comparison or just check name
               lastMicroBreakTime = now
            } else if config.name == normalBreak.name { // better to compare IDs if possible
               lastNormalBreakTime = now 
            } else {
                // Fallback, reset both if unsure or logic mandates
                if config.interval < normalBreak.interval { lastMicroBreakTime = now }
                else { lastNormalBreakTime = now }
            }
        }
        
        state = .working
        currentBreakEndTime = nil
    }

    func skipBreak() {
        endBreak()
    }
    
    func postponeBreak(minutes: TimeInterval = 5) {
        guard case .inBreak(let config) = state else { return }
        // We want to enter working state, but set the last break time such that it triggers again soon.
        // current time - interval + postpone duration?
        // Easier: Just set "lastBreakTime" to Now - Interval + PostponeMinutes
        // So: TimeSinceLast = Interval - Postpone
        // Wait, if we want it to trigger in 5 mins:
        // We need (Now - Last) to equal Interval in 5 mins.
        // (Now + 5m) - Last = Interval
        // Last = Now + 5m - Interval
        
        let now = Date()
        let interval = config.interval
        let adjustedLast = now.addingTimeInterval(minutes * 60).addingTimeInterval(-interval)
        
        if config.name == microBreak.name {
            lastMicroBreakTime = adjustedLast
        } else {
            lastNormalBreakTime = adjustedLast
        }
        
        state = .working
        currentBreakEndTime = nil
    }
    
    private func updateStatusString(now: Date) {
        // Find whichever is sooner
        var nextMicro = lastMicroBreakTime.addingTimeInterval(microBreak.interval)
        if !microBreak.isEnabled { nextMicro = Date.distantFuture }
        
        var nextNormal = lastNormalBreakTime.addingTimeInterval(normalBreak.interval)
        if !normalBreak.isEnabled { nextNormal = Date.distantFuture }
        
        let sooner = nextMicro < nextNormal ? nextMicro : nextNormal
        nextBreakTime = sooner
        
        // Formatted string logic if needed
    }
    
    // Helper simple comparison
    private func textToId(_ id: UUID) -> UUID { id }
}
