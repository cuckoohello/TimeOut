import Foundation

enum BreakDisplayMode: String, CaseIterable, Identifiable, Codable {
    case fullscreen
    case compact

    var id: String { rawValue }
}

enum BreakTheme: String, CaseIterable, Identifiable, Codable {
    case timer
    case breathing
    case eyeRest
    case stretch
    case customText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .breathing: "Breathing"
        case .eyeRest: "Eye Rest"
        case .stretch: "Stretch"
        case .customText: "Custom Text"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .breathing: "lungs.fill"
        case .eyeRest: "eye.fill"
        case .stretch: "figure.flexibility"
        case .customText: "text.quote"
        }
    }
}

struct BreakConfiguration: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var interval: TimeInterval // Time between breaks (work time)
    var duration: TimeInterval // Length of the break
    var isEnabled: Bool = true
    var resetOnIdle: Bool = true
    var idleThreshold: TimeInterval = 300 // 5 minutes default
    var theme: BreakTheme = .timer
    var displayMode: BreakDisplayMode = .fullscreen
    var customMessage: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        interval: TimeInterval,
        duration: TimeInterval,
        isEnabled: Bool = true,
        resetOnIdle: Bool = true,
        idleThreshold: TimeInterval = 300,
        theme: BreakTheme = .timer,
        displayMode: BreakDisplayMode = .fullscreen,
        customMessage: String = ""
    ) {
        self.id = id
        self.name = name
        self.interval = interval
        self.duration = duration
        self.isEnabled = isEnabled
        self.resetOnIdle = resetOnIdle
        self.idleThreshold = idleThreshold
        self.theme = theme
        self.displayMode = displayMode
        self.customMessage = customMessage
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case interval
        case duration
        case isEnabled
        case resetOnIdle
        case idleThreshold
        case theme
        case displayMode
        case customMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        interval = try container.decode(TimeInterval.self, forKey: .interval)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        resetOnIdle = try container.decodeIfPresent(Bool.self, forKey: .resetOnIdle) ?? true
        idleThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .idleThreshold) ?? 300
        theme = try container.decodeIfPresent(BreakTheme.self, forKey: .theme) ?? BreakConfiguration.defaultTheme(for: name)
        displayMode = try container.decodeIfPresent(BreakDisplayMode.self, forKey: .displayMode) ?? .fullscreen
        customMessage = try container.decodeIfPresent(String.self, forKey: .customMessage) ?? ""
    }

    private static func defaultTheme(for name: String) -> BreakTheme {
        name.lowercased() == "micro" ? .eyeRest : .stretch
    }

    static let defaultMicro = BreakConfiguration(
        name: "Micro",
        interval: 15 * 60, // 15 mins
        duration: 15,      // 15 secs
        idleThreshold: 120, // 2 mins
        theme: .eyeRest,
        displayMode: .compact
    )

    static let defaultNormal = BreakConfiguration(
        name: "Normal",
        interval: 60 * 60, // 1 hour
        duration: 10 * 60, // 10 mins
        idleThreshold: 600, // 10 mins
        theme: .stretch,
        displayMode: .fullscreen
    )
}
