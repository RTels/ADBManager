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
            self.error = "No XPC connection."
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
            self.error = "Could not connect to XPC service."
            self.isLoading = false
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.listDevices { [weak self] devices, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let error = error {
                        self.error = error.localizedDescription
                    } else if let devices = devices {
                        self.devices = devices
                    }
                    
                    if showLoading {
                        self.isLoading = false
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    deinit {
        pollingTask?.cancel()
        connection?.invalidate()
    }
}

