import Foundation

class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            updateLaunchAgent()
        }
    }
    
    private let label = "com.timeout.clone.launchatlogin"
    
    init() {
        self.isEnabled = checkLaunchAgentExists()
    }
    
    private var launchAgentPath: URL {
        let libraryURLs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        let launchAgentsUrl = libraryURLs.first!.appendingPathComponent("LaunchAgents")
        return launchAgentsUrl.appendingPathComponent("\(label).plist")
    }
    
    private func checkLaunchAgentExists() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentPath.path)
    }
    
    private func updateLaunchAgent() {
        if isEnabled {
            createLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }
    
    private func createLaunchAgent() {
        let execPath = Bundle.main.executablePath ?? ""
        guard !execPath.isEmpty else { return }
        
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        
        do {
            let directory = launchAgentPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentPath)
            print("Launch agent created at \(launchAgentPath.path)")
        } catch {
            print("Failed to create launch agent: \(error)")
        }
    }
    
    private func removeLaunchAgent() {
        do {
            if checkLaunchAgentExists() {
                try FileManager.default.removeItem(at: launchAgentPath)
                print("Launch agent removed")
            }
        } catch {
            print("Failed to remove launch agent: \(error)")
        }
    }
}
