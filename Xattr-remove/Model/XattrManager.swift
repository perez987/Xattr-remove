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
}
