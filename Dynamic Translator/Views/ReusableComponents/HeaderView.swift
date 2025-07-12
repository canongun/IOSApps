import SwiftUI

struct HeaderView: View {
    @Binding var translationMode: String
    let availableModes: [String]
    let remainingTime: String
    let onModeChange: (String) -> Void
    let onSubscriptionTap: () -> Void
    let onHistoryTap: () -> Void
    let onFeedbackTap: () -> Void
    let onLiveTranscriptionTap: () -> Void
    
    var body: some View {
        HStack {
            // Subscription/time remaining button
            Button(action: onSubscriptionTap) {
                HStack {
                    Image(systemName: "timer")
                    Text(remainingTime)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Mode selection dropdown
            Menu {
                ForEach(availableModes, id: \.self) { mode in
                    Button(mode) {
                        if translationMode != mode {
                            if mode == "Transcription" {
                                onLiveTranscriptionTap()
                            } else {
                                onModeChange(mode)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(translationMode)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // History button
            Button(action: onHistoryTap) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .padding()
            }
            
            // Feedback button
            Button(action: onFeedbackTap) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .padding()
            }
        }
    }
}