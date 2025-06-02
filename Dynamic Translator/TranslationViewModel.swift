import Foundation
import SwiftUI
import AVFoundation

@MainActor
class TranslationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isTranslating = false
    @Published var transcribedText = ""
    @Published var translatedText = ""
    @Published var detectedLanguage = "Unknown"
    @Published var isProcessing = false
    @Published var targetLanguage = "English"
    @Published var secondaryLanguage = "English"
    @Published var translationMode = "Manual"
    @Published var scale: CGFloat = 1.0
    
    // MARK: - Dependencies
    private let deepgramService = DeepgramService()
    private let translationService = TranslationService()
    private let elevenLabsService = ElevenLabsService()
    let audioRecorder = AudioRecorder()
    
    // MARK: - Constants
    let availableLanguages = [
        "Bulgarian", "Chinese", "Czech", "Danish", "Dutch", "English",
        "Finnish", "French", "German", "Greek", "Hindi", "Indonesian",
        "Italian", "Japanese", "Korean", "Malay", "Norwegian", "Polish",
        "Portuguese", "Romanian", "Russian", "Slovak", "Spanish",
        "Swedish", "Turkish", "Ukrainian", "Vietnamese"
    ]
    
    let availableModes = ["Manual", "Auto", "Conversational", "Transcription"]
    
    init() {
        setupAudioRecorder()
    }
    
    // MARK: - Public Methods
    func startTranslating() {
        guard !isTranslating else { return }
        
        isTranslating = true
        clearPreviousResults()
        
        if translationMode == "Auto" || translationMode == "Conversational" {
            setupSilenceDetection()
            audioRecorder.startRecording(withSilenceDetection: true)
        } else {
            audioRecorder.startRecording()
        }
        
        startPulsingAnimation()
    }
    
    func stopTranslating() {
        isTranslating = false
        audioRecorder.stopRecording()
        
        if translationMode == "Manual" {
            processTranslation()
        } else {
            audioRecorder.onSilenceDetected = nil
        }
        
        stopPulsingAnimation()
    }
    
    func changeMode(to newMode: String) {
        if isTranslating {
            stopTranslating()
        }
        translationMode = newMode
    }
    
    // MARK: - Private Methods
    private func setupAudioRecorder() {
        // Configure audio recorder
    }
    
    private func setupSilenceDetection() {
        audioRecorder.onSilenceDetected = { [weak self] in
            self?.processTranslation()
        }
    }
    
    private func clearPreviousResults() {
        if translationMode == "Auto" || translationMode == "Conversational" {
            transcribedText = ""
        }
    }
    
    private func startPulsingAnimation() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
    }
    
    private func stopPulsingAnimation() {
        withAnimation {
            scale = 1.0
        }
    }
    
    private func processTranslation() {
        guard let audioData = audioRecorder.recordedData,
              audioData.count >= 5000 else {
            handleEmptyAudio()
            return
        }
        
        isProcessing = true
        processAudioData(audioData)
    }
    
    private func processAudioData(_ audioData: Data) {
        deepgramService.transcribeAudio(audioData: audioData) { [weak self] result in
            Task { @MainActor in
                self?.handleTranscriptionResult(result)
            }
        }
    }
    
    private func handleTranscriptionResult(_ result: Result<TranscriptionResult, Error>) {
        switch result {
        case .success(let transcriptionResult):
            handleSuccessfulTranscription(transcriptionResult)
        case .failure(let error):
            handleTranscriptionError(error)
        }
    }
    
    private func handleSuccessfulTranscription(_ result: TranscriptionResult) {
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !text.isEmpty else {
            handleEmptyTranscription()
            return
        }
        
        transcribedText = text
        updateDetectedLanguage(from: result.metadata)
        
        let targetLang = determineTargetLanguage(detectedLanguage: detectedLanguage)
        translateText(text, to: targetLang)
    }
    
    private func updateDetectedLanguage(from metadata: TranscriptionMetadata?) {
        if let languageCode = metadata?.detectedLanguage {
            detectedLanguage = languageCodeToName(languageCode)
        }
    }
    
    private func determineTargetLanguage(detectedLanguage: String) -> String {
        guard translationMode == "Conversational" else {
            return targetLanguage
        }
        
        if detectedLanguage.lowercased() == targetLanguage.lowercased() {
            return secondaryLanguage
        } else if detectedLanguage.lowercased() == secondaryLanguage.lowercased() {
            return targetLanguage
        } else {
            return targetLanguage
        }
    }
    
    private func translateText(_ text: String, to targetLang: String) {
        translationService.translateText(text: text, targetLanguage: targetLang) { [weak self] result in
            Task { @MainActor in
                self?.handleTranslationResult(result, originalText: text, targetLanguage: targetLang)
            }
        }
    }
    
    private func handleTranslationResult(_ result: Result<String, Error>, originalText: String, targetLanguage: String) {
        isProcessing = false
        
        switch result {
        case .success(let translation):
            translatedText = translation
            synthesizeSpeech(translation, in: targetLanguage)
        case .failure(let error):
            print("Translation error: \(error)")
        }
    }
    
    private func synthesizeSpeech(_ text: String, in language: String) {
        elevenLabsService.synthesizeSpeech(text: text, language: language) { [weak self] result in
            switch result {
            case .success(let audioData):
                self?.playTranslatedAudio(audioData)
            case .failure(let error):
                print("Speech synthesis error: \(error)")
                self?.handleSpeechSynthesisFailure()
            }
        }
    }
    
    private func playTranslatedAudio(_ audioData: Data) {
        elevenLabsService.onPlaybackCompleted = { [weak self] in
            if self?.translationMode == "Auto" || self?.translationMode == "Conversational" {
                self?.restartLiveRecording()
            }
        }
        elevenLabsService.playAudio(data: audioData)
    }
    
    private func restartLiveRecording() {
        // Implementation for restarting live recording
    }
    
    private func handleEmptyAudio() {
        if translationMode == "Auto" || translationMode == "Conversational" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.restartLiveRecording()
            }
        }
    }
    
    private func handleEmptyTranscription() {
        transcribedText = "Speech not detected"
        translatedText = "I couldn't catch what you said. Could you please speak again?"
        
        if translationMode == "Auto" || translationMode == "Conversational" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.restartLiveRecording()
            }
        }
    }
    
    private func handleTranscriptionError(_ error: Error) {
        isProcessing = false
        print("Transcription error: \(error)")
    }
    
    private func handleSpeechSynthesisFailure() {
        if translationMode == "Auto" || translationMode == "Conversational" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.restartLiveRecording()
            }
        }
    }
    
    private func languageCodeToName(_ code: String) -> String {
        let languageMap = [
            "bg": "Bulgarian", "cs": "Czech", "da": "Danish", "de": "German",
            "el": "Greek", "en": "English", "es": "Spanish", "fi": "Finnish",
            "fr": "French", "hi": "Hindi", "id": "Indonesian", "it": "Italian",
            "ja": "Japanese", "ko": "Korean", "nl": "Dutch", "ms": "Malay",
            "no": "Norwegian", "pl": "Polish", "pt": "Portuguese", "ro": "Romanian",
            "ru": "Russian", "sk": "Slovak", "sv": "Swedish", "tr": "Turkish",
            "uk": "Ukrainian", "vi": "Vietnamese", "zh": "Chinese"
        ]
        return languageMap[code.lowercased()] ?? code
    }
}