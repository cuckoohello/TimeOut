import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        }
    }

    static var current: AppLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }

        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .chinese : .english
    }
}

enum L10n {
    static func text(_ english: String, _ chinese: String, language: AppLanguage = .current) -> String {
        switch language {
        case .english: english
        case .chinese: chinese
        }
    }
}

extension BreakDisplayMode {
    func title(language: AppLanguage = .current) -> String {
        switch self {
        case .fullscreen: L10n.text("Fullscreen", "全屏", language: language)
        case .compact: L10n.text("Compact", "紧凑", language: language)
        }
    }
}

extension BreakTheme {
    func title(language: AppLanguage = .current) -> String {
        switch self {
        case .timer: L10n.text("Timer", "计时器", language: language)
        case .breathing: L10n.text("Breathing", "呼吸", language: language)
        case .eyeRest: L10n.text("Eye Rest", "护眼", language: language)
        case .stretch: L10n.text("Stretch", "拉伸", language: language)
        case .customText: L10n.text("Custom Text", "自定义文字", language: language)
        }
    }
}

extension FullScreenBreakBehavior {
    func title(language: AppLanguage = .current) -> String {
        switch self {
        case .allow: L10n.text("Allow Breaks", "允许休息", language: language)
        case .postpone: L10n.text("Postpone Breaks", "推迟休息", language: language)
        case .skip: L10n.text("Skip Breaks", "跳过休息", language: language)
        }
    }

    func description(language: AppLanguage = .current) -> String {
        switch self {
        case .allow:
            L10n.text(
                "Start breaks even when another app is full screen.",
                "即使其他应用处于全屏，也正常开始休息。",
                language: language
            )
        case .postpone:
            L10n.text(
                "Delay breaks while another app is full screen.",
                "其他应用全屏时自动推迟休息。",
                language: language
            )
        case .skip:
            L10n.text(
                "Count the break as skipped while another app is full screen.",
                "其他应用全屏时将本次休息记为跳过。",
                language: language
            )
        }
    }
}
