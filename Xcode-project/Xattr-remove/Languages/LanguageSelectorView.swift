//
//  LanguageSelectorView.swift
//  Mp3Player
//
//  Language selector view with flag emojis
//

import SwiftUI

struct LanguageItem: Identifiable {
    let id: String
    let code: String
    let name: String
    let flag: String

    init(code: String, name: String, flag: String) {
        self.id = code
        self.code = code
        self.name = name
        self.flag = flag
    }
}

struct LanguageSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: String
    @State private var showRestartAlert = false
    private let initialLanguage: String

    // Available languages sorted by code
    private let languages: [LanguageItem] = [
        LanguageItem(code: "en", name: "English", flag: "🇬🇧"),
        LanguageItem(code: "es", name: "Español", flag: "🇪🇸"),
        LanguageItem(code: "de", name: "Deutsch", flag: "🇩🇪"),
        LanguageItem(code: "fr", name: "Français", flag: "🇫🇷"),
        LanguageItem(code: "it", name: "Italiano", flag: "🇮🇹")
    ]

    private var hasLanguageChanged: Bool {
        selectedLanguage != initialLanguage
    }

    init() {
        // Load current language preference
        let currentLang = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?
            .first?.components(separatedBy: "-").first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        _selectedLanguage = State(initialValue: currentLang)
        initialLanguage = currentLang
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.60, green: 0.82, blue: 1.0).opacity(0.18),
                    Color(red: 0.75, green: 0.65, blue: 1.0).opacity(0.18)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Image(systemName: "globe")
                    .padding(.top, 16)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.blue)
 
                Text(NSLocalizedString("language_selector_title", comment: "Language selector title"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                // Language list inside a glass card
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.green.opacity(0.35), lineWidth: 1)
                            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
                    )
                    .overlay(
                        List(languages, selection: $selectedLanguage) { language in
                            HStack(spacing: 10) {
                                Text(language.flag)
                                    .font(.title2)
                                Text(language.name)
                                    .font(.body)
                                    .foregroundColor(.primary.opacity(0.85))
                            }
                            .tag(language.code)
                            .padding(.vertical, 3)
                            .listRowBackground(
                                selectedLanguage == language.code
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear
                            )
                        }
                        .scrollContentBackground(.hidden)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    )
                    .frame(width: 234, height: 200)
                    .padding(.horizontal, 20)

                // Buttons
                HStack(spacing: 12) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(NSLocalizedString("accept", comment: "Accept button")) {
                        if hasLanguageChanged {
                            saveLanguagePreference()
                            showRestartAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
        }
        .frame(width: 280)
        .alert(
            NSLocalizedString("language_changed_title", comment: "Language changed alert title"),
            isPresented: $showRestartAlert
        ) {
            Button(NSLocalizedString("ok", comment: "OK button")) {
                dismiss()
            }
        } message: {
            Text(NSLocalizedString("language_changed_message", comment: "Language changed message"))
        }
    }

    private func saveLanguagePreference() {
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }
}

#Preview {
    LanguageSelectorView()
}
