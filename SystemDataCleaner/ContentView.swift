import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: CleanerViewModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            statusStrip

            if model.isBusy {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(AppTheme.surfaceRaised)
                        Rectangle()
                            .fill(AppTheme.accent)
                            .frame(width: max(4, geo.size.width * max(0.02, model.scanProgress)))
                            .animation(.easeOut(duration: 0.2), value: model.scanProgress)
                    }
                }
                .frame(height: 2)
            }

            if model.showSuccessBanner {
                banner(
                    icon: "checkmark.circle.fill",
                    tint: AppTheme.accent,
                    text: model.successMessage,
                    onClose: model.dismissSuccess
                )
            }

            if model.showFdaBanner {
                fdaBanner
            }

            Group {
                if model.categories.isEmpty && !model.isScanning {
                    emptyState
                } else {
                    mainContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .background(AppTheme.bg)
        .foregroundStyle(AppTheme.text)
        .navigationTitle("System Data Cleaner")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.pulse, isActive: !reduceMotion && model.isBusy)
                    .help("System Data Cleaner")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if model.isBusy {
                    Button(L10n.cancel, action: model.cancelWork)
                } else {
                    Button(L10n.smart, action: model.selectSmartRecommended)
                        .disabled(model.categories.isEmpty)
                        .help(L10n.smartHelp)

                    Button(L10n.scan, action: model.scan)
                        .help("⌘R")
                }
            }
        }
        .sheet(isPresented: $model.showConfirm) {
            ConfirmSheet(model: model)
        }
        .alert(L10n.errorTitle, isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onAppear {
            guard !model.suppressLifecycleHooks else { return }
            model.refreshPermissions()
            if model.categories.isEmpty { model.scan() }
        }
        .background { shortcutHooks }
    }

    /// Статус под title bar — не ломает системные отступы toolbar.
    private var statusStrip: some View {
        HStack(spacing: AppTheme.spaceXS) {
            Text(model.statusText)
                .font(AppTheme.body(12))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, AppTheme.spaceXS)
        .background(AppTheme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - Main

    private var mainContent: some View {
        VStack(spacing: 0) {
            metrics
            tools
            list
        }
    }

    private var metrics: some View {
        HStack(spacing: AppTheme.spaceSM) {
            metricTile(
                label: L10n.found,
                value: model.totalBytes > 0 ? model.formattedTotal : "—",
                hint: model.nonEmptyCount > 0 ? L10n.categoriesCount(model.nonEmptyCount) : L10n.afterScan,
                tint: AppTheme.accent
            )
            metricTile(
                label: L10n.selected,
                value: model.hasSelection
                    ? model.formattedSelected
                    : ByteCountFormatter.string(fromByteCount: 0, countStyle: .file),
                hint: model.hasSelection
                    ? L10n.categoriesShare(model.selectedCategoryCount, Int(model.selectionShare * 100))
                    : L10n.nothing,
                tint: model.hasSelection ? AppTheme.warn : AppTheme.textSecondary
            )
            metricTile(
                label: L10n.free,
                value: model.formattedFreeDisk ?? "—",
                hint: L10n.onDisk,
                tint: AppTheme.textSecondary
            )
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.top, AppTheme.blockGap)
        .padding(.bottom, AppTheme.spaceXS)
    }

    private func metricTile(label: String, value: String, hint: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spaceXXS) {
            Text(label)
                .font(AppTheme.body(11, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(AppTheme.title(17))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(hint)
                .font(AppTheme.body(11))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var tools: some View {
        HStack(spacing: AppTheme.spaceXS) {
            searchField
            filterBar
            sortMenu
            selectMenu
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.top, AppTheme.spaceXS)
        .padding(.bottom, AppTheme.blockGap)
    }

    private var searchField: some View {
        HStack(spacing: AppTheme.spaceXS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searchFocused ? AppTheme.accent : AppTheme.textTertiary)
                .font(.system(size: 12, weight: .semibold))
            TextField(L10n.searchPlaceholder, text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(AppTheme.body(13))
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.spaceSM)
        .frame(minWidth: 168, maxWidth: 260)
        .frame(height: AppTheme.controlHeight)
        .background(fieldBackground(focused: searchFocused))
    }

    private var filterBar: some View {
        HStack(spacing: 2) {
            ForEach(ListFilter.allCases) { filter in
                let on = model.listFilter == filter
                let count = model.filterCount(filter)
                Button {
                    model.listFilter = filter
                } label: {
                    HStack(spacing: AppTheme.spaceXXS) {
                        Text(filterShort(filter))
                        if filter != .all, count > 0 {
                            Text("\(count)")
                                .font(AppTheme.body(9, weight: .bold))
                                .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(on ? AppTheme.accent : AppTheme.surfaceRaised))
                        }
                    }
                    .font(AppTheme.body(11, weight: .semibold))
                    .foregroundStyle(on ? AppTheme.accent : AppTheme.textSecondary)
                    .padding(.horizontal, 9)
                    .frame(height: AppTheme.controlHeight - 4)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(AppTheme.accentSoft)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(height: AppTheme.controlHeight)
        .background(fieldBackground(focused: false))
    }

    private var sortMenu: some View {
        Group {
            if model.suppressLifecycleHooks {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: AppTheme.controlHeight, height: AppTheme.controlHeight)
                    .background(fieldBackground(focused: false))
            } else {
                Menu {
                    ForEach(SortMode.allCases) { mode in
                        Button(mode.title) { model.sortMode = mode }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: AppTheme.controlHeight, height: AppTheme.controlHeight)
                        .background(fieldBackground(focused: false))
                }
                .menuStyle(.borderlessButton)
                .help("\(L10n.sortHelpPrefix): \(model.sortMode.title)")
            }
        }
    }

    private var selectMenu: some View {
        Group {
            if model.suppressLifecycleHooks {
                Text(L10n.selectMenu)
                    .font(AppTheme.body(12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, AppTheme.spaceSM)
                    .frame(height: AppTheme.controlHeight)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
            } else {
                Menu {
                    Button(L10n.smartClean, action: model.selectSmartRecommended)
                    Button(L10n.safeOnly, action: model.selectSafeOnly)
                    Button(L10n.selectAllWithSize, action: model.selectAllJunk)
                    Divider()
                    Button(L10n.deselectAll, action: model.deselectAll)
                } label: {
                    Text(L10n.selectMenu)
                        .font(AppTheme.body(12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, AppTheme.spaceSM)
                        .frame(height: AppTheme.controlHeight)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private func fieldBackground(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .strokeBorder(focused ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
    }

    private func filterShort(_ f: ListFilter) -> String {
        L10n.filterShort(f)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            listStack
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.bottom, AppTheme.spaceLG)
        }
        .overlay {
            if model.isScanning && model.categories.isEmpty {
                scanningCard
            }
        }
    }

    @ViewBuilder
    private var listStack: some View {
        // LazyVStack пустой при offscreen-рендере скриншотов — VStack материализует строки.
        if model.suppressLifecycleHooks {
            VStack(alignment: .leading, spacing: AppTheme.spaceSM) {
                listRows
            }
        } else {
            LazyVStack(alignment: .leading, spacing: AppTheme.spaceSM, pinnedViews: [.sectionHeaders]) {
                listRows
            }
        }
    }

    @ViewBuilder
    private var listRows: some View {
        if model.filteredCategories.isEmpty {
            emptyFilter
        }

        ForEach(model.sections, id: \.0) { section, items in
            Section {
                if !model.isSectionCollapsed(section) {
                    ForEach(items) { scan in
                        CategoryRow(
                            scan: scan,
                            maxBytes: max(model.maxCategoryBytes, 1),
                            isExpanded: model.expandedCategory == scan.category,
                            onToggleCategory: { model.toggleCategory(scan.category) },
                            onToggleItem: { model.toggleItem(category: scan.category, itemId: $0) },
                            onReveal: model.revealInFinder,
                            onExpand: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    model.expandedCategory =
                                        model.expandedCategory == scan.category ? nil : scan.category
                                }
                            }
                        )
                    }
                }
            } header: {
                sectionHeader(section, count: items.count, bytes: items.reduce(0) { $0 + $1.byteCount })
            }
        }
    }

    private func sectionHeader(_ section: CleanSection, count: Int, bytes: Int64) -> some View {
        let collapsed = model.isSectionCollapsed(section)
        return Button {
            model.toggleSection(section)
        } label: {
            HStack(spacing: AppTheme.spaceXS) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .rotationEffect(.degrees(collapsed ? 0 : 90))
                    .frame(width: 12)
                Text(section.title)
                    .font(AppTheme.body(12, weight: .bold))
                Text("\(count)")
                    .font(AppTheme.body(10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.surfaceRaised, in: Capsule())
                Spacer()
                if bytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        .font(AppTheme.mono(11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.vertical, AppTheme.spaceSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AppTheme.bg)
    }

    private var scanningCard: some View {
        VStack(spacing: AppTheme.spaceSM) {
            ProgressView().tint(AppTheme.accent)
            Text(L10n.scanningProgress(Int(model.scanProgress * 100)))
                .font(AppTheme.body(13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .monospacedDigit()
        }
        .padding(AppTheme.spaceXL)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
    }

    private var emptyFilter: some View {
        VStack(spacing: AppTheme.spaceXS) {
            Text(L10n.nothingFound)
                .font(AppTheme.body(14, weight: .semibold))
            Button(L10n.resetFilter) {
                model.searchText = ""
                model.listFilter = .withSize
            }
            .buttonStyle(.plain)
            .font(AppTheme.body(12, weight: .bold))
            .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spaceMD) {
            Spacer()
            Image(systemName: "internaldrive")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(AppTheme.accent)
            Text(L10n.emptyTitle)
                .font(AppTheme.title(20))
            Text(L10n.emptyBody)
                .font(AppTheme.body(13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: model.scan) {
                Text(L10n.scanDisk)
                    .font(AppTheme.body(14, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: true))
            .padding(.top, AppTheme.spaceXS)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spaceXL)
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(spacing: AppTheme.spaceSM) {
            if let freed = model.lastFreed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text(L10n.freed(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)))
                    .font(AppTheme.body(13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            } else if model.hasSelection {
                Text(L10n.toDeleteSize(model.formattedSelected))
                    .font(AppTheme.body(13, weight: .semibold))
            } else {
                Text(L10n.pickOrSmart)
                    .font(AppTheme.body(12))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: model.requestClean) {
                HStack(spacing: 6) {
                    Image(systemName: model.isCleaning ? "hourglass" : "trash.fill")
                    Text(model.isCleaning ? L10n.cleaning : L10n.delete)
                        .font(AppTheme.body(13, weight: .bold))
                    if model.hasSelection && !model.isCleaning {
                        Text(model.formattedSelected)
                            .font(AppTheme.mono(12))
                    }
                }
                .foregroundStyle(model.hasSelection ? AppTheme.onAccent : AppTheme.textTertiary)
                .padding(.horizontal, AppTheme.spaceMD)
                .frame(height: 36)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: model.hasSelection && !model.isBusy))
            .disabled(!model.hasSelection || model.isBusy)
            .help("⌘⌫")
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, AppTheme.spaceSM)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private func banner(icon: String, tint: Color, text: String, onClose: @escaping () -> Void) -> some View {
        HStack(spacing: AppTheme.spaceSM) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text)
                .font(AppTheme.body(12, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: AppTheme.spaceXS)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, AppTheme.spaceSM)
        .background(tint.opacity(0.12))
    }

    private var fdaBanner: some View {
        HStack(spacing: AppTheme.spaceSM) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(AppTheme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.fdaTitle)
                    .font(AppTheme.body(12, weight: .semibold))
                Text(L10n.fdaBody)
                    .font(AppTheme.body(11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: AppTheme.spaceXS)
            Button(L10n.settings) { model.openFullDiskAccessSettings() }
                .buttonStyle(.plain)
                .font(AppTheme.body(12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Button { model.hideFdaBanner = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(AppTheme.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, AppTheme.spaceSM)
        .background(AppTheme.warn.opacity(0.1))
    }

    private var shortcutHooks: some View {
        Group {
            Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command)
            Button("") { model.requestClean() }.keyboardShortcut(.delete, modifiers: .command)
            Button("") { model.collapseExpanded() }.keyboardShortcut(.escape, modifiers: [])
            Button("") { model.deselectAll() }.keyboardShortcut("0", modifiers: [.command, .shift])
            Button("") { model.selectSmartRecommended() }.keyboardShortcut("2", modifiers: [.command, .shift])
            Button("") { model.selectSafeOnly() }.keyboardShortcut("1", modifiers: [.command, .shift])
            Button("") { model.scan() }.keyboardShortcut("r", modifiers: .command)
        }
        .opacity(0).allowsHitTesting(false)
    }
}

// MARK: - Confirm

struct ConfirmSheet: View {
    @ObservedObject var model: CleanerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.confirmTitle)
                        .font(AppTheme.title(18))
                    Text(L10n.confirmSubtitle)
                        .font(AppTheme.body(12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(model.formattedSelected)
                    .font(AppTheme.title(20))
                    .foregroundStyle(AppTheme.accent)
                    .monospacedDigit()
            }
            .padding(AppTheme.spaceLG)

            Divider().overlay(AppTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.blockGap) {
                    confirmRiskRows
                }
                .padding(AppTheme.spaceLG)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: AppTheme.spaceSM) {
                Button { dismiss() } label: {
                    Text(L10n.cancel)
                        .font(AppTheme.body(13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spaceSM)
                        .foregroundStyle(AppTheme.text)
                }
                .buttonStyle(SoftButtonStyle())

                Button {
                    dismiss()
                    model.confirmClean()
                } label: {
                    Text(L10n.delete)
                        .font(AppTheme.body(13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spaceSM)
                        .foregroundStyle(AppTheme.onAccent)
                }
                .buttonStyle(PrimaryButtonStyle(enabled: true))
            }
            .padding(AppTheme.spaceLG)
        }
        .frame(width: 440, height: 420)
        .background(AppTheme.bg)
    }

    @ViewBuilder
    private var confirmRiskRows: some View {
        ForEach(model.confirmByRisk) { group in
            VStack(alignment: .leading, spacing: AppTheme.spaceXS) {
                Text(riskTitle(group.risk))
                    .font(AppTheme.body(11, weight: .bold))
                    .foregroundStyle(riskColor(group.risk))
                ForEach(Array(group.rows.prefix(8).enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.title).font(AppTheme.body(13))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: row.bytes, countStyle: .file))
                            .font(AppTheme.mono(12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
                if group.rows.count > 8 {
                    Text(L10n.andMore(group.rows.count - 8))
                        .font(AppTheme.body(11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func riskColor(_ risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return AppTheme.accent
        case .caution: return AppTheme.warn
        case .danger: return AppTheme.danger
        }
    }

    private func riskTitle(_ risk: RiskLevel) -> String {
        L10n.riskTitle(risk)
    }
}

// MARK: - Category row

struct CategoryRow: View {
    let scan: CategoryScan
    let maxBytes: Int64
    let isExpanded: Bool
    var onToggleCategory: () -> Void
    var onToggleItem: (UUID) -> Void
    var onReveal: (String) -> Void
    var onExpand: () -> Void

    @State private var hovered = false

    private var checkIcon: String {
        if scan.items.isEmpty {
            return scan.isSelected ? "checkmark.circle.fill" : "circle"
        }
        let n = scan.items.filter(\.isSelected).count
        if n == 0 { return "circle" }
        if n == scan.items.count { return "checkmark.circle.fill" }
        return "minus.circle.fill"
    }

    private var risk: Color {
        switch scan.category.risk {
        case .safe: return AppTheme.accent
        case .caution: return AppTheme.warn
        case .danger: return AppTheme.danger
        }
    }

    private var bar: CGFloat {
        guard maxBytes > 0, scan.byteCount > 0 else { return 0 }
        return CGFloat(Double(scan.byteCount) / Double(maxBytes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.spaceSM) {
                Button(action: onToggleCategory) {
                    Image(systemName: checkIcon)
                        .font(.system(size: 17))
                        .foregroundStyle(scan.hasSelection ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(width: 24, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(scan.byteCount == 0 && !scan.exists)

                Image(systemName: scan.category.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(risk)
                    .frame(width: 28, height: 28)
                    .background(risk.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: AppTheme.spaceXXS) {
                    HStack(spacing: 6) {
                        Text(scan.category.title)
                            .font(AppTheme.body(13, weight: .semibold))
                            .lineLimit(1)
                        if scan.category.risk != .safe {
                            Text(scan.category.risk.label)
                                .font(AppTheme.body(9, weight: .bold))
                                .foregroundStyle(risk)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(risk.opacity(0.14), in: Capsule())
                        }
                    }
                    Text(scan.category.subtitle)
                        .font(AppTheme.body(11))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.surfaceRaised)
                            Capsule().fill(risk.opacity(0.85))
                                .frame(width: max(0, geo.size.width * bar))
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 2)
                }

                Spacer(minLength: AppTheme.spaceXS)

                Text(scan.formattedSize)
                    .font(AppTheme.mono(12))
                    .foregroundStyle(scan.byteCount > 0 ? AppTheme.text : AppTheme.textTertiary)

                Button(action: onExpand) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.vertical, AppTheme.spaceSM)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onExpand)

            if isExpanded {
                VStack(alignment: .leading, spacing: AppTheme.spaceXS) {
                    Text(scan.category.riskNote)
                        .font(AppTheme.body(11))
                        .foregroundStyle(risk)
                        .padding(AppTheme.spaceXS)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(risk.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous))

                    if let note = scan.detailNote {
                        Text(note)
                            .font(AppTheme.body(11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if scan.items.isEmpty {
                        HStack {
                            Text(scan.exists ? L10n.removesWhole : L10n.pathMissing)
                                .font(AppTheme.body(11))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            if let path = scan.paths.first {
                                Button(L10n.showInFinder) { onReveal(path) }
                                    .buttonStyle(.plain)
                                    .font(AppTheme.body(11, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    } else {
                        ForEach(scan.items.prefix(50)) { item in
                            ItemRow(
                                item: item,
                                onToggle: { onToggleItem(item.id) },
                                onReveal: { onReveal(item.path) }
                            )
                        }
                        if scan.items.count > 50 {
                            Text(L10n.showingOf(50, scan.items.count))
                                .font(AppTheme.body(10))
                                .foregroundStyle(AppTheme.textTertiary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.cardPadding)
                .padding(.bottom, AppTheme.cardPadding)
                .padding(.leading, 36)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                .fill(hovered ? AppTheme.surfaceHover : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                        .strokeBorder(
                            scan.hasSelection ? AppTheme.accent.opacity(0.35) : AppTheme.border,
                            lineWidth: 1
                        )
                )
        )
        .opacity(scan.byteCount == 0 && !scan.exists ? 0.42 : 1)
        .onHover { hovered = $0 }
    }
}

private struct ItemRow: View {
    let item: CleanItem
    var onToggle: () -> Void
    var onReveal: () -> Void
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isSelected ? AppTheme.accent : AppTheme.textTertiary)
                        .font(.system(size: 13))
                    Text(item.name)
                        .font(AppTheme.body(12))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if item.byteCount > 0 {
                        Text(item.formattedSize)
                            .font(AppTheme.mono(11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.displayPath)

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hovered ? AppTheme.accent : AppTheme.textTertiary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovered ? AppTheme.surfaceRaised.opacity(0.9) : .clear)
        )
        .onHover { hovered = $0 }
    }
}
