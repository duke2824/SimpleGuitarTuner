//
//  Reference.swift
//  SimpleGuitarTuner
//
//  Created by Nguyen Duc Anh on 2026/5/29.
//

enum GuitarString: String, CaseIterable {
    case E2, A2, D3, G3, B3, E4

    var frequency: Float {
        switch self {
        case .E2: return 82.41
        case .A2: return 110.00
        case .D3: return 146.83
        case .G3: return 196.00
        case .B3: return 246.94
        case .E4: return 329.63
        }
    }
}
