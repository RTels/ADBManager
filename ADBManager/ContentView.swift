//
//  ContentView.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import SwiftUI

// UI: Main view with WhatsApp-style split layout
struct ContentView: View {
    // STATE: Observable service - changes trigger UI updates (research: @StateObject vs @ObservedObject)
    @StateObject private var adbService = ADBService()
    
    // STATE: Currently selected device in sidebar (research: @State for view-local data)
    @State private var selectedDevice: AndroidDevice?
    
    var body: some View {
        // LAYOUT: Sidebar + Detail pattern (research: NavigationSplitView)
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // LIFECYCLE: Execute on view appearance
            Task {
                await adbService.refreshDevices()
                adbService.startMonitoring()  // Auto-start polling
            }
        }
    }
    
    // MARK: - Sidebar (Device List)
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            sidebarHeader
            
            Divider()
            
            // CONDITIONAL: Show loading, empty, or device list
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
                MonitoringIndicator()  // Animated pulse indicator
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var deviceList: some View {
        // BINDING: Two-way binding for selection (research: $ prefix)
        List(adbService.devices, selection: $selectedDevice) { device in
            DeviceListItem(device: device)
                .tag(device)  // SELECTION: Enable item selection
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
    
    // MARK: - Detail View
    
    private var detailView: some View {
        Group {
            if let device = selectedDevice {
                // REACTIVE: Pass deviceId to observe changes in devices array
                DeviceDetailView(adbService: adbService, deviceId: device.id)
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

// UI: Compact device row for sidebar
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
                    
                    Text(device.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())  // INTERACTION: Entire row is tappable
    }
    
    // COMPUTED: Prefer model name, fallback to device ID
    private var displayName: String {
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
    
    // VISUAL: Color coding by connection state
    private var statusColor: Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
    
    // VISUAL: Icon per connection state
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

// UI: Detailed device information panel
struct DeviceDetailView: View {
    // REACTIVE: Observe service to react to device updates (research: @ObservedObject)
    @ObservedObject var adbService: ADBService
    let deviceId: String
    @State private var isLoadingDetails = false
    
    // COMPUTED: Always get fresh device from array (reactive to changes)
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
            // LAZY: Fetch details only when device selected AND not already loaded
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
                
                Text(device.state.displayName.capitalized)
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
            InfoRow(label: "Status", value: device.state.displayName.capitalized)
            
            // CONDITIONAL: Only show if data exists
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

// UI: Reusable label-value row
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

// ANIMATION: Pulsing monitoring indicator
struct MonitoringIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(isAnimating ? 0.3 : 1.0)  // Pulse between 30% and 100%
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true  // Trigger animation
                }
            
            Text("Monitoring")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
