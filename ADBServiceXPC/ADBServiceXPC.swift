
//
//  Created by rrft on 02/10/25.
//

import Foundation

class adbXPCService: NSObject, ADBServiceProtocol {
    
    func listDevices(completion: @escaping ([AndroidDevice]?, Error?) -> Void) {
        Task {
            do {
                let devices = try await performListDevices()
                completion(devices, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    private func performListDevices() async throws -> [AndroidDevice] {
        // Get the adb executable path from bundle
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        // Create process to run adb
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["devices"]
        
        // Capture output
        let pipe = Pipe()
        process.standardOutput = pipe
        
        // Run the process
        try process.run()
        process.waitUntilExit()
        
        // Read output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        // Parse the output
        return parseADBOutput(output)
    }
    
    private func parseADBOutput(_ output: String) -> [AndroidDevice] {
        let lines = output.components(separatedBy: .newlines)
        var devices: [AndroidDevice] = []
        
        for line in lines {
            if line.isEmpty || line.contains("List of devices") {
                continue
            }
            
            let components = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            if components.count >= 2 {
                let device = AndroidDevice(id: components[0], stateString: components[1])
                devices.append(device)
            }
        }
        
        return devices
    }
}

enum ADBError: Error {
    case adbNotFound
    case invalidOutput
}


/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "com.rrft.ADBManager.adbXPCService")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: (any adbXPCServiceProtocol).self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? adbXPCServiceProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
