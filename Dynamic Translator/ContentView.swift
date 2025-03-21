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
    
    var body: some View {
        VStack {
            // Add usage indicator at the top
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
                
                // Live translation toggle
                Toggle(isOn: $isAutoTranslationEnabled) {
                    Text("")
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
                .onChange(of: isAutoTranslationEnabled) { newValue in
                    // If we're currently recording and switch modes, stop recording
                    if isTranslating {
                        stopTranslating()
                        stopVideo()
                    }
                }
                
                Text(isAutoTranslationEnabled ? "Auto" : "Manual")
                    .font(.caption)
                    .foregroundColor(.blue)
                
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
                        stopTranslating()
                        stopVideo()
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
                            if isAutoTranslationEnabled && isTranslating {
                                // Double tap in live mode fully stops the continuous cycle
                                stopTranslating()
                                stopVideo()
                                // Set a flag or use a boolean to prevent auto-restart
                                audioRecorder.onSilenceDetected = nil
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
            
            // Audio level indicator - only show in Live mode
            if isTranslating && isAutoTranslationEnabled {
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
            
            // Language selection dropdown
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
            // Set up the video player when the view appears
            setupVideoPlayer()
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
    
    private func setupVideoPlayer() {
        // More robust file lookup with error logging
        print("Attempting to load video file...")
        
        // Try to find it as a named resource
        if let path = Bundle.main.path(forResource: "Dynamic_Translator_Button_Animation", ofType: "mp4") {
            let url = URL(fileURLWithPath: path)
            print("Found video at path: \(url.absoluteString)")
            videoPlayer = AVPlayer(url: url)
        } else {
            print("Could not find video as a direct resource")
            
            // Try loading from Assets catalog
            if let assetURL = Bundle.main.url(forResource: "Dynamic_Translator_Button_Animation", 
                                            withExtension: "mp4", 
                                            subdirectory: "Assets.xcassets/Videos/Dynamic_Translator_Button_Animation.dataset") {
                print("Found video in assets at: \(assetURL.absoluteString)")
                videoPlayer = AVPlayer(url: assetURL)
            } else {
                print("Failed to find video in assets catalog")
            }
        }
        
        // Check if player item loaded properly
        if videoPlayer?.currentItem == nil {
            print("Failed to create player item")
        } else {
            print("Player item created successfully")
        }
        
        // Set up notification for when video playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: videoPlayer?.currentItem,
            queue: .main
        ) { _ in
            // Loop the video if we're still recording
            if self.isTranslating {
                self.videoPlayer?.seek(to: .zero)
                self.videoPlayer?.play()
            }
        }
    }
    

    private func startTranslating() {
        // Only reset if we're not already translating
        if !isTranslating {
            isTranslating = true
            
            // In live mode, we may want to clear the previous results for better UX
            if isAutoTranslationEnabled {
                // Leave the previous translation visible but clear the transcription
                // This allows users to see the ongoing conversation flow
                transcribedText = ""
            }
            
            // Set up silence detection callback if in live mode
            if isAutoTranslationEnabled {
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
        isTranslating = false
        audioRecorder.stopRecording()
        
        // Only process automatically in manual mode
        // In live mode, processing is triggered by the silence detection callback
        if !isAutoTranslationEnabled {
            processTranslation()
        }
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
                
                // Update detected language from transcription metadata
                if let metadata = transcriptionResult.metadata,
                   let detectedLanguageCode = metadata.detectedLanguage {
                    DispatchQueue.main.async {
                        self.detectedLanguage = self.languageCodeToName(detectedLanguageCode)
                    }
                }
                
                DispatchQueue.main.async {
                    self.transcribedText = transcriptionResult.text
                }
                
                // Step 2: Translate the transcribed text
                translationService.translateText(text: transcriptionResult.text, targetLanguage: targetLanguage) { result in
                    switch result {
                    case .success(let translatedText):
                        DispatchQueue.main.async {
                            self.translatedText = translatedText
                            
                            // Save to conversation history
                            self.conversationHistory.addEntry(
                                originalText: self.transcribedText,
                                translatedText: translatedText,
                                sourceLanguage: self.detectedLanguage,
                                targetLanguage: self.targetLanguage
                            )
                        }
                        
                        // Step 3: Convert translated text to speech using ElevenLabs
                        elevenLabsService.synthesizeSpeech(text: translatedText, language: targetLanguage) { result in
                            DispatchQueue.main.async {
                                self.isProcessing = false
                            }
                            
                            switch result {
                            case .success(let audioData):
                                // Set up the callback before playing audio
                                self.elevenLabsService.onPlaybackCompleted = {
                                    // This will be called when audio playback completes
                                    if self.isAutoTranslationEnabled {
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
                                if self.isAutoTranslationEnabled {
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
        
        // Only restart if we're in live mode and not processing
        guard isAutoTranslationEnabled && !isProcessing else {
            print("Cannot restart: liveMode=\(isAutoTranslationEnabled), isProcessing=\(isProcessing)")
            return
        }
        
        print("Conditions met for live recording restart")
        
        // Start recording immediately rather than with a delay
        // The speech detection logic will prevent premature translations
        if self.usageManager.canMakeTranslation() {
            print("Starting new recording session in live mode (waiting for speech)")
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
        } else if isAutoTranslationEnabled {
            if isTranslating {
                return "Speaking... (Tap to stop)"
            } else {
                return "Tap to Start Conversation"
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
