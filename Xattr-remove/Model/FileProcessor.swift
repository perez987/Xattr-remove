//
//  FileProcessor.swift
//  Xattr-rm
//
//  Manages file processing coordination across the app
//

import Foundation
import SwiftUI
import os.log

// Groups all alert-related state into a single value so that
// updating it triggers only one `objectWillChange` notification,
// preventing "Publishing changes from within view updates" warnings.
struct AlertState {
    var isPresented = false
    var title = ""
    var message = ""
}

class FileProcessor: ObservableObject {
    @Published var alertState = AlertState()

    private let logger = Logger(subsystem: "com.xattr-rm.app", category: "FileProcessor")

    // Delay for displaying success alert before auto-quit
    private let alertDisplayDuration: TimeInterval = 3.0
    // Delay after dismissing alert before terminating app (needed for macOS Sonoma compatibility)
    private let alertDismissalDelay: TimeInterval = 0.2

    // Process a list of file URLs
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

            // Capture the final counts before entering @MainActor context to avoid concurrency issues
            let finalRemovedCount = removedCount
            let finalNotFoundCount = notFoundCount
            let finalFailedCount = failedCount

            // Build alert state locally then assign once to trigger a single objectWillChange
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                var newState = AlertState()

                if finalFailedCount > 0 {
                
                    newState.title = NSLocalizedString("error_title", comment: "Error alert title")
                    if finalFailedCount == 1 && finalRemovedCount == 0 && finalNotFoundCount == 0 {
                        newState.message = NSLocalizedString("error_single_file", comment: "Error message for single file")
                    } else {
                        newState.message = String.localizedStringWithFormat(
                            NSLocalizedString("error_multiple_files", comment: "Error message for multiple files"),
                            finalFailedCount
                        )
                    }
                    newState.isPresented = true
                    self.alertState = newState
                } else if finalRemovedCount > 0 || finalNotFoundCount > 0 {
                    newState.title = NSLocalizedString("success_title", comment: "Success alert title")

                    // Build appropriate message based on counts
                    if finalRemovedCount > 0 && finalNotFoundCount == 0 {
                        // Only removed files
                        if finalRemovedCount == 1 {
                            newState.message = NSLocalizedString("success_removed_single", comment: "Success message for single removed file")
                        } else {
                            newState.message = String.localizedStringWithFormat(
                                NSLocalizedString("success_removed_multiple", comment: "Success message for multiple removed files"),
                                finalRemovedCount
                            )
                        }
                    } else if finalRemovedCount == 0 && finalNotFoundCount > 0 {
                        // Only not found files
                        if finalNotFoundCount == 1 {
                            newState.message = NSLocalizedString("success_not_present_single", comment: "Success message for single file without quarantine")
                        } else {
                            newState.message = String.localizedStringWithFormat(
                                NSLocalizedString("success_not_present_multiple", comment: "Success message for multiple files without quarantine"),
                                finalNotFoundCount
                            )
                        }
                    } else {
                        // Mixed results
                        let total = finalRemovedCount + finalNotFoundCount
                        newState.message = String.localizedStringWithFormat(
                            NSLocalizedString("success_mixed", comment: "Success message for mixed results"),
                            total, finalRemovedCount, finalNotFoundCount
                        )
                    }

                    newState.isPresented = true
                    self.alertState = newState

                    // Schedule app quit after display duration
                    // Hide windows first via orderOut (avoids SwiftUI binding teardown warnings),
                    // then exit cleanly without triggering SwiftUI view lifecycle
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.alertDisplayDuration) {
                        NSApplication.shared.windows.forEach { $0.orderOut(nil) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.alertDismissalDelay) {
                            exit(0)
                        }
                    }
                }
            }
        }
    }
}

