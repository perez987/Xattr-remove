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
    @EnvironmentObject var fileProcessor: FileProcessor
    
    /// Logger for UI events
    private let logger = Logger(subsystem: "com.xattr-rm.app", category: "ContentView")
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.up.trash")
                .font(.system(size: 58))
                .foregroundColor(isTargeted ? .blue : .gray)
            
            Text("Drop file here")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("to remove quarantine attribute")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(
            minWidth: 282,
            idealWidth: 282,
            maxWidth: 282,
            minHeight: 282,
            idealHeight: 282,
            maxHeight: 282
        )
        .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
        // Note: macOS may log reentrant drag IPC messages in Xcode console during drag operations.
        // These are system-level messages (e.g., "kDragIPCCompleted") and cannot be suppressed.
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .alert(fileProcessor.alertTitle, isPresented: $fileProcessor.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(fileProcessor.alertMessage)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
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
            self.fileProcessor.processFiles(urls)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FileProcessor())
}
