//
//  ADBManagerApp.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import SwiftUI

@main
struct ManagerApp: App {
    var body: some Scene {
        WindowGroup("ADB Manager"){
            ContentView()
                .navigationTitle("Android Debug Bridge")
        }
                .windowResizability(.contentSize)
    }
}
