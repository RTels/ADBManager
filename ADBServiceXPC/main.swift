//
//  main.swift
//  adbXPCService
//
//  Created by rrft on 02/10/25.
//

import Foundation
import XPCLibrary

let delegate = ADBXPCService()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

extension ADBXPCService: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(with: ADBServiceProtocol.self)
        
        // Register allowed classes for decoding
        let allowedClasses = NSSet(array: [NSArray.self, Device.self]) as! Set<AnyHashable>
        interface.setClasses(allowedClasses, for: #selector(ADBServiceProtocol.listDevices(completion:)), argumentIndex: 0, ofReply: true)
        
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
