//
//  ContentView.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct ContentView: View {
    @StateObject private var adbService = ADBService()
    @State private var selectedDevice: Device?
    
    var body: some View {
        NavigationSplitView {
            DeviceSidebarView(
                adbService: adbService,
                selectedDevice: $selectedDevice
            )
        } detail: {
            DeviceDetailView(
                adbService: adbService,
                deviceId: selectedDevice?.id
            )
            .frame(minWidth: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            Task {
                await adbService.refreshDevices()
                adbService.startMonitoring()
            }
        }
    }
}

#Preview {
    ContentView()
}
