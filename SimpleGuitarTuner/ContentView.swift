//
//  ContentView.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/24.
//

import SwiftUI

struct ContentView: View {
    @State private var pitchModel = PitchModel()
    
    var body: some View {
        TunerMeterView(cents: pitchModel.centOffset,
                       note: pitchModel.note,
                       isInTune: pitchModel.isInTune,
                       errorString: pitchModel.correctNote)
        .padding()
        .onAppear() {
            pitchModel.start()
        }
    }
}

#Preview {
    ContentView()
}
