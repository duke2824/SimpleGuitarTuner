//
//  ContentView.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/24.
//

import SwiftUI

struct ContentView: View {
    @State private var pitchModel = PitchModel()
    /// Whether the tuning is correct for at least amount of duration
    @State var isLockedIn: Bool = false
    private let lockInDuration: Duration = .seconds(1.5)
    
    var body: some View {
        VStack {
            TunerMeterView(cents: pitchModel.centOffset,
                           note: pitchModel.note,
                           isInTune: pitchModel.isInTune,
                           errorString: pitchModel.correctNote)
            .padding()
            .onAppear() {
                pitchModel.start()
            }
        }
        .sensoryFeedback(.success, trigger: isLockedIn)
        .task(id: pitchModel.isInTune, {
            guard pitchModel.isInTune else {
                isLockedIn = false
                return
            }
            
            do {
                try await Task.sleep(for: lockInDuration)
                isLockedIn = true
                print("Fire feedback")
            } catch {
                // Do nothing, don't flip isLockedIn
                print("Reset")
            }
        })
    }
}

#Preview {
    ContentView()
}
