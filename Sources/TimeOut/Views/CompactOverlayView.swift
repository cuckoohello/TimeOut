import SwiftUI

struct CompactOverlayView: View {
    @ObservedObject var manager: BreakManager
    @State private var breathingScale = 0.75
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some View {
        VStack(spacing: 14) {
            if let config = currentConfig {
                Text(title(for: config))
                    .font(.system(size: 16, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                if isPreparing {
                    Text(t("Starts in", "即将开始"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }

                compactProgressRing

                if !isPreparing {
                    compactThemeContent(for: config)
                }

                if isPreparing {
                    Button(action: {
                        manager.startBreakNow()
                    }) {
                        Label(t("Start Now", "立即开始"), systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.85))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }

                compactActionButtons
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    // MARK: - Progress Ring

    private var compactProgressRing: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.3)
                .foregroundColor(.gray)

            Circle()
                .trim(from: 0.0, to: CGFloat(manager.activeBreakProgress))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(.green)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: manager.activeBreakProgress)

            Text(manager.timeRemainingFormatted)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
    }

    // MARK: - Action Buttons

    private var compactActionButtons: some View {
        HStack(spacing: 10) {
            compactButton(icon: "clock.arrow.circlepath", title: "1m") {
                manager.postponeBreak(minutes: 1)
            }

            compactButton(icon: "clock.arrow.circlepath", title: "5m") {
                manager.postponeBreak(minutes: 5)
            }

            compactButton(icon: "clock.arrow.circlepath", title: "15m") {
                manager.postponeBreak(minutes: 15)
            }

            compactButton(icon: "forward.end.fill", title: t("Skip", "跳过")) {
                manager.skipBreak()
            }
        }
    }

    private func compactButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }

    // MARK: - Theme Content

    @ViewBuilder
    private func compactThemeContent(for config: BreakConfiguration) -> some View {
        switch config.theme {
        case .timer:
            compactTipCard(
                icon: config.theme.systemImage,
                title: t("Take a real pause", "真正暂停一下"),
                message: t("Look away from the screen and let your body relax.", "移开视线，让身体放松下来。")
            )
        case .breathing:
            compactBreathingView
        case .eyeRest:
            compactTipCard(
                icon: config.theme.systemImage,
                title: t("Rest your eyes", "让眼睛休息"),
                message: t("Look at something far away, blink slowly, and soften your focus.", "看向远处，慢慢眨眼，放松视线焦点。")
            )
        case .stretch:
            compactTipCard(
                icon: config.theme.systemImage,
                title: t("Move and stretch", "活动和拉伸"),
                message: t("Stand up, roll your shoulders, stretch your back, and take a few steps.", "站起来，转动肩膀，伸展背部，走动几步。")
            )
        case .customText:
            compactTipCard(
                icon: config.theme.systemImage,
                title: t("Your reminder", "你的提醒"),
                message: config.customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? t("Use settings to write a personal break reminder.", "在设置中填写你的个人休息提醒。")
                    : config.customMessage
            )
        }
    }

    private var compactBreathingView: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.65), Color.blue.opacity(0.15)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 60
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(breathingScale)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathingScale)

                Image(systemName: "lungs.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(t("Breathe slowly", "慢慢呼吸"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text(t("Inhale as the circle grows. Exhale as it shrinks.", "圆圈变大时吸气，变小时呼气。"))
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.12))
        .cornerRadius(12)
        .onAppear {
            breathingScale = 1.15
        }
    }

    private func compactTipCard(icon: String, title: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var currentConfig: BreakConfiguration? {
        switch manager.state {
        case .preparing(let config), .inBreak(let config):
            return config
        default:
            return nil
        }
    }

    private var isPreparing: Bool {
        if case .preparing = manager.state { return true }
        return false
    }

    private func title(for config: BreakConfiguration) -> String {
        if isPreparing {
            return L10n.text(
                "Upcoming \(breakName(for: config, language: .english)) Break",
                "即将开始\(breakName(for: config, language: .chinese))",
                language: language
            )
        }

        return L10n.text(
            "\(breakName(for: config, language: .english)) Break",
            breakName(for: config, language: .chinese),
            language: language
        )
    }

    private func breakName(for config: BreakConfiguration, language: AppLanguage) -> String {
        if config.name.lowercased() == "micro" {
            return L10n.text("Micro", "微休息", language: language)
        }

        if config.name.lowercased() == "normal" {
            return L10n.text("Normal", "常规休息", language: language)
        }

        return config.name
    }

    private func t(_ english: String, _ chinese: String) -> String {
        L10n.text(english, chinese, language: language)
    }
}
