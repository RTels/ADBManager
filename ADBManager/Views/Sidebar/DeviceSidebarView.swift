//
//  DeviceSidebarView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI
import XPCLibrary

struct DeviceSidebarView: View {
    @ObservedObject var adbService: ADBService
    @Binding var selectedDevice: Device?
    
    var body: some View {
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
}

#Preview {
    DeviceSidebarView(
        adbService: ADBService(),
        selectedDevice: .constant(nil)
    )
}
