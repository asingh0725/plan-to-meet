import SwiftUI

/// Shared color theme matching the iMessage extension and Expo app styles
enum Theme {
    // MARK: - Background Colors
    static let background = Color(red: 0.035, green: 0.035, blue: 0.043)
    static let cardBackground = Color(red: 0.063, green: 0.063, blue: 0.075)
    static let elevatedBackground = Color(red: 0.1, green: 0.1, blue: 0.12)

    // MARK: - Border Colors
    static let border = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let borderLight = Color(red: 0.2, green: 0.2, blue: 0.24)

    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.63, green: 0.63, blue: 0.67)
    static let textTertiary = Color(red: 0.4, green: 0.4, blue: 0.45)
    static let textDisabled = Color(red: 0.44, green: 0.44, blue: 0.48)

    // MARK: - Accent Colors
    static let accentBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let accentBlueDark = Color(red: 0.15, green: 0.40, blue: 0.85)
    static let accentGreen = Color.green
    static let accentOrange = Color.orange
    static let accentRed = Color.red

    // MARK: - Button Colors
    static let buttonDisabledBackground = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let buttonDisabledForeground = Color(red: 0.44, green: 0.44, blue: 0.48)

    // MARK: - Gradients
    static let blueGradient = LinearGradient(
        colors: [
            Color(red: 59/255, green: 130/255, blue: 246/255),
            Color(red: 37/255, green: 99/255, blue: 235/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
}

// MARK: - View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self
            .font(.body.weight(.semibold))
            .foregroundColor(isEnabled ? .white : Theme.buttonDisabledForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Theme.accentBlue : Theme.buttonDisabledBackground)
            .cornerRadius(Theme.cornerRadiusLarge)
    }

    func secondaryButtonStyle() -> some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundColor(Theme.accentBlue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.accentBlue.opacity(0.1))
            .cornerRadius(Theme.cornerRadiusSmall)
    }
}
