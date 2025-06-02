import SwiftUI
import AVFoundation

struct ContentView: View {
    // MARK: - View Models
    @StateObject private var viewModel = TranslationViewModel()
    @StateObject private var conversationHistory = ConversationHistory()
    @StateObject private var usageManager = UsageTimeManager()
    @StateObject private var subscriptionService = SubscriptionService()
    
    // MARK: - UI State
    @State private var showingHistory = false
    @State private var showingSubscriptionView = false
    @State private var showingFeedbackView = false
    @State private var showingLimitAlert = false
    @State private var showingLiveTranscription = false
    
    var body: some View {
        VStack {
            HeaderView(
                translationMode: $viewModel.translationMode,
                availableModes: viewModel.availableModes,
                remainingTime: usageManager.formattedRemainingTime(),
                onModeChange: { mode in
                    viewModel.changeMode(to: mode)
                },
                onSubscriptionTap: {
                    showingSubscriptionView = true
                },
                onHistoryTap: {
                    showingHistory = true
                },
                onFeedbackTap: {
                    showingFeedbackView = true
                },
                onLiveTranscriptionTap: {
                    showingLiveTranscription = true
                }
            )
            
            Spacer()
            
            TranslationResultsView(
                transcribedText: viewModel.transcribedText,
                translatedText: viewModel.translatedText,
                detectedLanguage: viewModel.detectedLanguage,
                isProcessing: viewModel.isProcessing
            )
            
            Spacer()
            
            TranslationButton(
                isTranslating: $viewModel.isTranslating,
                isProcessing: $viewModel.isProcessing,
                scale: viewModel.scale,
                translationMode: viewModel.translationMode,
                onTap: {
                    handleTranslationButtonTap()
                },
                onDoubleTap: {
                    handleDoubleTap()
                }
            )
            
            AudioLevelIndicator(
                currentAudioLevel: viewModel.audioRecorder.currentAudioLevel,
                isVisible: viewModel.isTranslating && 
                    (viewModel.translationMode == "Auto" || viewModel.translationMode == "Conversational")
            )
            
            Spacer()
            
            LanguageSelectionView(
                targetLanguage: $viewModel.targetLanguage,
                secondaryLanguage: $viewModel.secondaryLanguage,
                availableLanguages: viewModel.availableLanguages,
                translationMode: viewModel.translationMode,
                isTranslating: viewModel.isTranslating,
                isProcessing: viewModel.isProcessing
            )
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
        .sheet(isPresented: $showingFeedbackView) {
            FeedbackView()
        }
        .alert("Translation Time Limit Reached", isPresented: $showingLimitAlert) {
            Button("Get More Time", role: .none) {
                showingSubscriptionView = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've used all your available translation time. Subscribe or purchase more minutes to continue.")
        }
        .fullScreenCover(isPresented: $showingLiveTranscription) {
            LiveTranscriptionView()
                .environmentObject(usageManager)
        }
        .onAppear {
            requestMicrophonePermission()
        }
    }
    
    // MARK: - Private Methods
    private func handleTranslationButtonTap() {
        if viewModel.isTranslating {
            viewModel.stopTranslating()
        } else {
            if usageManager.canMakeTranslation() {
                if usageManager.startTranslation() {
                    viewModel.startTranslating()
                }
            } else {
                showingLimitAlert = true
            }
        }
    }
    
    private func handleDoubleTap() {
        if (viewModel.translationMode == "Auto" || viewModel.translationMode == "Conversational") && viewModel.isTranslating {
            viewModel.stopTranslating()
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied")
            }
        }
    }
}