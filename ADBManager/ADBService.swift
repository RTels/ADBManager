//
//  ADBService.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation

// THREAD: All properties/methods run on main thread (UI-safe)
@MainActor
class ADBService: ObservableObject {
    
    // REACTIVE: Changes auto-update SwiftUI views
    @Published var devices: [AndroidDevice] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isMonitoring = false
    
    // XPC: Bridge to separate process
    private var connection: NSXPCConnection?
    
    // POLLING: Background task that runs every 2s
    private var pollingTask: Task<Void, Never>?
    
    init() {
        setupConnection()
    }
    
    // XPC: Establish connection to worker process
    private func setupConnection() {
        // TARGET: Match bundle identifier from Info.plist
        let connection = NSXPCConnection(serviceName: "com.rrft.ADBServiceXPC")
        
        // CONTRACT: Define allowed operations
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        
        // SECURITY: Register safe classes for deserialization (research: XPC class allowlist)
        let allowedClasses = NSSet(array: [NSArray.self, AndroidDevice.self]) as! Set<AnyHashable>
        interface.setClasses(
            allowedClasses,
            for: #selector(ADBServiceProtocol.listDevices(completion:)),
            argumentIndex: 0,  // First param of completion handler
            ofReply: true      // In the reply, not request
        )
        
        connection.remoteObjectInterface = interface
        connection.resume()  // Activate connection
        self.connection = connection
    }
    
    // POLLING: Start continuous device checking
    func startMonitoring() {
        pollingTask?.cancel()  // Cancel previous if exists
        isMonitoring = true
        
        // TASK: Concurrent work (research: Swift Concurrency Task)
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshDevices(showLoading: false)  // Silent refresh
                try? await Task.sleep(for: .seconds(2))   // 2s interval
            }
        }
    }
    
    func stopMonitoring() {
        pollingTask?.cancel()
        isMonitoring = false
    }
    
    // FETCH: Get current device list from XPC
    func refreshDevices(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        error = nil
        
        guard let connection = connection else {
            self.error = "No XPC connection"
            self.isLoading = false
            return
        }
        
        // PROXY: Get reference to remote object (in other process)
        // MEMORY: weak self prevents retain cycle (research: closure capture)
        let service = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
            // ACTOR: Jump back to main thread for UI update
            Task { @MainActor in
                self?.error = error.localizedDescription
                self?.isLoading = false
            }
        }) as? ADBServiceProtocol
        
        guard let service = service else {
            self.error = "Could not connect to XPC service"
            self.isLoading = false
            return
        }
        
        // BRIDGE: Convert callback → async/await (research: withCheckedContinuation)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.listDevices { [weak self] newDevices, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()  // CRITICAL: Always resume
                        return
                    }
                    
                    if let error = error {
                        self.error = error.localizedDescription
                    } else if let newDevices = newDevices {
                        // PRESERVE: Don't lose fetched details on refresh
                        let updatedDevices = newDevices.map { newDevice -> AndroidDevice in
                            // MERGE: Copy details from existing device to new one
                            if let existingDevice = self.devices.first(where: { $0.id == newDevice.id }),
                               existingDevice.model != nil {
                                // TRANSFER: Move fetched data to refreshed device
                                newDevice.model = existingDevice.model
                                newDevice.manufacturer = existingDevice.manufacturer
                                newDevice.androidVersion = existingDevice.androidVersion
                                newDevice.batteryLevel = existingDevice.batteryLevel
                                newDevice.apiLevel = existingDevice.apiLevel
                            }
                            return newDevice
                        }
                        
                        self.devices = updatedDevices
                    }
                    
                    if showLoading {
                        self.isLoading = false
                    }
                    continuation.resume()  // CRITICAL: Signal completion
                }
            }
        }
    }
    
    // DETAIL: Fetch expensive device info on-demand
    func fetchDeviceDetails(for device: AndroidDevice) async {
        guard let connection = connection else {
            return
        }
        
        let service = connection.remoteObjectProxyWithErrorHandler({ error in
        }) as? ADBServiceProtocol
        
        guard let service = service else {
            return
        }
        
        // BRIDGE: Callback → async/await pattern
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.getDeviceDetails(deviceId: device.id) { [weak self] detailedDevice, error in
                
                if let detailedDevice = detailedDevice {
                    // ACTOR: Return to main thread for array mutation
                    Task { @MainActor in
                        // UPDATE: Replace device in array with detailed version
                        if let index = self?.devices.firstIndex(where: { $0.id == device.id }) {
                            self?.devices[index] = detailedDevice
                        }
                        continuation.resume()  // CRITICAL: Always resume
                    }
                } else {
                    continuation.resume()  // CRITICAL: Resume even on failure
                }
            }
        }
    }
    
    // CLEANUP: Cancel ongoing work when service is destroyed
    deinit {
        pollingTask?.cancel()
        connection?.invalidate()
    }
}
