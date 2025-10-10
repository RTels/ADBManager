//
//  ADBService.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation

@MainActor
class ADBService: ObservableObject {
    
    @Published var devices: [AndroidDevice] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isMonitoring = false
    
    private var connection: NSXPCConnection?
    private var pollingTask: Task<Void, Never>?
    
    init() {
        setupConnection()
    }
    
    private func setupConnection() {
        let connection = NSXPCConnection(serviceName: "com.rrft.ADBServiceXPC")
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        let allowedClasses = NSSet(array: [NSArray.self, AndroidDevice.self]) as! Set<AnyHashable>
        interface.setClasses(allowedClasses, for: #selector(ADBServiceProtocol.listDevices(completion:)), argumentIndex: 0, ofReply: true)
        connection.remoteObjectInterface = interface
        connection.resume()
        self.connection = connection
    }
    
    func startMonitoring() {
        pollingTask?.cancel()
        isMonitoring = true
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
    }
    
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
        
        let service = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
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
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.listDevices { [weak self] newDevices, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let error = error {
                        self.error = error.localizedDescription
                    } else if let newDevices = newDevices {
                        // Preserve details from existing devices
                        let updatedDevices = newDevices.map { newDevice -> AndroidDevice in
                            // Find if we already have this device with details
                            if let existingDevice = self.devices.first(where: { $0.id == newDevice.id }),
                               existingDevice.model != nil {
                                // Copy details to new device
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
                    continuation.resume()
                }
            }
        }
    }

    

    func fetchDeviceDetails(for device: AndroidDevice) async {
        print("📡 ADBService: Starting fetch for device \(device.id)")
        
        guard let connection = connection else {
            print("❌ ADBService: No connection!")
            return
        }
        
        print("📡 ADBService: Getting service proxy...")
        let service = connection.remoteObjectProxyWithErrorHandler({ error in
            print("❌ ADBService: Proxy error: \(error)")
        }) as? ADBServiceProtocol
        
        guard let service = service else {
            print("❌ ADBService: Could not cast to protocol!")
            return
        }
        
        print("📡 ADBService: Calling getDeviceDetails via XPC...")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.getDeviceDetails(deviceId: device.id) { [weak self] detailedDevice, error in
                print("📡 ADBService: Got XPC response")
                
                if let error = error {
                    print("❌ ADBService: Error from XPC: \(error)")
                }
                
                if let detailedDevice = detailedDevice {
                    print("✅ ADBService: Got detailed device!")
                    print("   - Model: \(detailedDevice.model ?? "nil")")
                    print("   - Manufacturer: \(detailedDevice.manufacturer ?? "nil")")
                    print("   - Android: \(detailedDevice.androidVersion ?? "nil")")
                    
                    Task { @MainActor in
                        if let index = self?.devices.firstIndex(where: { $0.id == device.id }) {
                            print("✅ ADBService: Updating device at index \(index)")
                            self?.devices[index] = detailedDevice
                        } else {
                            print("❌ ADBService: Could not find device in array!")
                        }
                        continuation.resume()
                    }
                } else {
                    print("❌ ADBService: detailedDevice is nil!")
                    continuation.resume()
                }
            }
        }
        
        print("📡 ADBService: fetchDeviceDetails completed")
    }



    
    deinit {
        pollingTask?.cancel()
        connection?.invalidate()
    }
}

