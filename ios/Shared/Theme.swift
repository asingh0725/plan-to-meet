import SwiftUI

/// Shared color theme matching the iMessage extension and Expo app styles
enum Theme {
    // MARK: - Background Colors
    static let background = Color(red: 0.02, green: 0.03, blue: 0.06)
    static let cardBackground = Color.white.opacity(0.06)
    static let elevatedBackground = Color(red: 0.08, green: 0.1, blue: 0.16)

    // MARK: - Border Colors
    static let border = Color.white.opacity(0.15)
    static let borderLight = Color.white.opacity(0.25)

    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let textSecondary = Color(red: 0.73, green: 0.78, blue: 0.86)
    static let textTertiary = Color(red: 0.52, green: 0.58, blue: 0.7)
    static let textDisabled = Color(red: 0.44, green: 0.48, blue: 0.58)

    // MARK: - Accent Colors
    static let accentBlue = Color(red: 0.49, green: 0.64, blue: 1.0)
    static let accentBlueDark = Color(red: 0.33, green: 0.5, blue: 0.95)
    static let accentGreen = Color.green
    static let accentOrange = Color.orange
    static let accentRed = Color.red

    // MARK: - Button Colors
    static let buttonDisabledBackground = Color.white.opacity(0.08)
    static let buttonDisabledForeground = Color(red: 0.6, green: 0.65, blue: 0.74)

    // MARK: - Gradients
    static let blueGradient = LinearGradient(
        colors: [
            Color(red: 0.49, green: 0.64, blue: 1.0),
            Color(red: 0.37, green: 0.53, blue: 0.95)
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
            .background(
                ZStack {
                    Theme.cardBackground
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(Theme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium - 2)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 12)
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

struct AuthKitBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.03, green: 0.05, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.35, green: 0.45, blue: 1.0, opacity: 0.22),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: size.width * 0.6
                )
                Canvas { context, _ in
                    var gridPath = Path()
                    let spacing: CGFloat = 80
                    stride(from: 0, through: size.width, by: spacing).forEach { x in
                        gridPath.move(to: CGPoint(x: x, y: 0))
                        gridPath.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    stride(from: 0, through: size.height, by: spacing).forEach { y in
                        gridPath.move(to: CGPoint(x: 0, y: y))
                        gridPath.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(gridPath, with: .color(Color.white.opacity(0.05)), lineWidth: 1)

                    var dotPath = Path()
                    let dotSpacing: CGFloat = 140
                    stride(from: 20, through: size.width, by: dotSpacing).forEach { x in
                        stride(from: 30, through: size.height, by: dotSpacing).forEach { y in
                            dotPath.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                        }
                    }
                    context.fill(dotPath, with: .color(Color.white.opacity(0.12)))
                }
            }
            .ignoresSafeArea()
        }
    }
}
