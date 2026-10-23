import SwiftUI

struct OrbyFace: View {
    var provider: String
    var sleeping = false
    var attention = false
    private var accent: Color {
        switch provider {
        case "Claude", "Claude Code": return .orange
        case "ChatGPT", "Codex": return .blue
        case "Gemini": return .purple
        default: return .gray
        }
    }
    private var halo: AngularGradient {
        AngularGradient(colors: provider == "Gemini" ? [.blue, .cyan, .purple, .pink, .blue] : [accent, accent.opacity(0.35), accent], center: .center)
    }
    var body: some View {
        ZStack {
            Circle().stroke(halo, lineWidth: 2).opacity(sleeping ? 0.25 : 0.8).padding(1)
            Circle().fill(Color(white: 0.91)).padding(5)
            HStack(spacing: 9) {
                eye; eye
            }
            if attention {
                Circle().fill(accent).frame(width: 5, height: 5).offset(x: -17, y: -17)
            }
        }.frame(width: 48, height: 48).accessibilityLabel(sleeping ? "Orby resting" : "Orby awake")
    }
    private var eye: some View {
        Capsule().fill(.black).frame(width: sleeping ? 8 : 4, height: sleeping ? 2 : 8)
    }
}
