import SwiftUI

extension Color {
    static let dreamBackgroundStart = Color(hex: "0F172A") // Midnight Blue
    static let dreamBackgroundEnd = Color(hex: "301934")   // Deep Purple
    static let dreamCard = Color.white.opacity(0.1)
    static let dreamAccent = Color(hex: "A366FF")          // Bright Purple
    static let dreamText = Color.white
    static let dreamTextSecondary = Color.white.opacity(0.7)
    
    // Hex init helper
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (0, 0, 0, 0) // 透明な色を返す
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Font {
    static let dreamTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let dreamHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let dreamBody = Font.system(size: 16, weight: .regular, design: .default)
    static let dreamCaption = Font.system(size: 12, weight: .medium, design: .default)
}

struct StarField: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<30) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.2...0.7)))
                    .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...proxy.size.width),
                        y: CGFloat.random(in: 0...proxy.size.height)
                    )
            }
        }
        .ignoresSafeArea()
    }
}

struct DreamBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.dreamBackgroundStart, .dreamBackgroundEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            StarField()
            
            content
        }
    }
}

extension View {
    func dreamBackground() -> some View {
        self.modifier(DreamBackground())
    }
}
