import AppKit
import SwiftUI

enum AppTheme {
    // Адаптивные цвета — системная светлая/тёмная тема, teal utility (не purple)
    static let bg = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.955, green: 0.965, blue: 0.975, alpha: 1),
        dark: NSColor(calibratedRed: 0.065, green: 0.08, blue: 0.10, alpha: 1)
    ))

    static let surface = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: NSColor(calibratedRed: 0.105, green: 0.125, blue: 0.155, alpha: 1)
    ))

    static let surfaceRaised = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.925, green: 0.938, blue: 0.955, alpha: 1),
        dark: NSColor(calibratedRed: 0.135, green: 0.16, blue: 0.195, alpha: 1)
    ))

    static let surfaceHover = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.90, green: 0.918, blue: 0.94, alpha: 1),
        dark: NSColor(calibratedRed: 0.155, green: 0.185, blue: 0.23, alpha: 1)
    ))

    static let border = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.09),
        dark: NSColor(calibratedWhite: 1, alpha: 0.09)
    ))

    static let borderStrong = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.15),
        dark: NSColor(calibratedWhite: 1, alpha: 0.15)
    ))

    static let accent = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.50, alpha: 1),
        dark: NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.68, alpha: 1)
    ))

    static let accentSoft = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.50, alpha: 0.11),
        dark: NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.68, alpha: 0.16)
    ))

    static let warn = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.78, green: 0.48, blue: 0.08, alpha: 1),
        dark: NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.30, alpha: 1)
    ))

    static let danger = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.82, green: 0.22, blue: 0.20, alpha: 1),
        dark: NSColor(calibratedRed: 0.93, green: 0.40, blue: 0.38, alpha: 1)
    ))

    static let text = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.14, alpha: 1),
        dark: NSColor(calibratedWhite: 1, alpha: 0.94)
    ))

    static let textSecondary = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.50),
        dark: NSColor(calibratedWhite: 1, alpha: 0.56)
    ))

    static let textTertiary = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.34),
        dark: NSColor(calibratedWhite: 1, alpha: 0.36)
    ))

    static let onAccent = Color(nsColor: .dynamic(
        light: NSColor.white,
        dark: NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.10, alpha: 1)
    ))

    static let spaceXXS: CGFloat = 4
    static let spaceXS: CGFloat = 8
    static let spaceSM: CGFloat = 12
    static let spaceMD: CGFloat = 16
    static let spaceLG: CGFloat = 20
    static let spaceXL: CGFloat = 28
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let pageInset: CGFloat = 22
    static let blockGap: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let controlHeight: CGFloat = 34

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static var nsWindowBackground: NSColor {
        .dynamic(
            light: NSColor(calibratedRed: 0.955, green: 0.965, blue: 0.975, alpha: 1),
            dark: NSColor(calibratedRed: 0.065, green: 0.08, blue: 0.10, alpha: 1)
        )
    }

    static func cardBackground(hovered: Bool = false, selected: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: radiusMD, style: .continuous)
            .fill(hovered ? surfaceHover : surface)
            .overlay(
                RoundedRectangle(cornerRadius: radiusMD, style: .continuous)
                    .strokeBorder(
                        selected ? accent.opacity(0.40) : border,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(hovered ? 0.06 : 0.03),
                radius: hovered ? 8 : 3,
                y: hovered ? 3 : 1
            )
    }
}

private extension NSColor {
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.surfaceHover : AppTheme.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .fill(enabled ? AppTheme.accent : AppTheme.surfaceRaised)
                    .shadow(
                        color: enabled ? AppTheme.accent.opacity(configuration.isPressed ? 0.15 : 0.28) : .clear,
                        radius: configuration.isPressed ? 2 : 6,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1)
            .opacity(enabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
