import SwiftUI

class DNSManager: ObservableObject {
    @Published var dnsServers = "" {
        didSet {
            UserDefaults.standard.set(dnsServers, forKey: "customDNS")
        }
    }
    
    init() {
        dnsServers = UserDefaults.standard.string(forKey: "customDNS") ?? ""
    }
    
    func applyDNSSettings() async throws {
        let dnsServersArray = dnsServers.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let command: String
        if dnsServersArray.isEmpty {
            command = "networksetup -setdnsservers Wi-Fi empty"
        } else {
            command = "networksetup -setdnsservers Wi-Fi \(dnsServersArray.joined(separator: " "))"
        }
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("dns_config.sh")
        try command.write(to: tempFile, atomically: true, encoding: .utf8)
        
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempFile.path)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \"\(tempFile.path)\" with administrator privileges"
        ]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw DNSError.configurationFailed
        }
        
        try? FileManager.default.removeItem(at: tempFile)
    }
    
    func getCurrentDNS() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getdnsservers", "Wi-Fi"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if !output.contains("There aren't any DNS Servers set") {
                        self.dnsServers = output
                            .components(separatedBy: .newlines)
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")
                    }
                }
            }
        } catch {
            print("Error getting DNS settings: \(error)")
        }
    }
}

enum DNSError: Error {
    case configurationFailed
}

struct DNSConfigView: View {
    @StateObject private var dnsManager = DNSManager()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section("DNS Configuration") {
                TextField("DNS Servers (comma-separated)", text: $dnsManager.dnsServers)
                    .textFieldStyle(.roundedBorder)
                    .help("Enter DNS servers separated by commas (e.g., 8.8.8.8, 8.8.4.4)")
                
                Text("Common DNS Servers:")
                    .font(.caption)
                
                HStack {
                    Button("Google DNS") {
                        dnsManager.dnsServers = "8.8.8.8, 8.8.4.4"
                    }
                    
                    Button("Cloudflare DNS") {
                        dnsManager.dnsServers = "1.1.1.1, 1.0.0.1"
                    }
                    
                    Button("403") {
                        dnsManager.dnsServers = "10.202.10.202, 10.202.10.102"
                    }
                    
                    Button("Shekan") {
                        dnsManager.dnsServers = "178.22.122.100, 185.51.200.2"
                    }
                }
            }
            
            Button("Apply DNS Settings") {
                Task {
                    do {
                        try await dnsManager.applyDNSSettings()
                        alertMessage = "DNS settings applied successfully"
                    } catch {
                        alertMessage = "Failed to apply DNS settings: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .alert("DNS Configuration", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
} 
