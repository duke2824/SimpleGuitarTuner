//
//  ContentView.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/24.
//

import SwiftUI

struct ContentView: View {
    private var audioManager = AudioManager()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear() {
            audioManager.start()
        }
    }
}

#Preview {
    ContentView()
}
