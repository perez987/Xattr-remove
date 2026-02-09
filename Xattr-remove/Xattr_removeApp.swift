//
//  Xattr_rmApp.swift
//  Xattr-rm
//
//  Created to remove com.apple.quarantine extended attribute from files
//

import SwiftUI

@main
struct Xattr_rmApp: App {
    @StateObject private var fileProcessor = FileProcessor()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileProcessor)
                .onOpenURL { url in
                    // Handle files dropped on the app icon
                    fileProcessor.processFiles([url])
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
