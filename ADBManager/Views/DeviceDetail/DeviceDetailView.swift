//
//  DeviceDetailView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//


import SwiftUI
import XPCLibrary
import AppKit

struct DeviceDetailView: View {
    @ObservedObject var adbService: ADBService
    let deviceId: String?
    
    @State private var isLoadingDetails = false
    @State private var selectedSourcePath: String? = "/sdcard/DCIM/Camera/"
    @State private var showFolderBrowser = false
    @State private var showSuccessAlert = false
    @State private var syncedPhotoCount = 0
    @State private var destinationFolder: String?
    @State private var lastKnownDevice: Device?
    
    private var device: Device? {
        guard let deviceId = deviceId else { return nil }
        
        if adbService.needsReconnection, let last = lastKnownDevice {
            return last
        }
        return adbService.devices.first(where: { $0.id == deviceId })
    }
    
    var body: some View {
        Group {
            if let device = device {
                deviceContent(device: device)
                    .onChange(of: device) {
                        if !adbService.needsReconnection {
                            lastKnownDevice = device
                        }
                    }
            } else {
                placeholderView
            }
        }
        .onAppear {
            if let deviceId = deviceId,
               let currentDevice = adbService.devices.first(where: { $0.id == deviceId }) {
                lastKnownDevice = currentDevice
            }
        }
    }
    
    @ViewBuilder
    private func deviceContent(device: Device) -> some View {
        ZStack {
            VStack(spacing: 0) {
                if let error = adbService.error, !adbService.needsReconnection {
                    ErrorBanner(message: error) {
                        adbService.error = nil
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        DeviceHeaderView(device: device)
                        Divider()
                        
                        if isLoadingDetails {
                            ProgressView("Loading device details...")
                        } else {
                            DeviceInfoView(device: device)
                        }
                        
                        Divider()
                        
                        PhotoSyncView(
                            device: device,
                            adbService: adbService,
                            selectedSourcePath: $selectedSourcePath,
                            showFolderBrowser: $showFolderBrowser,
                            destinationFolder: $destinationFolder,
                            onSyncComplete: { count in
                                syncedPhotoCount = count
                                showSuccessAlert = true
                            }
                        )
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .disabled(adbService.needsReconnection)
            .blur(radius: adbService.needsReconnection ? 3 : 0)
            
            if adbService.needsReconnection {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ReconnectionPanel(
                    adbService: adbService,
                    device: device,
                    sourcePath: selectedSourcePath ?? "/sdcard/DCIM/Camera/",
                    destinationPath: destinationFolder ?? ""
                ) {
                    await handleResumeSync(device: device)
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .task(id: device.id) {
            if device.model == nil && device.state == .device {
                isLoadingDetails = true
                await adbService.fetchDeviceDetails(for: device)
                isLoadingDetails = false
            }
        }
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
    
    private func handleResumeSync(device: Device) async {
        if let count = await adbService.resumeSync(
            for: device,
            from: selectedSourcePath ?? "/sdcard/DCIM/Camera/",
            to: destinationFolder ?? ""
        ) {
            if count > 0 && !adbService.needsReconnection {
                syncedPhotoCount = count
                showSuccessAlert = true
            }
        }
    }
}

#Preview {
    DeviceDetailView(
        adbService: ADBService(),
        deviceId: "test123"
    )
}
