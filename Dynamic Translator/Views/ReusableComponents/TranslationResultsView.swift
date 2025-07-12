import SwiftUI

struct TranslationResultsView: View {
    let transcribedText: String
    let translatedText: String
    let detectedLanguage: String
    let isProcessing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isProcessing {
                ProgressView("Processing...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcribed: \(transcribedText)")
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    if detectedLanguage != "Unknown" {
                        Text("Detected language: \(detectedLanguage)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
            }
            
            if !translatedText.isEmpty {
                Text("Translated: \(translatedText)")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
    }
}

struct AudioLevelIndicator: View {
    let currentAudioLevel: Float
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    Rectangle()
                        .fill(levelColor(for: Float(i * 5) - 50, currentLevel: currentAudioLevel))
                        .frame(width: 3, height: CGFloat(i * 2) + 5)
                        .cornerRadius(1.5)
                }
            }
            .animation(.spring(), value: currentAudioLevel)
            .padding(.top, 8)
        }
    }
    
    private func levelColor(for threshold: Float, currentLevel: Float) -> Color {
        if currentLevel >= threshold {
            let intensity = Double(min(1.0, (currentLevel - threshold) / 25.0))
            if intensity < 0.5 {
                return .green.opacity(0.7 + intensity * 0.6)
            } else {
                return .red.opacity(0.6 + (intensity - 0.5) * 0.8)
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}