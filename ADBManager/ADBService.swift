//
//  ADBService.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//


//
//  ADBService.swift
//  ADBManager
//

import Foundation
import XPCLibrary

/// ViewModel: Manages UI state and orchestrates XPC client
@MainActor
class ADBService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isMonitoring = false
    @Published var isSyncing = false
    @Published var syncProgress: String?
    
    // Reconnection state
    @Published var needsReconnection = false
    @Published var isReconnecting = false
    @Published var deviceReconnected = false
    @Published var deviceConfirmedGone = false
    @Published var partialSyncCount: Int?
    @Published var disconnectedDeviceId: String?
    
    // MARK: - Dependencies
    
    private let client: ADBServiceClient
    private var pollingTask: Task<Void, Never>?
    private var syncProgressTask: Task<Void, Never>?
    private var syncProgressCurrent = 0
    
    init(client: ADBServiceClient = ADBServiceClient()) {
        self.client = client
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        isMonitoring = true
        client.startMonitoring()
        
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshDevices(showLoading: false)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    func stopMonitoring() {
        pollingTask?.cancel()
        isMonitoring = false
        client.stopMonitoring()
    }
    
    // MARK: - Device Operations
    
    func refreshDevices(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        
        do {
            let fetchedDevices = try await client.listDevices()
            self.devices = fetchedDevices
            
            // Check reconnection state
            if isReconnecting, let deviceId = disconnectedDeviceId {
                let deviceExists = fetchedDevices.contains(where: { $0.id == deviceId && $0.state == .device })
                
                if !deviceExists {
                    deviceConfirmedGone = true
                } else if deviceConfirmedGone && deviceExists {
                    deviceReconnected = true
                    isReconnecting = false
                }
            }
            
        } catch {
            if !needsReconnection {
                self.error = error.localizedDescription
            }
        }
        
        if showLoading {
            isLoading = false
        }
    }
    
    func fetchDeviceDetails(for device: Device) async {
        do {
            let detailedDevice = try await client.getDeviceDetails(deviceId: device.id)
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = detailedDevice
            }
        } catch {
            print("Failed to fetch details for \(device.id): \(error)")
        }
    }
    
    // MARK: - Folder Operations
    
    func listFolders(for device: Device, at path: String) async throws -> [String] {
        return try await client.listFolders(deviceId: device.id, path: path)
    }
    
    // MARK: - Photo Sync
    
    func syncPhotos(
        for device: Device,
        from sourcePath: String,
        to destinationPath: String
    ) async -> Int? {
        isSyncing = true
        syncProgress = "Starting sync..."
        error = nil
        
        stopMonitoring()
        startSyncProgressPolling()
        
        do {
            let count = try await client.startPhotoSync(
                deviceId: device.id,
                sourcePath: sourcePath,
                destinationPath: destinationPath
            )
            
            syncProgress = "Sync complete!"
            
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if syncProgress == "Sync complete!" {
                        syncProgress = nil
                    }
                }
            }
            
            stopSyncProgressPolling()
            isSyncing = false
            startMonitoring()
            return count
            
        } catch {
            let partialCount = syncProgressCurrent
            
            syncProgress = nil
            stopSyncProgressPolling()
            isSyncing = false
            
            // Set reconnection state
            needsReconnection = true
            isReconnecting = true
            deviceConfirmedGone = false
            partialSyncCount = partialCount > 0 ? partialCount : nil
            disconnectedDeviceId = device.id
            self.error = error.localizedDescription
            
            startMonitoring()
            
            return partialCount > 0 ? partialCount : nil
        }
    }
    
    func resumeSync(
        for device: Device,
        from sourcePath: String,
        to destinationPath: String
    ) async -> Int? {
        // Reset reconnection state
        needsReconnection = false
        isReconnecting = false
        deviceReconnected = false
        disconnectedDeviceId = nil
        
        return await syncPhotos(for: device, from: sourcePath, to: destinationPath)
    }
    
    // MARK: - Progress Tracking
    
    private func startSyncProgressPolling() {
        syncProgressTask?.cancel()
        
        syncProgressTask = Task {
            while !Task.isCancelled {
                await updateSyncProgress()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    private func stopSyncProgressPolling() {
        syncProgressTask?.cancel()
        syncProgressTask = nil
    }
    
    private func updateSyncProgress() async {
        let progress = await client.getPhotoSyncProgress()
        
        if progress.total > 0 {
            syncProgress = "Syncing \(progress.current)/\(progress.total) photos..."
        }
        syncProgressCurrent = progress.current
    }
    
    // MARK: - Cleanup
    
    deinit {
        pollingTask?.cancel()
        client.invalidate()
    }
}
