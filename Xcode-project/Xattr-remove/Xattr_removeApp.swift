//
//  Xattr_removeApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import AppKit
import SwiftUI

/// Handles the Finder service declared under `NSServices` in Info.plist.
/// macOS launches the app if needed and calls `removeQuarantine(_:userData:error:)`
/// with the selected files on the pasteboard; they go through the same
/// `FileProcessor` path as a drag-and-drop (alert + auto-quit after 5").
final class ServiceProvider: NSObject {
    private let fileProcessor: FileProcessor

    init(fileProcessor: FileProcessor) {
        self.fileProcessor = fileProcessor
    }

    @objc func removeQuarantine(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls =
            pboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL] ?? []

        guard !urls.isEmpty else {
            error.pointee = "No files received from the Finder service." as NSString
            return
        }

        print("Finder service received \(urls.count) file(s)")

        // Same behaviour as a drop: architecture info only for a single item,
        // re-sign disabled (the checkbox always starts unchecked anyway).
        if urls.count == 1 {
            DispatchQueue.global(qos: .userInitiated).async {
                let architectureLabel = XattrManager.architectureDescription(
                    for: urls[0]
                )
                DispatchQueue.main.async {
                    self.fileProcessor.processFiles(
                        urls,
                        architectureInfo: architectureLabel
                    )
                }
            }
        } else {
            fileProcessor.processFiles(urls)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let fileProcessor = FileProcessor()
    private lazy var serviceProvider = ServiceProvider(
        fileProcessor: fileProcessor
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }
}

@main
struct Xattr_rmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var isLanguageSelectorPresented = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.fileProcessor)
                .sheet(isPresented: $isLanguageSelectorPresented) {
                    LanguageSelectorView()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(
                NSLocalizedString("menu_language", comment: "Language menu")
            ) {
                Button(
                    NSLocalizedString(
                        "menu_select_language",
                        comment: "Select Language menu item"
                    )
                ) {
                    isLanguageSelectorPresented = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button(
                    NSLocalizedString(
                        "Check for Updates…",
                        comment: "Menu item to check for app updates"
                    ),
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    GitHubUpdateChecker.shared.checkForUpdates(
                        userInitiated: true
                    )
                }
                .keyboardShortcut("u", modifiers: [.command])
            }
        }
    }
}
