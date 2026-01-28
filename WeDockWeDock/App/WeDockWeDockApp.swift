//
//  WeDockWeDockApp.swift
//  WeDockWeDock
//
//  Created by 박준하 on 1/27/26.
//

import SwiftUI

@main
struct WeDockWeDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environmentObject(appDelegate.favoritesStore)
                .environmentObject(appDelegate.hotkeyManager)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.favoritesStore)
                .environmentObject(appDelegate.hotkeyManager)
        }
    }
}
