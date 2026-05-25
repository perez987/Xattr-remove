//
//  XattrManager.swift
//  Xattr-rm
//
//  Manages extended attributes operations
//

import Foundation

// Result of removing a quarantine attribute
enum QuarantineRemovalResult {
    case success
    case notFound
    case permissionDenied
    case otherError(String)
}

enum ReSignResult {
    case success
    case failure(String)
}

class XattrManager {
    // The quarantine attribute name
    private static let quarantineAttribute = "com.apple.quarantine"
    private static let lipoTimeout: DispatchTimeInterval = .seconds(5)
    private static let architectureBundleExtensions = Set(["app", "framework", "bundle"])
    private static let architectureLibraryExtensions = Set(["dylib", "so"])
    
   /// XATTR_NOFOLLOW flag - don't follow symbolic links
    private static let XATTR_NOFOLLOW: Int32 = 0x0001
    
    // Returns a localized architecture description for .app bundles, executables, and libraries.
    // Returns nil when the dropped item is not a supported architecture candidate or cannot be resolved.
    static func architectureDescription(for url: URL) -> String? {
        guard let architectureTargetURL = architectureTargetURL(for: url) else {
            return nil
        }

        let lipoPath = "/usr/bin/lipo"
        guard FileManager.default.fileExists(atPath: lipoPath) else {
            print("lipo not found at expected path: \(lipoPath)")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lipoPath)
        process.arguments = ["-archs", architectureTargetURL.path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            let exitSemaphore = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in
                exitSemaphore.signal()
            }

            try process.run()
            let waitResult = exitSemaphore.wait(timeout: .now() + lipoTimeout)
            if waitResult == .timedOut {
                process.terminate()
                print("Timed out while running lipo for path: \(architectureTargetURL.path)")
                return nil
            }

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let rawOutput = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let tokens = rawOutput
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            let hasIntel = tokens.contains { $0 == "x86_64" || $0 == "i386" }
            let hasSilicon = tokens.contains { $0 == "arm64" || $0 == "arm64e" }

            let architectureValue: String
            if hasIntel && hasSilicon {
                architectureValue = NSLocalizedString("architecture_intel_silicon", comment: "Architecture label value for universal binary")
            } else if hasIntel {
                architectureValue = NSLocalizedString("architecture_intel_only", comment: "Architecture label value for Intel-only binary")
            } else if hasSilicon {
                architectureValue = NSLocalizedString("architecture_silicon_only", comment: "Architecture label value for Apple Silicon-only binary")
            } else if !tokens.isEmpty {
                architectureValue = String.localizedStringWithFormat(
                    NSLocalizedString("architecture_other_format", comment: "Architecture label value for other/unknown architectures"),
                    tokens.joined(separator: ", ")
                )
            } else {
                return nil
            }

            return String.localizedStringWithFormat(
                NSLocalizedString("architecture_label_format", comment: "Architecture info label format"),
                architectureValue
            )
        } catch {
            return nil
        }
    }

    private static func architectureTargetURL(for url: URL) -> URL? {
        if architectureBundleExtensions.contains(url.pathExtension.lowercased()) {
            return bundleExecutableURL(for: url)
        }

        guard isArchitectureCandidateFile(url) else {
            return nil
        }

        return url
    }

    private static func bundleExecutableURL(for bundleURL: URL) -> URL? {
        guard let bundle = Bundle(url: bundleURL) else {
            print("Unable to open bundle for architecture lookup: \(bundleURL.path)")
            return nil
        }

        guard let executableURL = bundle.executableURL else {
            print("Bundle has no executable for architecture lookup: \(bundleURL.path)")
            return nil
        }

        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            print("Bundle executable missing for architecture lookup: \(executableURL.path)")
            return nil
        }

        return executableURL
    }

    private static func isArchitectureCandidateFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return false
        }

        if FileManager.default.isExecutableFile(atPath: url.path) {
            return true
        }

        return architectureLibraryExtensions.contains(url.pathExtension.lowercased())
    }
    
    // Removes the com.apple.quarantine extended attribute from a file
    // - Parameter url: The URL of the file to process
    // - Returns: The result of the removal operation
    static func removeQuarantineAttribute(from url: URL) -> QuarantineRemovalResult {
        let path = url.path
        
        // First verify the file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            print("File does not exist at path: \(path)")
            return .otherError("File not found")
        }
        
        // Attempt to remove the attribute using C API
        // removexattr is a system function, part of Darwin's C standard library
        // Use XATTR_NOFOLLOW to not follow symbolic links
        let result = removexattr(path, quarantineAttribute, XATTR_NOFOLLOW)
        
        if result == 0 {
            print("Successfully removed quarantine attribute from: \(path)")
            return .success
        } else {
            let error = errno
            if error == ENOATTR {
                print("Quarantine attribute not found on: \(path)")
                return .notFound
            } else if error == EPERM || error == EACCES {
                print("Permission denied when removing quarantine attribute from \(path)")
                return .permissionDenied
            } else {
                let errorMsg = String(cString: strerror(error))
                print("Error removing quarantine attribute from \(path): \(errorMsg)")
                return .otherError(errorMsg)
            }
        }
    }

    // Re-signs Sparkle framework and app bundle in required order
    // - Parameter appURL: URL of the app bundle to re-sign
    // - Returns: Result of the re-sign operation
    static func reSignAppBundle(at appURL: URL) -> ReSignResult {
        guard appURL.pathExtension.lowercased() == "app" else {
            print("Re-signing requires a .app bundle: \(appURL.path)")
            return .failure("The dropped item is not an .app bundle.")
        }

        let appPath = appURL.path
        let sparkleFrameworkPath = appURL
            .appendingPathComponent("Contents/Frameworks/Sparkle.framework")
            .path

        guard FileManager.default.fileExists(atPath: sparkleFrameworkPath) else {
            print("Sparkle.framework not found at expected path: \(sparkleFrameworkPath)")
            return .failure("Sparkle.framework was not found inside the app bundle.")
        }

        let sparkleResult = runCodeSign(for: sparkleFrameworkPath)
        guard sparkleResult.success else {
            print("Failed to re-sign Sparkle.framework at \(sparkleFrameworkPath): \(sparkleResult.message)")
            return .failure(sparkleResult.message)
        }

        let appResult = runCodeSign(for: appPath)
        guard appResult.success else {
            print("Failed to re-sign app bundle at \(appPath): \(appResult.message)")
            return .failure(appResult.message)
        }

        print("Successfully re-signed Sparkle.framework and app bundle at: \(appPath)")
        return .success
    }

    private static func runCodeSign(for targetPath: String) -> (success: Bool, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        // Keep --deep to mirror the expected manual recovery command used by users for this app.
        process.arguments = ["--force", "--deep", "--sign", "-", targetPath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                return (true, output)
            } else {
                return (false, output.isEmpty ? "codesign failed with exit code \(process.terminationStatus)." : output)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
