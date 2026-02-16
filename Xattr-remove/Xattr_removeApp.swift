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
    // windowInitializationDelay: Wait for SwiftUI window to be created after activation from service
    // Significantly increased for macOS Tahoe to allow WindowGroup sufficient time to create window
    // Tahoe appears to need more time than Sonoma for SwiftUI window initialization
    private let windowInitializationDelay: TimeInterval = 0.5
    // windowCreationRetryDelay: Wait before retrying if windows don't exist
    private let windowCreationRetryDelay: TimeInterval = 0.2
    // Maximum attempts to find/create windows before giving up
    private let maxWindowCreationRetries = 5

    // Reference to the FileProcessor, set by the SwiftUI App when the view appears.
    // Allows the Finder service handler to reuse existing processing and alert logic.
    var fileProcessor: FileProcessor? {
        didSet { processPendingServiceURLs() }
    }

    // URLs received from a Finder service invocation before SwiftUI finished setup.
    private var pendingServiceURLs: [URL] = []
    
    // Track retry attempts for window creation
    private var windowCreationRetryCount = 0
    
    // Flag to track if we're launched from Finder service
    private var launchedFromService = false

    /// Called before applicationDidFinishLaunching to set up critical app configuration.
    /// On macOS Tahoe, services provider and activation policy MUST be registered here
    /// (not in applicationDidFinishLaunching) because:
    /// 1. Finder service handler may be invoked before applicationDidFinishLaunching completes
    /// 2. SwiftUI WindowGroup requires activation policy to be set before window creation
    /// 3. Early setup ensures app is ready to show windows when service is invoked
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register services provider early - this is critical for Finder services
        NSApp.servicesProvider = self
        
        // Set activation policy early to ensure app can come to foreground
        // This must happen BEFORE any service invocation on macOS Tahoe
        NSApp.setActivationPolicy(.regular)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // Return true to explicitly opt-in to secure coding, suppressing the warning.
        // State restoration is still disabled via window.isRestorable = false below.
        true
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
        
        // If launched from Finder service before applicationDidFinishLaunching,
        // ensure window is visible
        if launchedFromService {
            logger.info("Service launch detected, ensuring window visibility")
            DispatchQueue.main.asyncAfter(deadline: .now() + windowInitializationDelay) { [weak self] in
                self?.bringAppToForeground()
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
        
        // Mark that we're launched from service
        launchedFromService = true

        // On macOS Tahoe, apps launched from Finder services start hidden and
        // SwiftUI WindowGroup doesn't create windows until the app is fully initialized.
        // Solution: Activate synchronously BEFORE any async operations to force immediate
        // window creation, then handle window visibility.
        
        // CRITICAL: Unhide and activate SYNCHRONOUSLY before any async work
        // This forces macOS to initialize the app and create SwiftUI windows immediately
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        // Now proceed with async handling
        DispatchQueue.main.async {
            // Give SwiftUI time to create and initialize windows after activation
            DispatchQueue.main.asyncAfter(deadline: .now() + self.windowInitializationDelay) {
                // Bring the app window to the foreground
                self.bringAppToForeground()

                if let processor = self.fileProcessor {
                    processor.processFiles(urls)
                } else {
                    // App may still be setting up SwiftUI; buffer URLs until ready.
                    self.pendingServiceURLs.append(contentsOf: urls)
                }
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
        // Reset retry counter for new activation attempt
        windowCreationRetryCount = 0
        
        // Strategy 1: Unhide the app FIRST, before any other operations
        // This must happen synchronously and immediately for macOS Tahoe
        NSApp.unhide(nil)
        
        // Strategy 2: Use NSRunningApplication for more forceful activation
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        // Strategy 3: Activate the NSApplication itself
        NSApp.activate(ignoringOtherApps: true)
        
        // Strategy 4: Check if windows exist and show them
        // On macOS Tahoe, SwiftUI WindowGroup may not create windows when launched from service
        if NSApp.windows.isEmpty {
            logger.warning("No windows exist after activation, waiting for window creation")
            
            // Wait a bit more and try again with retry limit
            DispatchQueue.main.asyncAfter(deadline: .now() + windowCreationRetryDelay) { [weak self] in
                self?.showAllWindowsWithRetry()
            }
        } else {
            // Windows exist, show them immediately
            showAllWindows()
        }
    }
    
    // Helper method to retry showing windows with a maximum attempt limit
    private func showAllWindowsWithRetry() {
        windowCreationRetryCount += 1
        
        if NSApp.windows.isEmpty {
            if windowCreationRetryCount < maxWindowCreationRetries {
                logger.warning("Retry \(self.windowCreationRetryCount)/\(self.maxWindowCreationRetries): No windows exist, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + windowCreationRetryDelay) { [weak self] in
                    self?.showAllWindowsWithRetry()
                }
            } else {
                logger.error("Failed to create windows after \(self.maxWindowCreationRetries) retries")
                // Final attempt: Force window creation by calling NSApp.activate one more time
                // with a longer delay to give SwiftUI more time on Tahoe
                NSApp.activate(ignoringOtherApps: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + self.windowInitializationDelay) { [weak self] in
                    guard let self = self else { return }
                    if NSApp.windows.isEmpty {
                        self.logger.error("No windows created by SwiftUI WindowGroup after all attempts")
                        // Last resort: Access mainMenu to trigger app infrastructure initialization
                        // This can sometimes force SwiftUI to evaluate its scene hierarchy on Tahoe
                        _ = NSApp.mainMenu
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        self.logger.info("Window finally created after extended wait")
                        self.showAllWindows()
                    }
                }
            }
        } else {
            showAllWindows()
        }
    }
    
    // Helper method to show and activate all windows
    private func showAllWindows() {
        guard !NSApp.windows.isEmpty else {
            logger.warning("showAllWindows called but no windows exist")
            return
        }
        
        logger.info("Showing \(NSApp.windows.count) window(s)")
        
        // First, ensure the app itself is fully visible
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Iterate all windows and make them visible with maximum visibility settings
        for window in NSApp.windows {
            // If window is miniaturized, deminiaturize it
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            
            // Make window visible if it's not
            if !window.isVisible {
                logger.info("Window was not visible, making it visible")
            }
            
            // Set to floating level immediately for maximum visibility
            window.level = .floating
            
            // Make window opaque and remove any alpha
            window.isOpaque = true
            window.alphaValue = 1.0
            
            // Use orderFrontRegardless which is more forceful than makeKeyAndOrderFront
            window.orderFrontRegardless()
            
            // Make it key and main
            window.makeKeyAndOrderFront(nil)
            
            // Center the window on screen for better visibility
            window.center()
        }
        
        // Reset window level after ensuring visibility
        // Using weak capture to handle windows that may be closed during the delay
        let windowsToReset = NSApp.windows.compactMap { window -> NSWindow? in
            return window
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + windowLevelResetDelay) {
            for window in windowsToReset where NSApp.windows.contains(window) {
                window.level = .normal
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
