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
                    self.alertTitle = NSLocalizedString("error_title", comment: "Error alert title")
                    if failedCount == 1 && removedCount == 0 && notFoundCount == 0 {
                        self.alertMessage = NSLocalizedString("error_single_file", comment: "Error message for single file")
                    } else {
                        self.alertMessage = String.localizedStringWithFormat(
                            NSLocalizedString("error_multiple_files", comment: "Error message for multiple files"),
                            failedCount
                        )
                    }
                    self.showAlert = true
                } else if removedCount > 0 || notFoundCount > 0 {
                    self.alertTitle = NSLocalizedString("success_title", comment: "Success alert title")
                    
                    // Build appropriate message based on counts
                    if removedCount > 0 && notFoundCount == 0 {
                        // Only removed files
                        if removedCount == 1 {
                            self.alertMessage = NSLocalizedString("success_removed_single", comment: "Success message for single removed file")
                        } else {
                            self.alertMessage = String.localizedStringWithFormat(
                                NSLocalizedString("success_removed_multiple", comment: "Success message for multiple removed files"),
                                removedCount
                            )
                        }
                    } else if removedCount == 0 && notFoundCount > 0 {
                        // Only not found files
                        if notFoundCount == 1 {
                            self.alertMessage = NSLocalizedString("success_not_present_single", comment: "Success message for single file without quarantine")
                        } else {
                            self.alertMessage = String.localizedStringWithFormat(
                                NSLocalizedString("success_not_present_multiple", comment: "Success message for multiple files without quarantine"),
                                notFoundCount
                            )
                        }
                    } else {
                        // Mixed results
                        let total = removedCount + notFoundCount
                        self.alertMessage = String.localizedStringWithFormat(
                            NSLocalizedString("success_mixed", comment: "Success message for mixed results"),
                            total, removedCount, notFoundCount
                        )
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
