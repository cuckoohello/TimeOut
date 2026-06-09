import Foundation
import Combine
import AppKit
import UserNotifications

enum FullScreenBreakBehavior: String, CaseIterable, Identifiable, Codable {
    case allow
    case postpone
    case skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allow: "Allow Breaks"
        case .postpone: "Postpone Breaks"
        case .skip: "Skip Breaks"
        }
    }

    var description: String {
        switch self {
        case .allow: "Start breaks even when another app is full screen."
        case .postpone: "Delay breaks while another app is full screen."
        case .skip: "Count the break as skipped while another app is full screen."
        }
    }
}

struct ExcludedApplication: Identifiable, Equatable, Codable {
    var name: String
    var bundleIdentifier: String

    var id: String { bundleIdentifier }
}

struct DailyBreakStats: Equatable, Codable {
    var dateKey: String
    var microCompleted: Int = 0
    var normalCompleted: Int = 0
    var skipped: Int = 0
    var postponed: Int = 0
    var rulePostponed: Int = 0
    var naturalBreaks: Int = 0

    static func today() -> DailyBreakStats {
        DailyBreakStats(dateKey: Self.currentDateKey())
    }

    static func currentDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

enum BreakState: Equatable {
    case working
    case preparing(BreakConfiguration)
    case inBreak(BreakConfiguration)
    case idle
}

@MainActor
class BreakManager: ObservableObject {
    @Published var state: BreakState = .working
    @Published var nextBreakTime: Date?
    @Published var ruleStatus: String?
    @Published var fullScreenBreakBehavior: FullScreenBreakBehavior = .postpone {
        didSet { saveGeneralSettings() }
    }
    @Published var excludedApplications: [ExcludedApplication] = [] {
        didSet { saveGeneralSettings() }
    }
    @Published var notifyBeforeNormalBreak: Bool = true {
        didSet { saveGeneralSettings(); requestNotificationAuthorizationIfNeeded() }
    }
    @Published var notifyBreakStart: Bool = false {
        didSet { saveGeneralSettings(); requestNotificationAuthorizationIfNeeded() }
    }
    @Published var notifyBreakEnd: Bool = false {
        didSet { saveGeneralSettings(); requestNotificationAuthorizationIfNeeded() }
    }
    @Published var notifyRulePostponed: Bool = false {
        didSet { saveGeneralSettings(); requestNotificationAuthorizationIfNeeded() }
    }
    @Published var playSoundOnBreakStart: Bool = false {
        didSet { saveGeneralSettings() }
    }
    @Published var playSoundOnBreakEnd: Bool = false {
        didSet { saveGeneralSettings() }
    }
    @Published var limitPostponesPerBreak: Bool = false {
        didSet { saveGeneralSettings() }
    }
    @Published var maxPostponesPerBreak: Int = 2 {
        didSet {
            if maxPostponesPerBreak < 1 {
                maxPostponesPerBreak = 1
            } else {
                saveGeneralSettings()
            }
        }
    }
    @Published var limitSkipsPerDay: Bool = false {
        didSet { saveGeneralSettings() }
    }
    @Published var maxSkipsPerDay: Int = 3 {
        didSet {
            if maxSkipsPerDay < 1 {
                maxSkipsPerDay = 1
            } else {
                saveGeneralSettings()
            }
        }
    }
    @Published var scheduleEnabled: Bool = false {
        didSet { saveGeneralSettings(); updateStatusString(now: Date()) }
    }
    @Published var scheduleWeekdaysOnly: Bool = true {
        didSet { saveGeneralSettings(); updateStatusString(now: Date()) }
    }
    @Published var scheduleStartMinutes: Int = 9 * 60 {
        didSet { saveGeneralSettings(); updateStatusString(now: Date()) }
    }
    @Published var scheduleEndMinutes: Int = 18 * 60 {
        didSet { saveGeneralSettings(); updateStatusString(now: Date()) }
    }
    @Published var todayStats: DailyBreakStats = .today()
    @Published var activeBreakProgress: Double = 0.0 // 0.0 to 1.0
    @Published var timeRemainingFormatted: String = ""
    @Published var isPaused: Bool = false

