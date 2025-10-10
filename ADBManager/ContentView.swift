//
//  ContentView.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

//
//  ContentView.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var adbService = ADBService()
    @State private var selectedDevice: AndroidDevice?
    
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            Task {
                await adbService.refreshDevices()
                adbService.startMonitoring()
            }
        }
    }
    
    // MARK: - Sidebar (Device List)
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            sidebarHeader
            
            Divider()
            
            if adbService.isLoading {
                ProgressView("Searching...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if adbService.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }
            
            Divider()
            
            sidebarFooter
        }
        .frame(minWidth: 250, idealWidth: 300)
    }
    
    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.accentColor)
                Text("Devices")
                    .font(.headline)
                Spacer()
            }
            
            if adbService.isMonitoring {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Monitoring")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var deviceList: some View {
        List(adbService.devices, selection: $selectedDevice) { device in
            DeviceListItem(device: device)
                .tag(device)
        }
        .listStyle(.sidebar)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sidebarFooter: some View {
        HStack {
            Text("\(adbService.devices.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                if adbService.isMonitoring {
                    adbService.stopMonitoring()
                } else {
                    adbService.startMonitoring()
                }
            }) {
                Image(systemName: adbService.isMonitoring ? "stop.circle" : "play.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(adbService.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        Group {
            if let device = selectedDevice {
                DeviceDetailView(adbService: adbService, deviceId: device.id)  // ← Pass ID instead
            } else {
                placeholderView
            }
        }
        .frame(minWidth: 400)
    }

    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a Device")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Choose a device from the list to view details")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Device List Item (Sidebar)

struct DeviceListItem: View {
    let device: AndroidDevice
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(device.state.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var displayName: String {
        // Prefer model name, fallback to ID
        if let model = device.model, !model.isEmpty {
            return model
        }
        return device.id
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
    
    private var statusIcon: String {
        switch device.state {
        case .device: return "iphone"
        case .offline: return "moon.fill"
        case .unauthorized: return "lock.fill"
        case .unknown: return "questionmark"
        }
    }
}


// MARK: - Device Detail View (Right Panel)

struct DeviceDetailView: View {
    @ObservedObject var adbService: ADBService
    let deviceId: String  // ← Changed from device to deviceId
    @State private var isLoadingDetails = false
    
    // Computed property to get current device from service
    private var device: AndroidDevice? {
        adbService.devices.first(where: { $0.id == deviceId })
    }
    
    var body: some View {
        Group {
            if let device = device {
                deviceContent(device: device)
            } else {
                Text("Device not found")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func deviceContent(device: AndroidDevice) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                deviceHeader(device: device)
                
                Divider()
                
                if isLoadingDetails {
                    ProgressView("Loading device details...")
                } else {
                    deviceInfo(device: device)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(NSColor.textBackgroundColor))
        .task(id: deviceId) {
            if device.model == nil && device.state == .device {
                isLoadingDetails = true
                await adbService.fetchDeviceDetails(for: device)
                isLoadingDetails = false
            }
        }
    }
    
    private func deviceHeader(device: AndroidDevice) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor(for: device).opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 50))
                    .foregroundColor(statusColor(for: device))
            }
            
            Text(device.model ?? device.id)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(for: device))
                    .frame(width: 8, height: 8)
                
                Text(device.state.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func deviceInfo(device: AndroidDevice) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Information")
                .font(.headline)
            
            InfoRow(label: "Device ID", value: device.id)
            InfoRow(label: "Status", value: device.state.rawValue.capitalized)
            
            if let model = device.model {
                InfoRow(label: "Model", value: model)
            }
            
            if let manufacturer = device.manufacturer {
                InfoRow(label: "Manufacturer", value: manufacturer)
            }
            
            if let androidVersion = device.androidVersion {
                InfoRow(label: "Android Version", value: androidVersion)
            }
            
            if let apiLevel = device.apiLevel {
                InfoRow(label: "API Level", value: apiLevel)
            }
            
            if let batteryLevel = device.batteryLevel {
                InfoRow(label: "Battery", value: batteryLevel)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func statusColor(for device: AndroidDevice) -> Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
}


struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ContentView()
}
