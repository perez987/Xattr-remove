//
//  FileProcessor.swift
//  Xattr-rm
//
//  Manages file processing coordination across the app
//

import Foundation
import SwiftUI
import os.log

class FileProcessor: ObservableObject {
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    private let logger = Logger(subsystem: "com.xattr-rm.app", category: "FileProcessor")
    
    /// Process a list of file URLs
    func processFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        logger.info("Processing \(urls.count) file(s)")
        
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.xattr-rm.file-processing")
        var removedCount = 0
        var notFoundCount = 0
        var failedCount = 0
        
        for url in urls {
            group.enter()
            // Process file on background thread to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async {
                let result = XattrManager.removeQuarantineAttribute(from: url)
                
                queue.async {
                    switch result {
                    case .success:
                        removedCount += 1
                    case .notFound:
                        notFoundCount += 1
                    case .permissionDenied, .otherError:
                        failedCount += 1
                    }
                    group.leave()
                }
            }
        }
        
        // Show result alert after all files are processed
        group.notify(queue: queue) {
            self.logger.info("Processing complete: \(removedCount) removed, \(notFoundCount) not found, \(failedCount) failed")
            
            DispatchQueue.main.async {
                if failedCount > 0 {
                    self.alertTitle = "Error"
                    if failedCount == 1 && removedCount == 0 && notFoundCount == 0 {
                        self.alertMessage = "Failed to remove quarantine attribute. The file may be in a protected location or require administrator privileges."
                    } else {
                        self.alertMessage = "Failed to remove quarantine attribute from \(failedCount) file(s). Some files may be in protected locations or require administrator privileges."
                    }
                    self.showAlert = true
                } else if removedCount > 0 || notFoundCount > 0 {
                    self.alertTitle = "Success"
                    
                    // Build appropriate message based on counts
                    if removedCount > 0 && notFoundCount == 0 {
                        // Only removed files
                        if removedCount == 1 {
                            self.alertMessage = "Successfully removed quarantine attribute from file."
                        } else {
                            self.alertMessage = "Successfully removed quarantine attribute from \(removedCount) files."
                        }
                    } else if removedCount == 0 && notFoundCount > 0 {
                        // Only not found files
                        if notFoundCount == 1 {
                            self.alertMessage = "Successfully processed 1 file (quarantine attribute was not present)."
                        } else {
                            self.alertMessage = "Successfully processed \(notFoundCount) files (quarantine attribute was not present)."
                        }
                    } else {
                        // Mixed results
                        let total = removedCount + notFoundCount
                        self.alertMessage = "Successfully processed \(total) files (\(removedCount) removed, \(notFoundCount) already cleaned)."
                    }
                    
                    self.showAlert = true
                    
                    // Schedule app quit after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}
