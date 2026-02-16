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

    // Timing constant for window visibility
    // windowLevelResetDelay: Keep window elevated briefly to ensure visibility, then restore normal level
    private let windowLevelResetDelay: TimeInterval = 0.2

    // Reference to the FileProcessor, set by the SwiftUI App when the view appears.
    // Allows the Finder service handler to reuse existing processing and alert logic.
    var fileProcessor: FileProcessor? {
        didSet { processPendingServiceURLs() }
    }

    // URLs received from a Finder service invocation before SwiftUI finished setup.
    private var pendingServiceURLs: [URL] = []
    
    // Flag to track if we're launched from Finder service
    private var launchedFromService = false
    
    // Flag to track if window visibility has been enforced after creation
    private var windowVisibilityEnforced = false

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

        // On Sequoia/Tahoe, SwiftUI WindowGroup creates windows asynchronously.
        // We activate the app immediately to trigger window creation, but window
        // visibility enforcement happens later in ensureWindowVisibilityAfterCreation()
        // which is called from ContentView.onAppear when we know the window exists.
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        // Queue the files for processing - they'll be handled once SwiftUI is ready
        DispatchQueue.main.async {
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
        processor.processFiles(urls)
    }

    // Called from ContentView.onAppear to ensure window is visible when launched from service.
    // This is the key fix for Sequoia/Tahoe: enforce window visibility AFTER SwiftUI creates
    // the window, not before. The window exists at this point, we just need to bring it front.
    func ensureWindowVisibilityAfterCreation() {
        // Only enforce visibility once, and only if launched from service
        guard launchedFromService, !windowVisibilityEnforced else { return }
        windowVisibilityEnforced = true
        
        logger.info("ContentView appeared, enforcing window visibility for service launch")
        
        // At this point, the window exists (we're in onAppear), so just bring it to front
        bringAppToForeground()
    }

    // Brings the app window to the foreground so the user can see the result alert.
    // Uses multiple activation strategies to ensure the app is visible when invoked
    // from Finder services, which may launch the app in the background.
    private func bringAppToForeground() {
        // Strategy 1: Unhide the app
        NSApp.unhide(nil)
        
        // Strategy 2: Use NSRunningApplication for forceful activation
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        // Strategy 3: Activate the NSApplication itself
        NSApp.activate(ignoringOtherApps: true)
        
        // Strategy 4: Make all windows visible
        showAllWindows()
    }
    
    // Helper method to show and activate all windows
    private func showAllWindows() {
        guard !NSApp.windows.isEmpty else {
            logger.warning("showAllWindows called but no windows exist")
            return
        }
        
        logger.info("Showing \(NSApp.windows.count) window(s)")
        
        // Iterate all windows and make them visible with maximum visibility settings
        for window in NSApp.windows {
            // If window is miniaturized, deminiaturize it
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            
            // Set to floating level temporarily for maximum visibility
            window.level = .floating
            
            // Make window opaque and remove any alpha
            window.isOpaque = true
            window.alphaValue = 1.0
            
            // Use orderFrontRegardless which is more forceful than makeKeyAndOrderFront
            window.orderFrontRegardless()
            
            // Make it key and main
            window.makeKeyAndOrderFront(nil)
        }
        
        // Reset window level after ensuring visibility
        let windowsToReset = NSApp.windows
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
                    
                    // CRITICAL: If launched from service, window visibility must be enforced
                    // AFTER SwiftUI creates the window (i.e., now in onAppear).
                    // On Sequoia/Tahoe, the window exists but isn't brought to front properly
                    // when service handler runs before window creation.
                    appDelegate.ensureWindowVisibilityAfterCreation()
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
