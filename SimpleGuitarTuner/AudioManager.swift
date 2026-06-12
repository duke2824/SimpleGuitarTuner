//
//  AudioManager.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/25.
//

import AVFoundation
import Foundation
import Accelerate

@Observable final class AudioManager {
    var nearestNote: GuitarStringNote?
    var differenceCents: Double?
    
    // MARK: - Pre-allocated state
    
//    private var fftSetup: vDSP_DFT_Setup?
//    private var fftLength: Int = 0
    
    // ── Real-time state (audio thread only, NOT observed) ────────────────
    // Stored as a plain struct — zero @Observable overhead, no locks.
    private var rt = RealTimeBuffers()
    private var audioEngine: AVAudioEngine?
    
    func start() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement)
            try session.setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else { return }
        let format = inputNode.inputFormat(forBus: 0)
        
        let bufferSize = 1024  // larger = better low-freq resolution

        // ✅ Allocate here — on the main thread, before audio starts
        rt.allocate(capacity: bufferSize)
        
        inputNode.removeTap(onBus: 0) // Remove if already installed
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { [weak self] buffer, time in
//            let channelData = buffer.floatChannelData?[0]
//            let frameLength = Int(buffer.frameLength)
//            let maxSample = channelData.map { (data: UnsafeMutablePointer<Float>) -> Float in
//                var max: Float = 0
//                for i in 0..<frameLength {
//                    max = Swift.max(max, abs(data[i]))
//                }
//                return max
//            } ?? 0
//            print("Received audio buffer. Peak amplitude: \(maxSample)")
//            
//            let frequency = self?.detectFrequency(from: buffer)
//            print("Frequency detected: \(frequency ?? 0)")
//            
//            if let frequency = frequency,
//               let note = self?.nearestNote(to: frequency) {
//                let differenceHz = frequency - note.frequency
//                let differenceCents = 1200 * log2(frequency / note.frequency)
//                self?.nearestNote = note
//                self?.differenceCents = Double(differenceCents)
//                
//                print("Note: \(note.rawValue)")
//                print("Difference: \(differenceHz) Hz, \(differenceCents) cents")
//            }
            guard let self else { return }
            self.process(buffer: buffer)
        }
        
        do {
            try audioEngine?.start()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    // ── Audio thread: pure computation, no @Observable access ───────────────
    // `mutating` on a struct field from a class needs explicit self.rt mutation.
    private func process(buffer: AVAudioPCMBuffer) {
        let frameCount = Int(buffer.frameLength)
        guard
            let channelData = buffer.floatChannelData?[0],
            frameCount > 0,
            rt.fftSetup != nil
        else {
            print("[AudioManager] Invalid audio buffer: channelData nil or frameCount == 0")
            return
        }
        if rt.hannWindow.count < frameCount {
            print("[AudioManager] Reallocating buffers for larger frameCount: hannWindow.count = \(rt.hannWindow.count), frameCount = \(frameCount)")
            self.rt.allocate(capacity: frameCount)
        }

        // Silence gate — bail early, no heap allocation
        var rms: Float = 0
        if frameCount > 0 {
            vDSP_measqv(channelData, 1, &rms, vDSP_Length(frameCount))
        } else {
            rms = 0
        }
        guard rms > 0.00005 else { return }  // threshold

        // Reuse pre-allocated rt buffers — zero heap activity on audio thread
        let n = rt.fftLength
        guard rt.samples.count >= frameCount else {
            print("[AudioManager] samples buffer too small for frameCount: samples.count = \(rt.samples.count), frameCount = \(frameCount)")
            return
        }
        vDSP_vmul(channelData, 1, rt.hannWindow, 1, &rt.samples, 1, vDSP_Length(frameCount))
        if frameCount < n {
            rt.samples.withUnsafeMutableBufferPointer { ptr in
                let start = ptr.baseAddress! + frameCount
                memset(start, 0, (n - frameCount) * MemoryLayout<Float>.stride)
            }
        }

        // ... rest of your vDSP FFT autocorrelation (uses rt.fftReal, rt.fftImag etc.)
        let frequency = detectFrequency(from: buffer)//(sampleRate: Float(buffer.format.sampleRate))

        guard frequency > 0,
              let note = nearestNote(to: frequency) else { return }
        let cents = 1200 * log2(frequency / note.frequency)

        // ✅ UI update: hop to main actor — only observed writes happen here
        let capturedNote = note
        let capturedCents = Double(cents)
        print(capturedNote)
        print(capturedCents)
        // Guard exceed value that can be displayed
        if capturedCents < 50.0, capturedCents > -50.0 {
            DispatchQueue.main.async { [weak self] in
                self?.nearestNote = capturedNote
                self?.differenceCents = capturedCents
            }
        }
    }
    
    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        rt.deallocate() // frees vDSP_DFT_Setup + clears arrays
    }
    
    //    func detectFrequency(from buffer: AVAudioPCMBuffer) -> Float {
    //        let frameCount = Int(buffer.frameLength)
    //        guard let channelData = buffer.floatChannelData?[0], frameCount > 0 else { return 0 }
    //        let sampleRate = Float(buffer.format.sampleRate)
    //
    //        // Copy audio data to a Swift array
    //        var samples = [Float](repeating: 0, count: frameCount)
    //        for i in 0..<frameCount {
    //            samples[i] = channelData[i]
    //        }
    //
    //        // Optionally normalize
    //        let maxAmplitude = samples.max(by: { abs($0) < abs($1) }) ?? 1
    //        if abs(maxAmplitude) > 0 {
    //            samples = samples.map { $0 / maxAmplitude }
    //        }
    //
    //        // Autocorrelation
    //        var autocorrelation = [Float](repeating: 0, count: frameCount)
    //        for lag in 0..<frameCount {
    //            var sum: Float = 0
    //            for i in 0..<(frameCount - lag) {
    //                sum += samples[i] * samples[i + lag]
    //            }
    //            autocorrelation[lag] = sum
    //        }
    //
    //        // Find the first minimum (to skip the zero-lag peak)
    //        var peakIndex = 0
    //        let minLag = Int(sampleRate / 1000) // Ignore periods shorter than 1kHz
    //        let maxLag = Int(sampleRate / 50)   // Ignore periods longer than 50Hz
    //        var maxValue: Float = 0
    //        for lag in minLag..<min(maxLag, frameCount) {
    //            if autocorrelation[lag] > maxValue {
    //                maxValue = autocorrelation[lag]
    //                peakIndex = lag
    //            }
    //        }
    //
    //        if peakIndex == 0 { return 0 }
    //        let frequency = sampleRate / Float(peakIndex)
    //        return frequency
    //    }
    
    // MARK: - Pitch detection via FFT-based autocorrelation
    
    func detectFrequency(from buffer: AVAudioPCMBuffer) -> Float {
        var result: Float = 0.0
        let frameCount = Int(buffer.frameLength)
        guard
            let channelData = buffer.floatChannelData?[0],
            frameCount > 0,
            let setup = rt.fftSetup
        else { return 0 }
        
        let sampleRate = Float(buffer.format.sampleRate)
        let n = rt.fftLength  // power-of-two padded length (set in setupFFT)
        
        // ── 1. Window the signal (Hann) to reduce spectral leakage ──────────
        // Zero-pad into a power-of-two length buffer
        var windowed = [Float](repeating: 0, count: n)
        var hannWindow = [Float](repeating: 0, count: frameCount)
        vDSP_hann_window(&hannWindow, vDSP_Length(frameCount), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, hannWindow, 1, &windowed, 1, vDSP_Length(frameCount))
        
        // ── 2. Forward FFT → power spectrum ─────────────────────────────────
        // Split the real signal into even/odd for vDSP split-complex format
        var realPart = [Float](repeating: 0, count: n / 2)
        var imagPart = [Float](repeating: 0, count: n / 2)
        realPart.withUnsafeMutableBufferPointer { realP in
            imagPart.withUnsafeMutableBufferPointer { imagP in
                if let realP = realP.baseAddress, let imagP = imagP.baseAddress {
                    var spectrum = DSPSplitComplex(realp: realP, imagp: imagP)
                    
                    windowed.withUnsafeBytes { ptr in
                        let floatPtr = ptr.bindMemory(to: DSPComplex.self).baseAddress!
                        vDSP_ctoz(floatPtr, 2, &spectrum, 1, vDSP_Length(n / 2))
                    }
                    
                    vDSP_DFT_Execute(setup, spectrum.realp, spectrum.imagp, spectrum.realp, spectrum.imagp)
                    
                    // Compute power: |X(f)|²
                    var power = [Float](repeating: 0, count: n / 2)
                    vDSP_zvmags(&spectrum, 1, &power, 1, vDSP_Length(n / 2))
                    
                    // ── 3. NSDF autocorrelation via inverse FFT of power spectrum ────────
                    // Autocorrelation theorem: IFFT(|X(f)|²) = autocorrelation of x
                    // Set imaginary part to zero (power spectrum is real)
                    var powerImag = [Float](repeating: 0, count: n / 2)
                    power.withUnsafeMutableBufferPointer { power in
                        powerImag.withUnsafeMutableBufferPointer { powerImag in
                            if let powerImag = powerImag.baseAddress, let power = power.baseAddress {
                                var powerSpectrum = DSPSplitComplex(realp: power, imagp: powerImag)
                                
                                var acReal = [Float](repeating: 0, count: n / 2)
                                var acImag = [Float](repeating: 0, count: n / 2)
                                acReal.withUnsafeMutableBufferPointer { acReal in
                                    acImag.withUnsafeMutableBufferPointer { acImag in
                                        if let acReal = acReal.baseAddress, let acImag = acImag.baseAddress {
                                            var acComplex = DSPSplitComplex(realp: acReal, imagp: acImag)
                                            
                                            // Reuse the same DFT setup — forward DFT of real symmetric data = IDFT
                                            vDSP_DFT_Execute(setup, powerSpectrum.realp, powerSpectrum.imagp, acComplex.realp, acComplex.imagp)
                                            
                                            // Unpack split-complex → interleaved real output
                                            var autocorrelation = [Float](repeating: 0, count: n)
                                            autocorrelation.withUnsafeMutableBufferPointer { autocorrelation in
                                                if let autocorrelation = autocorrelation.baseAddress {
                                                    vDSP_ztoc(&acComplex, 1,
                                                              UnsafeMutablePointer<DSPComplex>(OpaquePointer(UnsafeMutableRawPointer(autocorrelation))),
                                                              2, vDSP_Length(n / 2))
                                                    
                                                    // Normalise by 1/n (vDSP FFT is unscaled)
                                                    var scale = 1.0 / Float(n)
                                                    vDSP_vsmul(autocorrelation, 1, &scale, autocorrelation, 1, vDSP_Length(n))
                                                    
                                                    // ── 4. Peak picking in the valid lag range ────────────────────────────
                                                    // Guitar range: ~82 Hz (low E) to ~1175 Hz (high e, 3 octaves up)
                                                    let minLag = Int(sampleRate / 1175)   // highest expected pitch
                                                    let maxLag = Int(sampleRate / 80)     // lowest expected pitch
                                                    let searchEnd = min(maxLag, n - 1)
                                                    guard minLag < searchEnd else { return 0 }
                                                    
                                                    // Find the first local minimum after zero-lag (end of the central peak)
                                                    var firstMin = minLag
                                                    for i in minLag..<searchEnd - 1 {
                                                        if autocorrelation[i] < autocorrelation[i + 1] {
                                                            firstMin = i
                                                            break
                                                        }
                                                    }
                                                    
                                                    // Find the highest subsequent peak (NSDF key maximum)
                                                    var peakIndex = firstMin
                                                    var peakValue: Float = autocorrelation[firstMin]
                                                    for lag in firstMin..<searchEnd {
                                                        if autocorrelation[lag] > peakValue {
                                                            peakValue = autocorrelation[lag]
                                                            peakIndex = lag
                                                        }
                                                    }
                                                    
                                                    guard peakIndex > 0, peakValue > 0 else { return 0 }
                                                    
                                                    // ── 5. Parabolic interpolation for sub-sample precision ──────────────
                                                    // Fits a parabola through the peak and its two neighbours
                                                    // to get a more accurate period estimate than integer lag alone.
                                                    let y1 = autocorrelation[peakIndex - 1]
                                                    let y2 = autocorrelation[peakIndex]
                                                    let y3 = autocorrelation[peakIndex + 1]
                                                    let refinedLag: Float
                                                    let denom = y1 - 2 * y2 + y3
                                                    if abs(denom) > 1e-6 {
                                                        let delta = 0.5 * (y1 - y3) / denom
                                                        refinedLag = Float(peakIndex) + delta
                                                    } else {
                                                        refinedLag = Float(peakIndex)
                                                    }
                                                    
                                                    result = sampleRate / refinedLag
                                                }
                                                
                                                return 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    /// Returns the nearest GuitarString note to the given frequency
    private func nearestNote(to frequency: Float) -> GuitarStringNote? {
        return GuitarStringNote.allCases.min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) })
    }
    
    private func toCents(detectedFrequency: Float, nearestNote: GuitarStringNote) -> Float {
        return 1200 * log2(detectedFrequency / nearestNote.frequency)
    }
}

// ── Real-time buffer container ───────────────────────────────────────────
// Plain struct, no @Observable, no class overhead.
// All fields are value types so no retain/release on the audio thread.
private struct RealTimeBuffers {
    var samples:         [Float] = []
    var autocorrelation: [Float] = []
    var hannWindow:      [Float] = []
    var fftReal:         [Float] = []
    var fftImag:         [Float] = []
    var fftSetup:        vDSP_DFT_Setup? = nil
    var fftLength:       Int = 0

    // Call once before the tap starts.
    // capacity = your installTap bufferSize, rounded up to next power of two.
    mutating func allocate(capacity: Int) {
        let n = nextPowerOfTwo(capacity)
        guard n != fftLength else { return }

        // Tear down old FFT plan if resizing
        if let old = fftSetup { vDSP_DFT_DestroySetup(old) }

        samples         = [Float](repeating: 0, count: n)
        autocorrelation = [Float](repeating: 0, count: n)
        hannWindow      = [Float](repeating: 0, count: capacity)
        fftReal         = [Float](repeating: 0, count: n / 2)
        fftImag         = [Float](repeating: 0, count: n / 2)
        fftSetup        = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(n), .FORWARD)
        fftLength       = n

        // Pre-compute the Hann window — it never changes
        vDSP_hann_window(&hannWindow, vDSP_Length(capacity), Int32(vDSP_HANN_NORM))
    }

    mutating func deallocate() {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
        fftSetup = nil
        fftLength = 0
        samples = []; autocorrelation = []; hannWindow = []
        fftReal = []; fftImag = []
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var p = 1; while p < n { p <<= 1 }; return p
    }
}

