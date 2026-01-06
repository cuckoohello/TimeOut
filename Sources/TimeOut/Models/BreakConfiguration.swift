import Foundation

struct BreakConfiguration: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var interval: TimeInterval // Time between breaks (work time)
    var duration: TimeInterval // Length of the break
    var isEnabled: Bool = true
    var resetOnIdle: Bool = true
    var idleThreshold: TimeInterval = 300 // 5 minutes default

    static let defaultMicro = BreakConfiguration(
        name: "Micro",
        interval: 15 * 60, // 15 mins
        duration: 15,      // 15 secs
        idleThreshold: 120 // 2 mins
    )

    static let defaultNormal = BreakConfiguration(
        name: "Normal",
        interval: 60 * 60, // 1 hour
        duration: 10 * 60, // 10 mins
        idleThreshold: 600 // 10 mins
    )
}
