import SwiftUI
import AVFoundation

struct LiveTranscriptionView: View {
    // Services
    @StateObject private var audioRecorder = AudioRecorder()
    private let deepgramService = DeepgramService()
    private let translationService = TranslationService()
    
    // Add transcription history
    @StateObject private var transcriptionHistory = LiveTranscriptionHistory()
    @State private var showingHistory = false
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var usageManager: UsageTimeManager
    
    // UI States
    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var detectedLanguage = "Unknown"
    @State private var transcriptionSegments: [TranscriptionSegment] = []
    @State private var isProcessing = false
    @State private var showingLimitAlert = false
    
    // Language selection
    @State private var targetLanguage = "English"
    @State private var availableLanguages = [
        "Bulgarian", "Chinese", "Czech", "Danish", "Dutch", "English",
        "Finnish", "French", "German", "Greek", "Hindi", "Indonesian",
        "Italian", "Japanese", "Korean", "Malay", "Norwegian", "Polish",
        "Portuguese", "Romanian", "Russian", "Slovak", "Spanish",
        "Swedish", "Turkish", "Ukrainian", "Vietnamese"
    ]
    
    // Animation properties
    @State private var scale: CGFloat = 1.0
    @State private var isTranscribing = false
    
    // Time tracking
    @State private var sessionStartTime: Date? = nil
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: {
                    if isRecording {
                        stopRecording()
                    }
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Add history button
                Button(action: {
                    showingHistory = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                
                Menu {
                    ForEach(availableLanguages, id: \.self) { language in
                        Button(language) {
                            targetLanguage = language
                        }
                    }
                } label: {
                    HStack {
                        Text("Translate to: \(targetLanguage)")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isRecording)
                
                Text(usageManager.formattedRemainingTime())
                    .font(.caption)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                if isRecording {
                    Text(timeString(from: elapsedSeconds))
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.opacity)
                }
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if transcriptionSegments.isEmpty && !isRecording {
                        Text("Tap the microphone button to start live transcription and translation")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 100)
                    } else {
                        ForEach(transcriptionSegments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                if !segment.translatedText.isEmpty {
                                    Text(segment.translatedText)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                HStack {
                                    if segment.language != "Unknown" {
                                        Text("Detected: \(segment.language)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(segment.timestamp)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        if !transcribedText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transcribedText)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                if !translatedText.isEmpty {
                                    Text(translatedText)
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                if detectedLanguage != "Unknown" {
                                    Text("Detected: \(detectedLanguage)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding()
            }
            
            if isRecording {
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(levelColor(for: Float(i * 5) - 50, currentLevel: audioRecorder.currentAudioLevel))
                            .frame(width: 3, height: CGFloat(i * 2) + 5)
                            .cornerRadius(1.5)
                    }
                }
                .animation(.spring(), value: audioRecorder.currentAudioLevel)
                .padding()
            }
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    if usageManager.canMakeTranslation() {
                        if usageManager.startTranslation(isTranscriptionOnly: true) {
                            startRecording()
                        }
                    } else {
                        showingLimitAlert = true
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .strokeBorder(isRecording ? Color.red : Color.blue, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundColor(isRecording ? .red : .blue)
                        .scaleEffect(scale)
                }
            }
            .padding(.bottom, 30)
            .disabled(isProcessing)
        }
        .alert("Translation Time Limit Reached", isPresented: $showingLimitAlert) {
            Button("Get More Time", role: .none) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've used all your available time. Subscribe or purchase more minutes to continue.")
        }
        .onAppear {
            requestMicrophonePermission()
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
        }
        .sheet(isPresented: $showingHistory) {
            LiveTranscriptionHistoryView(transcriptionHistory: transcriptionHistory)
        }
    }
    
    private func startRecording() {
        isRecording = true
        transcribedText = ""
        translatedText = ""
        
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
        
        sessionStartTime = Date()
        startTimer()
        
        audioRecorder.onSilenceDetected = {
            DispatchQueue.main.async {
                self.processCurrentAudio()
            }
        }
        
        audioRecorder.startRecording(withSilenceDetection: true)
    }
    
    private func stopRecording() {
        withAnimation {
            scale = 1.0
        }
        
        audioRecorder.onSilenceDetected = nil
        audioRecorder.stopRecording()
        isRecording = false
        
        stopTimer()
        
        processCurrentAudio()
        
        if let timeUsed = usageManager.stopTranslation(isTranscriptionOnly: true) {
            usageManager.confirmUsage(minutes: timeUsed, isTranscriptionOnly: true)
        }
    }
    
    private func processCurrentAudio() {
        assert(Thread.isMainThread, "processCurrentAudio must be called from main thread")
        
        guard let audioData = audioRecorder.recordedData, audioData.count > 5000 else {
            if isRecording {
                audioRecorder.startRecording(withSilenceDetection: true)
            }
            return
        }
        
        isProcessing = true
        
        deepgramService.transcribeAudio(audioData: audioData) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcriptionResult):
                    let text = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !text.isEmpty {
                        var detectedLang = "Unknown"
                        if let metadata = transcriptionResult.metadata,
                           let languageCode = metadata.detectedLanguage {
                            detectedLang = self.languageCodeToName(languageCode)
                        }
                        
                        DispatchQueue.main.async {
                            self.transcribedText = text
                            self.detectedLanguage = detectedLang
                        }
                        
                        self.translationService.translateText(text: text, targetLanguage: self.targetLanguage) { translationResult in
                            DispatchQueue.main.async {
                                self.isProcessing = false
                                
                                switch translationResult {
                                case .success(let translatedText):
                                    self.translatedText = translatedText
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        let formatter = DateFormatter()
                                        formatter.timeStyle = .short
                                        let timestamp = formatter.string(from: Date())
                                        
                                        let newSegment = TranscriptionSegment(
                                            id: UUID(),
                                            text: text,
                                            translatedText: translatedText,
                                            language: detectedLang,
                                            timestamp: timestamp
                                        )
                                        
                                        self.transcriptionSegments.append(newSegment)
                                        self.transcribedText = ""
                                        self.translatedText = ""
                                        
                                        // Save to history
                                        self.transcriptionHistory.addEntry(
                                            originalText: text,
                                            translatedText: translatedText,
                                            sourceLanguage: detectedLang,
                                            targetLanguage: self.targetLanguage
                                        )
                                    }
                                    
                                case .failure(let error):
                                    print("Translation error: \(error.localizedDescription)")
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        let formatter = DateFormatter()
                                        formatter.timeStyle = .short
                                        let timestamp = formatter.string(from: Date())
                                        
                                        let newSegment = TranscriptionSegment(
                                            id: UUID(),
                                            text: text,
                                            translatedText: "Translation failed",
                                            language: detectedLang,
                                            timestamp: timestamp
                                        )
                                        
                                        self.transcriptionSegments.append(newSegment)
                                        self.transcribedText = ""
                                        self.translatedText = ""
                                    }
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isProcessing = false
                        }
                    }
                    
                case .failure(let error):
                    print("Transcription error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                }
                
                if self.isRecording {
                    self.audioRecorder.startRecording(withSilenceDetection: true)
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func languageCodeToName(_ code: String) -> String {
        let languageMap = [
            "bg": "Bulgarian",
            "cs": "Czech",
            "da": "Danish",
            "de": "German",
            "el": "Greek",
            "en": "English",
            "es": "Spanish",
            "fi": "Finnish",
            "fr": "French",
            "hi": "Hindi",
            "id": "Indonesian",
            "it": "Italian",
            "ja": "Japanese",
            "ko": "Korean",
            "nl": "Dutch",
            "ms": "Malay",
            "no": "Norwegian",
            "pl": "Polish",
            "pt": "Portuguese",
            "ro": "Romanian",
            "ru": "Russian",
            "sk": "Slovak",
            "sv": "Swedish",
            "tr": "Turkish",
            "uk": "Ukrainian",
            "vi": "Vietnamese",
            "zh": "Chinese"
        ]
        
        return languageMap[code.lowercased()] ?? code
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

struct TranscriptionSegment: Identifiable {
    let id: UUID
    let text: String
    let translatedText: String
    let language: String
    let timestamp: String
}
