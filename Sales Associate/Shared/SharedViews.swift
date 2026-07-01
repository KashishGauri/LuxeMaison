import SwiftUI

struct ProductImageView: View {
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.selected

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(1.06)
                    .offset(y: -8)
            }
            .clipped()
        }
    }
}
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.line.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}

enum Theme {
    static let ink = Color(red: 0.15, green: 0.13, blue: 0.11)
    static let muted = Color(red: 0.54, green: 0.49, blue: 0.44)
    static let gold = Color(red: 0.70, green: 0.54, blue: 0.33)
    static let line = Color(red: 0.82, green: 0.78, blue: 0.73).opacity(0.35)
    static let selected = Color(red: 0.94, green: 0.90, blue: 0.85)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.98, blue: 0.97),
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.94, green: 0.91, blue: 0.87)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.68, green: 0.52, blue: 0.31),
            Color(red: 0.78, green: 0.63, blue: 0.42)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

