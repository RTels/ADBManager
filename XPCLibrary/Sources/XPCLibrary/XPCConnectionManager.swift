//
//  XPCConnectionManager.swift
//  XPCLibrary
//

import Foundation

/// Manages the XPC connection lifecycle
public final class XPCConnectionManager {
    
    private var connection: NSXPCConnection?
    private let serviceName: String
    
    public init(serviceName: String = "com.rrft.ADBServiceXPC") {
        self.serviceName = serviceName
        setupConnection()
    }
    
    // MARK: - Connection Setup
    
    private func setupConnection() {
        let connection = NSXPCConnection(serviceName: serviceName)
        
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        
        // Register safe classes for Device array deserialization
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
    
    // MARK: - Service Access
    
    /// Get service proxy (simple version)
    public func getService() -> ADBServiceProtocol? {
        guard let connection = connection else { return nil }
        return connection.remoteObjectProxy as? ADBServiceProtocol
    }
    
    /// Get service proxy with error handler
    public func getServiceWithErrorHandler(
        errorHandler: @escaping (Error) -> Void
    ) -> ADBServiceProtocol? {
        guard let connection = connection else { return nil }
        
        let service = connection.remoteObjectProxyWithErrorHandler { error in
            errorHandler(error)
        } as? ADBServiceProtocol
        
        return service
    }
    
    // MARK: - Cleanup
    
    public func invalidate() {
        connection?.invalidate()
        connection = nil
    }
    
    deinit {
        invalidate()
    }
}
