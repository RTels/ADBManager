//
//  XPCServiceMain.swift
//  XPCLibrary
//

import Foundation

/// Main entry point for ADB XPC Service
/// Handles all listener and connection setup
public final class ADBServiceMain: NSObject, NSXPCListenerDelegate {
    
    private let listener: NSXPCListener
    private let implementation: ADBServiceImplementation
    
    private init(listener: NSXPCListener) {
        self.listener = listener
        self.implementation = ADBServiceImplementation()
        super.init()
    }
    
    public static func run() {
        let listener = NSXPCListener.service()
        let main = ADBServiceMain(listener: listener)
        listener.delegate = main
        listener.resume()
        RunLoop.main.run()
    }
    
    
    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        
        let allowedClasses = NSSet(array: [NSArray.self, Device.self]) as! Set<AnyHashable>
        interface.setClasses(
            allowedClasses,
            for: #selector(ADBServiceProtocol.listDevices(completion:)),
            argumentIndex: 0,
            ofReply: true
        )
        
        newConnection.exportedInterface = interface
        newConnection.exportedObject = implementation
        newConnection.resume()
        
        return true
    }
}
