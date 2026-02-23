//
//  Xattr_rmApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import SwiftUI
import Sparkle

@main
struct Xattr_rmApp: App {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var isLanguageSelectorPresented = false
    @StateObject private var updaterController = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileProcessor)
                .sheet(isPresented: $isLanguageSelectorPresented) {
                    LanguageSelectorView()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(
                    NSLocalizedString(
                        "Check for Updates...",
                        comment: "Menu item to check for app updates"
                    ),
//                    systemImage: "square.and.arrow.down.badge.checkmark"
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    updaterController.checkForUpdates()
                }
                .keyboardShortcut("u", modifiers: [.command])
                .disabled(!updaterController.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) { }
            CommandMenu(NSLocalizedString("menu_language", comment: "Language menu")) {
                Button(NSLocalizedString("menu_select_language", comment: "Select Language menu item")) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
