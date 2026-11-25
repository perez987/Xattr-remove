//
//  Remove-quarantine
//  Minimal app with no window and no Dock icon that provides a single Finder
//  service: "Remove quarantine". It removes only com.apple.quarantine
//  (recursively in folders and bundles) and quits by itself. No messages.
//

import AppKit
import Darwin

final class ServiceProvider: NSObject {
    private var quitTimer: Timer?

    /// Quits the app after `seconds` of inactivity.
    func scheduleQuit(after seconds: TimeInterval) {
        quitTimer?.invalidate()
        quitTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            NSApp.terminate(nil)
        }
    }

    /// Selector declared in Info.plist (NSMessage = removeQuarantine).
    @objc func removeQuarantine(_ pboard: NSPasteboard,
                                userData: String?,
                                error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        for url in urls {
            Self.removeRecursively(url)
        }
        scheduleQuit(after: 2)
    }

    private static func strip(_ path: String) {
        // If the attribute is missing (ENOATTR) or removal fails, ignore it silently.
        _ = removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
    }

    private static func removeRecursively(_ url: URL) {
        strip(url.path)

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values?.isDirectory == true, values?.isSymbolicLink != true else { return }

        // No skip options: includes hidden files and package contents (.app).
        guard let enumerator = FileManager.default.enumerator(at: url,
                                                              includingPropertiesForKeys: nil,
                                                              options: [],
                                                              errorHandler: { _, _ in true }) else { return }
        for case let item as URL in enumerator {
            strip(item.path)
        }
    }
}

let app = NSApplication.shared
let provider = ServiceProvider()
app.setActivationPolicy(.accessory)
app.servicesProvider = provider
NSUpdateDynamicServices()
// Whether opened manually or launched by macOS for a service, it quits by itself when done.
provider.scheduleQuit(after: 10)
app.run()
