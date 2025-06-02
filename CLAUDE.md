# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dynamic Translator (branded as "LinkVoice") is an iOS app that provides real-time speech translation using AI services. The app captures audio, transcribes it using Deepgram, translates using Anthropic's Claude API, and synthesizes speech using ElevenLabs.

## Core Architecture

### Main Components

- **ContentView**: Primary interface with translation modes (Manual, Auto, Conversational, Transcription)
- **LiveTranscriptionView**: Dedicated transcription-only mode with scrolling history
- **AudioRecorder**: Handles recording with adaptive silence detection and energy decay patterns
- **Service Layer**: Three main services for different AI APIs
  - `DeepgramService`: Speech-to-text transcription with language detection
  - `TranslationService`: Text translation via Anthropic Claude API  
  - `ElevenLabsService`: Text-to-speech synthesis
- **Usage Management**: Subscription and usage tracking system
  - `UsageTimeManager`: Tracks time-based usage with subscription tiers
  - `SubscriptionService`: Handles StoreKit integration for subscriptions

### Translation Modes

1. **Manual**: Tap to record, tap to process translation
2. **Auto**: Continuous recording with automatic processing on silence detection
3. **Conversational**: Bidirectional translation between two selected languages
4. **Transcription**: Live transcription-only mode (charges half the time)

### Data Models

- `TranscriptionResult`: Contains transcribed text with metadata (detected language, confidence)
- `TranscriptionSegment`: Individual transcription segments for history display
- `SubscriptionTier`: Enum defining free/basic/pro tiers with minute allowances

## Development Commands

### Build and Run
```bash
# Build the project (requires Xcode)
xcodebuild -project "Dynamic Translator.xcodeproj" -scheme "Dynamic Translator" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild test -project "Dynamic Translator.xcodeproj" -scheme "Dynamic Translator" -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Project Structure
- Main app code: `Dynamic Translator/`
- Tests: `Dynamic TranslatorTests/` (uses Swift Testing framework)
- UI Tests: `Dynamic TranslatorUITests/`

## Key Configuration

### API Integration
- API keys are centralized in `Configuration.swift` (⚠️ contains actual keys - handle with care)
- Services use different models:
  - Deepgram: `nova-2` model with language detection
  - Anthropic: `claude-3-5-haiku-20241022` model
  - ElevenLabs: Text-to-speech synthesis

### Subscription System
- Built with StoreKit 2
- Three tiers: Free (5 min), Basic (20 min), Pro (45 min)
- Additional credit packs available (15 min)
- Transcription-only mode charges 50% of normal rate

## Technical Considerations

### Audio Processing
- Uses adaptive silence detection with ambient noise calibration
- Energy decay pattern detection for natural speech ending detection
- Optimized recording settings (8kHz, AAC, medium quality) for faster processing

### State Management
- Uses SwiftUI with `@StateObject` and `@EnvironmentObject`
- Persistent storage via UserDefaults for usage tracking
- Real-time UI updates via `@Published` properties

### Error Handling
- Robust API error handling with fallbacks
- Microphone permission management
- Session state recovery after interruptions

## Development Guidelines

### When Working with Services
- Always handle API errors gracefully
- Use appropriate async/await patterns for network calls
- Test with various audio lengths and qualities
- Consider usage time tracking for any translation operations

### When Working with UI
- Follow existing SwiftUI patterns and state management
- Maintain accessibility for voice-based app
- Test translation modes thoroughly
- Ensure proper cleanup of audio sessions

### Testing
- Use Swift Testing framework (not XCTest)
- Focus on service integration tests
- Test subscription and usage tracking logic
- Verify audio recording/playback functionality

## Common Development Tasks

### Adding New Languages
1. Update `availableLanguages` arrays in views
2. Add language code mappings in `languageCodeToName()` functions
3. Test with Deepgram language detection

### Modifying Usage Limits
1. Update `SubscriptionTier` enum values
2. Verify `UsageTimeManager` calculations
3. Test subscription flow end-to-end

### API Integration Changes
1. Update service classes in respective files
2. Modify `Configuration.swift` if new keys needed
3. Test error handling and timeouts