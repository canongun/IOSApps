//
//  ContentView.swift
//  Dynamic Translator
//
//  Created by can on 13.03.25.
//

import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @State private var isTranslating = false
    @State private var targetLanguage = "English"
    @State private var availableLanguages = [
        "Bulgarian", 
        "Chinese", 
        "Czech",
        "Danish", 
        "Dutch", 
        "English", 
        "Finnish",
        "French", 
        "German", 
        "Greek",
        "Hindi", 
        "Indonesian",
        "Italian", 
        "Japanese", 
        "Korean",
        "Malay",
        "Norwegian",
        "Polish",
        "Portuguese", 
        "Romanian",
        "Russian",
        "Slovak",
        "Spanish", 
        "Swedish",
        "Turkish", 
        "Ukrainian",
        "Vietnamese"
    ]
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var isProcessing = false
    @State private var showingHistory = false
    @State private var detectedLanguage = "Unknown"
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var conversationHistory = ConversationHistory()
    @StateObject private var usageManager = UsageTimeManager()
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var showingSubscriptionView = false
    @State private var showingLimitAlert = false
    
    private let deepgramService = DeepgramService()
    private let translationService = TranslationService()
    private let elevenLabsService = ElevenLabsService()
    
    @State private var videoPlayer: AVPlayer?
    @State private var isVideoPlaying = false
    
    @State private var scale: CGFloat = 1.0
    
    @State private var isAutoTranslationEnabled = false
    
    @State private var translationMode = "Manual"
    @State private var availableModes = ["Manual", "Auto", "Conversational"]
    @State private var secondaryLanguage = "English"
    
    var body: some View {
        VStack {
            // Replace the current mode toggle with a dropdown
            HStack {
                // Subscription/time remaining button
                Button(action: {
                    showingSubscriptionView = true
                }) {
                    HStack {
                        Image(systemName: "timer")
                        Text(usageManager.formattedRemainingTime())
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
                                // If we're currently recording and switch modes, stop recording
                                if isTranslating {
                                    stopTranslating()
                                }
                                translationMode = mode
                                // Reset isAutoTranslationEnabled based on mode
                                isAutoTranslationEnabled = (mode == "Auto")
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
                
                // Existing history button
                Button(action: {
                    showingHistory = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView("Processing...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            }
            
            if !transcribedText.isEmpty {
                Text("Transcribed: \(transcribedText)")
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                if detectedLanguage != "Unknown" {
                    Text("Detected language: \(detectedLanguage)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            if !translatedText.isEmpty {
                Text("Translated: \(translatedText)")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Replace your current button with this new implementation
            VStack {
                // Main translation button
                Button(action: {
                    if isTranslating {
                        // When stopping, make sure to clear the silence detection callback
                        // This prevents auto-restart after stopping
                        audioRecorder.onSilenceDetected = nil
                        stopTranslating()
                    } else {
                        // Check if user has available time before starting
                        if usageManager.canMakeTranslation() {
                            if usageManager.startTranslation() {
                                startTranslating()
                            }
                        } else {
                            showingLimitAlert = true
                        }
                    }
                }) {
                    ZStack {
                        // Background circle
                        Circle()
                            .strokeBorder(isTranslating ? Color.red : Color.blue, lineWidth: 3)
                            .frame(width: 200, height: 200)
                        
                        // Microphone icon
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
                                // Double tap in auto/conversational mode fully stops the continuous cycle
                                print("Double-tap detected, stopping continuous cycle")
                                // Clear the callback first to prevent auto-restart
                                audioRecorder.onSilenceDetected = nil
                                stopTranslating()
                            }
                        }
                )
                .padding(.bottom, 8)
                .disabled(isProcessing)
                
                // Text label below the button
                Text(buttonLabel)
                    .font(.headline)
                    .foregroundColor(isTranslating ? .red : .blue)
                    .padding(.bottom, 10)
            }
            .onChange(of: isTranslating) { isRecording in
                if isRecording {
                    // Create a pulsing animation
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                } else {
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
            
            // Audio level indicator - show in both Auto and Conversational modes
            if isTranslating && (translationMode == "Auto" || translationMode == "Conversational") {
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        Rectangle()
                            .fill(self.levelColor(for: Float(i * 5) - 50, currentLevel: self.audioRecorder.currentAudioLevel))
                            .frame(width: 3, height: CGFloat(i * 2) + 5)
                            .cornerRadius(1.5)
                    }
                }
                .animation(.spring(), value: audioRecorder.currentAudioLevel)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Add language selection for conversational mode
            if translationMode == "Conversational" {
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
            } else {
                // Language selection dropdown (only in non-conversational modes)
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
                .disabled(isTranslating || isProcessing)
            }
        }
        .padding()
        .sheet(isPresented: $showingHistory) {
            HistoryView(conversationHistory: conversationHistory)
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView(
                usageManager: usageManager,
                subscriptionService: subscriptionService
            )
        }
        .alert("Translation Time Limit Reached", isPresented: $showingLimitAlert) {
            Button("Get More Time", role: .none) {
                showingSubscriptionView = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've used all your available translation time. Subscribe or purchase more minutes to continue.")
        }
        .onAppear {
            requestMicrophonePermission()
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied")
            }
        }
    }

    private func startTranslating() {
        // Only reset if we're not already translating
        if !isTranslating {
            isTranslating = true
            
            // In auto or conversational mode, we may want to clear the previous results for better UX
            if translationMode == "Auto" || translationMode == "Conversational" {
                // Leave the previous translation visible but clear the transcription
                // This allows users to see the ongoing conversation flow
                transcribedText = ""
            }
            
            // Set up silence detection callback if in auto or conversational mode
            if translationMode == "Auto" || translationMode == "Conversational" {
                audioRecorder.onSilenceDetected = {
                    self.processTranslation()
                }
                // Start recording with silence detection
                audioRecorder.startRecording(withSilenceDetection: true)
            } else {
                // Regular recording without silence detection
                audioRecorder.startRecording()
            }
        } else {
            print("Warning: Tried to start translating while already in translating state")
        }
    }
    
    private func stopTranslating() {
        // First set isTranslating to false to prevent any race conditions
        isTranslating = false
        
        // Stop recording
        audioRecorder.stopRecording()
        
        // Only process automatically in manual mode
        // In auto/conversational mode, processing is triggered by the silence detection callback
        if translationMode == "Manual" {
            processTranslation()
        } else {
            // For Auto and Conversational modes, explicitly clear the callback
            // to prevent auto-restart after stopping
            audioRecorder.onSilenceDetected = nil
        }
        
        print("Recording stopped, translationMode: \(translationMode)")
    }
    
    private func processTranslation() {
        // Ensure isTranslating is false before processing
        if isAutoTranslationEnabled {
            isTranslating = false
        }
        
        if let audioData = audioRecorder.recordedData {
            // Skip very short recordings which likely don't contain real speech
            if audioData.count < 5000 { // Skip if less than ~0.5 seconds
                print("Skipping very short audio segment (likely no speech)")
                
                // If in live mode, immediately restart recording
                if isAutoTranslationEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.restartLiveRecording()
                    }
                }
                return
            }
            
            isProcessing = true
            processAudio(audioData: audioData)
        }
    }
    
    private func processAudio(audioData: Data) {
        print("Audio data size: \(audioData.count) bytes")
        
        // Step 1: Transcribe audio using Deepgram
        deepgramService.transcribeAudio(audioData: audioData) { result in
            switch result {
            case .success(let transcriptionResult):
                print("Transcription successful: \(transcriptionResult.text)")
                
                var detectedLanguageCode = ""
                // Update detected language from transcription metadata
                if let metadata = transcriptionResult.metadata,
                   let languageCode = metadata.detectedLanguage {
                    detectedLanguageCode = languageCode
                    DispatchQueue.main.async {
                        self.detectedLanguage = self.languageCodeToName(languageCode)
                    }
                }
                
                DispatchQueue.main.async {
                    self.transcribedText = transcriptionResult.text
                }
                
                // Determine which language to translate to based on the mode
                var translationTarget = self.targetLanguage
                
                if self.translationMode == "Conversational" {
                    // In conversational mode, translate to the other language
                    let detectedLanguageName = self.languageCodeToName(detectedLanguageCode)
                    
                    if detectedLanguageName.lowercased() == self.targetLanguage.lowercased() {
                        translationTarget = self.secondaryLanguage
                    } else if detectedLanguageName.lowercased() == self.secondaryLanguage.lowercased() {
                        translationTarget = self.targetLanguage
                    } else {
                        // If detected language doesn't match either selected language,
                        // default to the first selected language
                        translationTarget = self.targetLanguage
                    }
                    
                    print("Conversational mode: Detected \(detectedLanguageName), translating to \(translationTarget)")
                }
                
                // Step 2: Translate the transcribed text to the determined target
                translationService.translateText(text: transcriptionResult.text, targetLanguage: translationTarget) { result in
                    switch result {
                    case .success(let translatedText):
                        DispatchQueue.main.async {
                            self.translatedText = translatedText
                            
                            // Save to conversation history
                            self.conversationHistory.addEntry(
                                originalText: self.transcribedText,
                                translatedText: translatedText,
                                sourceLanguage: self.detectedLanguage,
                                targetLanguage: translationTarget
                            )
                        }
                        
                        // Step 3: Convert translated text to speech using ElevenLabs
                        elevenLabsService.synthesizeSpeech(text: translatedText, language: translationTarget) { result in
                            DispatchQueue.main.async {
                                self.isProcessing = false
                            }
                            
                            switch result {
                            case .success(let audioData):
                                // Set up the callback before playing audio
                                self.elevenLabsService.onPlaybackCompleted = {
                                    // This will be called when audio playback completes
                                    if self.translationMode == "Auto" || self.translationMode == "Conversational" {
                                        print("Audio playback completed, restarting live recording")
                                        
                                        // Force isTranslating to false to ensure we can restart
                                        DispatchQueue.main.async {
                                            self.isTranslating = false 
                                            self.restartLiveRecording()
                                        }
                                    }
                                }
                                
                                // Now play the audio
                                self.elevenLabsService.playAudio(data: audioData)
                                
                            case .failure(let error):
                                print("Speech synthesis error: \(error.localizedDescription)")
                                
                                // If speech synthesis fails, we should still restart recording in live mode
                                if self.translationMode == "Auto" || self.translationMode == "Conversational" {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.restartLiveRecording()
                                    }
                                }
                            }
                        }
                        
                        // After successful translation, dispatch to main thread:
                        DispatchQueue.main.async {
                            if let timeUsed = self.usageManager.stopTranslation() {
                                // Only confirm usage after successful processing
                                self.usageManager.confirmUsage(minutes: timeUsed)
                            }
                        }
                        
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.isProcessing = false
                        }
                        print("Translation error: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                print("Transcription error: \(error.localizedDescription)")
            }
        }
    }
    
    // Replace the entire restartLiveRecording method
    private func restartLiveRecording() {
        print("Attempting to restart live recording")
        
        // Clear any existing recording state
        isTranslating = false
        
        // Make sure audio sessions are properly reset
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error resetting audio session: \(error)")
        }
        
        // Only restart if we're in auto or conversational mode and not processing
        guard (translationMode == "Auto" || translationMode == "Conversational") && !isProcessing else {
            print("Cannot restart: mode=\(translationMode), isProcessing=\(isProcessing)")
            return
        }
        
        print("Conditions met for live recording restart")
        
        if self.usageManager.canMakeTranslation() {
            print("Starting new recording session in \(translationMode) mode (waiting for speech)")
            if self.usageManager.startTranslation() {
                // Make absolutely sure isTranslating is false before calling startTranslating
                self.isTranslating = false
                self.startTranslating()
            } else {
                self.showingLimitAlert = true
            }
        } else {
            self.showingLimitAlert = true
        }
    }
    
    // Helper function to convert language codes to human-readable names
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
            // Add more languages as needed
        ]
        
        return languageMap[code.lowercased()] ?? code
    }
    
    // Computed property for button label text
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
    
    private func levelColor(for threshold: Float, currentLevel: Float) -> Color {
        if currentLevel >= threshold {
            // Gradient from green to yellow to red as level increases
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

#Preview {
    ContentView()
}
