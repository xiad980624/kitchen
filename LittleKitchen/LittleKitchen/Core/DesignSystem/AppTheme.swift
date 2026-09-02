import SwiftUI

enum AppTheme {
    static let cream = Color(red: 1.0, green: 0.973, blue: 0.929)
    static let paper = Color.white
    static let ink = Color(red: 0.216, green: 0.2, blue: 0.176)
    static let muted = Color(red: 0.549, green: 0.522, blue: 0.482)
    static let sage = Color(red: 0.373, green: 0.608, blue: 0.478)
    static let sageSoft = Color(red: 0.882, green: 0.941, blue: 0.91)
    static let carrot = Color(red: 0.969, green: 0.647, blue: 0.29)
    static let carrotSoft = Color(red: 1.0, green: 0.941, blue: 0.843)
    static let tomato = Color(red: 0.941, green: 0.42, blue: 0.329)
    static let tomatoSoft = Color(red: 1.0, green: 0.898, blue: 0.875)
    static let line = Color(red: 0.933, green: 0.906, blue: 0.863)
}

struct AppCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.05), radius: 10, y: 4)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCard())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.sage.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityAddTraits(.isStaticText)
    }
}
