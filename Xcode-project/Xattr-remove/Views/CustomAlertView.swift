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

    // Determine icon and tint from title content
    private var isError: Bool {
        title.localizedCaseInsensitiveContains("error") ||
        title.localizedCaseInsensitiveContains("err") ||
        title.localizedCaseInsensitiveContains("fail")
    }
    private var iconName: String { isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill" }
    private var iconColor: Color { isError ? Color(red: 1.0, green: 0.45, blue: 0.35) : Color(red: 0.30, green: 0.80, blue: 0.55) }

    var body: some View {
        ZStack {
            // Glass-style background
            LinearGradient(
                colors: [
                    Color(red: 0.60, green: 0.7, blue: 0.8).opacity(0.22),
                    Color(red: 0.8, green: 0.65, blue: 1.0).opacity(0.22)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Status icon
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(iconColor)
                    .padding(.top, 8)

                // Title
                if !title.isEmpty {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary.opacity(0.9))
                }

                // Message
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                // OK button
                Button(action: { dismiss() }) {
                    Text(NSLocalizedString("ok_button", comment: "OK button"))
                        .frame(minWidth: 90)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .padding(28)
            .frame(minWidth: 200, maxWidth: 200)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
            .padding(16)
        }
        .frame(minWidth: 260, idealWidth: 260, maxWidth: 260)
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
