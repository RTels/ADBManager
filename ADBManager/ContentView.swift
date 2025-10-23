//
//  ContentView.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import SwiftUI
import XPCLibrary

struct ContentView: View {
    @StateObject private var adbService = ADBService()
    @State private var selectedDevice: Device?
    
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
    
    // MARK: - Sidebar
    
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
                MonitoringIndicator()
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
    
    // MARK: - Detail View
    
    private var detailView: some View {
        Group {
            if let device = selectedDevice {
                // FIXED: Pass device ID, not model
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

// MARK: - Device List Item

struct DeviceListItem: View {
    let device: Device
    
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
        .contentShape(Rectangle())
    }
    
    // FIXED: Show model if available, fallback to ID
    private var displayName: String {
        if let model = device.model, !model.isEmpty {
            return model
        }
        return device.id  // ← FIXED: was device.model
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

// MARK: - Device Detail View

struct DeviceDetailView: View {
    @ObservedObject var adbService: ADBService
    let deviceId: String
    @State private var isLoadingDetails = false
    
    // FIXED: Search by ID, not model
    private var device: Device? {
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
    private func deviceContent(device: Device) -> some View {
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
    
    private func deviceHeader(device: Device) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor(for: device).opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 50))
                    .foregroundColor(statusColor(for: device))
            }
            
            // FIXED: Show displayName (handles model/id logic)
            Text(device.displayName)
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
    
    private func deviceInfo(device: Device) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Information")
                .font(.headline)
            
            // FIXED: Show ID (always available)
            InfoRow(label: "Device ID", value: device.id)
            InfoRow(label: "Status", value: device.state.displayName.capitalized)
            
            // Show optional fields only if they exist
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
    
    private func statusColor(for device: Device) -> Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Info Row

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

// MARK: - Monitoring Indicator

struct MonitoringIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
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
