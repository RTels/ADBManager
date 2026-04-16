# ADBManager

A native macOS app for syncing photos from Android devices to your Mac over ADB.

## Features

- **Device Discovery** — Automatically detects connected Android devices and displays model, battery level, Android version, and connection status.
- **Photo Sync** — Recursively syncs photos (JPG, PNG, HEIC, DNG, RAW) from any folder on your Android device to a local destination. Skips duplicates automatically.
- **Resilient Transfers** — Detects mid-sync disconnections, prompts for reconnection, and resumes where it left off.
- **Folder Browser** — Navigate your device's file system to pick the source folder for syncing.
- **Real-time Monitoring** — Continuously polls for device connections and sync progress.

## Architecture

```
ADBManager App  →  ADBServiceClient (async/await)
                        ↓
                   XPCConnectionManager (NSXPCConnection)
                        ↓
                   ADBServiceXPC (XPC service)
                        ↓
                   Bundled adb binary
```

The app communicates with a bundled ADB binary through an XPC service, keeping privileged operations isolated from the main process.

## Requirements

- macOS 15.5 (Sequoia) or later
- Xcode 16+
- An Android device with USB debugging enabled

## Building

1. Clone the repository.
2. Open `ADBManager.xcodeproj` in Xcode.
3. Build and run the **ADBManager** scheme.

No external dependencies — the ADB binary is bundled in the XPCLibrary package resources.

## Usage

1. Connect your Android device via USB and enable USB debugging.
2. Launch ADBManager — your device should appear in the sidebar.
3. Select a device, choose a source folder on the device and a destination on your Mac.
4. Start syncing. If the device disconnects, the app will wait for reconnection and resume.

## Tech Stack

- **SwiftUI** — UI framework
- **XPC Services** — Sandboxed ADB execution
- **Swift Concurrency** — async/await throughout
- **Swift Package Manager** — XPCLibrary internal package
