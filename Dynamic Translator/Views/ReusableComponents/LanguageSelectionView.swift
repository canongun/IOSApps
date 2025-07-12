import SwiftUI

struct LanguageSelectionView: View {
    @Binding var targetLanguage: String
    @Binding var secondaryLanguage: String
    let availableLanguages: [String]
    let translationMode: String
    let isTranslating: Bool
    let isProcessing: Bool
    
    var body: some View {
        if translationMode == "Conversational" {
            ConversationalLanguageSelection(
                targetLanguage: $targetLanguage,
                secondaryLanguage: $secondaryLanguage,
                availableLanguages: availableLanguages
            )
        } else {
            SingleLanguageSelection(
                targetLanguage: $targetLanguage,
                availableLanguages: availableLanguages,
                isDisabled: isTranslating || isProcessing
            )
        }
    }
}

struct ConversationalLanguageSelection: View {
    @Binding var targetLanguage: String
    @Binding var secondaryLanguage: String
    let availableLanguages: [String]
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary language selection
            Menu {
                ForEach(availableLanguages, id: \.self) { language in
                    Button(language) {
                        targetLanguage = language
                    }
                }
            } label: {
                HStack {
                    Text("Language 1: \(targetLanguage)")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                    Spacer()
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            
            // Secondary language selection
            Menu {
                ForEach(availableLanguages, id: \.self) { language in
                    Button(language) {
                        secondaryLanguage = language
                    }
                }
            } label: {
                HStack {
                    Text("Language 2: \(secondaryLanguage)")
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                    Spacer()
                }
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct SingleLanguageSelection: View {
    @Binding var targetLanguage: String
    let availableLanguages: [String]
    let isDisabled: Bool
    
    var body: some View {
        Menu {
            ForEach(availableLanguages, id: \.self) { language in
                Button(language) {
                    targetLanguage = language
                }
            }
        } label: {
            HStack {
                Text("Translate to: \(targetLanguage)")
                    .font(.headline)
                Image(systemName: "chevron.down")
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        .padding(.bottom, 50)
        .disabled(isDisabled)
    }
}