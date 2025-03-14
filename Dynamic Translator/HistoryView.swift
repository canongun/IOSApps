import SwiftUI

struct HistoryView: View {
    @ObservedObject var conversationHistory: ConversationHistory
    @Environment(\.presentationMode) var presentationMode
    @State private var showingConfirmation = false
    private let dateFormatter = DateFormatter()
    
    init(conversationHistory: ConversationHistory) {
        self.conversationHistory = conversationHistory
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }
    
    var body: some View {
        NavigationView {
            List {
                if conversationHistory.entries.isEmpty {
                    Text("No conversation history yet")
                        .foregroundColor(.gray)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(conversationHistory.entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(entry.sourceLanguage) → \(entry.targetLanguage)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(dateFormatter.string(from: entry.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.originalText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Text(entry.translatedText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Conversation History")
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    showingConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
                .disabled(conversationHistory.entries.isEmpty)
            )
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Clear History"),
                    message: Text("Are you sure you want to clear all your conversation history? This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear")) {
                        conversationHistory.clearHistory()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

#Preview {
    let history = ConversationHistory()
    // Add some sample entries for the preview
    history.addEntry(
        originalText: "Hello, how are you?",
        translatedText: "Hola, ¿cómo estás?",
        sourceLanguage: "English",
        targetLanguage: "Spanish"
    )
    history.addEntry(
        originalText: "The weather is nice today",
        translatedText: "El clima está agradable hoy",
        sourceLanguage: "English",
        targetLanguage: "Spanish"
    )
    
    return HistoryView(conversationHistory: history)
} 