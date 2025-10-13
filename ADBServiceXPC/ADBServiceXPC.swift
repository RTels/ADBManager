//
//  adbXPCService.swift
//  ADBServiceXPC
//
//  Created by rrft on 02/10/25.
//

import Foundation

// XPC: Implementation of protocol contract (runs in separate process)
class adbXPCService: NSObject, ADBServiceProtocol {
    
    // PROTOCOL: List all connected devices
    func listDevices(completion: @escaping ([AndroidDevice]?, Error?) -> Void) {
        Task {
            do {
                let devices = try await performListDevices()
                completion(devices, nil)  // Success
            } catch {
                completion(nil, error)  // Failure
            }
        }
    }
    
    // PROTOCOL: Get detailed info for specific device
    func getDeviceDetails(deviceId: String, completion: @escaping (AndroidDevice?, Error?) -> Void) {
        Task {
            do {
                let device = try await fetchDeviceDetails(deviceId: deviceId)
                completion(device, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    // EXEC: Run 'adb devices' command
    private func performListDevices() async throws -> [AndroidDevice] {
        // BUNDLE: Get bundled adb executable path
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        // PROCESS: Spawn separate process for adb command (research: Foundation.Process)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["devices"]
        
        // PIPE: Capture command output (research: Foundation.Pipe)
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()  // Block until command completes
        
        // READ: Extract output from pipe
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        return parseADBOutput(output)
    }
    
    // DETAIL: Execute multiple ADB commands to gather device info
    private func fetchDeviceDetails(deviceId: String) async throws -> AndroidDevice {
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        let device = AndroidDevice(id: deviceId, stateString: "device")
        
        // PROPERTY: Fetch device model (e.g., "Pixel 7", "Mi A2")
        device.model = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.model"]
        )
        
        // PROPERTY: Fetch manufacturer (e.g., "Google", "Xiaomi")
        device.manufacturer = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.manufacturer"]
        )
        
        // PROPERTY: Fetch Android version (e.g., "14", "10")
        device.androidVersion = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.release"]
        )
        
        // PROPERTY: Fetch API level (e.g., "34", "29")
        device.apiLevel = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.sdk"]
        )
        
        // BATTERY: Parse battery level from dumpsys output
        if let batteryOutput = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["dumpsys", "battery"]
        ) {
            device.batteryLevel = parseBatteryLevel(from: batteryOutput)
        }
        
        return device
    }
    
    // EXEC: Run single ADB command targeting specific device
    private func runADBCommand(adbPath: String, deviceId: String, command: String, args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        // TARGET: -s flag targets specific device by serial number
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
    
    // PARSE: Extract battery percentage from dumpsys output
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
    
    // PARSE: Convert 'adb devices' output to AndroidDevice objects
    private func parseADBOutput(_ output: String) -> [AndroidDevice] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> AndroidDevice? in
                // FILTER: Skip header and empty lines
                guard !line.isEmpty,
                      !line.contains("List of devices") else {
                    return nil
                }
                
                // SPLIT: Line format is "deviceId\tstate"
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                guard components.count >= 2 else {
                    return nil
                }
                
                // BUILD: Create device from parsed components
                return AndroidDevice(id: components[0], stateString: components[1])
            }
    }
}

// ERRORS: Custom error types for ADB operations
enum ADBError: Error {
    case adbNotFound      // adb executable not in bundle
    case invalidOutput    // Command output couldn't be decoded
}
