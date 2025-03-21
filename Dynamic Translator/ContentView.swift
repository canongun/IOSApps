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
    
    @State private var isLiveTranslationEnabled = false
    
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
                Toggle(isOn: $isLiveTranslationEnabled) {
                    Text("")
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .labelsHidden()
                .onChange(of: isLiveTranslationEnabled) { newValue in
                    // If we're currently recording and switch modes, stop recording
                    if isTranslating {
                        stopTranslating()
                        stopVideo()
                    }
                }
                
                Text(isLiveTranslationEnabled ? "Live" : "Manual")
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
                                startVideo()
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
            
            // Audio level indicator
            if isTranslating {
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
    
    private func startVideo() {
        print("Starting video playback")
        videoPlayer?.seek(to: .zero)
        videoPlayer?.play()
        
        // Check what's happening
        if videoPlayer == nil {
            print("Error: videoPlayer is nil")
        } else if videoPlayer?.currentItem == nil {
            print("Error: player item is nil")
        } else {
            print("Video should be playing")
        }
        
        isVideoPlaying = true
    }
    
    private func stopVideo() {
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)
        isVideoPlaying = false
    }
    
    private func startTranslating() {
        isTranslating = true
        
        // Set up silence detection callback if in live mode
        if isLiveTranslationEnabled {
            audioRecorder.onSilenceDetected = {
                self.processTranslation()
            }
            // Start recording with silence detection
            audioRecorder.startRecording(withSilenceDetection: true)
        } else {
            // Regular recording without silence detection
            audioRecorder.startRecording()
        }
    }
    
    private func stopTranslating() {
        isTranslating = false
        audioRecorder.stopRecording()
        
        // Only process automatically in manual mode
        // In live mode, processing is triggered by the silence detection callback
        if !isLiveTranslationEnabled {
            processTranslation()
        }
    }
    
    private func processTranslation() {
        if let audioData = audioRecorder.recordedData {
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
                                elevenLabsService.playAudio(data: audioData)
                            case .failure(let error):
                                print("Speech synthesis error: \(error.localizedDescription)")
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
        } else if isLiveTranslationEnabled {
            return isTranslating ? "Speaking... (Auto)" : "Tap to Speak"
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
