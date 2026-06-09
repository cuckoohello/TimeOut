import SwiftUI

private struct OverlayLayout {
    let scale: CGFloat
    let compactScale: CGFloat
    let spacing: CGFloat
    let edgePadding: CGFloat
    let titleFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let ringSize: CGFloat
    let ringLineWidth: CGFloat
    let timerFontSize: CGFloat
    let buttonIconSize: CGFloat
    let buttonTextSize: CGFloat
    let buttonPadding: CGFloat
    let buttonSpacing: CGFloat
    let primaryButtonHorizontalPadding: CGFloat
    let primaryButtonVerticalPadding: CGFloat
    let cardMaxWidth: CGFloat
    let cardHorizontalPadding: CGFloat
    let cardVerticalPadding: CGFloat
    let cardIconSize: CGFloat
    let cardIconFrameSize: CGFloat
    let cardTitleFontSize: CGFloat
    let cardMessageFontSize: CGFloat
    let breathingCircleSize: CGFloat
    let breathingIconSize: CGFloat
    let cornerRadius: CGFloat
}

struct OverlayView: View {
    @ObservedObject var manager: BreakManager
    @State private var breathingScale = 0.75
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.current.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .english
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = overlayLayout(for: proxy.size)

            ZStack {
                // Background Dim
                Color.black.opacity(isPreparing ? 0.55 : 0.8)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: layout.spacing) {
                    if let config = currentConfig {
                        Text(title(for: config))
                            .font(.system(size: layout.titleFontSize, weight: .bold))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(.white)

                        if isPreparing {
                            Text(t("Starts in", "即将开始"))
                                .font(.system(size: layout.subtitleFontSize, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        
                        progressRing(layout: layout)

                        if !isPreparing {
                            themeContent(for: config, layout: layout)
                        }

                        if isPreparing {
                            Button(action: {
                                manager.startBreakNow()
                            }) {
                                Label(t("Start Now", "立即开始"), systemImage: "play.fill")
                                    .font(.system(size: layout.buttonTextSize, weight: .semibold))
                                    .padding(.horizontal, layout.primaryButtonHorizontalPadding)
                                    .padding(.vertical, layout.primaryButtonVerticalPadding)
                                    .background(Color.green.opacity(0.85))
                                    .cornerRadius(layout.cornerRadius)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white)
                        }

                        actionButtons(layout: layout)
                    }
                }
                .padding(.horizontal, layout.edgePadding)
                .padding(.vertical, layout.edgePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func overlayLayout(for size: CGSize) -> OverlayLayout {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let shortSide = min(width, height)
        let heightScale = height / 950
        let widthScale = width / 1280
        let scale = min(1, max(0.55, min(heightScale, widthScale, shortSide / 850)))
        let compactScale = min(1, max(0.45, min(height / 760, width / 900)))
        let ringSize = min(300 * scale, height * 0.34, width * 0.38)

        return OverlayLayout(
            scale: scale,
            compactScale: compactScale,
            spacing: max(10, 40 * scale),
            edgePadding: max(16, 40 * scale),
            titleFontSize: max(30, 60 * scale),
            subtitleFontSize: max(18, 22 * scale),
            ringSize: max(150, ringSize),
            ringLineWidth: max(10, 20 * scale),
            timerFontSize: max(34, 80 * scale),
            buttonIconSize: max(20, 30 * compactScale),
            buttonTextSize: max(14, 18 * compactScale),
            buttonPadding: max(9, 16 * compactScale),
            buttonSpacing: max(10, 18 * compactScale),
            primaryButtonHorizontalPadding: max(18, 24 * compactScale),
            primaryButtonVerticalPadding: max(10, 14 * compactScale),
            cardMaxWidth: min(680, width - max(32, 80 * scale)),
            cardHorizontalPadding: max(18, 28 * compactScale),
            cardVerticalPadding: max(14, 20 * compactScale),
            cardIconSize: max(28, 36 * compactScale),
            cardIconFrameSize: max(44, 56 * compactScale),
            cardTitleFontSize: max(18, 22 * compactScale),
            cardMessageFontSize: max(16, 20 * compactScale),
            breathingCircleSize: max(110, 170 * compactScale),
            breathingIconSize: max(38, 52 * compactScale),
            cornerRadius: max(10, 22 * compactScale)
        )
    }

    private func progressRing(layout: OverlayLayout) -> some View {
        ZStack {
            Circle()
                .stroke(lineWidth: layout.ringLineWidth)
                .opacity(0.3)
                .foregroundColor(.gray)

            Circle()
                .trim(from: 0.0, to: CGFloat(manager.activeBreakProgress))
                .stroke(style: StrokeStyle(lineWidth: layout.ringLineWidth, lineCap: .round, lineJoin: .round))
                .foregroundColor(.green)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: manager.activeBreakProgress)
            
            Text(manager.timeRemainingFormatted)
                .font(.system(size: layout.timerFontSize, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.65)
                .foregroundColor(.white)
        }
        .frame(width: layout.ringSize, height: layout.ringSize)
    }

    private func actionButtons(layout: OverlayLayout) -> some View {
        HStack(spacing: layout.buttonSpacing) {
            overlayActionButton(icon: "clock.arrow.circlepath", title: "1m", layout: layout) {
                manager.postponeBreak(minutes: 1)
            }

            overlayActionButton(icon: "clock.arrow.circlepath", title: "5m", layout: layout) {
                manager.postponeBreak(minutes: 5)
            }

            overlayActionButton(icon: "clock.arrow.circlepath", title: "15m", layout: layout) {
                manager.postponeBreak(minutes: 15)
            }

            overlayActionButton(icon: "forward.end.fill", title: t("Skip", "跳过"), layout: layout) {
                manager.skipBreak()
            }
        }
    }

    private func overlayActionButton(icon: String, title: String, layout: OverlayLayout, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: layout.buttonIconSize))
                Text(title)
                    .font(.system(size: layout.buttonTextSize, weight: .medium))
            }
            .padding(layout.buttonPadding)
            .background(Color.white.opacity(0.2))
            .cornerRadius(max(8, layout.cornerRadius * 0.45))
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
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
    private func themeContent(for config: BreakConfiguration, layout: OverlayLayout) -> some View {
        switch config.theme {
        case .timer:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Take a real pause", "真正暂停一下"),
                message: t("Look away from the screen and let your body relax.", "移开视线，让身体放松下来。"),
                layout: layout
            )
        case .breathing:
            breathingView(layout: layout)
        case .eyeRest:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Rest your eyes", "让眼睛休息"),
                message: t("Look at something far away, blink slowly, and soften your focus.", "看向远处，慢慢眨眼，放松视线焦点。"),
                layout: layout
            )
        case .stretch:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Move and stretch", "活动和拉伸"),
                message: t("Stand up, roll your shoulders, stretch your back, and take a few steps.", "站起来，转动肩膀，伸展背部，走动几步。"),
                layout: layout
            )
        case .customText:
            tipCard(
                icon: config.theme.systemImage,
                title: t("Your reminder", "你的提醒"),
                message: config.customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? t("Use settings to write a personal break reminder.", "在设置中填写你的个人休息提醒。")
                    : config.customMessage,
                layout: layout
            )
        }
    }

    private func breathingView(layout: OverlayLayout) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.65), Color.blue.opacity(0.15)],
                            center: .center,
                            startRadius: 10,
                            endRadius: layout.breathingCircleSize * 0.7
                        )
                    )
                    .frame(width: layout.breathingCircleSize, height: layout.breathingCircleSize)
                    .scaleEffect(breathingScale)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathingScale)

                Image(systemName: "lungs.fill")
                    .font(.system(size: layout.breathingIconSize))
                    .foregroundColor(.white.opacity(0.9))
            }

            Text(t("Breathe slowly", "慢慢呼吸"))
                .font(.system(size: layout.cardTitleFontSize, weight: .semibold))
                .foregroundColor(.white)

            Text(t("Inhale as the circle grows. Exhale as it shrinks.", "圆圈变大时吸气，变小时呼气。"))
                .font(.system(size: layout.cardMessageFontSize))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, layout.cardHorizontalPadding)
        .padding(.vertical, layout.cardVerticalPadding)
        .frame(maxWidth: layout.cardMaxWidth)
        .background(Color.white.opacity(0.12))
        .cornerRadius(layout.cornerRadius)
        .onAppear {
            breathingScale = 1.15
        }
    }

    private func tipCard(icon: String, title: String, message: String, layout: OverlayLayout) -> some View {
        HStack(spacing: max(12, 18 * layout.compactScale)) {
            Image(systemName: icon)
                .font(.system(size: layout.cardIconSize))
                .frame(width: layout.cardIconFrameSize, height: layout.cardIconFrameSize)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: layout.cardTitleFontSize, weight: .semibold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: layout.cardMessageFontSize))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, layout.cardHorizontalPadding)
        .padding(.vertical, layout.cardVerticalPadding)
        .frame(maxWidth: layout.cardMaxWidth, alignment: .leading)
        .background(Color.white.opacity(0.12))
        .cornerRadius(layout.cornerRadius)
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
