import AppKit
import Foundation
import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published var categories: [CategoryScan] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusText = "Готов к сканированию «Системных данных»."
    @Published var lastFreed: Int64?
    @Published var errorMessage: String?
    @Published var showConfirm = false
    @Published var expandedCategory: CleanCategoryID?
    @Published var searchText = ""
    @Published var listFilter: ListFilter = .withSize
    @Published var sortMode: SortMode = .size
    @Published var scanProgress: Double = 0
    @Published var freeDiskBytes: Int64?
    @Published var needsFullDiskAccess = false
    @Published var hideFdaBanner = false
    @Published var showSuccessBanner = false
    @Published var successMessage = ""
    @Published var collapsedSections: Set<CleanSection> = []
    @Published var freeDiskBeforeClean: Int64?

    /// Не запускать scan/FDA при рендере README-скриншотов.
    var suppressLifecycleHooks = false

    private let engine = CleanerEngine()
    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?
    private var successHideTask: Task<Void, Never>?

    private let smartCautionThreshold: Int64 = 100_000_000

    var selectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.selectedBytes }
    }

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.byteCount }
    }

    var maxCategoryBytes: Int64 {
        max(categories.map(\.byteCount).max() ?? 1, 1)
    }

    var selectedCount: Int {
        categories.reduce(0) { $0 + $1.selectedItemCount }
    }

    var selectedCategoryCount: Int {
        categories.filter(\.hasSelection).count
    }

    var hasSelection: Bool {
        categories.contains(where: \.hasSelection)
    }

    var showFdaBanner: Bool {
        needsFullDiskAccess && !hideFdaBanner
    }

    var isBusy: Bool {
        isScanning || isCleaning
    }

    var selectedPreview: [(title: String, bytes: Int64, risk: RiskLevel)] {
        categories
            .filter(\.hasSelection)
            .sorted { $0.selectedBytes > $1.selectedBytes }
            .prefix(8)
            .map { ($0.category.title, $0.selectedBytes, $0.category.risk) }
    }

    var selectionShare: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(selectedBytes) / Double(totalBytes))
    }

    var formattedSelected: String {
        ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var formattedFreeDisk: String? {
        guard let freeDiskBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: freeDiskBytes, countStyle: .file)
    }

    var nonEmptyCount: Int {
        categories.filter { $0.byteCount > 0 }.count
    }

    func filterCount(_ filter: ListFilter) -> Int {
        categories.filter { matchesFilter($0, filter) }.count
    }

    private func matchesFilter(_ scan: CategoryScan, _ filter: ListFilter) -> Bool {
        switch filter {
        case .withSize: return scan.byteCount > 0 || scan.exists
        case .selected: return scan.hasSelection
        case .all: return true
        case .risky: return scan.category.risk != .safe && (scan.byteCount > 0 || scan.exists)
        }
    }

    var filteredCategories: [CategoryScan] {
        let filtered = categories.filter { scan in
            scan.category.matches(searchText) && matchesFilter(scan, listFilter)
        }
        return sort(filtered)
    }

    var sections: [(CleanSection, [CategoryScan])] {
        CleanSection.allCases.compactMap { section in
            let items = filteredCategories.filter { $0.category.section == section }
            return items.isEmpty ? nil : (section, items)
        }
    }

    var recommendedBytes: Int64 {
        categories.reduce(0) { sum, scan in
            sum + smartBytes(for: scan)
        }
    }

    var formattedRecommended: String {
        ByteCountFormatter.string(fromByteCount: recommendedBytes, countStyle: .file)
    }

    private func smartBytes(for scan: CategoryScan) -> Int64 {
        switch scan.category.risk {
        case .danger:
            return 0
        case .safe:
            return scan.byteCount
        case .caution:
            return scan.byteCount >= smartCautionThreshold ? scan.byteCount : 0
        }
    }

    func isSectionCollapsed(_ section: CleanSection) -> Bool {
        collapsedSections.contains(section)
    }

    func toggleSection(_ section: CleanSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedSections.contains(section) {
                collapsedSections.remove(section)
            } else {
                collapsedSections.insert(section)
            }
        }
    }

    var confirmSummary: String {
        let risky = categories.filter { $0.hasSelection && $0.category.risk != .safe }.count
        var parts = ["Будет удалено \(selectedCount) пунктов (~ \(formattedSelected))."]
        if risky > 0 {
            parts.append("Среди них \(risky) рискованных категорий.")
        }
        parts.append("Отменить будет нельзя.")
        return parts.joined(separator: " ")
    }

    struct ConfirmRiskGroup: Identifiable {
        let id: RiskLevel
        let rows: [(title: String, bytes: Int64)]
        var risk: RiskLevel { id }
    }

    var confirmByRisk: [ConfirmRiskGroup] {
        let groups: [RiskLevel] = [.safe, .caution, .danger]
        return groups.compactMap { risk -> ConfirmRiskGroup? in
            let rows: [(title: String, bytes: Int64)] = categories
                .filter { $0.hasSelection && $0.category.risk == risk }
                .sorted { $0.selectedBytes > $1.selectedBytes }
                .map { (title: $0.category.title, bytes: $0.selectedBytes) }
            guard !rows.isEmpty else { return nil }
            return ConfirmRiskGroup(id: risk, rows: rows)
        }
    }

    private func sort(_ items: [CategoryScan]) -> [CategoryScan] {
        switch sortMode {
        case .size:
            return items.sorted { $0.byteCount > $1.byteCount }
        case .name:
            return items.sorted {
                $0.category.title.localizedCaseInsensitiveCompare($1.category.title) == .orderedAscending
            }
        case .risk:
            let rank: (RiskLevel) -> Int = {
                switch $0 {
                case .danger: return 0
                case .caution: return 1
                case .safe: return 2
                }
            }
            return items.sorted {
                let lr = rank($0.category.risk)
                let rr = rank($1.category.risk)
                if lr != rr { return lr < rr }
                return $0.byteCount > $1.byteCount
            }
        }
    }

    func refreshPermissions() {
        Task {
            let fda = await engine.hasFullDiskAccess()
            let free = await engine.freeDiskBytes()
            needsFullDiskAccess = !fda
            freeDiskBytes = free
        }
    }

    func openFullDiskAccessSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    func collapseExpanded() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            expandedCategory = nil
        }
    }

    func toggleCategory(_ id: CleanCategoryID) {
        guard let i = categories.firstIndex(where: { $0.category == id }) else { return }
        let turnOn = !categories[i].isSelected
        withAnimation(.easeInOut(duration: 0.15)) {
            if categories[i].items.isEmpty {
                categories[i].isSelected = turnOn
            } else {
                categories[i].setAllItems(selected: turnOn)
            }
        }
    }

    func toggleItem(category id: CleanCategoryID, itemId: UUID) {
        guard let ci = categories.firstIndex(where: { $0.category == id }),
              let ii = categories[ci].items.firstIndex(where: { $0.id == itemId }) else { return }
        categories[ci].items[ii].isSelected.toggle()
        categories[ci].syncParentFromItems()
    }

    func selectSafeOnly() {
        withAnimation(.easeInOut(duration: 0.15)) {
            for i in categories.indices {
                let on = categories[i].category.selectedByDefault && categories[i].byteCount > 0
                if categories[i].items.isEmpty {
                    categories[i].isSelected = on
                } else {
                    categories[i].setAllItems(selected: on)
                }
            }
        }
    }

    func selectSmartRecommended() {
        withAnimation(.easeInOut(duration: 0.15)) {
            for i in categories.indices {
                let scan = categories[i]
                let on: Bool
                switch scan.category.risk {
                case .danger:
                    on = false
                case .safe:
                    on = scan.byteCount > 0 || scan.exists
                case .caution:
                    on = scan.byteCount >= smartCautionThreshold
                }
                if scan.items.isEmpty {
                    categories[i].isSelected = on
                } else if on {
                    if scan.category.risk == .caution {
                        // Крупные caution — выбираем только крупные подпункты
                        for j in categories[i].items.indices {
                            categories[i].items[j].isSelected =
                                categories[i].items[j].byteCount >= smartCautionThreshold
                                    || categories[i].items[j].byteCount == scan.byteCount
                        }
                        // Если нет крупных подпунктов, но категория сама крупная — все
                        if !categories[i].items.contains(where: \.isSelected) {
                            categories[i].setAllItems(selected: true)
                        } else {
                            categories[i].syncParentFromItems()
                        }
                    } else {
                        categories[i].setAllItems(selected: true)
                    }
                } else {
                    categories[i].setAllItems(selected: false)
                }
            }
        }
        statusText = hasSelection
            ? "Умная очистка: \(formattedSelected)"
            : "Для умной очистки пока мало безопасного мусора"
    }

    func selectAllJunk() {
        withAnimation(.easeInOut(duration: 0.15)) {
            for i in categories.indices where categories[i].byteCount > 0 || categories[i].exists {
                if categories[i].items.isEmpty {
                    categories[i].isSelected = true
                } else {
                    categories[i].setAllItems(selected: true)
                }
            }
        }
    }

    func deselectAll() {
        withAnimation(.easeInOut(duration: 0.15)) {
            for i in categories.indices {
                if categories[i].items.isEmpty {
                    categories[i].isSelected = false
                } else {
                    categories[i].setAllItems(selected: false)
                }
            }
        }
    }

    func cancelWork() {
        scanTask?.cancel()
        cleanTask?.cancel()
        scanTask = nil
        cleanTask = nil
        isScanning = false
        isCleaning = false
        statusText = categories.isEmpty ? "Скан отменён" : "Операция отменена · найдено \(formattedTotal)"
    }

    func dismissSuccess() {
        withAnimation(.easeOut(duration: 0.2)) {
            showSuccessBanner = false
        }
    }

    private func presentSuccess(_ message: String) {
        successMessage = message
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showSuccessBanner = true
        }
        NSSound(named: "Glass")?.play()
        successHideTask?.cancel()
        successHideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            dismissSuccess()
        }
    }

    func scan() {
        guard !isBusy else { return }
        isScanning = true
        errorMessage = nil
        lastFreed = nil
        showSuccessBanner = false
        scanProgress = 0
        statusText = "Сканирование…"
        refreshPermissions()

        let previous = selectionSnapshot()
        let hadPrevious = !previous.parents.isEmpty || !previous.items.isEmpty

        scanTask = Task {
            let result = await engine.scanAll(
                progress: { [weak self] done, total, name in
                    Task { @MainActor in
                        guard let self, !Task.isCancelled else { return }
                        self.scanProgress = total > 0 ? Double(done) / Double(total) : 0
                        let found = self.totalBytes > 0
                            ? " · найдено уже \(self.formattedTotal)"
                            : ""
                        self.statusText = "Сканирую \(done)/\(total): \(name)\(found)"
                    }
                },
                onPartial: { [weak self] partial in
                    Task { @MainActor in
                        guard let self, self.isScanning else { return }
                        if hadPrevious {
                            self.categories = self.applySelection(previous, to: partial)
                        } else {
                            self.categories = partial
                        }
                    }
                }
            )

            guard !Task.isCancelled else {
                isScanning = false
                return
            }

            categories = applySelection(previous, to: result)
            isScanning = false
            scanProgress = 1
            freeDiskBytes = await engine.freeDiskBytes()
            statusText = totalBytes > 0
                ? "Найдено \(formattedTotal) · \(nonEmptyCount) категорий с данными"
                : "Лишнего почти нет — диск в порядке"
            scanTask = nil
        }
    }

    func requestClean() {
        guard hasSelection else {
            errorMessage = CleanerError.nothingSelected.localizedDescription
            return
        }
        showConfirm = true
    }

    func confirmClean() {
        showConfirm = false
        guard !isBusy else { return }
        isCleaning = true
        errorMessage = nil
        showSuccessBanner = false
        statusText = "Очистка…"
        scanProgress = 0
        let snapshot = categories
        freeDiskBeforeClean = freeDiskBytes
        let beforeFree = freeDiskBytes

        cleanTask = Task {
            do {
                let freed = try await engine.clean(snapshot) { [weak self] done, total, name in
                    Task { @MainActor in
                        self?.scanProgress = total > 0 ? Double(done) / Double(total) : 0
                        self?.statusText = "Чищу \(done)/\(total): \(name)"
                    }
                }
                guard !Task.isCancelled else {
                    isCleaning = false
                    return
                }
                lastFreed = freed
                statusText = "Пересчёт…"
                let previous = selectionSnapshot()
                let result = await engine.scanAll(
                    progress: { [weak self] done, total, name in
                        Task { @MainActor in
                            self?.scanProgress = total > 0 ? Double(done) / Double(total) : 0
                            self?.statusText = "Пересчёт \(done)/\(total): \(name)"
                        }
                    },
                    onPartial: { [weak self] partial in
                        Task { @MainActor in
                            self?.categories = partial
                        }
                    }
                )
                categories = applySelection(previous, to: result)
                freeDiskBytes = await engine.freeDiskBytes()
                isCleaning = false

                var msg = "Освобождено \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))"
                if let beforeFree, let after = freeDiskBytes, after > beforeFree {
                    let delta = after - beforeFree
                    let beforeStr = ByteCountFormatter.string(fromByteCount: beforeFree, countStyle: .file)
                    let afterStr = ByteCountFormatter.string(fromByteCount: after, countStyle: .file)
                    msg += " · диск \(beforeStr) → \(afterStr) (+\(ByteCountFormatter.string(fromByteCount: delta, countStyle: .file)))"
                }
                statusText = "Готово. \(msg)"
                presentSuccess(msg)
            } catch {
                isCleaning = false
                errorMessage = error.localizedDescription
                statusText = "Очистка прервана"
            }
            cleanTask = nil
        }
    }

    // MARK: - Selection persistence

    private struct SelectionKey: Hashable {
        let category: CleanCategoryID
        let path: String
    }

    private func selectionSnapshot() -> (parents: Set<CleanCategoryID>, items: Set<SelectionKey>) {
        var parents = Set<CleanCategoryID>()
        var items = Set<SelectionKey>()
        for scan in categories {
            if scan.items.isEmpty {
                if scan.isSelected { parents.insert(scan.category) }
            } else {
                for item in scan.items where item.isSelected {
                    items.insert(SelectionKey(category: scan.category, path: item.path))
                }
            }
        }
        return (parents, items)
    }

    private func applySelection(
        _ previous: (parents: Set<CleanCategoryID>, items: Set<SelectionKey>),
        to scans: [CategoryScan]
    ) -> [CategoryScan] {
        let hadPrevious = !previous.parents.isEmpty || !previous.items.isEmpty
        return scans.map { scan in
            var copy = scan
            if !hadPrevious { return copy }
            if copy.items.isEmpty {
                copy.isSelected = previous.parents.contains(copy.category) && (copy.byteCount > 0 || copy.exists)
            } else {
                for i in copy.items.indices {
                    let key = SelectionKey(category: copy.category, path: copy.items[i].path)
                    if previous.items.contains(key) {
                        copy.items[i].isSelected = true
                    } else {
                        copy.items[i].isSelected = false
                    }
                }
                copy.syncParentFromItems()
            }
            return copy
        }
    }

    /// Демо-данные для README-скриншотов (`--export-screenshots`).
    func applyDemoSnapshot() {
        suppressLifecycleHooks = true
        needsFullDiskAccess = false
        hideFdaBanner = true
        freeDiskBytes = 52_429_000_000
        statusText = "Найдено 18 категорий · ~86 ГБ потенциального мусора"
        listFilter = .withSize
        sortMode = .size
        showSuccessBanner = false
        isScanning = false
        isCleaning = false
        scanProgress = 0

        let home = "/Users/demo"
        func items(_ pairs: [(String, Int64, Bool)]) -> [CleanItem] {
            pairs.map { CleanItem(path: "\(home)/Library/\($0.0)", byteCount: $0.1, isSelected: $0.2) }
        }

        categories = [
            CategoryScan(
                category: .xcodeDerivedData,
                byteCount: 28_500_000_000,
                paths: ["\(home)/Library/Developer/Xcode/DerivedData"],
                items: items([
                    ("Developer/Xcode/DerivedData/App-abc", 12_000_000_000, true),
                    ("Developer/Xcode/DerivedData/Kit-def", 9_200_000_000, true),
                    ("Developer/Xcode/DerivedData/ModuleCache.noindex", 7_300_000_000, false)
                ]),
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .iosDeviceSupport,
                byteCount: 14_200_000_000,
                paths: ["\(home)/Library/Developer/Xcode/iOS DeviceSupport"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: "Старые версии iOS"
            ),
            CategoryScan(
                category: .docker,
                byteCount: 11_800_000_000,
                paths: ["\(home)/Library/Containers/com.docker.docker"],
                items: [],
                isSelected: false,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .browserCaches,
                byteCount: 6_400_000_000,
                paths: ["\(home)/Library/Caches/Google", "\(home)/Library/Caches/Firefox"],
                items: items([
                    ("Caches/Google/Chrome", 3_100_000_000, true),
                    ("Caches/company.thebrowser.Browser", 2_000_000_000, true),
                    ("Caches/Firefox", 1_300_000_000, false)
                ]),
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .userCaches,
                byteCount: 4_850_000_000,
                paths: ["\(home)/Library/Caches"],
                items: items([
                    ("Caches/com.apple.python", 1_200_000_000, true),
                    ("Caches/Homebrew", 980_000_000, true),
                    ("Caches/ms-playwright", 870_000_000, true),
                    ("Caches/node-gyp", 400_000_000, false)
                ]),
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .npm,
                byteCount: 3_600_000_000,
                paths: ["\(home)/.npm", "\(home)/Library/Caches/Yarn"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .aiDevTools,
                byteCount: 2_900_000_000,
                paths: ["\(home)/.cache/claude", "\(home)/Library/Application Support/Cursor"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .simulatorCaches,
                byteCount: 2_400_000_000,
                paths: ["\(home)/Library/Developer/CoreSimulator/Caches"],
                items: [],
                isSelected: false,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .gradle,
                byteCount: 1_950_000_000,
                paths: ["\(home)/.gradle/caches"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .messengerCaches,
                byteCount: 1_420_000_000,
                paths: ["\(home)/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .userLogs,
                byteCount: 680_000_000,
                paths: ["\(home)/Library/Logs"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .temporary,
                byteCount: 420_000_000,
                paths: ["/tmp", "\(home)/Library/Caches/TemporaryItems"],
                items: [],
                isSelected: true,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .projectArtifacts,
                byteCount: 3_100_000_000,
                paths: ["\(home)/Projects"],
                items: items([
                    ("Projects/web/node_modules", 1_800_000_000, false),
                    ("Projects/api/.next", 780_000_000, false),
                    ("Projects/cli/target", 520_000_000, false)
                ]),
                isSelected: false,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .trash,
                byteCount: 890_000_000,
                paths: ["\(home)/.Trash"],
                items: [],
                isSelected: false,
                exists: true,
                detailNote: nil
            ),
            CategoryScan(
                category: .iosBackups,
                byteCount: 18_000_000_000,
                paths: ["\(home)/Library/Application Support/MobileSync/Backup"],
                items: [],
                isSelected: false,
                exists: true,
                detailNote: nil
            )
        ]

        for i in categories.indices where !categories[i].items.isEmpty {
            categories[i].syncParentFromItems()
        }

        expandedCategory = .browserCaches
    }
}
