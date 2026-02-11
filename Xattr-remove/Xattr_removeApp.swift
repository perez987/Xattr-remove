//
//  Xattr_rmApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // This app does not use state restoration
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable window state restoration to prevent
        // _NSPersistentUIDeleteItemAtFileURL console warnings.
        // Deferred to ensure SwiftUI windows are created.
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.isRestorable = false
            }
        }
    }
}

@main
struct Xattr_rmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
