//
//  ADBService.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation
import XPCLibrary

enum ADBServiceError: LocalizedError {
    case noConnection
    case serviceUnavailable
    case xpcError(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "XPC connection not established"
        case .serviceUnavailable:
            return "Could not connect to XPC service"
        case .xpcError(let message):
            return message
        }
    }
}

// VIEWMODEL: Manages device state and communicates with XPC
@MainActor
class ADBService: ObservableObject {
    
    // REACTIVE: Auto-update SwiftUI views
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isMonitoring = false
    @Published var isSyncing = false
    @Published var syncProgress: String?
    
    
    
    private var connection: NSXPCConnection?
    private var pollingTask: Task<Void, Never>?
    private var syncProgressTask: Task<Void, Never>?
    private var syncProgressCurrent = 0
    
    init() {
        setupConnection()
    }
    
    // MARK: - XPC Connection Setup
    
    private func setupConnection() {
        let connection = NSXPCConnection(serviceName: "com.rrft.ADBServiceXPC")
        
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        
        // SECURITY: Register safe classes for deserialization
        let allowedClasses = NSSet(array: [NSArray.self, Device.self]) as! Set<AnyHashable>
        interface.setClasses(
            allowedClasses,
            for: #selector(ADBServiceProtocol.listDevices(completion:)),
            argumentIndex: 0,
            ofReply: true
        )
        
        connection.remoteObjectInterface = interface
        connection.resume()
        self.connection = connection
    }
    
    // MARK: - Public API (Async/Await Only)
    
    // MONITORING: Start continuous device checking
    func startMonitoring() {
        isMonitoring = true
        
        guard let service = getService() else {
            error = "Service unavailable"
            return
        }
        
        // Tell XPC to start polling
        service.startMonitoring()
        
        // UI refresh loop (reads cached data from XPC)
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshDevices(showLoading: false)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    // MONITORING: Stop device checking
    func stopMonitoring() {
        pollingTask?.cancel()
        isMonitoring = false
        
        guard let service = getService() else { return }
        service.stopMonitoring()
    }
    
    // FETCH: Get current device list from XPC
    func refreshDevices(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        error = nil
        
        do {
            // Pure async/await call
            let fetchedDevices = try await listDevices()
            self.devices = fetchedDevices
        } catch {
            self.error = error.localizedDescription
        }
        
        if showLoading {
            isLoading = false
        }
    }
    
    // DETAIL: Fetch device info on-demand
    func fetchDeviceDetails(for device: Device) async {
        do {
            let detailedDevice = try await getDeviceDetails(deviceId: device.id)
            
            // Update device in array
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = detailedDevice
            }
        } catch {
            // Silent failure - details are optional
            print("Failed to fetch details for \(device.id): \(error)")
        }
    }
    
    // SYNC: Sync photos from device to Mac folder
    func syncPhotos(
        for device: Device,
        from sourcePath: String,
        to destinationPath: String
    ) async -> Int? {
        isSyncing = true
        syncProgress = "Starting sync..."
        error = nil
        
        stopMonitoring()  // Stop monitoring during sync
        startSyncProgressPolling()
        
        do {
            let count = try await syncPhotosInternal(
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
            startMonitoring()  // Restart monitoring on success
            return count
            
        } catch {
            // Get partial count if available
            let partialCount = syncProgressCurrent
            
            // Show detailed error with partial progress
            if partialCount > 0 {
                self.error = "\(error.localizedDescription)\n\nPartial sync: \(partialCount) photos were successfully copied before disconnection."
            } else {
                self.error = error.localizedDescription
            }
            
            syncProgress = nil
            stopSyncProgressPolling()
            isSyncing = false
            
            // DON'T restart monitoring on error
            // Let user dismiss error to trigger refresh
            
            return partialCount > 0 ? partialCount : nil
        }
    }




    
    
    
    // BROWSE: List folders on device
    func listFolders(for device: Device, at path: String) async throws -> [String] {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.listFolders(
                deviceId: device.id,
                path: path,
                completion: { folders, error in
                    Task { @MainActor in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let folders = folders {
                            continuation.resume(returning: folders)
                        } else {
                            continuation.resume(throwing: ADBServiceError.xpcError("No folders returned"))
                        }
                    }
                }
            )
        }
    }


    
    // WRAPPER: Convert XPC callback to async/await
    private func syncPhotosInternal(
        deviceId: String,
        sourcePath: String,
        destinationPath: String
    ) async throws -> Int {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.startPhotoSync(
                deviceId: deviceId,
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                completion: { (count: NSNumber?, error: Error?) in
                    Task { @MainActor in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let count = count {
                            continuation.resume(returning: count.intValue)  // ← Convert to Int
                        } else {
                            continuation.resume(throwing: ADBServiceError.xpcError("No count returned"))
                        }
                    }
                }
            )
        }
    }






    
    // MARK: - Private Async Wrappers (Hide Callbacks)
    
    // WRAPPER: Convert callback-based listDevices to async/await
    private func listDevices() async throws -> [Device] {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.listDevices { devices, error in
                if let error = error {
                    continuation.resume(throwing: ADBServiceError.xpcError(error.localizedDescription))
                } else if let devices = devices {
                    continuation.resume(returning: devices)
                } else {
                    continuation.resume(throwing: ADBServiceError.xpcError("No data returned"))
                }
            }
        }
    }
    
    // WRAPPER: Convert callback-based getDeviceDetails to async/await
    private func getDeviceDetails(deviceId: String) async throws -> Device {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.getDeviceDetails(deviceId: deviceId) { device, error in
                if let error = error {
                    continuation.resume(throwing: ADBServiceError.xpcError(error.localizedDescription))
                } else if let device = device {
                    continuation.resume(returning: device)
                } else {
                    continuation.resume(throwing: ADBServiceError.xpcError("No data returned"))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // HELPER: Get service proxy (simple)
    private func getService() -> ADBServiceProtocol? {
        guard let connection = connection else { return nil }
        return connection.remoteObjectProxy as? ADBServiceProtocol
    }
    
    // HELPER: Get service proxy with error handler
    private func getServiceWithErrorHandler() -> ADBServiceProtocol? {
        guard let connection = connection else { return nil }
        
        let service = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            Task { @MainActor in
                self?.error = error.localizedDescription
            }
        } as? ADBServiceProtocol
        
        return service
    }
    
    private func startSyncProgressPolling() {
        syncProgressTask?.cancel()
        
        syncProgressTask = Task {
            while !Task.isCancelled {
                await updateSyncProgress()
                try? await Task.sleep(for: .milliseconds(500))  // Poll every 0.5s
            }
        }
    }

    private func stopSyncProgressPolling() {
        syncProgressTask?.cancel()
        syncProgressTask = nil
    }

    private func updateSyncProgress() async {
        guard let service = getService() else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.getPhotoSyncProgress { [weak self] current, total in
                Task { @MainActor in
                    if total > 0 {
                        self?.syncProgress = "Syncing \(current)/\(total) photos..."
                    }
                    continuation.resume()
                }
            }
        }
    }

    
    // CLEANUP: Cancel tasks and invalidate connection
    deinit {
        pollingTask?.cancel()
        connection?.invalidate()
    }
}
