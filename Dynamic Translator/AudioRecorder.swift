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
    
    // Configuration for silence detection
    private let silenceThreshold: Float = -20.0 // dB threshold for silence
    private let silenceDuration: TimeInterval = 1.0 // 1.5 seconds of silence to trigger stop
    
    // Callback for silence detection
    var onSilenceDetected: (() -> Void)?
    
    func startRecording(withSilenceDetection: Bool = false) {
        // Stop any existing recording first
        if isRecording {
            stopRecording()
        }
        
        // Reset recorded data
        recordedData = nil
        
        // Reset audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Force deactivate and reactivate to clear any previous state
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("recording.m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
            
            // Check if we're detecting silence
            if averagePower < self.silenceThreshold {
                // If we're already counting silence, do nothing
                if self.silenceTimer == nil {
                    // Start counting silence
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                        guard let self = self, self.isRecording else { return }
                        
                        print("Silence detected, stopping recording")
                        
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
}
