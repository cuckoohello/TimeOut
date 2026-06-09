import SwiftUI

struct OverlayView: View {
    @ObservedObject var manager: BreakManager
    @State private var breathingScale = 0.75
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some View {
        ZStack {
            // Background Dim
            Color.black.opacity(isPreparing ? 0.55 : 0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 40) {
                if let config = currentConfig {
                    Text(title(for: config))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)

                    if isPreparing {
                        Text(t("Starts in", "即将开始"))
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 20)
                            .opacity(0.3)
                            .foregroundColor(.gray)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(manager.activeBreakProgress))
                            .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.green)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: manager.activeBreakProgress)
                        
                        Text(manager.timeRemainingFormatted)
                            .font(.system(size: 80, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .frame(width: 300, height: 300)

                    if !isPreparing {
                        themeContent(for: config)
                    }

                    if isPreparing {
                        Button(action: {
                            manager.startBreakNow()
                        }) {
                            Label(t("Start Now", "立即开始"), systemImage: "play.fill")
                                .font(.title2)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color.green.opacity(0.85))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                    }

                    HStack(spacing: 18) {
                        Button(action: {
                            manager.postponeBreak(minutes: 1)
                        }) {
                            VStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                Text("1m")
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)

                        Button(action: {
                            manager.postponeBreak(minutes: 5)
                        }) {
                            VStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                Text("5m")
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)

                        Button(action: {
                            manager.postponeBreak(minutes: 15)
                        }) {
                            VStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                Text("15m")
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)

                        Button(action: {
                            manager.skipBreak()
                        }) {
                            VStack {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 30))
                                Text(t("Skip", "跳过"))
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }

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

    @ViewBuilder
    private func themeContent(for config: BreakConfiguration) -> some View {
        switch config.theme {
        case .timer:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Take a real pause", "真正暂停一下"),
                message: t("Look away from the screen and let your body relax.", "移开视线，让身体放松下来。")
            )
        case .breathing:
            breathingView
        case .eyeRest:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Rest your eyes", "让眼睛休息"),
                message: t("Look at something far away, blink slowly, and soften your focus.", "看向远处，慢慢眨眼，放松视线焦点。")
            )
        case .stretch:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Move and stretch", "活动和拉伸"),
                message: t("Stand up, roll your shoulders, stretch your back, and take a few steps.", "站起来，转动肩膀，伸展背部，走动几步。")
            )
        case .customText:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Your reminder", "你的提醒"),
                message: config.customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? t("Use settings to write a personal break reminder.", "在设置中填写你的个人休息提醒。")
                    : config.customMessage
            )
        }
    }

    private var breathingView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.65), Color.blue.opacity(0.15)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(width: 170, height: 170)
                    .scaleEffect(breathingScale)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathingScale)

                Image(systemName: "lungs.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(t("Breathe slowly", "慢慢呼吸"))
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)

            Text(t("Inhale as the circle grows. Exhale as it shrinks.", "圆圈变大时吸气，变小时呼气。"))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(Color.white.opacity(0.12))
        .cornerRadius(24)
        .onAppear {
            breathingScale = 1.15
        }
    }

    private func tipCard(icon: String, title: String, message: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(maxWidth: 680, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .cornerRadius(22)
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
