import AppKit
import SwiftUI

enum AppTheme {
    // Адаптивные цвета — следуют системной светлой/тёмной теме
    static let bg = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1),
        dark: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.11, alpha: 1)
    ))

    static let surface = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.16, alpha: 1)
    ))

    static let surfaceRaised = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.21, alpha: 1)
    ))

    static let surfaceHover = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.94, alpha: 1),
        dark: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.24, alpha: 1)
    ))

    static let border = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.10),
        dark: NSColor(calibratedWhite: 1, alpha: 0.08)
    ))

    static let borderStrong = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.16),
        dark: NSColor(calibratedWhite: 1, alpha: 0.14)
    ))

    static let accent = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.52, alpha: 1),
        dark: NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.66, alpha: 1)
    ))

    static let accentSoft = Color(nsColor: .dynamic(
        light: NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.52, alpha: 0.12),
        dark: NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.66, alpha: 0.14)
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
        light: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1),
        dark: NSColor(calibratedWhite: 1, alpha: 0.95)
    ))

    static let textSecondary = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.52),
        dark: NSColor(calibratedWhite: 1, alpha: 0.58)
    ))

    static let textTertiary = Color(nsColor: .dynamic(
        light: NSColor(calibratedWhite: 0, alpha: 0.36),
        dark: NSColor(calibratedWhite: 1, alpha: 0.38)
    ))

    /// Текст на акцентной кнопке (удалить / primary CTA).
    static let onAccent = Color(nsColor: .dynamic(
        light: NSColor.white,
        dark: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.11, alpha: 1)
    ))

    // 8pt grid — удобные отступы по всему UI
    static let spaceXXS: CGFloat = 4
    static let spaceXS: CGFloat = 8
    static let spaceSM: CGFloat = 12
    static let spaceMD: CGFloat = 16
    static let spaceLG: CGFloat = 20
    static let spaceXL: CGFloat = 28
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    /// Горизонтальные поля окна
    static let pageInset: CGFloat = 20
    /// Вертикальный ритм между блоками
    static let blockGap: CGFloat = 14
    /// Внутренний padding карточек
    static let cardPadding: CGFloat = 14
    /// Минимальная высота кликабельных контролов
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

    /// Фон окна для NSWindow — тоже динамический.
    static var nsWindowBackground: NSColor {
        .dynamic(
            light: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1),
            dark: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.11, alpha: 1)
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
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .fill(enabled ? AppTheme.accent : AppTheme.surfaceRaised)
            )
            .opacity(configuration.isPressed && enabled ? 0.88 : 1)
    }
}
