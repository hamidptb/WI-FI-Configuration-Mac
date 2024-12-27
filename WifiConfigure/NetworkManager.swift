import Foundation
import SystemConfiguration

class NetworkManager: ObservableObject {
    @Published var isUsingDHCP = true {
        didSet { 
            UserDefaults.standard.set(isUsingDHCP, forKey: "isUsingDHCP")
        }
    }
    @Published var ipAddress = ""
    @Published var subnetMask = ""
    @Published var router = ""
    @Published var dnsServers = ""
    
    @Published var savedManualSettings: Settings?
    
    struct Settings: Codable {
        var isUsingDHCP: Bool
        var ipAddress: String
        var subnetMask: String
        var router: String
        var dnsServers: String
    }
    
    init() {
        // Load DHCP status
        isUsingDHCP = UserDefaults.standard.bool(forKey: "isUsingDHCP")
        
        // Load manual settings
        loadManualSettings()
        
        // If we're in manual mode, restore the manual settings
        if !isUsingDHCP {
            restoreManualSettings()
        }
    }
    
    private func loadManualSettings() {
        if let ipAddress = UserDefaults.standard.string(forKey: "manualIP"),
           let subnetMask = UserDefaults.standard.string(forKey: "manualSubnet"),
           let router = UserDefaults.standard.string(forKey: "manualRouter"),
           let dns = UserDefaults.standard.string(forKey: "manualDNS") {
            
            savedManualSettings = Settings(
                isUsingDHCP: false,
                ipAddress: ipAddress,
                subnetMask: subnetMask,
                router: router,
                dnsServers: dns
            )
            
            print("Loaded manual settings: IP=\(ipAddress), Subnet=\(subnetMask), Router=\(router), DNS=\(dns)")
        }
    }
    
    private func saveManualSettings() {
        UserDefaults.standard.set(ipAddress, forKey: "manualIP")
        UserDefaults.standard.set(subnetMask, forKey: "manualSubnet")
        UserDefaults.standard.set(router, forKey: "manualRouter")
        UserDefaults.standard.set(dnsServers, forKey: "manualDNS")
        
        savedManualSettings = Settings(
            isUsingDHCP: false,
            ipAddress: ipAddress,
            subnetMask: subnetMask,
            router: router,
            dnsServers: dnsServers
        )
        
        print("Saved manual settings: IP=\(ipAddress), Subnet=\(subnetMask), Router=\(router), DNS=\(dnsServers)")
    }
    
    func restoreManualSettings() {
        if let saved = savedManualSettings {
            print("Restoring manual settings")
            ipAddress = saved.ipAddress
            subnetMask = saved.subnetMask
            router = saved.router
            dnsServers = saved.dnsServers
        } else {
            print("No manual settings found to restore, setting default values")
            // Set default placeholder values
            ipAddress = "192.168.1.100"
            subnetMask = "255.255.255.0"
            router = "192.168.1.1"
            dnsServers = "8.8.8.8, 8.8.4.4"
            
            // Save these defaults as manual settings
            saveManualSettings()
        }
    }
    
    private var currentInterface: String? {
        let wifiInterface = "en0"
        return wifiInterface
    }
    
    func getCurrentWiFiSettings() {
        // Only get the DHCP status, don't update the values
        guard let interface = currentInterface else {
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getinfo", "Wi-Fi"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseNetworkSettings(output)
            }
        } catch {
            print("Error getting network settings: \(error)")
        }
    }
    
    private func parseNetworkSettings(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        DispatchQueue.main.async {
            for line in lines {
                if line.contains("DHCP Configuration") {
                    self.isUsingDHCP = true
                } else if line.contains("Manual Configuration") {
                    self.isUsingDHCP = false
                }
                // Don't update the values when getting current settings
                // This preserves the manual input values
            }
        }
    }
    
    private func parseDNSSettings(_ output: String) {
        // Don't update DNS settings automatically
        // Let the user's manual settings persist
    }
    
    func applyNetworkSettings() async throws {
        guard let interface = currentInterface else {
            throw NetworkError.noActiveInterface
        }
        
        // Save manual settings when applying in manual mode
        if !isUsingDHCP {
            saveManualSettings()
        }
        
        var commands: [String] = []
        
        // Network configuration command
        if isUsingDHCP {
            commands.append("networksetup -setdhcp Wi-Fi")
        } else {
            commands.append("networksetup -setmanual Wi-Fi \(ipAddress) \(subnetMask) \(router)")
        }
        
        // DNS configuration command
        if !isUsingDHCP && !dnsServers.isEmpty {
            let dnsServersArray = dnsServers.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            if !dnsServersArray.isEmpty {
                let dnsCommand = "networksetup -setdnsservers Wi-Fi \(dnsServersArray.joined(separator: " "))"
                commands.append(dnsCommand)
            }
        } else if isUsingDHCP {
            commands.append("networksetup -setdnsservers Wi-Fi empty")
        }
        
        let scriptContent = commands.joined(separator: "\n")
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("network_config.sh")
        try scriptContent.write(to: tempFile, atomically: true, encoding: .utf8)
        
        // Make the script executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile.path)
        
        // Execute the script with admin privileges
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \"\(tempFile.path)\" with administrator privileges"
        ]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NetworkError.configurationFailed
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: tempFile)
    }
}

enum NetworkError: Error {
    case noActiveInterface
    case configurationFailed
} 
