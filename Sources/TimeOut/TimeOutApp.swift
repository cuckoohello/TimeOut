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
    @AppStorage("showCountdownInMenuBar") private var showCountdownInMenuBar = false
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some Scene {
        MenuBarExtra {
            statusSection

            Divider()

            primaryActions

            Divider()

            quickBreaksSection

            Divider()

            todaySection

            Divider()

            Button(t("Settings…", "设置…")) {
                appDelegate.showSettings(manager: breakManager)
            }
            .keyboardShortcut(",")

            Button(t("Quit TimeOut", "退出 TimeOut")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarLabel(manager: breakManager)
        }
        .onChange(of: breakManager.state) { oldState, newState in
            if newState.showsOverlay && !oldState.showsOverlay {
                overlayManager.showOverlay(manager: breakManager)
            } else if !newState.showsOverlay && oldState.showsOverlay {
                overlayManager.hideOverlay()
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Label(breakManager.nextBreakStatusText(now: context.date, language: language), systemImage: statusIcon)
        }
        if let ruleStatus = breakManager.ruleStatus {
            Label(ruleStatus, systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        switch breakManager.state {
        case .working:
            if breakManager.isPaused {
                Button {
                    breakManager.togglePause()
                } label: {
                    Label(t("Resume", "继续"), systemImage: "play.fill")
                }
            } else {
                Button {
                    breakManager.togglePause()
                } label: {
                    Label(t("Pause", "暂停"), systemImage: "pause.fill")
                }
            }
        case .preparing:
            Button {
                breakManager.startBreakNow()
            } label: {
                Label(t("Start Break Now", "立即开始休息"), systemImage: "play.fill")
            }

            Menu(t("Postpone", "推迟")) {
                Button(t("1 minute", "1 分钟")) { breakManager.postponeBreak(minutes: 1) }
                Button(t("5 minutes", "5 分钟")) { breakManager.postponeBreak(minutes: 5) }
                Button(t("15 minutes", "15 分钟")) { breakManager.postponeBreak(minutes: 15) }
            }

            Button {
                breakManager.skipBreak()
            } label: {
                Label(t("Skip Break", "跳过休息"), systemImage: "forward.end.fill")
            }
        case .inBreak:
            Menu(t("Postpone", "推迟")) {
                Button(t("1 minute", "1 分钟")) { breakManager.postponeBreak(minutes: 1) }
                Button(t("5 minutes", "5 分钟")) { breakManager.postponeBreak(minutes: 5) }
                Button(t("15 minutes", "15 分钟")) { breakManager.postponeBreak(minutes: 15) }
            }

            Button {
                breakManager.skipBreak()
            } label: {
                Label(t("Skip Break", "跳过休息"), systemImage: "forward.end.fill")
            }
        case .idle:
            Text(t("Idle", "空闲"))
        }
    }

    @ViewBuilder
    private var quickBreaksSection: some View {
        Menu(t("Start Break", "开始休息")) {
            Button {
                breakManager.startMicroBreakNow()
            } label: {
                Label(t("Micro Break", "微休息"), systemImage: "eye")
            }
            .disabled(!breakManager.microBreak.isEnabled)

            Button {
                breakManager.startNormalBreakNow()
            } label: {
                Label(t("Normal Break", "常规休息"), systemImage: "figure.walk")
            }
            .disabled(!breakManager.normalBreak.isEnabled)
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        Text(t("Today", "今天"))
        Label("\(t("Completed", "已完成")): \(breakManager.todayStats.microCompleted + breakManager.todayStats.normalCompleted)", systemImage: "checkmark.circle")
        Label("\(t("Skipped", "已跳过")): \(breakManager.todayStats.skipped)", systemImage: "forward.end")
        Label("\(t("Postponed", "已推迟")): \(breakManager.todayStats.postponed + breakManager.todayStats.rulePostponed)", systemImage: "clock.arrow.circlepath")
    }

    private var statusIcon: String {
        if breakManager.isPaused { return "pause.circle" }
        switch breakManager.state {
        case .working: return "timer"
        case .preparing: return "hourglass"
        case .inBreak: return "figure.mind.and.body"
        case .idle: return "moon"
        }
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, language: language)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var manager: BreakManager
    @StateObject private var clock = MenuBarClock()
    @AppStorage("showCountdownInMenuBar") private var showCountdownInMenuBar = false
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: "timer")
                .imageScale(.medium)

            if showCountdownInMenuBar {
                Text(manager.menuBarCountdownText(now: clock.now, language: language))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
    }
}

@MainActor
private final class MenuBarClock: ObservableObject {
    @Published var now = Date()
    private var timer: Timer?

    init() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit {
        timer?.invalidate()
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
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.text("TimeOut Settings", "TimeOut 设置")
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

private extension BreakState {
    var showsOverlay: Bool {
        switch self {
        case .inBreak:
            return true
        case .preparing, .working, .idle:
            return false
        }
    }
}
