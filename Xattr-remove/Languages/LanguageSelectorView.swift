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
        LanguageItem(code: "de", name: "Deutsch", flag: "🇩🇪"),
        LanguageItem(code: "en", name: "English", flag: "🇬🇧"),
        LanguageItem(code: "es", name: "Español", flag: "🇪🇸"),
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
        VStack(spacing: 20) {
            Text(NSLocalizedString("language_selector_title", comment: "Language selector title"))
                .font(.title2)
                .padding(.top)

            List(languages, selection: $selectedLanguage) { language in
                HStack {
                    Text(language.flag)
                        .font(.title2)
                    Text(language.name)
                        .font(.body)
                }
                .tag(language.code)
                .padding(.vertical, 4)
            }
            .frame(width: 222, height: 208)
            .border(Color.gray.opacity(0.3), width: 1)

            HStack(spacing: 12) {
                Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("accept", comment: "Accept button")) {
                    // Only show alert if language actually changed
                    if hasLanguageChanged {
                        saveLanguagePreference()
                        showRestartAlert = true
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .padding()
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
