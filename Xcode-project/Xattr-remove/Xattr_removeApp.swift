//
//  Xattr_removeApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import SwiftUI

@main
struct Xattr_rmApp: App {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var isLanguageSelectorPresented = false

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
            CommandGroup(replacing: .newItem) {}
            CommandMenu(NSLocalizedString("menu_language", comment: "Language menu")) {
                Button(NSLocalizedString("menu_select_language", comment: "Select Language menu item")) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                  Button(NSLocalizedString("Check for Updates…", comment: "Menu item to check for app updates"),
                         systemImage: "arrow.triangle.2.circlepath")
                  {
                      GitHubUpdateChecker.shared.checkForUpdates(userInitiated: true)
                  }
                  .keyboardShortcut("u", modifiers: [.command])
              }
        }
    }
}
