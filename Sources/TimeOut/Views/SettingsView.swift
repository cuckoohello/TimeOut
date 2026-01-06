import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: BreakManager
    @StateObject var launchManager = LaunchAtLoginManager()

    var body: some View {
        Form {
            Section(header: Text("Micro Break").font(.headline)) {
                Toggle("Enable Micro Breaks", isOn: $manager.microBreak.isEnabled)
                
                if manager.microBreak.isEnabled {
                    HStack {
                        Text("Every:")
                        TextField("Interval (sec)", value: $manager.microBreak.interval, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("For:")
                        TextField("Duration (sec)", value: $manager.microBreak.duration, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    Toggle("Reset after idle", isOn: $manager.microBreak.resetOnIdle)
                }
            }
            
            Divider()
            
            Section(header: Text("Normal Break").font(.headline)) {
                Toggle("Enable Normal Breaks", isOn: $manager.normalBreak.isEnabled)
                
                if manager.normalBreak.isEnabled {
                    HStack {
                        Text("Every:")
                        TextField("Interval (sec)", value: $manager.normalBreak.interval, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("For:")
                        TextField("Duration (sec)", value: $manager.normalBreak.duration, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    Toggle("Reset after idle", isOn: $manager.normalBreak.resetOnIdle)
                }
            }
            
            Divider()
            
            Section(header: Text("General").font(.headline)) {
                Toggle("Launch at Login", isOn: $launchManager.isEnabled)
            }

            Divider()

            Section {
                 if let next = manager.nextBreakTime {
                     Text("Next break at: \(next.formatted(date: .omitted, time: .standard))")
                         .foregroundColor(.secondary)
                 }
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}
