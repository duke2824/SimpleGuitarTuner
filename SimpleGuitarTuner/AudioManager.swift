//
//  AudioManager.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/25.
//

import AVFoundation

class AudioManager {
    private var audioEngine: AVAudioEngine?
    
    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else { return }
        let format = inputNode.inputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0) // Remove if already installed
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            let maxSample = channelData.map { (data: UnsafeMutablePointer<Float>) -> Float in
                var max: Float = 0
                for i in 0..<frameLength {
                    max = Swift.max(max, abs(data[i]))
                }
                return max
            } ?? 0
            print("Received audio buffer. Peak amplitude: \(maxSample)")
        }
        
        do {
            try audioEngine?.start()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    func stop() {
        audioEngine?.stop()
        audioEngine = nil
    }
}
