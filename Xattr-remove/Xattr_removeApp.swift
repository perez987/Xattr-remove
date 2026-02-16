//
//  Xattr_rmApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import SwiftUI
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.xattr-rm.app", category: "AppDelegate")

    // Timing constants for window activation sequence
    // activationDelay: Wait for activation APIs to complete before window operations
    private let activationDelay: TimeInterval = 0.1
    // windowLevelResetDelay: Keep window elevated briefly to ensure visibility, then restore normal level
    private let windowLevelResetDelay: TimeInterval = 0.2

    // Reference to the FileProcessor, set by the SwiftUI App when the view appears.
    // Allows the Finder service handler to reuse existing processing and alert logic.
    var fileProcessor: FileProcessor? {
        didSet { processPendingServiceURLs() }
    }

    // URLs received from a Finder service invocation before SwiftUI finished setup.
    private var pendingServiceURLs: [URL] = []

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // Return true to explicitly opt-in to secure coding, suppressing the warning.
        // State restoration is still disabled via window.isRestorable = false below.
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register this object as the Finder services provider so macOS
        // delivers the "Clear Quarantine Attribute" service message here.
        NSApp.servicesProvider = self

        // Disable window state restoration to prevent
        // _NSPersistentUIDeleteItemAtFileURL console warnings.
        // Deferred to ensure SwiftUI windows are created.
        DispatchQueue.main.async {
            for window in NSApplication.shared.windows {
                window.isRestorable = false
            }
        }
    }
    // Finder Service Handler

    // Called by macOS when the user invokes "Clear Quarantine Attribute" from the
    // Finder Services menu. Receives file paths via the pasteboard and forwards
    // them to `FileProcessor` for quarantine attribute removal.
    @objc func removeQuarantine(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let filePaths = pboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String], !filePaths.isEmpty else {
            logger.error("Finder service: failed to read file paths from pasteboard")
            error.pointee = "No files provided" as NSString
            return
        }

        let urls = filePaths.map { URL(fileURLWithPath: $0) }
        logger.info("Finder service: received \(urls.count) file(s)")

        DispatchQueue.main.async {
            // Bring the app window to the foreground when invoked from the Finder service
            self.bringAppToForeground()

            if let processor = self.fileProcessor {
                processor.processFiles(urls)
            } else {
                // App may still be setting up SwiftUI; buffer URLs until ready.
                self.pendingServiceURLs.append(contentsOf: urls)
            }
        }
    }

    private func processPendingServiceURLs() {
        guard let processor = fileProcessor, !pendingServiceURLs.isEmpty else { return }
        let urls = pendingServiceURLs
        pendingServiceURLs = []
        bringAppToForeground()
        processor.processFiles(urls)
    }

    // Brings the app window to the foreground so the user can see the result alert.
    // Uses multiple activation strategies to ensure the app is visible when invoked
    // from Finder services, which may launch the app in the background.
    private func bringAppToForeground() {
        // Strategy 1: Set activation policy to regular to ensure app can come to foreground
        NSApp.setActivationPolicy(.regular)
        
        // Strategy 2: Use NSRunningApplication for more forceful activation
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        // Strategy 3: Activate the NSApplication itself
        NSApp.activate(ignoringOtherApps: true)
        
        // Strategy 4: Immediately unhide and show window before delayed activation
        // This is critical for macOS Tahoe where the window may be hidden by default
        if let window = NSApp.windows.first {
            // Unhide the application if it's hidden
            if NSApp.isHidden {
                NSApp.unhide(nil)
            }
            
            // If window is miniaturized, deminiaturize it
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            
            // Use orderFrontRegardless which is more forceful than makeKeyAndOrderFront
            window.orderFrontRegardless()
        }
        
        // Strategy 5: Bring window to front with a slight delay to ensure activation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) { [weak self] in
            guard let self = self else { return }
            let resetDelay = self.windowLevelResetDelay
            
            if let window = NSApp.windows.first {
                // Set window level to ensure visibility
                window.level = .floating
                window.makeKeyAndOrderFront(nil)
                
                // Reset window level after a brief moment.
                // Using weak capture to prevent retain cycles and checking window validity
                // to handle the edge case where window is closed during the delay.
                DispatchQueue.main.asyncAfter(deadline: .now() + resetDelay) { [weak window] in
                    // Verify window still exists and is in the window list before resetting level
                    if let window = window, NSApp.windows.contains(window) {
                        window.level = .normal
                    }
                }
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
                .onAppear {
                    // Provide FileProcessor to AppDelegate so the Finder service
                    // handler can reuse the same processing and alert logic.
                    appDelegate.fileProcessor = fileProcessor
                }
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
