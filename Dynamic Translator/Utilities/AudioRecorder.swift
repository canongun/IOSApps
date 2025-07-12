import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession!
    private var silenceTimer: Timer?
    private var levelTimer: Timer?
    
    @Published var isRecording = false
    @Published var recordedData: Data?
    @Published var currentAudioLevel: Float = 0.0
    
    // Add a flag to track if speech has been detected in the current recording
    private var speechDetected = false
    
    // Replace fixed thresholds with adaptive ones
    private var silenceThreshold: Float = -21.0 // Will be adjusted dynamically
    private var speechThreshold: Float = -18.0 // Will be adjusted dynamically
    
    // Add parameters for noise adaptation
    private var ambientNoiseLevel: Float = -60.0 // Starting assumption for quiet environment
    private var isCalibrating = false
    private var calibrationSamples = [Float]()
    private let calibrationDuration: TimeInterval = 0.75 // seconds to calibrate
    private let speechMargin: Float = 6.0 // dB above ambient to consider as speech
    private let silenceMargin: Float = 3.0 // dB above ambient to distinguish from silence
    
    // Configuration for silence detection
    private let silenceDuration: TimeInterval = 1.0 // seconds of silence to trigger stop
    private let minSpeechDuration: TimeInterval = 0.3 // minimum speech duration to consider valid
    
    // For ongoing noise adaptation
    private var recentLevels = [Float]()
    private let recentLevelMaxCount = 20 // Keep track of recent levels for adaptation
    private var adaptationCounter = 0
    private let adaptationInterval = 10 // Adapt every N samples
    
    // Callback for silence detection
    var onSilenceDetected: (() -> Void)?
    
    // Add these properties to your AudioRecorder class
    private var audioLevelBuffer: [Float] = []
    private let audioLevelBufferSize = 15 // ~1.5 seconds at 10 samples/sec
    private var decayDetectionEnabled = false
    private var lastDecayCheckTime = Date()
    private let decayCheckInterval = 0.2 // Check every 200ms
    
    func startRecording(withSilenceDetection: Bool = false) {
        // Stop any existing recording first
        if isRecording {
            stopRecording()
        }
        
        // Reset flags
        speechDetected = false
        recordedData = nil
        
        // Reset calibration state
        isCalibrating = true
        calibrationSamples = []
        recentLevels = []
        
        // Reset audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Force deactivate and reactivate to clear any previous state
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("recording.m4a")
            
            // Optimized recording settings for faster processing
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 8000, // Reduced from 12000
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue, // Changed from high to medium
                AVEncoderBitRateKey: 16000 // Adding explicit bit rate control
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable metering for silence detection
            audioRecorder?.record()
            isRecording = true
            
            // If silence detection is enabled, start monitoring audio levels
            if withSilenceDetection {
                startMonitoringAudioLevels()
            }
            
            // Reset audio level buffer when starting a new recording
            audioLevelBuffer.removeAll()
            lastDecayCheckTime = Date()
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // Stop all timers
        silenceTimer?.invalidate()
        silenceTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Get the recorded data
        if let url = audioRecorder?.url {
            do {
                recordedData = try Data(contentsOf: url)
                try? FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to load recorded audio: \(error.localizedDescription)")
            }
        }
    }
    
    // Start monitoring audio levels for silence detection
    private func startMonitoringAudioLevels() {
        // Create a timer that checks audio levels frequently
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, self.isRecording else { return }
            
            recorder.updateMeters() // Update the audio levels
            
            // Get the average power level in dB
            let averagePower = recorder.averagePower(forChannel: 0)
            DispatchQueue.main.async {
                self.currentAudioLevel = averagePower
            }
            
            // Add to level history buffer for decay detection
            self.audioLevelBuffer.append(averagePower)
            if self.audioLevelBuffer.count > self.audioLevelBufferSize * 2 {
                self.audioLevelBuffer.removeFirst(self.audioLevelBuffer.count - self.audioLevelBufferSize * 2)
            }
            
            // Handle calibration phase
            if self.isCalibrating {
                self.calibrationSamples.append(averagePower)
                
                // Check if we've collected enough samples for calibration
                if self.calibrationSamples.count >= Int(self.calibrationDuration / 0.1) {
                    self.finishCalibration()
                }
                return
            }
            
            // Add to recent levels for ongoing adaptation
            self.recentLevels.append(averagePower)
            if self.recentLevels.count > self.recentLevelMaxCount {
                self.recentLevels.removeFirst()
            }
            
            // Periodically adapt thresholds to changing environment
            self.adaptationCounter += 1
            if self.adaptationCounter >= self.adaptationInterval {
                self.adaptThresholds()
                self.adaptationCounter = 0
            }
            
            // Modify the speech detection logic to include decay pattern detection
            if !self.speechDetected && averagePower > self.speechThreshold {
                print("Speech detected! Level: \(averagePower), Threshold: \(self.speechThreshold)")
                self.speechDetected = true
            }
            
            // Only monitor for silence after speech has been detected
            if self.speechDetected {
                // First check for decay pattern
                let now = Date()
                if now.timeIntervalSince(self.lastDecayCheckTime) >= self.decayCheckInterval {
                    self.lastDecayCheckTime = now
                    
                    if self.detectEnergyDecayPattern() {
                        print("Speech end detected via energy decay pattern")
                        
                        // Important: Save the callback before stopping recording
                        let callback = self.onSilenceDetected
                        
                        // Stop recording first - this sets isRecording to false
                        self.stopRecording()
                        
                        // Then invoke the callback
                        DispatchQueue.main.async {
                            callback?()
                        }
                        return
                    }
                }
                
                // Then check the regular silence threshold (existing code)
                if averagePower < self.silenceThreshold {
                    // If we're already counting silence, do nothing
                    if self.silenceTimer == nil {
                        // Start counting silence
                        self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                            guard let self = self, self.isRecording else { return }
                            
                            print("Silence after speech detected, stopping recording")
                            
                            // Important: Save the callback before stopping recording
                            let callback = self.onSilenceDetected
                            
                            // Stop recording first - this sets isRecording to false
                            self.stopRecording()
                            
                            // Then invoke the callback
                            DispatchQueue.main.async {
                                callback?()
                            }
                        }
                    }
                } else {
                    // Reset the silence timer if audio is detected
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil
                }
            }
        }
    }
    
    // New method to finish calibration and set initial thresholds
    private func finishCalibration() {
        guard !calibrationSamples.isEmpty else { return }
        
        // Sort samples and take the median to avoid outliers
        let sortedSamples = calibrationSamples.sorted()
        let medianIndex = sortedSamples.count / 2
        ambientNoiseLevel = sortedSamples[medianIndex]
        
        // Set thresholds relative to ambient noise
        updateThresholdsBasedOnAmbient()
        
        // Mark calibration as complete
        isCalibrating = false
        
        print("Calibration complete. Ambient level: \(ambientNoiseLevel)dB, Speech threshold: \(speechThreshold)dB, Silence threshold: \(silenceThreshold)dB")
    }
    
    // New method for updating thresholds based on ambient level
    private func updateThresholdsBasedOnAmbient() {
        // Use ambient noise plus margins to set thresholds
        // Ensure there's a minimum dB value even in very quiet environments
        speechThreshold = max(-35.0, ambientNoiseLevel + speechMargin)
        silenceThreshold = max(-40.0, ambientNoiseLevel + silenceMargin)
        
        // Ensure the speech threshold is always above silence threshold
        if speechThreshold <= silenceThreshold {
            speechThreshold = silenceThreshold + 3.0
        }
    }
    
    // New method for ongoing adaptation
    private func adaptThresholds() {
        guard recentLevels.count >= 5 else { return } // Need enough samples
        
        // Filter out likely speech samples to find the ambient noise
        let sortedLevels = recentLevels.sorted()
        let lowerThird = Int(Double(sortedLevels.count) * 0.33)
        
        // Use lower third of samples to estimate ambient noise
        var sum: Float = 0
        for i in 0..<lowerThird {
            if i < sortedLevels.count {
                sum += sortedLevels[i]
            }
        }
        
        let newAmbientEstimate = sum / Float(lowerThird)
        
        // Only update if there's a significant change (prevents constant small adjustments)
        if abs(newAmbientEstimate - ambientNoiseLevel) > 3.0 {
            ambientNoiseLevel = newAmbientEstimate
            updateThresholdsBasedOnAmbient()
            
            print("Adapted thresholds. New ambient: \(ambientNoiseLevel)dB, Speech: \(speechThreshold)dB, Silence: \(silenceThreshold)dB")
        }
    }
    
    // AVAudioRecorderDelegate methods
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Encoding error during recording: \(error.localizedDescription)")
        }
    }
    
    // Add this method to detect energy decay patterns
    private func detectEnergyDecayPattern() -> Bool {
        // Need enough samples to analyze
        guard audioLevelBuffer.count >= audioLevelBufferSize else { return false }
        
        // Get the most recent samples for analysis
        let samples = Array(audioLevelBuffer.suffix(audioLevelBufferSize))
        
        // Calculate slope of recent audio levels
        var consistentDecayCount = 0
        var previousLevel: Float = samples[0]
        
        // Check if we have a consistent decay pattern
        // We want at least 70% of the samples to show decay
        let requiredDecaySegments = Int(Float(samples.count - 1) * 0.7)
        
        for i in 1..<samples.count {
            let currentLevel = samples[i]
            
            // If current level is lower than previous (with small tolerance)
            if currentLevel < previousLevel - 0.5 {
                consistentDecayCount += 1
            } else if currentLevel > previousLevel + 2.0 {
                // Sharp increase - reset decay detection
                // This handles cases where someone starts speaking again
                consistentDecayCount = 0
            }
            
            previousLevel = currentLevel
        }
        
        // Check if we have enough decay segments and if final level is near silence
        let finalLevelNearSilence = samples.last! < silenceThreshold + 3
        return consistentDecayCount >= requiredDecaySegments && finalLevelNearSilence
    }
    
    // Modify your existing updateMetering method to incorporate decay detection
    func updateMetering() {
        guard isRecording else { return }
        
        // This should be called on a timer (~10 times per second)
        audioRecorder?.updateMeters()
        
        // Get current audio level
        let currentLevel = audioRecorder?.averagePower(forChannel: 0) ?? -160.0
        currentAudioLevel = currentLevel
        
        // Add to level history
        audioLevelBuffer.append(currentLevel)
        if audioLevelBuffer.count > audioLevelBufferSize * 2 {
            audioLevelBuffer.removeFirst(audioLevelBuffer.count - audioLevelBufferSize * 2)
        }
        
        // Update ambient noise level calculation (your existing code)
        // ...
        
        // Speech detection logic (your existing code with modifications)
        if isRecording {
            if currentLevel > speechThreshold {
                // Speech detected
                speechDetected = false
                print("Speech detected, level: \(currentLevel), threshold: \(speechThreshold)")
            }
        } else if speechDetected {
            // Now looking for end of speech, using both silence threshold and decay pattern
            
            // Check decay pattern periodically (not every single update)
            let now = Date()
            if now.timeIntervalSince(lastDecayCheckTime) >= decayCheckInterval {
                lastDecayCheckTime = now
                
                // Check if we detect speech ending via energy decay pattern
                if detectEnergyDecayPattern() {
                    print("Speech end detected via energy decay pattern")
                    speechDetected = false
                    onSilenceDetected?()
                    return
                }
            }
            
            // Also keep the existing silence threshold detection
            if currentLevel < silenceThreshold {
                speechDetected = false
            }
        }
    }
    
    // Add a method to reset the speech detection state
    private func resetSpeechDetection() {
        speechDetected = false
        // Clear the audio buffer for the next session
        audioLevelBuffer.removeAll()
    }
}
