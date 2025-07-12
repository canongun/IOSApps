import SwiftUI

struct TranslationButton: View {
    @Binding var isTranslating: Bool
    @Binding var isProcessing: Bool
    let scale: CGFloat
    let translationMode: String
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .strokeBorder(isTranslating ? Color.red : Color.blue, lineWidth: 3)
                        .frame(width: 200, height: 200)
                    
                    Image(systemName: isTranslating ? "mic.fill" : "mic")
                        .font(.system(size: 80))
                        .foregroundColor(isTranslating ? .red : .blue)
                        .scaleEffect(scale)
                }
            }
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded { _ in
                        if (translationMode == "Auto" || translationMode == "Conversational") && isTranslating {
                            onDoubleTap()
                        }
                    }
            )
            .padding(.bottom, 8)
            .disabled(isProcessing)
            
            Text(buttonLabel)
                .font(.headline)
                .foregroundColor(isTranslating ? .red : .blue)
                .padding(.bottom, 10)
        }
    }
    
    private var buttonLabel: String {
        if isProcessing {
            return "Processing..."
        } else if translationMode == "Auto" || translationMode == "Conversational" {
            if isTranslating {
                return "Speaking... (Tap to stop)"
            } else {
                return translationMode == "Conversational" ?
                    "Tap to Start Conversation" : "Tap to Start Translation"
            }
        } else {
            return isTranslating ? "Tap to Translate" : "Tap to Speak"
        }
    }
}