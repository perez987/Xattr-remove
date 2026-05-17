//
//  XattrManager.swift
//  Xattr-rm
//
//  Manages extended attributes operations
//

import Foundation
import os.log

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
    
   /// XATTR_NOFOLLOW flag - don't follow symbolic links
    private static let XATTR_NOFOLLOW: Int32 = 0x0001
    
    // Logger for xattr operations
    private static let logger = Logger(subsystem: "com.xattr-rm.app", category: "XattrManager")
    
    // Removes the com.apple.quarantine extended attribute from a file
    // - Parameter url: The URL of the file to process
    // - Returns: The result of the removal operation
    static func removeQuarantineAttribute(from url: URL) -> QuarantineRemovalResult {
        let path = url.path
        
        // First verify the file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            logger.error("File does not exist at path: \(path)")
            return .otherError("File not found")
        }
        
        // Attempt to remove the attribute using C API
        // removexattr is a system function, part of Darwin's C standard library
        // Use XATTR_NOFOLLOW to not follow symbolic links
        let result = removexattr(path, quarantineAttribute, XATTR_NOFOLLOW)
        
        if result == 0 {
            logger.info("Successfully removed quarantine attribute from: \(path)")
            return .success
        } else {
            let error = errno
            if error == ENOATTR {
                logger.debug("Quarantine attribute not found on: \(path)")
                return .notFound
            } else if error == EPERM || error == EACCES {
                logger.warning("Permission denied when removing quarantine attribute from \(path)")
                return .permissionDenied
            } else {
                let errorMsg = String(cString: strerror(error))
                logger.error("Error removing quarantine attribute from \(path): \(errorMsg)")
                return .otherError(errorMsg)
            }
        }
    }

    // Re-signs Sparkle framework and app bundle in required order
    // - Parameter appURL: URL of the app bundle to re-sign
    // - Returns: Result of the re-sign operation
    static func reSignAppBundle(at appURL: URL) -> ReSignResult {
        guard appURL.pathExtension.lowercased() == "app" else {
            logger.error("Re-signing requires a .app bundle: \(appURL.path)")
            return .failure("The dropped item is not an .app bundle.")
        }

        let appPath = appURL.path
        let sparkleFrameworkPath = appURL
            .appendingPathComponent("Contents/Frameworks/Sparkle.framework")
            .path

        guard FileManager.default.fileExists(atPath: sparkleFrameworkPath) else {
            logger.error("Sparkle.framework not found at expected path: \(sparkleFrameworkPath)")
            return .failure("Sparkle.framework was not found inside the app bundle.")
        }

        let sparkleResult = runCodeSign(for: sparkleFrameworkPath)
        guard sparkleResult.success else {
            logger.error("Failed to re-sign Sparkle.framework at \(sparkleFrameworkPath): \(sparkleResult.message)")
            return .failure(sparkleResult.message)
        }

        let appResult = runCodeSign(for: appPath)
        guard appResult.success else {
            logger.error("Failed to re-sign app bundle at \(appPath): \(appResult.message)")
            return .failure(appResult.message)
        }

        logger.info("Successfully re-signed Sparkle.framework and app bundle at: \(appPath)")
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
