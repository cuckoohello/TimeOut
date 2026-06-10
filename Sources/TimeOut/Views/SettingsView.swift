import SwiftUI
import AppKit

private enum SettingsTab: String, CaseIterable, Identifiable {
    case breaks
    case rules
    case alerts
    case stats
    case general

    var id: String { rawValue }

    var title: String {
        title(language: .current)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .breaks: L10n.text("Breaks", "休息", language: language)
        case .rules: L10n.text("Rules", "规则", language: language)
        case .alerts: L10n.text("Alerts", "提醒", language: language)
        case .stats: L10n.text("Stats", "统计", language: language)
        case .general: L10n.text("General", "通用", language: language)
        }
    }

    var icon: String {
        switch self {
        case .breaks: "timer"
        case .rules: "slider.horizontal.3"
        case .alerts: "bell.badge"
        case .stats: "chart.bar"
        case .general: "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var manager: BreakManager
    @StateObject var launchManager = LaunchAtLoginManager()
    @AppStorage("showCountdownInMenuBar") private var showCountdownInMenuBar = false
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue
    @State private var selectedTab: SettingsTab = .breaks

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            TabView(selection: $selectedTab) {
                breaksPage
                    .tabItem { Label(SettingsTab.breaks.title(language: language), systemImage: SettingsTab.breaks.icon) }
                    .tag(SettingsTab.breaks)

                rulesPage
                    .tabItem { Label(SettingsTab.rules.title(language: language), systemImage: SettingsTab.rules.icon) }
                    .tag(SettingsTab.rules)

                alertsPage
                    .tabItem { Label(SettingsTab.alerts.title(language: language), systemImage: SettingsTab.alerts.icon) }
                    .tag(SettingsTab.alerts)

                statsPage
                    .tabItem { Label(SettingsTab.stats.title(language: language), systemImage: SettingsTab.stats.icon) }
                    .tag(SettingsTab.stats)

                generalPage
                    .tabItem { Label(SettingsTab.general.title(language: language), systemImage: SettingsTab.general.icon) }
                    .tag(SettingsTab.general)
            }
        }
        .frame(width: 760, height: 620)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: 48, height: 48)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("TimeOut")
                    .font(.title2.weight(.semibold))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(manager.nextBreakStatusText(now: context.date, language: language))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let ruleStatus = manager.ruleStatus {
                Label(ruleStatus, systemImage: "info.circle")
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let next = manager.nextBreakTime {
                VStack(alignment: .trailing, spacing: 4) {
                Text(t("Scheduled", "计划时间"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(next.formatted(date: .omitted, time: .shortened))
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .padding(20)
    }

    private var breaksPage: some View {
        settingsPage {
            breakEditor(
                title: t("Micro Break", "微休息"),
                subtitle: t("Short, frequent breaks for your eyes and posture.", "短而频繁的休息，帮助眼睛和姿势放松。"),
                config: $manager.microBreak
            )

            breakEditor(
                title: t("Normal Break", "常规休息"),
                subtitle: t("Longer breaks that help you actually leave the screen.", "更长的休息，帮助你真正离开屏幕。"),
                config: $manager.normalBreak
            )
        }
    }

    private var rulesPage: some View {
        settingsPage {
            settingsCard(
                title: t("Schedule", "时间计划"),
                subtitle: t("Keep TimeOut active only during the hours you care about.", "只在你关心的时间段启用 TimeOut。")
            ) {
                Toggle(t("Only active during schedule", "仅在计划时间内启用"), isOn: $manager.scheduleEnabled)

                if manager.scheduleEnabled {
                    Divider()
                    Toggle(t("Weekdays only", "仅工作日"), isOn: $manager.scheduleWeekdaysOnly)
                    Stepper(
                        "\(t("Start", "开始")): \(manager.scheduleStartTimeFormatted)",
                        value: $manager.scheduleStartMinutes,
                        in: 0...(23 * 60 + 59),
                        step: 15
                    )
                    Stepper(
                        "\(t("End", "结束")): \(manager.scheduleEndTimeFormatted)",
                        value: $manager.scheduleEndMinutes,
                        in: 0...(23 * 60 + 59),
                        step: 15
                    )
                    helperText(t("Outside this schedule, breaks are inactive and timers reset instead of firing.", "计划时间之外不会触发休息，而是重置计时器。"))
                }
            }

            settingsCard(
                title: t("Interruption Rules", "打断规则"),
                subtitle: t("Avoid breaks when another activity should not be interrupted.", "在不适合打断的场景中避免弹出休息。")
            ) {
                Picker(t("When another app is full screen", "当其他应用全屏时"), selection: $manager.fullScreenBreakBehavior) {
                    ForEach(FullScreenBreakBehavior.allCases) { behavior in
                        Text(behavior.title(language: language)).tag(behavior)
                    }
                }
                .pickerStyle(.menu)

                helperText(manager.fullScreenBreakBehavior.description(language: language))
            }

            settingsCard(
                title: t("Excluded Apps", "排除应用"),
                subtitle: t("Breaks are postponed while any excluded app is frontmost.", "当前台应用位于排除列表时自动推迟休息。")
            ) {
                Menu {
                    let applications = manager.availableApplicationsForExclusion
                    if applications.isEmpty {
                        Text(t("No running apps available", "没有可添加的运行中应用"))
                    } else {
                        ForEach(applications) { application in
                            Button {
                                manager.addExcludedApplication(application)
                            } label: {
                                Label {
                                    Text(application.name)
                                } icon: {
                                    Image(nsImage: application.icon)
                                }
                            }
                        }
                    }
                } label: {
                    Label(t("Add Running App", "添加运行中应用"), systemImage: "plus")
                }

                if manager.excludedApplications.isEmpty {
                    emptyState(t("No excluded apps yet.", "还没有排除应用。"))
                } else {
                    VStack(spacing: 8) {
                        ForEach(manager.excludedApplications) { application in
                            HStack(spacing: 12) {
                                Image(nsImage: application.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(application.name)
                                    Text(application.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    manager.removeExcludedApplication(application)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(10)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var alertsPage: some View {
        settingsPage {
            settingsCard(
                title: t("Notifications", "通知"),
                subtitle: t("Use lightweight system notifications before or around breaks.", "在休息前后使用轻量系统通知提醒你。")
            ) {
                Toggle(t("Notify before Normal Break", "常规休息前通知"), isOn: $manager.notifyBeforeNormalBreak)
                Toggle(t("Notify when break starts", "休息开始时通知"), isOn: $manager.notifyBreakStart)
                Toggle(t("Notify when break ends", "休息结束时通知"), isOn: $manager.notifyBreakEnd)
                Toggle(t("Notify when rules postpone a break", "规则推迟休息时通知"), isOn: $manager.notifyRulePostponed)
            }

            settingsCard(
                title: t("Sounds", "声音"),
                subtitle: t("Use a small sound cue when breaks start or end.", "休息开始或结束时播放简短提示音。")
            ) {
                Toggle(t("Play sound when break starts", "休息开始时播放声音"), isOn: $manager.playSoundOnBreakStart)
                Toggle(t("Play sound when break ends", "休息结束时播放声音"), isOn: $manager.playSoundOnBreakEnd)
            }

            settingsCard(
                title: t("Limits", "限制"),
                subtitle: t("Keep postponing and skipping useful without making breaks meaningless.", "限制推迟和跳过次数，避免休息变得没有意义。")
            ) {
                Toggle(t("Limit postpones per break", "限制每次休息的推迟次数"), isOn: $manager.limitPostponesPerBreak)
                if manager.limitPostponesPerBreak {
                    Stepper("\(t("Max postpones", "最多推迟")): \(manager.maxPostponesPerBreak)", value: $manager.maxPostponesPerBreak, in: 1...10)
                }

                Divider()

                Toggle(t("Limit skips per day", "限制每天跳过次数"), isOn: $manager.limitSkipsPerDay)
                if manager.limitSkipsPerDay {
                    Stepper("\(t("Max skips per day", "每天最多跳过")): \(manager.maxSkipsPerDay)", value: $manager.maxSkipsPerDay, in: 1...20)
                }
            }
        }
    }

    private var statsPage: some View {
        settingsPage {
            settingsCard(
                title: t("Today", "今天"),
                subtitle: t("A lightweight view of how well TimeOut helped you today.", "快速查看 TimeOut 今天帮助你休息的情况。")
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    statTile(t("Micro", "微休息"), manager.todayStats.microCompleted, "eye")
                    statTile(t("Normal", "常规休息"), manager.todayStats.normalCompleted, "figure.walk")
                    statTile(t("Skipped", "已跳过"), manager.todayStats.skipped, "forward.end")
                    statTile(t("Postponed", "已推迟"), manager.todayStats.postponed, "clock.arrow.circlepath")
                    statTile(t("Rule postponed", "规则推迟"), manager.todayStats.rulePostponed, "shield")
                    statTile(t("Natural", "自然休息"), manager.todayStats.naturalBreaks, "moon")
                }
            }
        }
    }

    private var generalPage: some View {
        settingsPage {
            settingsCard(
                title: t("Menu Bar", "菜单栏"),
                subtitle: t("Control how TimeOut appears in the menu bar.", "控制 TimeOut 在菜单栏中的显示方式。")
            ) {
                Toggle(t("Show countdown in menu bar", "在菜单栏显示倒计时"), isOn: $showCountdownInMenuBar)
            }

            settingsCard(
                title: t("Startup", "启动"),
                subtitle: t("Start TimeOut automatically when you log in.", "登录系统时自动启动 TimeOut。")
            ) {
                Toggle(t("Launch at Login", "登录时启动"), isOn: $launchManager.isEnabled)
            }

            settingsCard(
                title: t("Language", "语言"),
                subtitle: t("Choose the display language for TimeOut.", "选择 TimeOut 的显示语言。")
            ) {
                Picker(t("Language", "语言"), selection: $appLanguageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func breakEditor(title: String, subtitle: String, config: Binding<BreakConfiguration>) -> some View {
        settingsCard(title: title, subtitle: subtitle) {
            Toggle(t("Enable", "启用"), isOn: config.isEnabled)

            if config.wrappedValue.isEnabled {
                Divider()

                HStack(spacing: 12) {
                    labeledNumberField(t("Every", "每隔"), value: config.interval, unit: t("seconds", "秒"))
                    labeledNumberField(t("For", "持续"), value: config.duration, unit: t("seconds", "秒"))
                }

                Toggle(t("Reset after idle", "空闲后重置计时"), isOn: config.resetOnIdle)
                if config.wrappedValue.resetOnIdle {
                    labeledNumberField(t("Idle threshold", "空闲阈值"), value: config.idleThreshold, unit: t("seconds", "秒"))
                }

                Divider()

                themePicker(selection: config.theme)
                if config.wrappedValue.theme == .customText {
                    TextField(t("Custom reminder", "自定义提醒"), text: config.customMessage, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                Picker(t("Display mode", "显示模式"), selection: config.displayMode) {
                    ForEach(BreakDisplayMode.allCases) { mode in
                        Text(mode.title(language: language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func settingsPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        }
    }

    private func labeledNumberField(_ title: String, value: Binding<TimeInterval>, unit: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .frame(width: 100, alignment: .leading)
                .foregroundColor(.secondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            Text(unit)
                .foregroundColor(.secondary)
        }
    }

    private func statTile(_ title: String, _ value: Int, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func themePicker(selection: Binding<BreakTheme>) -> some View {
        Picker(t("Theme", "主题"), selection: selection) {
            ForEach(BreakTheme.allCases) { theme in
                Label(theme.title(language: language), systemImage: theme.systemImage)
                    .tag(theme)
            }
        }
        .pickerStyle(.menu)
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, language: language)
    }
}
