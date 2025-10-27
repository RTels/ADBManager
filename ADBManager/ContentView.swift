//
//  ContentView.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import SwiftUI
import XPCLibrary
import AppKit

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
    
    private var detailView: some View {
        Group {
            if let device = selectedDevice {
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
    @State private var selectedSourcePath: String? = "/sdcard/DCIM/Camera/"
    @State private var showFolderBrowser = false
    @State private var showSuccessAlert = false
    @State private var syncedPhotoCount = 0
    @State private var destinationFolder: String?
    
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
        VStack(spacing: 0) {
            // ERROR BANNER
            if let error = adbService.error {
                ErrorBanner(message: error) {
                    adbService.error = nil
                    adbService.startMonitoring()  // ← Restart monitoring when dismissed
                }
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    deviceHeader(device: device)
                    
                    Divider()
                    
                    if isLoadingDetails {
                        ProgressView("Loading device details...")
                    } else {
                        deviceInfo(device: device)
                    }
                    
                    Divider()
                    photoSyncSection(device: device)
                    Spacer()
                }
                .padding()
            }
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
            
            InfoRow(label: "Device ID", value: device.id)
            InfoRow(label: "Status", value: device.state.displayName.capitalized)
            
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
    
    private func photoSyncSection(device: Device) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photo Sync")
                .font(.headline)
            
            if adbService.isSyncing {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    if let progress = adbService.syncProgress {
                        Text(progress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Folder:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(selectedSourcePath ?? "/sdcard/DCIM/Camera/")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Button(action: {
                            showFolderBrowser = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("Browse...")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                Button(action: {
                    Task {
                        await handleSyncPhotos(for: device)
                    }
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Sync Photos to Mac")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(device.state != .device)
                
                Text("Syncs all photos from selected folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .sheet(isPresented: $showFolderBrowser) {
            FolderBrowserView(
                adbService: adbService,
                device: device,
                selectedPath: $selectedSourcePath
            )
        }
        .alert("Sync Complete!", isPresented: $showSuccessAlert) {
            Button("Open Folder") {
                if let folder = destinationFolder {
                    NSWorkspace.shared.open(URL(fileURLWithPath: folder))
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Successfully synced \(syncedPhotoCount) photo\(syncedPhotoCount == 1 ? "" : "s")!")
        }
    }
    
    private func handleSyncPhotos(for device: Device) async {
        guard let sourcePath = selectedSourcePath else {
            adbService.error = "Please select a source folder"
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose destination folder for photos"
        panel.prompt = "Select Folder"
        
        let picturesPath = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        panel.directoryURL = picturesPath
        
        let response = await panel.begin()
        
        guard response == .OK, let url = panel.url else {
            print("User cancelled folder selection")
            return
        }
        
        if let count = await adbService.syncPhotos(
            for: device,
            from: sourcePath,
            to: url.path
        ) {
            if count > 0 {
                syncedPhotoCount = count
                destinationFolder = url.path
                showSuccessAlert = true
            } else {
                adbService.error = "All photos already exist in destination folder. Nothing to sync."
            }
        }
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

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Folder Browser

struct FolderBrowserView: View {
    @ObservedObject var adbService: ADBService
    let device: Device
    @Binding var selectedPath: String?
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPath: String = "/sdcard/"
    @State private var folders: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pathHistory: [String] = ["/sdcard/"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Browse Device Folders")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(pathHistory.count <= 1)
                
                Text(currentPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding()
            
            Divider()
            
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(folders, id: \.self) { folder in
                            FolderRow(folderName: folder) {
                                navigateInto(folder: folder)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Selected: \(currentPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Select This Folder") {
                    selectedPath = currentPath
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 500, height: 400)
        .task {
            await loadFolders()
        }
    }
    
    private func loadFolders() async {
        isLoading = true
        errorMessage = nil
        
        do {
            folders = try await adbService.listFolders(for: device, at: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func navigateInto(folder: String) {
        var newPath = (currentPath as NSString).appendingPathComponent(folder)
        if !newPath.hasSuffix("/") {
            newPath += "/"
        }
        
        pathHistory.append(currentPath)
        currentPath = newPath
        
        Task {
            await loadFolders()
        }
    }
    
    private func goBack() {
        guard pathHistory.count > 1 else { return }
        currentPath = pathHistory.removeLast()
        
        Task {
            await loadFolders()
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folderName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(folderName)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
