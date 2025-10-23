//
//  ADBXPCService.swift
//  ADBServiceXPC
//
//  Created by rrft on 02/10/25.
//

import Foundation
import XPCLibrary

class ADBXPCService: NSObject, ADBServiceProtocol {
    
    private var cachedDevices: [Device] = []
    private var pollingTask: Task<Void, Never>?
    private let cacheLock = NSLock()
    
    func startMonitoring() {
        pollingTask?.cancel()
        
        pollingTask = Task {
            while !Task.isCancelled {
                if let devices = try? await performListDevices() {
                    updateCache(devices)
                } else {
                    print("XPC: Failed to fetch device list")
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // return cached device list (instant)
    func listDevices(completion: @escaping ([Device]?, Error?) -> Void) {
        let devices = getCache()
        completion(devices, nil)
    }
    
    // get detailed info for specific device (on-demand)
    func getDeviceDetails(deviceId: String, completion: @escaping (Device?, Error?) -> Void) {
        Task {
            do {
                let device = try await fetchDeviceDetails(deviceId: deviceId)
                completion(device, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    private func performListDevices() async throws -> [Device] {
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
        
        let basicDevices = parseADBOutput(output)
        var detailedDevices: [Device] = []
        
        for device in basicDevices {
            if device.state == .device {
                do {
                    let detailed = try await fetchDeviceDetails(deviceId: device.id)
                    detailedDevices.append(detailed)
                } catch {
                    print("XPC: Failed to fetch details for \(device.id): \(error)")
                    detailedDevices.append(device)
                }
            } else {
                detailedDevices.append(device)
            }
        }
        
        return detailedDevices
    }
    
    // fetch all properties for a specific device
    private func fetchDeviceDetails(deviceId: String) async throws -> Device {
        guard let adbPath = Bundle.main.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        let device = Device(id: deviceId, stateString: "device")
        
        device.model = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.model"]
        )
    
        device.manufacturer = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.manufacturer"]
        )
        
        device.androidVersion = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.release"]
        )
        
        device.apiLevel = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.sdk"]
        )
        
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
    
    // run single ADB command
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
    
    // extract battery percentage from dumpsys output
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
    
    // convert 'adb devices' output to Device objects
    private func parseADBOutput(_ output: String) -> [Device] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> Device? in
                guard !line.isEmpty,
                      !line.contains("List of devices") else {
                    return nil
                }
                
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                guard components.count >= 2 else {
                    return nil
                }
                
                return Device(id: components[0], stateString: components[1])
            }
    }
    
    // CACHE: Thread-safe write
    private func updateCache(_ devices: [Device]) {
        cacheLock.lock()
        cachedDevices = devices
        cacheLock.unlock()
    }
    
    // CACHE: Thread-safe read
    private func getCache() -> [Device] {
        cacheLock.lock()
        let devices = cachedDevices
        cacheLock.unlock()
        return devices
    }
}

// ERRORS: Custom error types for ADB operations
enum ADBError: Error {
    case adbNotFound      // adb executable not in bundle
    case invalidOutput    // Command output couldn't be decoded
}
