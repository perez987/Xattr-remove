//
//  ContentView.swift
//  Xattr-rm
//
//  Main view for the app that accepts file drops
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isTargeted = false
    // Re-sign option always false at run
    @State private var shouldResignAfterProcessing = false
    @State private var architectureInfoText: String?
    @State private var latestDropID = UUID()
    @EnvironmentObject var fileProcessor: FileProcessor

    // Subtle gradient that shifts slightly when a file is dragged over
    private var backgroundGradient: LinearGradient {
        if isTargeted {
            return LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.35),
                    Color(red: 0.70, green: 0.60, blue: 1.0).opacity(0.35)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.60, green: 0.82, blue: 1.0).opacity(0.18),
                    Color(red: 0.75, green: 0.65, blue: 1.0).opacity(0.18)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drop-target icon
                ZStack {
                    Circle()
                        .fill(
                            isTargeted
                                ? Color.accentColor.opacity(0.22)
                                : Color.white.opacity(0.15)
                        )
                        .frame(width: 88, height: 88)
                        .blur(radius: isTargeted ? 2 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)

                    Image(systemName: "arrow.up.trash")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(
                            isTargeted
                                ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.45, green: 0.65, blue: 1.0),
                                            Color(red: 0.60, green: 0.45, blue: 0.95)
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)
                }
                .padding(.top, 28)

                // Title
                Text(NSLocalizedString("drop_file_here", comment: "Main UI text"))
                    .font(.title.weight(.semibold))
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(.top, 16)

                // Subtitle
                Text(NSLocalizedString("remove_quarantine_subtitle", comment: "Subtitle text"))
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .padding(.horizontal, 24)

                // Glass-card divider area
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                    )
                    .overlay(
                        Toggle(
                            NSLocalizedString("resign_after_processing_option", comment: "Option to re-sign dropped app bundles"),
                            isOn: $shouldResignAfterProcessing
                        )
                        .toggleStyle(.checkbox)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    )
                    .frame(height: 54)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)

                // Architecture info (shown only for single-file drops)
                if let architectureInfoText {
                    Text(architectureInfoText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .accessibilityLabel(
                            String.localizedStringWithFormat(
                                NSLocalizedString("architecture_accessibility_label_format", comment: "Accessibility label for architecture info text"),
                                architectureInfoText
                            )
                        )
                } else {
                    Spacer().frame(height: 14)
                }

                Spacer(minLength: 20)
            }
        }
        .frame(
            minWidth: 360, idealWidth: 360, maxWidth: 360,
            minHeight: 340, idealHeight: 340, maxHeight: 340
        )
        // Subtle ring when a file is dragged over
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    isTargeted ? Color.accentColor.opacity(0.55) : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.15), value: isTargeted)
        )
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
                        print("Error loading dropped item: \(error.localizedDescription)")
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
