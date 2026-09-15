import AppKit
import SwiftUI

@main
struct SystemDataCleanerApp: App {
    @StateObject private var model = CleanerViewModel()

    init() {
        if let dir = ScreenshotExporter.directoryFromArgs() {
            ScreenshotExporter.run(outputDirectory: dir)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 860, minHeight: 620)
                .background(AppAppearance())
        }
        // Обычный title bar + compact toolbar = нормальные системные отступы
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 960, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button(L10n.scan) { model.scan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button(L10n.deleteSelectedMenu) { model.requestClean() }
                    .keyboardShortcut(.delete, modifiers: .command)
                Divider()
                Button(L10n.safeOnly) { model.selectSafeOnly() }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                Button(L10n.smartClean) { model.selectSmartRecommended() }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button(L10n.deselectAll) { model.deselectAll() }
                    .keyboardShortcut("0", modifiers: [.command, .shift])
                Divider()
                Button(L10n.collapseDetails) { model.collapseExpanded() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

private struct AppAppearance: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { Self.style(v.window) }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.style(nsView.window) }
    }

    private static func style(_ window: NSWindow?) {
        guard let window else { return }
        window.appearance = nil
        window.backgroundColor = AppTheme.nsWindowBackground
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .line
        }
    }
}
