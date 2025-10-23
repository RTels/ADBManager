
//
//  ADBServiceImplementation.swift
//  XPCLibrary
//
//  Reference implementation of ADBServiceProtocol
//

import Foundation

// PUBLIC: Full implementation that users can use directly
public class ADBServiceImplementation: NSObject, ADBServiceProtocol {
    
    // CACHE: Store latest device list with details
    private var cachedDevices: [Device] = []
    private var pollingTask: Task<Void, Never>?
    private let cacheLock = NSLock()
    private var cachedADBPath: String?
    
    // PUBLIC: Must have public initializer
    public override init() {
        super.init()
    }
    
    // MARK: - Protocol Implementation
    
    public func startMonitoring() {
        pollingTask?.cancel()
        
        pollingTask = Task {
            while !Task.isCancelled {
                await pollDevices()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    public func listDevices(completion: @escaping ([Device]?, Error?) -> Void) {
        let devices = getCache()
        completion(devices, nil)
    }
    
    public func getDeviceDetails(deviceId: String, completion: @escaping (Device?, Error?) -> Void) {
        Task {
            do {
                let device = try await fetchDeviceDetails(deviceId: deviceId)
                completion(device, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func pollDevices() async {
        do {
            let devices = try await performListDevices()
            updateCache(devices)
        } catch {
            print("⚠️ Polling failed: \(error)")
        }
    }
    
    private func getADBPath() throws -> String {
        if let cached = cachedADBPath {
            return cached
        }
        
        let path = try ADBUtilities.getADBPath()
        cachedADBPath = path
        return path
    }
    
    private func performListDevices() async throws -> [Device] {
        let adbPath = try getADBPath()
        
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
                    print("⚠️ Failed to fetch details for \(device.id): \(error)")
                    detailedDevices.append(device)
                }
            } else {
                detailedDevices.append(device)
            }
        }
        
        return detailedDevices
    }
    
    private func fetchDeviceDetails(deviceId: String) async throws -> Device {
        let adbPath = try getADBPath()
        
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
    
    private func updateCache(_ devices: [Device]) {
        cacheLock.lock()
        cachedDevices = devices
        cacheLock.unlock()
    }
    
    private func getCache() -> [Device] {
        cacheLock.lock()
        let devices = cachedDevices
        cacheLock.unlock()
        return devices
    }
}

