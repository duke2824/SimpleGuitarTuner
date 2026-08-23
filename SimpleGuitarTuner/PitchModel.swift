//
//  PitchModel.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/8/23.
//

import Foundation
import Pitchy
import PitchDetector

@Observable final class PitchModel: PitchEngineDelegate {
    var note: String = "N/A"
    var centOffset: Double = 0.0
    var isInTune: Bool {
        centOffset.isInfinite || centOffset.isNaN ? false : (centOffset.isNormal ? (abs(centOffset) < 5.0) : true)
    }
    var correctNote: String {
        centOffset > 5.0 ? "Tune down" : (centOffset < -5.0 ? "Tune up" : "In tune")
    }
    
    func pitchEngine(_ pitchEngine: PitchDetector.PitchEngine, didReceivePitch pitch: Pitchy.Pitch) {
        note = pitch.note.string
        centOffset = pitch.closestOffset.cents
        print("Note detected: \(note)")
        print("Cent offset: \(centOffset)")
    }
    
    func pitchEngine(_ pitchEngine: PitchDetector.PitchEngine, didReceiveError error: any Error) {
        print("Error: \(error)")
    }
    
    func pitchEngineWentBelowLevelThreshold(_ pitchEngine: PitchDetector.PitchEngine) {
        print("Below level threshold")
    }
    
    var pitchEngine: PitchEngine = PitchEngine()
    
    func config() {
        pitchEngine = PitchEngine(config: .init(estimationStrategy: .yin), delegate: self)
        pitchEngine.levelThreshold = -30.0
    }
    
    func start() {
        config()
        
        pitchEngine.start()
    }
}
