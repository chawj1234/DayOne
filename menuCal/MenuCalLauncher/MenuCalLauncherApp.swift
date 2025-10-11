//
//  MenuCalLauncherApp.swift
//  MenuCalLauncher
//
//  Created by Helper on 2025/06/26.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct MenuCalLauncherApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }

    init() {
        registerMainApp()
        launchMainApp()
        NSApplication.shared.terminate(nil)
    }

    private func registerMainApp() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("Failed to register main app for launch: \(error)")
        }
    }

    private func launchMainApp() {
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // LoginItems
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // DayOne!.app
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: nil)
    }
}
