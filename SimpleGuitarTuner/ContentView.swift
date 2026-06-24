//
//  ContentView.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/24.
//

import SwiftUI

struct ContentView: View {
    @State private var audioManager = AudioManager()
    
    var body: some View {
        TunerMeterView(cents: audioManager.differenceCents ?? 0, note: audioManager.nearestNote?.rawValue ?? "N/A", isInTune: true, errorString: nil)
        .padding()
        .onAppear() {
            audioManager.start()
        }
    }
}

#Preview {
    ContentView()
}
