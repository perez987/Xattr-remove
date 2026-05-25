//
//  ContentView.swift
//  Xattr-rm
//
//  Main view for the app that accepts file drops
//

import SwiftUI
import UniformTypeIdentifiers
import os.log

struct ContentView: View {
    @State private var isTargeted = false
    // Re-sign option saved between runs
//    @AppStorage("resign_after_processing") private var shouldResignAfterProcessing = false
    //  Re-sign option always false at run
    @State private var shouldResignAfterProcessing = false
    @State private var architectureInfoText: String?
    @State private var latestDropID = UUID()
    @EnvironmentObject var fileProcessor: FileProcessor
    
    // Logger for UI events
    private let logger = Logger(subsystem: "com.xattr-rm.app", category: "ContentView")
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.trash")
                .font(.system(size: 58))
                .foregroundColor(isTargeted ? .blue : .gray)
            
            Text(NSLocalizedString("drop_file_here", comment: "Main UI text"))
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("remove_quarantine_subtitle", comment: "Subtitle text"))
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()

            Toggle(
                NSLocalizedString("resign_after_processing_option", comment: "Option to re-sign dropped app bundles"),
                isOn: $shouldResignAfterProcessing
            )
//            .padding(.leading, 20)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .toggleStyle(.checkbox)
            .frame(maxWidth: 240,)
            
            Divider()

            if let architectureInfoText {
                Text(architectureInfoText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
//                    .frame(maxWidth: 240, alignment: .leading)
                    .accessibilityLabel(
                        String.localizedStringWithFormat(
                            NSLocalizedString("architecture_accessibility_label_format", comment: "Accessibility label for architecture info text"),
                            architectureInfoText
                        )
                    )
            }
        }
        .frame(
            minWidth: 360,
            idealWidth: 360,
            maxWidth: 360,
            minHeight: 340,
            idealHeight: 340,
            maxHeight: 340
        )
        .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
        // Note: macOS may log reentrant drag IPC messages in Xcode console during drag operations.
        // These are system-level messages (e.g., "kDragIPCCompleted") and cannot be suppressed.
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .sheet(isPresented: $fileProcessor.alertState.isPresented) {
            CustomAlertView(
                title: fileProcessor.alertState.title,
                message: fileProcessor.alertState.message
            )
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        let dropID = UUID()
        latestDropID = dropID

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.xattr-rm.url-collection")
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    if let error = error {
                        self.logger.error("Error loading dropped item: \(error.localizedDescription)")
                    }
                    group.leave()
                    return
                }
                
                queue.async {
                    urls.append(url)
                    group.leave()
                }
            }
        }
        
        // Process all collected URLs after loading completes
        group.notify(queue: queue) {
            if urls.count == 1 {
                let droppedURL = urls[0]
                DispatchQueue.global(qos: .userInitiated).async {
                    let architectureLabel = XattrManager.architectureDescription(for: droppedURL)
                    DispatchQueue.main.async {
                        guard self.latestDropID == dropID else { return }
                        self.architectureInfoText = architectureLabel
                        self.processDroppedFiles(urls, architectureInfo: architectureLabel)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    guard self.latestDropID == dropID else { return }
                    self.architectureInfoText = nil
                    self.processDroppedFiles(urls, architectureInfo: nil)
                }
            }
        }
    }

    private func processDroppedFiles(_ urls: [URL], architectureInfo: String?) {
        fileProcessor.processFiles(
            urls,
            shouldResign: shouldResignAfterProcessing,
            architectureInfo: architectureInfo
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(FileProcessor())
}
