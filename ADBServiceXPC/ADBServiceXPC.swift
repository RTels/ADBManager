
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
    
    func getDeviceDetails(deviceId: String, completion: @escaping (AndroidDevice?, Error?) -> Void) {
        print("🔧 XPC: getDeviceDetails called for: \(deviceId)")
        
        Task {
            do {
                print("🔧 XPC: Fetching details...")
                let device = try await fetchDeviceDetails(deviceId: deviceId)
                print("🔧 XPC: Got device details!")
                print("   - Model: \(device.model ?? "nil")")
                print("   - Manufacturer: \(device.manufacturer ?? "nil")")
                completion(device, nil)
            } catch {
                print("❌ XPC: Error fetching details: \(error)")
                completion(nil, error)
            }
        }
    }


    
    private func performListDevices() async throws -> [AndroidDevice] {
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["devices"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        return parseADBOutput(output)
    }
    
    private func fetchDeviceDetails(deviceId: String) async throws -> AndroidDevice {
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        let device = AndroidDevice(id: deviceId, stateString: "device")
        
        // Fetch model
        device.model = try? await runADBCommand(adbPath: adbPath, deviceId: deviceId, command: "shell", args: ["getprop", "ro.product.model"])
        
        // Fetch manufacturer
        device.manufacturer = try? await runADBCommand(adbPath: adbPath, deviceId: deviceId, command: "shell", args: ["getprop", "ro.product.manufacturer"])
        
        // Fetch Android version
        device.androidVersion = try? await runADBCommand(adbPath: adbPath, deviceId: deviceId, command: "shell", args: ["getprop", "ro.build.version.release"])
        
        // Fetch API level
        device.apiLevel = try? await runADBCommand(adbPath: adbPath, deviceId: deviceId, command: "shell", args: ["getprop", "ro.build.version.sdk"])
        
        // Fetch battery (parse from dumpsys)
        if let batteryOutput = try? await runADBCommand(adbPath: adbPath, deviceId: deviceId, command: "shell", args: ["dumpsys", "battery"]) {
            device.batteryLevel = parseBatteryLevel(from: batteryOutput)
        }
        
        return device
    }
    
    private func runADBCommand(adbPath: String, deviceId: String, command: String, args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["-s", deviceId, command] + args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseBatteryLevel(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("level:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces) + "%"
                }
            }
        }
        return nil
    }
    
    private func parseADBOutput(_ output: String) -> [AndroidDevice] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> AndroidDevice? in
                guard !line.isEmpty,
                      !line.contains("List of devices") else {
                    return nil
                }
                
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                guard components.count >= 2 else {
                    return nil
                }
                
                return AndroidDevice(id: components[0], stateString: components[1])
            }
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
