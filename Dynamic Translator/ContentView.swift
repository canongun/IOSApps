//
//  ContentView.swift
//  Dynamic Translator
//
//  Created by can on 13.03.25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var isTranslating = false
    @State private var targetLanguage = "English"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Italian", "Turkish"]
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
            
            // Main translation button
            Button(action: {
                if isTranslating {
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
                Circle()
                    .fill(isTranslating ? Color.red : Color.blue)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: isTranslating ? "mic.fill" : "mic")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    )
            }
            .padding(.bottom, 50)
            .disabled(isProcessing)
            
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
        isTranslating = true
        audioRecorder.startRecording()
    }
    
    private func stopTranslating() {
        isTranslating = false
        audioRecorder.stopRecording()
        
        if let audioData = audioRecorder.recordedData {
            isProcessing = true
            processAudio(audioData: audioData)
        }
        
        // We'll calculate time usage after successful processing
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
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "tr": "Turkish",
            // Add more languages as needed
        ]
        
        return languageMap[code.lowercased()] ?? code
    }
}

#Preview {
    ContentView()
}
