//
//  ReconnectionView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI
import XPCLibrary

struct ReconnectionPanel: View {
    @ObservedObject var adbService: ADBService
    let device: Device
    let sourcePath: String
    let destinationPath: String
    let onResume: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Title
            Text("Device Disconnected")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Partial sync info
            if let count = adbService.partialSyncCount, count > 0 {
                Text("\(count) photo\(count == 1 ? "" : "s") synced before disconnection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Reconnection status
            HStack(spacing: 12) {
                if adbService.deviceReconnected {
                    // Success checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Device Reconnected")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else if adbService.isReconnecting {
                    // Loading animation
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Waiting for device...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "cable.connector")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Please reconnect your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 44)
            
            Divider()
                .padding(.vertical, 8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    adbService.needsReconnection = false
                    adbService.isReconnecting = false
                    adbService.deviceReconnected = false
                    adbService.partialSyncCount = nil
                    adbService.disconnectedDeviceId = nil
                }
                .buttonStyle(.bordered)
                
                Button("Resume Sync") {
                    Task {
                        await onResume()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!adbService.deviceReconnected)
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

