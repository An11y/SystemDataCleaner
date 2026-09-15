import AppKit
import SwiftUI

/// Рендер UI в PNG без Screen Recording (offscreen NSWindow + cacheDisplay).
enum ScreenshotExporter {
    static func directoryFromArgs(_ args: [String] = CommandLine.arguments) -> String? {
        guard let idx = args.firstIndex(of: "--export-screenshots") else { return nil }
        if args.indices.contains(idx + 1), !args[idx + 1].hasPrefix("-") {
            return args[idx + 1]
        }
        return "docs/screenshots"
    }

    @MainActor
    static func run(outputDirectory: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let out = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        } catch {
            fputs("mkdir failed: \(error)\n", stderr)
            exit(1)
        }

        let model = CleanerViewModel()
        model.applyDemoSnapshot()

        let main = ContentView()
            .environmentObject(model)
            .frame(width: 960, height: 720)

        capture(
            view: main,
            size: NSSize(width: 960, height: 720),
            scale: 2,
            to: out.appendingPathComponent("main.png")
        )

        let confirm = ConfirmSheet(model: model)
            .frame(width: 440, height: 420)
        capture(
            view: confirm,
            size: NSSize(width: 440, height: 420),
            scale: 2,
            to: out.appendingPathComponent("confirm.png")
        )

        print("Screenshots → \(out.path)")
        exit(0)
    }

    @MainActor
    private static func capture<V: View>(view: V, size: NSSize, scale: CGFloat, to url: URL) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()

        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()

        let pixelSize = NSSize(width: size.width * scale, height: size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fputs("bitmap failed: \(url.lastPathComponent)\n", stderr)
            exit(1)
        }
        rep.size = size

        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fputs("png failed: \(url.lastPathComponent)\n", stderr)
            exit(1)
        }
        do {
            try png.write(to: url)
            print("OK \(url.lastPathComponent) \(rep.pixelsWide)×\(rep.pixelsHigh)")
        } catch {
            fputs("write failed: \(error)\n", stderr)
            exit(1)
        }
        window.orderOut(nil)
        window.contentView = nil
    }
}
