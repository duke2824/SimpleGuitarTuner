//
//  AudioManager.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/25.
//

import AVFoundation
import Foundation

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
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
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
            
            let frequency = self?.detectFrequency(from: buffer)
            print("Frequency detected: \(frequency ?? 0)")
            
            if let frequency = frequency,
               let note = self?.nearestNote(to: frequency) {
                let differenceHz = frequency - note.frequency
                let differenceCents = 1200 * log2(frequency / note.frequency)
                print("Note: \(note.rawValue)")
                print("Difference: \(differenceHz) Hz, \(differenceCents) cents")
            }
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
    
    func detectFrequency(from buffer: AVAudioPCMBuffer) -> Float {
        let frameCount = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData?[0], frameCount > 0 else { return 0 }
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Copy audio data to a Swift array
        var samples = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            samples[i] = channelData[i]
        }
        
        // Optionally normalize
        let maxAmplitude = samples.max(by: { abs($0) < abs($1) }) ?? 1
        if abs(maxAmplitude) > 0 {
            samples = samples.map { $0 / maxAmplitude }
        }
        
        // Autocorrelation
        var autocorrelation = [Float](repeating: 0, count: frameCount)
        for lag in 0..<frameCount {
            var sum: Float = 0
            for i in 0..<(frameCount - lag) {
                sum += samples[i] * samples[i + lag]
            }
            autocorrelation[lag] = sum
        }
        
        // Find the first minimum (to skip the zero-lag peak)
        var peakIndex = 0
        let minLag = Int(sampleRate / 1000) // Ignore periods shorter than 1kHz
        let maxLag = Int(sampleRate / 50)   // Ignore periods longer than 50Hz
        var maxValue: Float = 0
        for lag in minLag..<min(maxLag, frameCount) {
            if autocorrelation[lag] > maxValue {
                maxValue = autocorrelation[lag]
                peakIndex = lag
            }
        }
        
        if peakIndex == 0 { return 0 }
        let frequency = sampleRate / Float(peakIndex)
        return frequency
    }
    
    /// Returns the nearest GuitarString note to the given frequency
    func nearestNote(to frequency: Float) -> GuitarString? {
        return GuitarString.allCases.min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) })
    }
    
    func toCents(detectedFrequency: Float, nearestNote: GuitarString) -> Float {
        return 1200 * log2(detectedFrequency / nearestNote.frequency)
    }
}
