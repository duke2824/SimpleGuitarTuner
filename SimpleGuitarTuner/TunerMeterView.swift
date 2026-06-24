//
//  TunerMeterView.swift
//  SimpleGuitarTuner
//
//  Created for analog-style tuning meter UI
//

import SwiftUI

/// An analog tuning meter view with arc, moving needle, and note display.
struct TunerMeterView: View {
    /// The cents offset from the reference note, e.g. -50 (flat) to +50 (sharp)
    var cents: Double
    /// The detected note name, e.g. "B2"
    var note: String
    /// Whether the tuning is correct (within a reasonable tolerance)
    var isInTune: Bool
    /// Error string, e.g. "TUNE UP" or "TUNE DOWN", or nil for in-tune
    var errorString: String?
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                ZStack {
                    let r = min(geo.size.width, geo.size.height) * 0.45
                    let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                    let dynamicSpacing = geo.size.width < geo.size.height ? 128.0 : 32.0
                    
                    ShadowArc(radius: r - 9)
                        .stroke(Color(.systemGray3).opacity(0.35), lineWidth: 3)
                        .blur(radius: 1)
                    
                    ForEach([-50, -20, 0, 20, 50], id: \.self) { mark in
                        TunerTick(angle: angle(for: Double(mark)), label: "\(mark)")
                    }
                    
                    Needle(angle: angle(for: cents), color: needleColor)
                        .offset(x: center.x - geo.size.width/2, y: center.y - geo.size.height/2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: cents)
                    
                    VStack(spacing: dynamicSpacing) {
                        Text(note)
                        Text(errorString ?? "")
                    }
                    .offset(y: geo.size.width < geo.size.height ? r : r*0.5)
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
    
    // Helper: map cents (-50 to 50) to degree (-120 to +120)
    private func angle(for cents: Double) -> Double {
        return (cents / 50.0) * 60.0
    }
    
    private var needleColor: Color {
        isInTune ? Color.green : Color.red
    }
}

// MARK: - Arc Shape
struct ShadowArc: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle(degrees: -150)
        let endAngle = Angle(degrees: -30)
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

// MARK: - Needle View
struct Needle: View {
    var angle: Double
    var color: Color
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 4, height: 88)
            .cornerRadius(2)
            .offset(y: -44)
            .rotationEffect(.degrees(angle))
            .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Tick Marks
struct TunerTick: View {
    var angle: Double
    var label: String
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) * 0.45
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let tickLength: CGFloat = label == "0" ? 18 : 12
            let thickness: CGFloat = label == "0" ? 3 : 1.5
            let start = point(center: center, radius: r - tickLength, angle: angle)
            let end = point(center: center, radius: r, angle: angle)
            let labelPoint = point(center: center, radius: r - tickLength - 16, angle: angle)
            
            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(label == "0" ? Color.primary : Color(.systemGray3), lineWidth: thickness)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(label == "0" ? .primary : .secondary)
                    .position(labelPoint)
            }
        }
    }
    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let rad = (angle - 90) * .pi / 180
        return CGPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
    }
}

// MARK: - Preview
#Preview {
        TunerMeterView(cents: 20, note: "B2", isInTune: false, errorString: "TUNE UP")
            .preferredColorScheme(.light)
}
#Preview {
    TunerMeterView(cents: 0, note: "B2", isInTune: true)
        .preferredColorScheme(.light)
}