    // Configurations
    @Published var microBreak: BreakConfiguration = .defaultMicro
    @Published var normalBreak: BreakConfiguration = .defaultNormal

    private var timer: Timer?
    private let idleMonitor = IdleMonitor()
    private let fullScreenPostponeMinutes: TimeInterval = 1
    
    // Internal trackers
    private var lastMicroBreakTime: Date = Date()
    private var lastNormalBreakTime: Date = Date()
    
    // For the current break
    private var currentBreakEndTime: Date?
    private var preparationEndTime: Date?
    private var ruleStatusExpirationTime: Date?
    private var postponeCountsByBreakName: [String: Int] = [:]
    private var countedMicroNaturalBreak = false
    private var countedNormalNaturalBreak = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSettings()
        loadGeneralSettings()
        loadTodayStats()
        requestNotificationAuthorizationIfNeeded()
        
        idleMonitor.startMonitoring()
        startLoop()
        scheduleNextBreaks()
        
        // Auto-save when settings change
        $microBreak
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.settingsDidChange() }
            .store(in: &cancellables)
            
        $normalBreak
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.settingsDidChange() }
            .store(in: &cancellables)

        observeWorkspaceLifecycle()
    }

    private func settingsDidChange() {
        saveSettings()
        updateStatusString(now: Date())
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(microBreak) {
            UserDefaults.standard.set(encoded, forKey: "microBreakConfig")
        }
        if let encoded = try? JSONEncoder().encode(normalBreak) {
            UserDefaults.standard.set(encoded, forKey: "normalBreakConfig")
        }
    }

    private func saveGeneralSettings() {
        UserDefaults.standard.set(fullScreenBreakBehavior.rawValue, forKey: "fullScreenBreakBehavior")
        UserDefaults.standard.set(notifyBeforeNormalBreak, forKey: "notifyBeforeNormalBreak")
        UserDefaults.standard.set(notifyBreakStart, forKey: "notifyBreakStart")
        UserDefaults.standard.set(notifyBreakEnd, forKey: "notifyBreakEnd")
        UserDefaults.standard.set(notifyRulePostponed, forKey: "notifyRulePostponed")
        UserDefaults.standard.set(playSoundOnBreakStart, forKey: "playSoundOnBreakStart")
        UserDefaults.standard.set(playSoundOnBreakEnd, forKey: "playSoundOnBreakEnd")
        UserDefaults.standard.set(limitPostponesPerBreak, forKey: "limitPostponesPerBreak")
        UserDefaults.standard.set(maxPostponesPerBreak, forKey: "maxPostponesPerBreak")
        UserDefaults.standard.set(limitSkipsPerDay, forKey: "limitSkipsPerDay")
        UserDefaults.standard.set(maxSkipsPerDay, forKey: "maxSkipsPerDay")
        UserDefaults.standard.set(scheduleEnabled, forKey: "scheduleEnabled")
        UserDefaults.standard.set(scheduleWeekdaysOnly, forKey: "scheduleWeekdaysOnly")
        UserDefaults.standard.set(scheduleStartMinutes, forKey: "scheduleStartMinutes")
        UserDefaults.standard.set(scheduleEndMinutes, forKey: "scheduleEndMinutes")
        if let encoded = try? JSONEncoder().encode(excludedApplications) {
            UserDefaults.standard.set(encoded, forKey: "excludedApplications")
        }
    }

    private func loadGeneralSettings() {
        if let rawValue = UserDefaults.standard.string(forKey: "fullScreenBreakBehavior"),
           let behavior = FullScreenBreakBehavior(rawValue: rawValue) {
            fullScreenBreakBehavior = behavior
        }

        if let data = UserDefaults.standard.data(forKey: "excludedApplications"),
           let applications = try? JSONDecoder().decode([ExcludedApplication].self, from: data) {
            excludedApplications = applications
        }

        notifyBeforeNormalBreak = UserDefaults.standard.object(forKey: "notifyBeforeNormalBreak") as? Bool ?? true
        notifyBreakStart = UserDefaults.standard.bool(forKey: "notifyBreakStart")
        notifyBreakEnd = UserDefaults.standard.bool(forKey: "notifyBreakEnd")
        notifyRulePostponed = UserDefaults.standard.bool(forKey: "notifyRulePostponed")
        playSoundOnBreakStart = UserDefaults.standard.bool(forKey: "playSoundOnBreakStart")
        playSoundOnBreakEnd = UserDefaults.standard.bool(forKey: "playSoundOnBreakEnd")
        limitPostponesPerBreak = UserDefaults.standard.bool(forKey: "limitPostponesPerBreak")
        maxPostponesPerBreak = max(1, UserDefaults.standard.object(forKey: "maxPostponesPerBreak") as? Int ?? 2)
        limitSkipsPerDay = UserDefaults.standard.bool(forKey: "limitSkipsPerDay")
        maxSkipsPerDay = max(1, UserDefaults.standard.object(forKey: "maxSkipsPerDay") as? Int ?? 3)
        scheduleEnabled = UserDefaults.standard.bool(forKey: "scheduleEnabled")
        scheduleWeekdaysOnly = UserDefaults.standard.object(forKey: "scheduleWeekdaysOnly") as? Bool ?? true
        scheduleStartMinutes = clampedScheduleMinutes(UserDefaults.standard.object(forKey: "scheduleStartMinutes") as? Int ?? 9 * 60)
        scheduleEndMinutes = clampedScheduleMinutes(UserDefaults.standard.object(forKey: "scheduleEndMinutes") as? Int ?? 18 * 60)
    }

    private func loadTodayStats() {
        let key = DailyBreakStats.currentDateKey()
        if let data = UserDefaults.standard.data(forKey: "dailyBreakStats.\(key)"),
           let stats = try? JSONDecoder().decode(DailyBreakStats.self, from: data) {
            todayStats = stats
        } else {
            todayStats = .today()
            saveTodayStats()
        }
    }

    private func saveTodayStats() {
        if let encoded = try? JSONEncoder().encode(todayStats) {
            UserDefaults.standard.set(encoded, forKey: "dailyBreakStats.\(todayStats.dateKey)")
        }
    }

    private func ensureTodayStats() {
        if todayStats.dateKey != DailyBreakStats.currentDateKey() {
            todayStats = .today()
            postponeCountsByBreakName = [:]
            saveTodayStats()
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "microBreakConfig"),
           let config = try? JSONDecoder().decode(BreakConfiguration.self, from: data) {
            self.microBreak = config
        }
        
        if let data = UserDefaults.standard.data(forKey: "normalBreakConfig"),
           let config = try? JSONDecoder().decode(BreakConfiguration.self, from: data) {
            self.normalBreak = config
        }
    }

    private func startLoop() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func observeWorkspaceLifecycle() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        [
            NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ].forEach { notificationName in
            notificationCenter.publisher(for: notificationName)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.handleWorkspaceBecameInactive(reason: L10n.text("System away", "系统离开"))
                }
                .store(in: &cancellables)
        }

        [
            NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ].forEach { notificationName in
            notificationCenter.publisher(for: notificationName)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.handleWorkspaceBecameActive(reason: L10n.text("Natural break detected", "检测到自然休息"))
                }
                .store(in: &cancellables)
        }
    }

    private func handleWorkspaceBecameInactive(reason: String) {
        let now = Date()
        markSystemNaturalBreak(reason: reason, now: now)
        state = .working
        currentBreakEndTime = nil
        preparationEndTime = nil
    }

    private func handleWorkspaceBecameActive(reason: String) {
        markSystemNaturalBreak(reason: reason, now: Date())
    }

    private func markSystemNaturalBreak(reason: String, now: Date) {
        resetBreakTimers(now: now)
        todayStats.naturalBreaks += 1
        saveTodayStats()
        setRuleStatus(reason, now: now)
        updateStatusString(now: now)
    }
    
    private func scheduleNextBreaks() {
        updateStatusString(now: Date())
    }

    private func tick() {
        let now = Date()
        ensureTodayStats()
        
        if isPaused {
            // Shift the last break times forward so the interval doesn't grow
            // Effectively freezing the "time since last break"
            lastMicroBreakTime = lastMicroBreakTime.addingTimeInterval(1)
            lastNormalBreakTime = lastNormalBreakTime.addingTimeInterval(1)
            updateStatusString(now: now)
            return
        }

        clearExpiredRuleStatus(now: now)

        let idleSeconds = idleMonitor.timeSinceLastInput()

        // 1. Check for Idle Reset (Smart Break)
        // If we are working and user is idle for long enough, we can reset the timers (Natural Break).
        if case .working = state {
            if !isWithinActiveSchedule(now: now) {
                resetBreakTimers(now: now)
                updateStatusString(now: now)
                return
            }

            checkIdleReset(idleSeconds: idleSeconds, now: now)
            
            // Check if it's time for a break
            checkTriggers(now: now)
            
            // Update UI for next break
            updateStatusString(now: now)
        } else if case .preparing(let config) = state {
            // 2. We are preparing for a break. Give the user a short warning window.
            updatePreparationProgress(now: now, config: config)
        } else if case .inBreak(let config) = state {
            // 3. We are in a break. Update progress.
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
        
        let microReset = microBreak.resetOnIdle && idleSeconds >= microBreak.idleThreshold
        let normalReset = normalBreak.resetOnIdle && idleSeconds >= normalBreak.idleThreshold

        if microReset {
             lastMicroBreakTime = now
        }

        if normalReset {
             lastNormalBreakTime = now
        }

        if microReset || normalReset {
            if !countedMicroNaturalBreak && !countedNormalNaturalBreak {
                todayStats.naturalBreaks += 1
                saveTodayStats()
            }
            countedMicroNaturalBreak = microReset
            countedNormalNaturalBreak = normalReset
        } else {
            countedMicroNaturalBreak = false
            countedNormalNaturalBreak = false
        }
    }

    private func checkTriggers(now: Date) {
        guard isWithinActiveSchedule(now: now) else {
            setRuleStatus(L10n.text("Inactive: Schedule", "未启用：计划外"), now: now, expiresAfter: 60)
            resetBreakTimers(now: now)
            return
        }

        // Decide which break to take. Normal takes precedence?
        // Let's check Normal first.
        let timeSinceNormal = now.timeIntervalSince(lastNormalBreakTime)
        if normalBreak.isEnabled && timeSinceNormal >= normalBreak.interval {
            handleTriggeredBreak(normalBreak, now: now)
            return
        }

        let timeSinceMicro = now.timeIntervalSince(lastMicroBreakTime)
        if microBreak.isEnabled && timeSinceMicro >= microBreak.interval {
            handleTriggeredBreak(microBreak, now: now)
            return
        }
    }

    private func handleTriggeredBreak(_ config: BreakConfiguration, now: Date) {
        if let excludedApplication = activeExcludedApplication() {
            postponeTriggeredBreak(config, minutes: fullScreenPostponeMinutes, now: now)
            todayStats.rulePostponed += 1
            saveTodayStats()
            setRuleStatus("\(L10n.text("Postponed", "已推迟")): \(excludedApplication.name)", now: now)
            notifyIfEnabled(
                notifyRulePostponed,
                title: L10n.text("Break postponed", "休息已推迟"),
                body: L10n.text(
                    "\(localizedBreakName(config, language: .english)) Break postponed because \(excludedApplication.name) is active.",
                    "因为 \(excludedApplication.name) 正在使用，\(localizedBreakName(config, language: .chinese))已推迟。"
                )
            )
            return
        }

        guard shouldApplyFullScreenRule() else {
            prepareBreak(config)
            return
        }

        switch fullScreenBreakBehavior {
        case .allow:
            prepareBreak(config)
        case .postpone:
            postponeTriggeredBreak(config, minutes: fullScreenPostponeMinutes, now: now)
            todayStats.rulePostponed += 1
            saveTodayStats()
            setRuleStatus(L10n.text("Postponed: Full Screen", "已推迟：全屏应用"), now: now)
            notifyIfEnabled(
                notifyRulePostponed,
                title: L10n.text("Break postponed", "休息已推迟"),
                body: L10n.text(
                    "\(localizedBreakName(config, language: .english)) Break postponed because another app is full screen.",
                    "因为其他应用正在全屏，\(localizedBreakName(config, language: .chinese))已推迟。"
                )
            )
        case .skip:
            markSkipped(config, at: now)
            setRuleStatus(L10n.text("Skipped: Full Screen", "已跳过：全屏应用"), now: now)
        }
    }

    private func setRuleStatus(_ message: String, now: Date, expiresAfter: TimeInterval = 10) {
        ruleStatus = message
        ruleStatusExpirationTime = now.addingTimeInterval(expiresAfter)
    }

    private func clearExpiredRuleStatus(now: Date) {
        guard let expiration = ruleStatusExpirationTime, now >= expiration else { return }
        ruleStatus = nil
        ruleStatusExpirationTime = nil
    }

    private func shouldApplyFullScreenRule() -> Bool {
        fullScreenBreakBehavior != .allow && isAnotherAppFullScreen()
    }

    private func postponeTriggeredBreak(_ config: BreakConfiguration, minutes: TimeInterval, now: Date) {
        let adjustedLast = now.addingTimeInterval(minutes * 60).addingTimeInterval(-config.interval)
        if isMicroBreak(config) {
            lastMicroBreakTime = adjustedLast
        } else {
            lastNormalBreakTime = adjustedLast
        }
        updateStatusString(now: now)
    }

    private func prepareBreak(_ config: BreakConfiguration) {
        let leadTime = preparationLeadTime(for: config)
        if leadTime <= 0 {
            startBreak(config)
            return
        }

        if isNormalBreak(config) {
            notifyIfEnabled(
                notifyBeforeNormalBreak,
                title: L10n.text("Break starts soon", "休息即将开始"),
                body: L10n.text(
                    "Normal Break starts in \(formatDuration(leadTime)).",
                    "常规休息将在 \(formatDuration(leadTime)) 后开始。"
                )
            )
        }

        state = .preparing(config)
        preparationEndTime = Date().addingTimeInterval(leadTime)
        currentBreakEndTime = nil
        activeBreakProgress = 0.0
        updateTimeRemaining(leadTime)
    }

    private func preparationLeadTime(for config: BreakConfiguration) -> TimeInterval {
        if isMicroBreak(config) {
            return min(5, max(0, config.interval / 3))
        }

        return min(30, max(0, config.interval / 6))
    }

    private func updatePreparationProgress(now: Date, config: BreakConfiguration) {
        guard let end = preparationEndTime else {
            startBreak(config)
            return
        }

        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 {
            startBreak(config)
        } else {
            let total = max(preparationLeadTime(for: config), 1)
            activeBreakProgress = 1.0 - (remaining / total)
            updateTimeRemaining(remaining)
        }
    }

    func startBreakNow() {
        guard case .preparing(let config) = state else { return }
        startBreak(config)
    }

    func startMicroBreakNow() {
        startManualBreak(microBreak)
    }

    func startNormalBreakNow() {
        startManualBreak(normalBreak)
    }

    private func startManualBreak(_ config: BreakConfiguration) {
        guard config.isEnabled else { return }
        state = .working
        currentBreakEndTime = nil
        preparationEndTime = nil
        startBreak(config)
    }

    private func startBreak(_ config: BreakConfiguration) {
        state = .inBreak(config)
        currentBreakEndTime = Date().addingTimeInterval(config.duration)
        preparationEndTime = nil
        activeBreakProgress = 0.0
        updateTimeRemaining(config.duration)
        notifyIfEnabled(
            notifyBreakStart,
            title: L10n.text(
                "\(localizedBreakName(config, language: .english)) Break started",
                "\(localizedBreakName(config, language: .chinese))已开始"
            ),
            body: L10n.text("Take a moment away from your screen.", "离开屏幕，休息一下吧。")
        )
        playSystemSoundIfEnabled(playSoundOnBreakStart)
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
            updateTimeRemaining(remaining)
        }
    }

    func endBreak() {
        // Reset timers
        let now = Date()
        if case .inBreak(let config) = state {
            if isMicroBreak(config) {
               lastMicroBreakTime = now
               todayStats.microCompleted += 1
            } else if isNormalBreak(config) {
               lastNormalBreakTime = now 
               todayStats.normalCompleted += 1
            } else {
                // Fallback, reset both if unsure or logic mandates
                if config.interval < normalBreak.interval { lastMicroBreakTime = now }
                else { lastNormalBreakTime = now }
            }
            postponeCountsByBreakName[config.name] = 0
            saveTodayStats()
            notifyIfEnabled(
                notifyBreakEnd,
                title: L10n.text(
                    "\(localizedBreakName(config, language: .english)) Break finished",
                    "\(localizedBreakName(config, language: .chinese))已结束"
                ),
                body: L10n.text("Nice work — your break is complete.", "做得好，本次休息已完成。")
            )
            playSystemSoundIfEnabled(playSoundOnBreakEnd)
        }
        
        state = .working
        currentBreakEndTime = nil
        preparationEndTime = nil
    }

    func skipBreak() {
        guard canSkipBreak() else {
            setRuleStatus(L10n.text("Skip limit reached", "已达到跳过次数上限"), now: Date())
            return
        }

        if case .preparing(let config) = state {
            markSkipped(config, at: Date())
            state = .working
            preparationEndTime = nil
            currentBreakEndTime = nil
            updateStatusString(now: Date())
            return
        }

        if case .inBreak(let config) = state {
            markSkipped(config, at: Date())
            postponeCountsByBreakName[config.name] = 0
            state = .working
            currentBreakEndTime = nil
            preparationEndTime = nil
        }
    }
    
    func postponeBreak(minutes: TimeInterval = 5) {
        let config: BreakConfiguration
        switch state {
        case .preparing(let pendingConfig), .inBreak(let pendingConfig):
            config = pendingConfig
        default:
            return
        }

        guard canPostponeBreak(config) else {
            setRuleStatus(L10n.text("Postpone limit reached", "已达到推迟次数上限"), now: Date())
            return
        }

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
        
        if isMicroBreak(config) {
            lastMicroBreakTime = adjustedLast
        } else {
            lastNormalBreakTime = adjustedLast
        }
        postponeCountsByBreakName[config.name, default: 0] += 1
        todayStats.postponed += 1
        saveTodayStats()
        
        state = .working
        currentBreakEndTime = nil
        preparationEndTime = nil
        updateStatusString(now: now)
    }
    
    private func updateStatusString(now: Date) {
        if !isWithinActiveSchedule(now: now) {
            if nextBreakTime != nil {
                nextBreakTime = nil
            }
            return
        }

        // Find whichever is sooner
        var nextMicro = lastMicroBreakTime.addingTimeInterval(microBreak.interval)
        if !microBreak.isEnabled { nextMicro = Date.distantFuture }
        
        var nextNormal = lastNormalBreakTime.addingTimeInterval(normalBreak.interval)
        if !normalBreak.isEnabled { nextNormal = Date.distantFuture }
        
        let sooner = nextMicro < nextNormal ? nextMicro : nextNormal
        let updatedNextBreakTime = sooner == Date.distantFuture ? nil : sooner
        if nextBreakTime != updatedNextBreakTime {
            nextBreakTime = updatedNextBreakTime
        }
    }

    func nextBreakStatusText(now: Date = Date(), language: AppLanguage = .current) -> String {
        if isPaused { return L10n.text("Paused", "已暂停", language: language) }
        if !isWithinActiveSchedule(now: now) { return L10n.text("Inactive: Schedule", "未启用：计划外", language: language) }

        if case .preparing(let config) = state {
            let remaining = max(0, (preparationEndTime ?? now).timeIntervalSince(now))
            return L10n.text(
                "\(localizedBreakName(config, language: .english)) break starts in \(formatDuration(remaining))",
                "\(localizedBreakName(config, language: .chinese))将在 \(formatDuration(remaining)) 后开始",
                language: language
            )
        }

        if case .inBreak(let config) = state {
            let remaining = max(0, (currentBreakEndTime ?? now).timeIntervalSince(now))
            return L10n.text(
                "\(localizedBreakName(config, language: .english)) break: \(formatDuration(remaining)) left",
                "\(localizedBreakName(config, language: .chinese))剩余 \(formatDuration(remaining))",
                language: language
            )
        }

        guard let nextBreakTime else {
            return L10n.text("Next break: disabled", "下一次休息：已禁用", language: language)
        }

        return L10n.text(
            "Next break in \(formatDuration(max(0, nextBreakTime.timeIntervalSince(now))))",
            "下一次休息还有 \(formatDuration(max(0, nextBreakTime.timeIntervalSince(now))))",
            language: language
        )
    }

    func menuBarCountdownText(now: Date = Date(), language: AppLanguage = .current) -> String {
        if isPaused { return L10n.text("Paused", "暂停", language: language) }
        if !isWithinActiveSchedule(now: now) { return L10n.text("Off", "关闭", language: language) }

        if case .preparing = state {
            let remaining = max(0, (preparationEndTime ?? now).timeIntervalSince(now))
            return formatDuration(remaining)
        }

        if case .inBreak = state {
            let remaining = max(0, (currentBreakEndTime ?? now).timeIntervalSince(now))
            return formatDuration(remaining)
        }

        guard let nextBreakTime else {
            return "--"
        }

        return formatDuration(max(0, nextBreakTime.timeIntervalSince(now)))
    }

    private func resetBreakTimers(now: Date) {
        lastMicroBreakTime = now
        lastNormalBreakTime = now
    }

    private func clampedScheduleMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 0), 23 * 60 + 59)
    }

    var scheduleStartTimeFormatted: String {
        formatScheduleMinutes(scheduleStartMinutes)
    }

    var scheduleEndTimeFormatted: String {
        formatScheduleMinutes(scheduleEndMinutes)
    }

    private func formatScheduleMinutes(_ minutes: Int) -> String {
        let clamped = clampedScheduleMinutes(minutes)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    private func isWithinActiveSchedule(now: Date) -> Bool {
        guard scheduleEnabled else { return true }

        let calendar = Calendar.current
        if scheduleWeekdaysOnly {
            let weekday = calendar.component(.weekday, from: now)
            if weekday == 1 || weekday == 7 {
                return false
            }
        }

        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        if scheduleStartMinutes == scheduleEndMinutes {
            return true
        } else if scheduleStartMinutes < scheduleEndMinutes {
            return currentMinutes >= scheduleStartMinutes && currentMinutes < scheduleEndMinutes
        } else {
            return currentMinutes >= scheduleStartMinutes || currentMinutes < scheduleEndMinutes
        }
    }
    
    private func markSkipped(_ config: BreakConfiguration, at now: Date = Date()) {
        if isMicroBreak(config) {
            lastMicroBreakTime = now
        } else {
            lastNormalBreakTime = now
        }
        todayStats.skipped += 1
        saveTodayStats()
        updateStatusString(now: now)
    }

    private func canSkipBreak() -> Bool {
        !limitSkipsPerDay || todayStats.skipped < maxSkipsPerDay
    }

    private func canPostponeBreak(_ config: BreakConfiguration) -> Bool {
        !limitPostponesPerBreak || postponeCountsByBreakName[config.name, default: 0] < maxPostponesPerBreak
    }

    private func requestNotificationAuthorizationIfNeeded() {
        guard notifyBeforeNormalBreak || notifyBreakStart || notifyBreakEnd || notifyRulePostponed else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyIfEnabled(_ enabled: Bool, title: String, body: String) {
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "timeout.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func playSystemSoundIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        NSSound(named: "Ping")?.play()
    }

    var availableApplicationsForExclusion: [ExcludedApplication] {
        var seenBundleIdentifiers = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { application -> ExcludedApplication? in
            guard application.activationPolicy == .regular,
                  application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  let bundleIdentifier = application.bundleIdentifier,
                  !bundleIdentifier.isEmpty,
                  !excludedApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }),
                  !seenBundleIdentifiers.contains(bundleIdentifier) else {
                return nil
            }

            seenBundleIdentifiers.insert(bundleIdentifier)
            return ExcludedApplication(
                name: application.localizedName ?? bundleIdentifier,
                bundleIdentifier: bundleIdentifier
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addExcludedApplication(_ application: ExcludedApplication) {
        guard !excludedApplications.contains(where: { $0.bundleIdentifier == application.bundleIdentifier }) else { return }
        excludedApplications.append(application)
        excludedApplications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func removeExcludedApplication(_ application: ExcludedApplication) {
        excludedApplications.removeAll { $0.bundleIdentifier == application.bundleIdentifier }
    }

    private func activeExcludedApplication() -> ExcludedApplication? {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return nil
        }

        return excludedApplications.first { $0.bundleIdentifier == bundleIdentifier }
    }

    private func isAnotherAppFullScreen() -> Bool {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return false
        }

        let frontmostPID = frontmostApplication.processIdentifier
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        return windowInfoList.contains { windowInfo in
            guard let ownerPID = (windowInfo[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPID == frontmostPID,
                  let layer = (windowInfo[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  layer == 0,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds.cgFloatValue(forKey: "X"),
                  let y = bounds.cgFloatValue(forKey: "Y"),
                  let width = bounds.cgFloatValue(forKey: "Width"),
                  let height = bounds.cgFloatValue(forKey: "Height") else {
                return false
            }

            let windowFrame = CGRect(x: x, y: y, width: width, height: height)
            return NSScreen.screens.contains { screen in
                windowFrame.matchesFullScreen(screen.frame)
            }
        }
    }

    private func updateTimeRemaining(_ remaining: TimeInterval) {
        let formatted = formatDuration(remaining)
        timeRemainingFormatted = formatted
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }

    private func isMicroBreak(_ config: BreakConfiguration) -> Bool {
        config.id == microBreak.id || config.name == microBreak.name
    }

    private func isNormalBreak(_ config: BreakConfiguration) -> Bool {
        config.id == normalBreak.id || config.name == normalBreak.name
    }

    private func localizedBreakName(_ config: BreakConfiguration, language: AppLanguage = .current) -> String {
        if isMicroBreak(config) {
            return L10n.text("Micro", "微休息", language: language)
        }

        if isNormalBreak(config) {
            return L10n.text("Normal", "常规休息", language: language)
        }

        return config.name
    }
}

private extension Dictionary where Key == String, Value == Any {
    func cgFloatValue(forKey key: String) -> CGFloat? {
        if let value = self[key] as? CGFloat {
            return value
        }
        if let value = self[key] as? NSNumber {
            return CGFloat(truncating: value)
        }
        if let value = self[key] as? Double {
            return CGFloat(value)
        }
        if let value = self[key] as? Int {
            return CGFloat(value)
        }
        return nil
    }
}

private extension CGRect {
    func matchesFullScreen(_ screenFrame: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(origin.x - screenFrame.origin.x) <= tolerance &&
        abs(origin.y - screenFrame.origin.y) <= tolerance &&
        abs(width - screenFrame.width) <= tolerance &&
        abs(height - screenFrame.height) <= tolerance
    }
}
