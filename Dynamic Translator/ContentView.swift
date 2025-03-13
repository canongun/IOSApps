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
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Italian"]
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var isProcessing = false
    
    @StateObject private var audioRecorder = AudioRecorder()
    private let deepgramService = DeepgramService()
    private let translationService = TranslationService()
    private let elevenLabsService = ElevenLabsService()
    
    var body: some View {
        VStack {
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
            }
            
            if !translatedText.isEmpty {
                Text("Translated: \(translatedText)")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Spacer()
            
            // Main translation button
            Button(action: {
                if isTranslating {
                    stopTranslating()
                } else {
                    startTranslating()
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
    }
    
    private func processAudio(audioData: Data) {
        print("Audio data size: \(audioData.count) bytes")
        
        // Step 1: Transcribe audio using Deepgram
        deepgramService.transcribeAudio(audioData: audioData) { result in
            switch result {
            case .success(let transcribedText):
                print("Transcription successful: \(transcribedText)")
                DispatchQueue.main.async {
                    self.transcribedText = transcribedText
                }
                
                // Step 2: Translate the transcribed text
                translationService.translateText(text: transcribedText, targetLanguage: targetLanguage) { result in
                    switch result {
                    case .success(let translatedText):
                        DispatchQueue.main.async {
                            self.translatedText = translatedText
                        }
                        
                        // Step 3: Convert translated text to speech using ElevenLabs
                        elevenLabsService.synthesizeSpeech(text: translatedText) { result in
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
}

#Preview {
    ContentView()
}
