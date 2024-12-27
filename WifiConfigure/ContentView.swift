//
//  ContentView.swift
//  WifiConfigure
//
//  Created by Hamid on 12/27/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NetworkConfigView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
            
            DNSConfigView()
                .tabItem {
                    Label("DNS", systemImage: "server.rack")
                }
        }
        .frame(width: 600, height: 400)  // Increased height for tabs
    }
}

// Move the existing network configuration to a new view
struct NetworkConfigView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section("IPv4 Configuration") {
                Picker("Configuration Method", selection: $networkManager.isUsingDHCP) {
                    Text("Home (Using DHCP)").tag(true)
                    Text("Office (Manually)").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: networkManager.isUsingDHCP) { newValue in
                    if !newValue {
                        networkManager.restoreManualSettings()
                    }
                }
                
                if !networkManager.isUsingDHCP {
                    TextField("IP Address", text: $networkManager.ipAddress)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Subnet Mask", text: $networkManager.subnetMask)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Router", text: $networkManager.router)
                        .textFieldStyle(.roundedBorder)
                        
                    TextField("DNS Servers (comma-separated)", text: $networkManager.dnsServers)
                        .textFieldStyle(.roundedBorder)
                        .help("Enter DNS servers separated by commas (e.g., 8.8.8.8, 8.8.4.4)")
                }
            }
            
            Button("Apply Settings") {
                Task {
                    do {
                        try await networkManager.applyNetworkSettings()
                        alertMessage = "Settings applied successfully"
                    } catch {
                        alertMessage = "Failed to apply settings: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
            .disabled(networkManager.isUsingDHCP == false && 
                     (networkManager.ipAddress.isEmpty || 
                      networkManager.subnetMask.isEmpty || 
                      networkManager.router.isEmpty))
            .padding(.horizontal)
        }
        .padding()
        .alert("Network Configuration", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if networkManager.isUsingDHCP {
                networkManager.getCurrentWiFiSettings()
            }
        }
    }
}

#Preview {
    ContentView()
}
