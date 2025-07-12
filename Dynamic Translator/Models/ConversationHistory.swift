import Foundation

struct ConversationEntry: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let translatedText: String
    let sourceLanguage: String  // Detected language
    let targetLanguage: String  // Language translated to
    let timestamp: Date
    
    init(originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        self.id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
    }
}

class ConversationHistory: ObservableObject {
    @Published var entries: [ConversationEntry] = []
    private let storageKey = "conversationHistory"
    
    init() {
        loadHistory()
    }
    
    func addEntry(originalText: String, translatedText: String, sourceLanguage: String, targetLanguage: String) {
        let newEntry = ConversationEntry(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        
        entries.insert(newEntry, at: 0) // Add new entries at the top
        saveHistory()
    }
    
    func clearHistory() {
        entries.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        // Limit history to most recent 100 entries to prevent excessive storage use
        if entries.count > 100 {
            entries = Array(entries.prefix(100))
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save conversation history: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // No saved history found
            return
        }
        
        do {
            let decoder = JSONDecoder()
            entries = try decoder.decode([ConversationEntry].self, from: data)
        } catch {
            print("Failed to load conversation history: \(error.localizedDescription)")
        }
    }
} 