//
//  ADBService.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation
import XPCLibrary

// ERRORS: Service-specific errors
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
    
    // XPC: Bridge to separate process
    private var connection: NSXPCConnection?
    
    // POLLING: Background task for UI updates
    private var pollingTask: Task<Void, Never>?
    
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
    
    // CLEANUP: Cancel tasks and invalidate connection
    deinit {
        pollingTask?.cancel()
        connection?.invalidate()
    }
}
