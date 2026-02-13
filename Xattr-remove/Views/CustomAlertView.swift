//
//  CustomAlertView.swift
//  Xattr-rm
//
//  Custom alert view displayed as a sheet, providing full control over presentation
//  without showing the app icon that appears in standard SwiftUI alerts on Sonoma/Sequoia
//

import SwiftUI

struct CustomAlertView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    
    // Alert sizing constants
    private let minWidth: CGFloat = 300
    private let maxWidth: CGFloat = 300
    private let minHeight: CGFloat = 200
    
    var body: some View {
            VStack(spacing: 20) {
                
                // Title section
                if !title.isEmpty {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                }
                
                // Message section
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // OK button
                Button(action: { dismiss() }) {
                    Text(NSLocalizedString("ok_button", comment: "OK button"))
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(30)
            .frame(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

#Preview {
    CustomAlertView(
        title: NSLocalizedString("success_title", comment: "Success alert title"),
        message: NSLocalizedString("success_removed_single", comment: "Success message for single removed file")
    )
}
