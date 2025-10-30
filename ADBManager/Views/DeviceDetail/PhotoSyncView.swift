//
//  PhotoSyncView.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary
import AppKit

struct PhotoSyncView: View {
    let device: Device
    @ObservedObject var adbService: ADBService
    
    @Binding var selectedSourcePath: String?
    @Binding var showFolderBrowser: Bool
    @Binding var destinationFolder: String?
    
    let onSyncComplete: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photo Sync")
                .font(.headline)
            
            if adbService.isSyncing {
                syncingView
            } else {
                syncConfigView
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var syncingView: some View {
        VStack(spacing: 16) {
            if let progress = adbService.syncProgress {
                Text(progress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if adbService.syncTotalCount > 0 {
                ProgressView(value: Double(adbService.syncCurrentCount), total: Double(adbService.syncTotalCount))
                    .progressViewStyle(.linear)
                    .tint(.gray)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        
            if !adbService.syncCurrentPhoto.isEmpty {
                VStack(spacing: 8) {
                    Text("Current:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(adbService.syncCurrentPhoto)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var syncConfigView: some View {
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
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await handleSyncPhotos()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Sync Photos to Mac")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(device.state != .device)
                
                Text("Syncs all photos from selected folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func handleSyncPhotos() async {
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
            return
        }
        
        destinationFolder = url.path
        
        if let count = await adbService.syncPhotos(
            for: device,
            from: sourcePath,
            to: url.path
        ) {
            if count > 0 && !adbService.needsReconnection {
                onSyncComplete(count)
            } else if count == 0 {
                adbService.error = "All photos already exist in destination folder. Nothing to sync."
            }
        }
    }
}

#Preview("Ready to Sync") {
    PhotoSyncView(
        device: {
            let device = Device(id: "ABC123", stateString: "device")
            device.model = "Pixel 6 Pro"
            return device
        }(),
        adbService: {
            let service = ADBService()
            service.isMonitoring = true
            return service
        }(),
        selectedSourcePath: .constant("/sdcard/DCIM/Camera/"),
        showFolderBrowser: .constant(false),
        destinationFolder: .constant(nil),
        onSyncComplete: { _ in }
    )
    .padding()
    .frame(width: 500)
}

#Preview("Syncing") {
    PhotoSyncView(
        device: {
            let device = Device(id: "ABC123", stateString: "device")
            device.model = "Pixel 6 Pro"
            return device
        }(),
        adbService: {
            let service = ADBService()
            service.isSyncing = true
            service.syncProgress = "Syncing 42/100 photos..."
            service.syncCurrentCount = 42
            service.syncTotalCount = 100
            service.syncCurrentPhoto = "Syncing: IMG_20250115_143022.jpg"
            return service
        }(),
        selectedSourcePath: .constant("/sdcard/DCIM/Camera/"),
        showFolderBrowser: .constant(false),
        destinationFolder: .constant(nil),
        onSyncComplete: { _ in }
    )
    .padding()
    .frame(width: 500)
}
