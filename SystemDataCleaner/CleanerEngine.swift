import Foundation

/// Потокобезопасный кэш размеров каталогов для параллельного скана.
private final class SizeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Int64] = [:]

    func reset() {
        lock.lock()
        storage.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func get(_ key: String) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func set(_ key: String, _ value: Int64) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }
}

final class CleanerEngine: @unchecked Sendable {
    private let fm = FileManager.default
    private let home: URL
    private let sizeCache = SizeCache()

    private let bannedCacheNames: Set<String> = [
        "CloudKit", "com.apple.Safari", "FamilyCircle", "PassKit",
        "com.apple.HomeKit", "com.apple.findmy", "com.apple.accountsd"
    ]

    private let projectArtifactNames: Set<String> = [
        "node_modules", ".next", ".nuxt", ".svelte-kit", ".turbo", ".parcel-cache",
        ".vite", ".webpack", ".angular", ".expo", ".expo-shared", ".output",
        "dist", "build", "out", "target", ".gradle", "Pods", ".dart_tool",
        "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox",
        ".cache", "DerivedData", ".vercel", ".netlify", "coverage", ".nyc_output",
        "storybook-static", ".serverless", "vendor", "vendor/bundle", ".bundle", ".build",
        ".yarn", ".pnpm-store", "bower_components", ".terraform", ".pulumi",
        "Carthage", "Checkouts", ".swiftpm", "bazel-bin", "bazel-out", "bazel-testlogs",
        ".cxx", "cmake-build-debug", "cmake-build-release",
        "Pods", "Carthage/Build", ".pub-cache", ".dart_tool", "ios/Pods",
        "android/.gradle", "android/app/build", "android/build", "ios/build",
        ".deno", ".esbuild", ".rollup.cache", ".sass-cache", ".eslintcache",
        ".stylelintcache", "tmp", "temp", ".tmp", ".temp", "logs", ".logs",
        "htmlcov", ".hypothesis", ".nox", ".pdm-build", ".tox",
        "node_modules/.cache", ".vite/deps", ".webpack/cache"
    ]

    init() {
        home = fm.homeDirectoryForCurrentUser
    }

    func scanAll(
        progress: @Sendable (Int, Int, String) -> Void,
        onPartial: (@Sendable ([CategoryScan]) -> Void)? = nil
    ) async -> [CategoryScan] {
        sizeCache.reset()
        let ids = Array(CleanCategoryID.allCases)
        let total = ids.count
        var results: [CategoryScan?] = Array(repeating: nil, count: total)

        // Реальный параллелизм (раньше actor сериализовал всё). 4 — баланс CPU/диска.
        let maxConcurrent = 4

        await withTaskGroup(of: (Int, CategoryScan)?.self) { group in
            var submitted = 0

            func submitNext() {
                guard submitted < total else { return }
                let i = submitted
                submitted += 1
                let id = ids[i]
                group.addTask(priority: .utility) { [weak self] in
                    guard let self else { return nil }
                    if Task.isCancelled { return nil }
                    return (i, self.scan(id))
                }
            }

            for _ in 0..<min(maxConcurrent, total) {
                submitNext()
            }

            var completed = 0
            var lastPartialAt = ContinuousClock.Instant.now
            var lastPartialCount = 0
            let partialInterval: ContinuousClock.Duration = .milliseconds(280)

            for await item in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                guard let (index, scan) = item else {
                    submitNext()
                    continue
                }
                results[index] = scan
                completed += 1
                progress(completed, total, scan.category.title)

                let now = ContinuousClock.Instant.now
                let duePartial = completed == total
                    || completed - lastPartialCount >= 8
                    || now - lastPartialAt >= partialInterval
                if duePartial, let onPartial {
                    let partial = results.compactMap { $0 }.sorted { $0.byteCount > $1.byteCount }
                    onPartial(partial)
                    lastPartialAt = now
                    lastPartialCount = completed
                }
                submitNext()
            }
        }

        return results.compactMap { $0 }.sorted { $0.byteCount > $1.byteCount }
    }

    func freeDiskBytes() -> Int64? {
        let homeURL = fm.homeDirectoryForCurrentUser
        let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let v = values?.volumeAvailableCapacityForImportantUsage {
            return Int64(v)
        }
        let attrs = try? fm.attributesOfFileSystem(forPath: homeURL.path)
        return attrs?[.systemFreeSize] as? Int64
    }

    func hasFullDiskAccess() -> Bool {
        let probes = [
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Messages"),
            home.appendingPathComponent("Library/Containers/com.apple.mail")
        ]
        var anyExists = false
        for url in probes where fm.fileExists(atPath: url.path) {
            anyExists = true
            if (try? fm.contentsOfDirectory(atPath: url.path)) != nil {
                return true
            }
        }
        return !anyExists
    }

    func scan(_ id: CleanCategoryID) -> CategoryScan {
        switch id.strategy {
        case .timeMachineSnapshots:
            return scanTimeMachineSnapshots(id)
        case .downloadInstallers:
            return scanDownloadInstallers(id)
        case .oldLargeDownloads:
            return scanOldLargeDownloads(id)
        case .chromeProfilesDeep:
            return scanChromeProfilesDeep(id)
        case .orphanedAppSupport:
            return scanOrphanedAppSupport(id)
        case .crashReportsDeep:
            return scanCrashReportsDeep(id)
        case .xcodeOldDeviceSupport:
            return scanXcodeOldDeviceSupport(id)
        case .projectArtifacts:
            return scanProjectArtifacts(id)
        case .groupContainerCaches:
            return scanGroupContainerCaches(id)
        case .documentRevisions:
            return scanDocumentRevisions(id)
        case .containerAppCaches:
            return scanContainerAppCaches(id)
        case .editorStateBloat:
            return scanEditorStateBloat(id)
        case .electronAppJunk:
            return scanElectronAppJunk(id)
        case .shell where id == .unavailableSimulators:
            let size = directorySize(at: home.appendingPathComponent("Library/Developer/CoreSimulator/Devices"))
            return CategoryScan(
                category: id,
                byteCount: size > 0 ? max(size / 25, 1) : 0,
                paths: [],
                items: [],
                isSelected: id.selectedByDefault && size > 0,
                exists: size > 0,
                detailNote: "xcrun simctl delete unavailable"
            )
        case .shell where id == .docker:
            return scanSizedPaths(
                id,
                [
                    home.appendingPathComponent("Library/Containers/com.docker.docker"),
                    home.appendingPathComponent("Library/Group Containers/group.com.docker")
                ],
                note: "docker system prune -af --volumes",
                forceSelected: false
            )
        case .shell where id == .brewCleanup:
            let cache = home.appendingPathComponent("Library/Caches/Homebrew")
            let size = directorySize(at: cache)
            return CategoryScan(
                category: id,
                byteCount: size,
                paths: fm.fileExists(atPath: cache.path) ? [cache.path] : [],
                items: [],
                isSelected: id.selectedByDefault && size > 0,
                exists: size > 0,
                detailNote: "brew cleanup -as"
            )
        case .shell where id == .goCache:
            return scanSizedPaths(
                id,
                goCacheURLs(),
                note: "go clean -modcache",
                forceSelected: nil
            )
        default:
            break
        }

        return scanFileCategory(id)
    }

    func clean(
        _ categories: [CategoryScan],
        progress: @Sendable (Int, Int, String) -> Void
    ) async throws -> Int64 {
        let toClean = categories.filter(\.hasSelection)
        guard !toClean.isEmpty else { throw CleanerError.nothingSelected }

        var freed: Int64 = 0
        var failures: [String] = []
        let total = toClean.count

        for (offset, scan) in toClean.enumerated() {
            if Task.isCancelled { break }
            progress(offset + 1, total, scan.category.title)
            let beforeTotal = scan.byteCount
            do {
                switch scan.category.strategy {
                case .files:
                    for path in selectedPaths(for: scan) {
                        if Task.isCancelled { break }
                        try removeContents(at: path, category: scan.category)
                    }
                case .shell(let args):
                    _ = runProcess(args)
                case .timeMachineSnapshots:
                    if scan.items.isEmpty {
                        try deleteLocalSnapshots()
                    } else {
                        for item in scan.items where item.isSelected {
                            let stamp = item.path
                                .replacingOccurrences(of: "com.apple.TimeMachine.", with: "")
                                .replacingOccurrences(of: ".local", with: "")
                            _ = shellZsh("tmutil deletelocalsnapshots \(stamp) 2>/dev/null || true")
                        }
                    }
                case .downloadInstallers, .oldLargeDownloads, .chromeProfilesDeep,
                     .orphanedAppSupport, .crashReportsDeep, .xcodeOldDeviceSupport,
                     .projectArtifacts, .groupContainerCaches,
                     .documentRevisions, .containerAppCaches,
                     .editorStateBloat, .electronAppJunk:
                    for item in scan.items where item.isSelected {
                        if Task.isCancelled { break }
                        try? fm.removeItem(atPath: item.path)
                    }
                }
            } catch {
                failures.append("\(scan.category.title): \(error.localizedDescription)")
            }
            let after = self.scan(scan.category)
            freed += max(0, beforeTotal - after.byteCount)
        }

        if !failures.isEmpty && freed == 0 {
            throw CleanerError.partiallyFailed(failures.prefix(4).joined(separator: "\n"))
        }
        return freed
    }

    private func selectedPaths(for scan: CategoryScan) -> [String] {
        if !scan.items.isEmpty {
            return scan.items.filter(\.isSelected).map(\.path)
        }
        return cleanablePaths(for: scan)
    }

    // MARK: - File scan

    private func scanFileCategory(_ id: CleanCategoryID) -> CategoryScan {
        // Сначала убираем вложенные таргеты (parent + child иначе считаются дважды).
        let targets = collapseNestedURLs(resolveTargets(for: id))
        var existingPaths: [String] = []
        var folderSizes: [(String, Int64)] = []

        let expandChildren: Set<CleanCategoryID> = [
            .userCaches, .userLogs, .iosDeviceSupport, .iosBackups,
            .jetbrainsCaches, .aiDevTools, .browserCaches, .messengerCaches,
            .homeDotCache, .androidSDKCaches, .mlModels, .vscodeCaches,
            .electronApps, .dockerDesktopData
        ]

        for url in targets {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            existingPaths.append(url.path)

            if isDir.boolValue {
                if expandChildren.contains(id) {
                    let children = (try? fm.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    for child in children {
                        if id == .userCaches, shouldExcludeFromUserCaches(child.lastPathComponent) {
                            continue
                        }
                        let size = directorySize(at: child)
                        if size > 0 { folderSizes.append((child.path, size)) }
                    }
                } else {
                    let size = directorySize(at: url)
                    if size > 0 { folderSizes.append((url.path, size)) }
                }
            } else if let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64), size > 0 {
                folderSizes.append((url.path, size))
            }
        }

        let collapsed = PathAccounting.collapseEntries(folderSizes)
        let total = collapsed.reduce(0) { $0 + $1.1 }
        let defaultSel = id.selectedByDefault
        let items = collapsed
            .sorted { $0.1 > $1.1 }
            .map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: defaultSel && $0.1 > 0) }

        return CategoryScan(
            category: id,
            byteCount: total,
            paths: existingPaths,
            items: items,
            isSelected: defaultSel && total > 0,
            exists: !existingPaths.isEmpty,
            detailNote: nil
        )
    }

    private func scanSizedPaths(
        _ id: CleanCategoryID,
        _ urls: [URL],
        note: String?,
        forceSelected: Bool?
    ) -> CategoryScan {
        var folderSizes: [(String, Int64)] = []
        var paths: [String] = []
        let defaultSel = forceSelected ?? id.selectedByDefault
        for u in collapseNestedURLs(urls) where fm.fileExists(atPath: u.path) {
            let size = directorySize(at: u)
            paths.append(u.path)
            if size > 0 { folderSizes.append((u.path, size)) }
        }
        let collapsed = PathAccounting.collapseEntries(folderSizes)
        let total = collapsed.reduce(0) { $0 + $1.1 }
        let items = collapsed
            .sorted { $0.1 > $1.1 }
            .map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: defaultSel && $0.1 > 0) }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: paths,
            items: items,
            isSelected: defaultSel && total > 0,
            exists: total > 0,
            detailNote: note
        )
    }

    /// Папки Library/Caches, которые уже покрыты узкими категориями.
    private func shouldExcludeFromUserCaches(_ name: String) -> Bool {
        if bannedCacheNames.contains(name) { return true }
        let lower = name.lowercased()
        let owned: [String] = [
            "google", "chrome", "chromium", "brave", "firefox", "mozilla", "edge", "opera", "vivaldi",
            "safari", "orion", "arc", "zen-browser", "telegram", "discord", "slack", "whatsapp",
            "spotify", "adobe", "zoom", "steam", "figma", "notion", "dropbox", "electron",
            "microsoft", "onedrive", "viber", "signal", "loom", "miro", "docker", "homebrew",
            "grype", "trivy", "snyk", "playwright", "shipit", "cursor", "windsurf",
            "com.microsoft.vscode", "com.todesktop"
        ]
        return owned.contains { lower.contains($0) }
    }

    // MARK: - Targets

    private func resolveTargets(for id: CleanCategoryID) -> [URL] {
        switch id {
        case .userCaches:
            return [home.appendingPathComponent("Library/Caches")]
        case .userLogs:
            return existing([
                "Library/Logs",
                "Library/Logs/DiagnosticReports",
                "Library/Logs/CoreSimulator",
                "Library/Logs/CreativeCloud",
                "Library/Logs/Google",
                "Library/Logs/Adobe",
                "Library/Logs/Homebrew",
                "Library/Logs/DiagnosticReports/Retired"
            ])
        case .temporary:
            var urls = uniqueURLs([
                URL(fileURLWithPath: NSTemporaryDirectory()),
                home.appendingPathComponent("Library/Caches/TemporaryItems"),
                home.appendingPathComponent("Library/Caches/com.apple.bird.token"),
                URL(fileURLWithPath: "/private/tmp")
            ].filter { fm.fileExists(atPath: $0.path) })
            if let darwinTmp = shellZsh("getconf DARWIN_USER_TEMP_DIR 2>/dev/null"), !darwinTmp.isEmpty {
                let u = URL(fileURLWithPath: darwinTmp.trimmingCharacters(in: .whitespacesAndNewlines))
                if fm.fileExists(atPath: u.path) { urls.append(u) }
            }
            if let darwinCache = shellZsh("getconf DARWIN_USER_CACHE_DIR 2>/dev/null"), !darwinCache.isEmpty {
                let u = URL(fileURLWithPath: darwinCache.trimmingCharacters(in: .whitespacesAndNewlines))
                if fm.fileExists(atPath: u.path) { urls.append(u) }
            }
            return uniqueURLs(urls)
        case .trash:
            return [home.appendingPathComponent(".Trash")]
        case .quickLook:
            return existing([
                "Library/Caches/com.apple.QuickLook.thumbnailcache",
                "Library/Caches/CloudKit/com.apple.QuickLook.thumbnailcache"
            ])
        case .fontCaches:
            return existing([
                "Library/Caches/com.apple.ATS",
                "Library/Fonts/.uuid"
            ])
        case .savedState:
            return existing(["Library/Saved Application State"])
        case .mediaAnalysis:
            return existing([
                "Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches",
                "Library/Caches/com.apple.MediaAnalysis"
            ])
        case .appleIntelligence:
            return existing([
                "Library/Caches/com.apple.SiriTTS",
                "Library/Caches/com.apple.IntelligentRouting",
                "Library/Application Support/Apple/Intelligence",
                "Library/Caches/com.apple.VoiceMemos",
                "Library/Assistant/SiriVocabulary"
            ])
        case .iosSoftwareUpdates:
            return existing([
                "Library/iTunes/iPhone Software Updates",
                "Library/iTunes/iPod Software Updates",
                "Library/Group Containers/K36BKF7T3D.group.softwareupdateservicesd"
            ])
        case .xcodeDerivedData:
            return existing(["Library/Developer/Xcode/DerivedData"])
        case .xcodeArchives:
            return existing(["Library/Developer/Xcode/Archives"])
        case .iosDeviceSupport:
            return existing([
                "Library/Developer/Xcode/iOS DeviceSupport",
                "Library/Developer/Xcode/watchOS DeviceSupport",
                "Library/Developer/Xcode/tvOS DeviceSupport",
                "Library/Developer/Xcode/visionOS DeviceSupport"
            ])
        case .simulatorCaches:
            return existing([
                "Library/Developer/CoreSimulator/Caches",
                "Library/Logs/CoreSimulator"
            ])
        case .unavailableSimulators, .timeMachineSnapshots, .docker, .installerImages,
             .brewCleanup, .projectArtifacts, .oldLargeDownloads, .chromeProfilesDeep,
             .orphanedAppSupport, .crashReportsDeep, .xcodeOldDeviceSupport:
            return []
        case .swiftPMCache:
            return existing([
                "Library/Caches/org.swift.swiftpm",
                "Library/org.swift.swiftpm"
            ])
        case .xcodeCaches:
            return existing([
                "Library/Developer/Xcode/DerivedData/ModuleCache.noindex",
                "Library/Developer/Xcode/iOS Device Logs",
                "Library/Developer/Xcode/watchOS Device Logs",
                "Library/Caches/com.apple.dt.Xcode",
                "Library/Developer/Xcode/UserData/IB Support",
                "Library/Developer/Xcode/Products"
            ])
        case .carthage:
            return existing([
                "Library/Caches/org.carthage.CarthageKit",
                "Library/Caches/Carthage",
                "Library/Developer/Xcode/DerivedData/Carthage"
            ])
        case .iosBackups:
            return existing(["Library/Application Support/MobileSync/Backup"])
        case .homebrew:
            var urls = existing(["Library/Caches/Homebrew"])
            if let brewCache = shellZsh("brew --cache") {
                urls.append(URL(fileURLWithPath: brewCache))
            }
            return uniqueURLs(urls)
        case .npm:
            return existingAbs([
                home.appendingPathComponent(".npm"),
                home.appendingPathComponent(".npm/_cacache"),
                home.appendingPathComponent(".npm/_logs"),
                home.appendingPathComponent(".npm/_npx"),
                home.appendingPathComponent("Library/Caches/Yarn"),
                home.appendingPathComponent("Library/Caches/pnpm"),
                home.appendingPathComponent(".cache/yarn"),
                home.appendingPathComponent(".cache/pnpm"),
                home.appendingPathComponent(".cache/node-gyp"),
                home.appendingPathComponent("Library/Caches/node-gyp"),
                home.appendingPathComponent(".local/share/pnpm/store"),
                home.appendingPathComponent("Library/pnpm"),
                home.appendingPathComponent(".pnpm-store"),
                home.appendingPathComponent(".yarn/berry/cache"),
                home.appendingPathComponent(".yarn/cache"),
                home.appendingPathComponent(".turbo"),
                home.appendingPathComponent(".cache/typescript"),
                home.appendingPathComponent("Library/Caches/typescript")
            ])
        case .bun:
            return existingAbs([home.appendingPathComponent(".bun/install/cache")])
        case .deno:
            return existingAbs([
                home.appendingPathComponent("Library/Caches/deno"),
                home.appendingPathComponent(".cache/deno"),
                home.appendingPathComponent("Library/Caches/com.denoland.deno")
            ])
        case .cocoapods:
            return existing([
                "Library/Caches/CocoaPods",
                ".cocoapods/repos"
            ])
        case .gradle:
            return existingAbs([
                home.appendingPathComponent(".gradle/caches"),
                home.appendingPathComponent(".gradle/wrapper/dists"),
                home.appendingPathComponent(".android/build-cache"),
                home.appendingPathComponent("Library/Android/sdk/.temp"),
                home.appendingPathComponent("Library/Android/sdk/ndk"),
                home.appendingPathComponent("Library/Android/sdk/system-images")
            ])
        case .maven:
            return existingAbs([home.appendingPathComponent(".m2/repository")])
        case .pip:
            return existingAbs([
                home.appendingPathComponent(".cache/pip"),
                home.appendingPathComponent("Library/Caches/pip"),
                home.appendingPathComponent(".cache/uv"),
                home.appendingPathComponent(".cache/pipx"),
                home.appendingPathComponent(".local/pipx/.cache"),
                home.appendingPathComponent(".cache/pre-commit")
            ])
        case .poetry:
            return existingAbs([
                home.appendingPathComponent("Library/Caches/pypoetry"),
                home.appendingPathComponent(".cache/pypoetry")
            ])
        case .conda:
            return existingAbs([
                home.appendingPathComponent("anaconda3/pkgs"),
                home.appendingPathComponent("miniconda3/pkgs"),
                home.appendingPathComponent("mambaforge/pkgs"),
                home.appendingPathComponent(".conda/pkgs")
            ])
        case .goCache:
            return goCacheURLs()
        case .cargo:
            return existingAbs([
                home.appendingPathComponent(".cargo/registry/cache"),
                home.appendingPathComponent(".cargo/registry/src"),
                home.appendingPathComponent(".cargo/git")
            ])
        case .flutter:
            return existingAbs([
                home.appendingPathComponent(".pub-cache"),
                home.appendingPathComponent("Library/Caches/flutter_engine"),
                home.appendingPathComponent("flutter/.pub-cache"),
                home.appendingPathComponent("development/flutter/bin/cache")
            ])
        case .composer:
            return existingAbs([
                home.appendingPathComponent(".composer/cache"),
                home.appendingPathComponent("Library/Caches/composer")
            ])
        case .nuget:
            return existingAbs([
                home.appendingPathComponent(".nuget/packages"),
                home.appendingPathComponent(".local/share/NuGet")
            ])
        case .playwright:
            return existing([
                "Library/Caches/ms-playwright",
                "Library/Caches/ms-playwright-mcp",
                ".cache/ms-playwright",
                ".cache/ms-playwright-mcp"
            ])
        case .cypress:
            return existingAbs([
                home.appendingPathComponent("Library/Caches/Cypress"),
                home.appendingPathComponent(".cache/Cypress")
            ])
        case .puppeteer:
            return existingAbs([
                home.appendingPathComponent(".cache/puppeteer"),
                home.appendingPathComponent("Library/Caches/puppeteer")
            ])
        case .jetbrainsCaches:
            return existing(["Library/Caches/JetBrains", "Library/Logs/JetBrains"])
        case .vscodeCaches:
            return existing([
                "Library/Caches/Code",
                "Library/Caches/Cursor",
                "Library/Caches/Windsurf",
                "Library/Caches/com.microsoft.VSCode",
                "Library/Caches/cursor-compile-cache",
                "Library/Application Support/Code/Cache",
                "Library/Application Support/Code/CachedData",
                "Library/Application Support/Code/CachedExtensions",
                "Library/Application Support/Code/CachedExtensionVSIXs",
                "Library/Application Support/Code/Crashpad",
                "Library/Application Support/Code/GPUCache",
                "Library/Application Support/Code/logs",
                "Library/Application Support/Code/WebStorage",
                "Library/Application Support/Cursor/Cache",
                "Library/Application Support/Cursor/CachedData",
                "Library/Application Support/Cursor/GPUCache",
                "Library/Application Support/Cursor/Crashpad",
                "Library/Application Support/Cursor/logs",
                "Library/Application Support/Cursor/CachedProfilesData",
                "Library/Application Support/Windsurf/Cache",
                "Library/Application Support/Windsurf/CachedData",
                "Library/Application Support/Windsurf/logs"
            ])
        case .androidStudio:
            var urls = existing([
                "Library/Caches/Google",
                "Library/Logs/Google"
            ])
            let studioParent = home.appendingPathComponent("Library/Application Support/Google")
            if let kids = try? fm.contentsOfDirectory(atPath: studioParent.path) {
                for name in kids where name.hasPrefix("AndroidStudio") {
                    let u = studioParent.appendingPathComponent(name).appendingPathComponent("caches")
                    if fm.fileExists(atPath: u.path) { urls.append(u) }
                    let logs = studioParent.appendingPathComponent(name).appendingPathComponent("log")
                    if fm.fileExists(atPath: logs.path) { urls.append(logs) }
                }
            }
            return urls
        case .aiDevTools:
            return existingAbs([
                home.appendingPathComponent(".claude"),
                home.appendingPathComponent(".codex"),
                home.appendingPathComponent(".cursor/projects"),
                home.appendingPathComponent(".cursor/ai-tracking"),
                home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/anysphere.cursor-agent-worker"),
                home.appendingPathComponent("Library/Application Support/Claude"),
                home.appendingPathComponent("Library/Caches/com.anthropic.claudefordesktop"),
                home.appendingPathComponent("Library/Application Support/Claude/Cache"),
                home.appendingPathComponent("Library/Application Support/Claude/Code Cache"),
                home.appendingPathComponent("Library/Application Support/Claude/GPUCache"),
                home.appendingPathComponent("Library/Application Support/Windsurf/User/globalStorage"),
                home.appendingPathComponent("Library/Application Support/GitHub Copilot"),
                home.appendingPathComponent("Library/Caches/com.github.CopilotForXcode"),
                home.appendingPathComponent(".cache/claude"),
                home.appendingPathComponent(".continue"),
                home.appendingPathComponent(".aider"),
                home.appendingPathComponent(".gemini"),
                home.appendingPathComponent(".cache/gemini"),
                home.appendingPathComponent(".cache/chatgpt"),
                home.appendingPathComponent("Library/Application Support/ChatGPT/Cache"),
                home.appendingPathComponent("Library/Application Support/ChatGPT/Code Cache"),
                home.appendingPathComponent("Library/Application Support/ChatGPT/GPUCache"),
                home.appendingPathComponent("Library/Application Support/com.openai.chat/Cache"),
                home.appendingPathComponent(".cache/gh-copilot"),
                home.appendingPathComponent("Library/Caches/dev.warp.Warp-Stable"),
                home.appendingPathComponent(".cache/lm-studio"),
                home.appendingPathComponent(".cache/ollama")
            ])
        case .mlModels:
            return existingAbs([
                home.appendingPathComponent(".ollama/models"),
                home.appendingPathComponent(".cache/huggingface"),
                home.appendingPathComponent(".cache/huggingface/hub"),
                home.appendingPathComponent(".cache/torch"),
                home.appendingPathComponent(".cache/whisper"),
                home.appendingPathComponent(".cache/mlx"),
                home.appendingPathComponent(".cache/diffusers"),
                home.appendingPathComponent(".cache/comfyui"),
                home.appendingPathComponent(".cache/transformers"),
                home.appendingPathComponent("Library/Application Support/com.apple.dt.Xcode/Downloads"),
                home.appendingPathComponent("Library/Application Support/DiffusionBee"),
                home.appendingPathComponent("Library/Application Support/StabilityMatrix"),
                home.appendingPathComponent(".lmstudio/models"),
                home.appendingPathComponent("Library/Application Support/LM Studio")
            ])
        case .browserCaches:
            // Только Library/Caches — профили Application Support считает chromeProfilesDeep.
            return existing([
                "Library/Caches/Google/Chrome",
                "Library/Caches/com.google.Chrome",
                "Library/Caches/Chromium",
                "Library/Caches/BraveSoftware",
                "Library/Caches/com.brave.Browser",
                "Library/Caches/company.thebrowser.Browser",
                "Library/Caches/Firefox",
                "Library/Caches/org.mozilla.firefox",
                "Library/Caches/Microsoft Edge",
                "Library/Caches/com.microsoft.edgemac",
                "Library/Caches/Opera",
                "Library/Caches/com.operasoftware.Opera",
                "Library/Caches/Vivaldi",
                "Library/Caches/com.apple.Safari",
                "Library/Caches/com.apple.Safari.SafeBrowsing",
                "Library/Caches/orion",
                "Library/Caches/com.kagi.orion",
                "Library/Caches/company.thebrowser.dia",
                "Library/Caches/app.zen-browser.zen",
                "Library/Caches/com.apple.SafariTechnologyPreview"
            ])
        case .messengerCaches:
            // WhatsApp Media и глубокий Telegram — отдельные категории, здесь только кэши.
            return existing([
                "Library/Caches/ru.keepcoder.Telegram",
                "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram.TelegramShare",
                "Library/Caches/com.tinyspeck.slackmacgap",
                "Library/Application Support/Slack/Cache",
                "Library/Application Support/Slack/Code Cache",
                "Library/Application Support/Slack/GPUCache",
                "Library/Application Support/Slack/Service Worker",
                "Library/Application Support/Slack/storage",
                "Library/Application Support/discord/Cache",
                "Library/Application Support/discord/Code Cache",
                "Library/Application Support/discord/GPUCache",
                "Library/Caches/com.hnc.Discord",
                "Library/Caches/com.apple.MobileSMS",
                "Library/Caches/net.whatsapp.WhatsApp",
                "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Library/Caches",
                "Library/Application Support/ViberPC/data",
                "Library/Caches/com.viber.osx",
                "Library/Application Support/Signal/Cache",
                "Library/Application Support/Signal/Code Cache",
                "Library/Application Support/Signal/GPUCache",
                "Library/Caches/org.telegram.desktop"
            ])
        case .officeCaches:
            return existing([
                "Library/Caches/com.microsoft.Word",
                "Library/Caches/com.microsoft.Excel",
                "Library/Caches/com.microsoft.Powerpoint",
                "Library/Caches/com.microsoft.Outlook",
                "Library/Caches/com.microsoft.office",
                "Library/Containers/com.microsoft.Word/Data/Library/Caches",
                "Library/Containers/com.microsoft.Excel/Data/Library/Caches",
                "Library/Containers/com.microsoft.Powerpoint/Data/Library/Caches",
                "Library/Containers/com.microsoft.Outlook/Data/Library/Caches",
                "Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/Caches",
                "Library/Caches/com.microsoft.OneDrive",
                "Library/Caches/com.microsoft.OneDriveStandaloneUpdater"
            ])
        case .whatsappMedia:
            return existing([
                "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media",
                "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Media",
                "Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches"
            ])
        case .cloudStorageCaches:
            // OneDrive Caches уже в officeCaches.
            return existingAbs([
                home.appendingPathComponent("Library/Caches/CloudKit"),
                home.appendingPathComponent("Library/Caches/com.apple.bird"),
                home.appendingPathComponent("Library/Application Support/Google/DriveFS"),
                home.appendingPathComponent("Library/Caches/com.google.drivefs"),
                home.appendingPathComponent("Library/CloudStorage/.Trash"),
                home.appendingPathComponent("Library/Application Support/OneDrive"),
                home.appendingPathComponent("Library/Caches/com.dropbox.DropboxMacUpdate")
            ])
        case .uvRyeCache:
            return existingAbs([
                home.appendingPathComponent(".cache/uv"),
                home.appendingPathComponent("Library/Caches/uv"),
                home.appendingPathComponent(".local/share/uv"),
                home.appendingPathComponent(".rye/py"),
                home.appendingPathComponent(".rye/tools"),
                home.appendingPathComponent("Library/Caches/rye")
            ])
        case .gitLfsCache:
            return existingAbs([
                home.appendingPathComponent(".git/lfs"),
                home.appendingPathComponent(".cache/git-lfs"),
                home.appendingPathComponent("Library/Caches/com.github.GitHubClient"),
                home.appendingPathComponent("Library/Caches/com.github.GitHubClient.ShipIt"),
                home.appendingPathComponent("Library/Application Support/GitHub Desktop/Cache"),
                home.appendingPathComponent("Library/Application Support/GitHub Desktop/GPUCache"),
                home.appendingPathComponent("Library/Application Support/GitHub Desktop/Code Cache")
            ])
        case .spotifyCache:
            return existing([
                "Library/Caches/com.spotify.client",
                "Library/Application Support/Spotify/PersistentCache",
                "Library/Application Support/Spotify/Storage"
            ])
        case .adobeCache:
            return existing([
                "Library/Caches/Adobe",
                "Library/Application Support/Adobe/Common/Media Cache Files",
                "Library/Application Support/Adobe/Common/Media Cache"
            ])
        case .zoomCache:
            return existing([
                "Library/Caches/us.zoom.xos",
                "Library/Application Support/zoom.us/data",
                "Library/Application Support/zoom.us/Cache"
            ])
        case .steamCache:
            return existing([
                "Library/Application Support/Steam/appcache",
                "Library/Application Support/Steam/steamapps/shadercache",
                "Library/Application Support/Steam/steamapps/temp",
                "Library/Application Support/Steam/steamapps/downloading",
                "Library/Application Support/Steam/depotcache",
                "Library/Application Support/Steam/logs",
                "Library/Application Support/Steam/htmlcache",
                "Library/Caches/com.valvesoftware.steam",
                "Library/Caches/com.valvesoftware.steam.helper"
            ])
        case .unityCache:
            return existing([
                "Library/Unity/Cache",
                "Library/Caches/com.unity3d.UnityEditor",
                "Library/Application Support/Unity/Cache",
                "Library/Logs/Unity"
            ])
        case .unrealCache:
            return existingAbs([
                home.appendingPathComponent("Library/Application Support/Epic/UnrealEngine/Common/DerivedDataCache"),
                home.appendingPathComponent("Library/Caches/com.epicgames.EpicGamesLauncher")
            ])
        case .blenderCache:
            return existing([
                "Library/Caches/Blender",
                "Library/Application Support/Blender"
            ].flatMap { base -> [String] in
                // Только Cache подверсии, не все конфиги
                let root = home.appendingPathComponent(base)
                guard let kids = try? fm.contentsOfDirectory(atPath: root.path) else {
                    return fm.fileExists(atPath: root.appendingPathComponent("Cache").path)
                        ? [base + "/Cache"] : []
                }
                return kids.compactMap { v in
                    let cache = root.appendingPathComponent(v).appendingPathComponent("cache")
                    return fm.fileExists(atPath: cache.path) ? "\(base)/\(v)/cache" : nil
                }
            })
        case .figmaCache:
            return existing([
                "Library/Caches/com.figma.Desktop",
                "Library/Application Support/Figma/DesktopProfile/Cache",
                "Library/Application Support/Figma/DesktopProfile/GPUCache",
                "Library/Application Support/Figma/DesktopProfile/Code Cache"
            ])
        case .teamsCache:
            return existing([
                "Library/Application Support/Microsoft/Teams/Cache",
                "Library/Application Support/Microsoft/Teams/Code Cache",
                "Library/Application Support/Microsoft/Teams/GPUCache",
                "Library/Application Support/Microsoft/Teams/Service Worker",
                "Library/Caches/com.microsoft.teams2"
            ])
        case .notionCache:
            return existing([
                "Library/Application Support/Notion/Cache",
                "Library/Application Support/Notion/Code Cache",
                "Library/Application Support/Notion/GPUCache",
                "Library/Caches/notion.id",
                "Library/Caches/notion.id.ShipIt",
                "Library/Caches/notion-updater"
            ])
        case .dropboxCache:
            return existing([
                "Library/Caches/com.getdropbox.dropbox",
                ".dropbox.cache"
            ])
        case .iMessageAttachments:
            return existing(["Library/Messages/Attachments"])
        case .bazelCache:
            return existingAbs([
                home.appendingPathComponent(".cache/bazel"),
                home.appendingPathComponent("Library/Caches/Bazel")
            ])
        case .sbtCache:
            return existingAbs([
                home.appendingPathComponent(".ivy2/cache"),
                home.appendingPathComponent(".sbt"),
                home.appendingPathComponent("Library/Caches/Coursier")
            ])
        case .electronApps:
            return existing([
                "Library/Caches/Electron",
                "Library/Application Support/Caches",
                "Library/Caches/com.github.Electron"
            ])
        case .nvmCache:
            return existingAbs([
                home.appendingPathComponent(".nvm/versions/node"),
                home.appendingPathComponent(".fnm/node-versions"),
                home.appendingPathComponent(".local/share/fnm/node-versions")
            ])

        case .homeDotCache:
            return existingAbs([home.appendingPathComponent(".cache")])
        case .xcodePreviews:
            return existing([
                "Library/Developer/Xcode/UserData/Previews",
                "Library/Developer/Xcode/UserData/IB Support",
                "Library/Caches/com.apple.dt.Xcode.Previews"
            ])
        case .coreSimulatorLogs:
            var urls = existing(["Library/Logs/CoreSimulator"])
            let devices = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            if let kids = try? fm.contentsOfDirectory(atPath: devices.path) {
                for id in kids.prefix(100) {
                    let log = devices.appendingPathComponent(id).appendingPathComponent("data/Library/Logs")
                    if fm.fileExists(atPath: log.path) { urls.append(log) }
                }
            }
            return uniqueURLs(urls)
        case .androidSDKCaches:
            var urls = existingAbs([
                home.appendingPathComponent("Library/Android/sdk/.temp"),
                home.appendingPathComponent("Library/Android/sdk/system-images"),
                home.appendingPathComponent(".android/cache"),
                home.appendingPathComponent(".android/avd"),
                home.appendingPathComponent(".gradle/caches"),
                home.appendingPathComponent(".gradle/wrapper/dists")
            ])
            let google = home.appendingPathComponent("Library/Caches/Google")
            if let kids = try? fm.contentsOfDirectory(atPath: google.path) {
                for name in kids where name.hasPrefix("AndroidStudio") || name.contains("Android") {
                    urls.append(google.appendingPathComponent(name))
                }
            }
            return uniqueURLs(urls)
        case .ccacheSccache:
            return existingAbs([
                home.appendingPathComponent(".ccache"),
                home.appendingPathComponent(".cache/ccache"),
                home.appendingPathComponent(".cache/sccache"),
                home.appendingPathComponent("Library/Caches/Mozilla.sccache")
            ])
        case .rubyGemsCache:
            return existingAbs([
                home.appendingPathComponent(".gem/cache"),
                home.appendingPathComponent(".gem/ruby"),
                home.appendingPathComponent("Library/Caches/CocoaPods"),
                home.appendingPathComponent(".cocoapods/repos"),
                home.appendingPathComponent("Library/Caches/org.carthage.CarthageKit")
            ])
        case .jupyterCache:
            return existingAbs([
                home.appendingPathComponent(".jupyter"),
                home.appendingPathComponent("Library/Jupyter"),
                home.appendingPathComponent(".ipynb_checkpoints"),
                home.appendingPathComponent(".cache/jupyter"),
                home.appendingPathComponent("Library/Caches/s.jupyternotebook")
            ])
        case .systemUpdateLeftovers:
            var urls = existing([
                "Library/Updates",
                "Library/Caches/com.apple.SoftwareUpdate",
                "Library/Caches/com.apple.MobileSoftwareUpdate",
                "Library/Caches/com.apple.MobileAsset",
                "Library/iTunes/iPhone Software Updates",
                "Library/Application Support/com.apple.MobileSoftwareUpdate"
            ])
            // Остатки ShipIt / Sparkle-установщиков в Caches (часто сотни МБ–ГБ).
            let caches = home.appendingPathComponent("Library/Caches")
            if let kids = try? fm.contentsOfDirectory(atPath: caches.path) {
                for name in kids where name.hasSuffix(".ShipIt") || name.hasSuffix("-updater") || name.hasSuffix("Updater") {
                    let p = caches.appendingPathComponent(name)
                    if fm.fileExists(atPath: p.path) { urls.append(p) }
                }
            }
            return uniqueURLs(urls)
        case .instrumentsTraces:
            return existing([
                "Library/Developer/Xcode/Instruments",
                "Library/Application Support/Instruments",
                "Library/Caches/com.apple.dt.Instruments"
            ])
        case .metalShaderCaches:
            return existing([
                "Library/Caches/com.apple.metal",
                "Library/Caches/com.apple.Metal",
                "Library/Caches/org.sparkle-project.SparkleUpdaterShaderCache"
            ])
        case .loomMiroCaches:
            return existing([
                "Library/Application Support/Loom/Cache",
                "Library/Application Support/Loom/Code Cache",
                "Library/Application Support/Loom/GPUCache",
                "Library/Caches/com.loom.desktop",
                "Library/Application Support/Miro/Cache",
                "Library/Application Support/Miro/Code Cache",
                "Library/Application Support/Miro/GPUCache",
                "Library/Caches/com.electron.realtimeboard",
                "Library/Application Support/Notion Calendar/Cache",
                "Library/Application Support/Notion Calendar/Code Cache"
            ])
        case .telegramMediaDeep:
            // Все аккаунты Telegram Desktop (user_data, user_data#2…) + tupdates.
            var urls: [URL] = []
            let tdata = home.appendingPathComponent("Library/Application Support/Telegram Desktop/tdata")
            if let kids = try? fm.contentsOfDirectory(atPath: tdata.path) {
                for name in kids where name == "user_data" || name.hasPrefix("user_data#") {
                    let account = tdata.appendingPathComponent(name)
                    if fm.fileExists(atPath: account.path) { urls.append(account) }
                }
            }
            let tupdates = home.appendingPathComponent("Library/Application Support/Telegram Desktop/tupdates")
            if fm.fileExists(atPath: tupdates.path) { urls.append(tupdates) }
            let emoji = home.appendingPathComponent("Library/Application Support/Telegram Desktop/tdata/emoji")
            if fm.fileExists(atPath: emoji.path) { urls.append(emoji) }
            return uniqueURLs(urls)
        case .secToolCaches:
            return existingAbs([
                home.appendingPathComponent("Library/Caches/grype"),
                home.appendingPathComponent("Library/Caches/trivy"),
                home.appendingPathComponent("Library/Caches/snyk"),
                home.appendingPathComponent(".cache/trivy"),
                home.appendingPathComponent(".cache/grype"),
                home.appendingPathComponent(".cache/snyk"),
                home.appendingPathComponent("Library/Caches/dotslash")
            ])
        case .editorStateBloat, .electronAppJunk:
            return []
        case .dockerDesktopData:
            return existing([
                "Library/Containers/com.docker.docker/Data",
                "Library/Group Containers/group.com.docker",
                "Library/Caches/com.docker.docker",
                "Library/Logs/Docker Desktop",
                ".docker/buildx",
                ".docker/scan"
            ])
        case .xcodeDocCaches:
            return existing([
                "Library/Developer/Shared/Documentation/DocSets",
                "Library/Developer/DocumentationCache",
                "Library/Developer/Xcode/DocumentationCache",
                "Library/Caches/com.apple.dt.Xcode.Downloadable"
            ])
        case .voltaAsdfNode:
            return existingAbs([
                home.appendingPathComponent(".volta/tools/image"),
                home.appendingPathComponent(".volta/tmp"),
                home.appendingPathComponent(".asdf/installs/nodejs"),
                home.appendingPathComponent(".asdf/downloads"),
                home.appendingPathComponent(".n/versions"),
                home.appendingPathComponent(".local/share/mise/installs/node"),
                home.appendingPathComponent(".local/share/mise/downloads"),
                home.appendingPathComponent(".nvm/.cache")
            ])

        case .mailDownloads:
            return existing([
                "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                "Library/Mail Downloads"
            ])
        case .webkitCache:
            return existing([
                "Library/Caches/WebKit",
                "Library/Caches/com.apple.WebKit.WebContent",
                "Library/Caches/com.apple.WebKit.Networking",
                "Library/Caches/com.apple.WebKit.GPU"
            ])
        case .iconServices:
            return existing([
                "Library/Caches/com.apple.iconservices.store",
                "Library/Caches/com.apple.iconservices"
            ])
        case .coreSuggestions:
            return existing([
                "Library/Caches/com.apple.suggestions",
                "Library/Caches/com.apple.proactive.eventtracker",
                "Library/Caches/com.apple.proactived",
                "Library/Caches/com.apple.duetexpertd"
            ])
        case .iCloudDaemonCache:
            return existing([
                "Library/Caches/com.apple.bird",
                "Library/Caches/com.apple.cloudd",
                "Library/Caches/com.apple.nsurlsessiond",
                "Library/Caches/com.apple.bird.token"
            ])
        case .spotlightIndexer:
            return existing([
                "Library/Caches/com.apple.Spotlight",
                "Library/Caches/com.apple.parsecd",
                "Library/Caches/Metadata"
            ])
        case .appleMediaApps:
            return existing([
                "Library/Caches/com.apple.podcasts",
                "Library/Caches/com.apple.Music",
                "Library/Caches/com.apple.tv",
                "Library/Caches/com.apple.AMPLibraryAgent",
                "Library/Caches/com.apple.iTunes",
                "Library/Group Containers/group.com.apple.podcasts/Library/Caches",
                "Library/Group Containers/group.com.apple.tv/Library/Caches",
                "Library/Application Support/com.apple.amp.itmstransporter"
            ])
        case .mapsCache:
            return existing([
                "Library/Caches/com.apple.geoanalyticsd",
                "Library/Caches/com.apple.Maps",
                "Library/Group Containers/group.com.apple.Maps/Library/Caches"
            ])
        case .screenTimeKnowledge:
            return existing([
                "Library/Application Support/Knowledge",
                "Library/Caches/com.apple.remindd",
                "Library/Caches/com.apple.ScreenTimeAgent",
                "Library/Caches/familycircled"
            ])
        case .mailCaches:
            return existing([
                "Library/Containers/com.apple.mail/Data/Library/Caches",
                "Library/Containers/com.apple.mail/Data/Library/WebKit",
                "Library/Mail/V10/MailData/Envelope Index.tmp"
            ])
        case .booksCache:
            return existing([
                "Library/Containers/com.apple.iBooksX/Data/Library/Caches",
                "Library/Containers/com.apple.iBooksX/Data/Library/WebKit",
                "Library/Caches/com.apple.iBooksX",
                "Library/Caches/com.apple.iBooks"
            ])
        case .mobileAssetCache:
            return existing([
                "Library/Caches/com.apple.MobileAsset",
                "Library/Caches/com.apple.MobileSoftwareUpdate.UpdateBrainService",
                "Library/Caches/com.apple.appstoreagent"
            ])
        case .speechVoicePacks:
            return existing([
                "Library/Caches/com.apple.speech.synthesis",
                "Library/Caches/com.apple.speech.recognition",
                "Library/Caches/com.apple.ttsd",
                "Library/Caches/com.apple.TextToSpeechService"
            ])
        case .parallelsVM:
            return existing([
                "Library/Caches/com.parallels.desktop.console",
                "Library/Parallels/Downloads",
                "Library/Logs/Parallels"
            ])
        case .proVideoApps:
            return existing([
                "Library/Caches/com.apple.FinalCut",
                "Library/Caches/com.apple.logic10",
                "Library/Caches/com.apple.garageband10",
                "Library/Caches/com.apple.motionapp",
                "Library/Application Support/ProApps",
                "Library/Application Support/Final Cut Pro/Workflows/Render Files",
                "Library/Application Support/Motion/Library/Render Files",
                "Library/Application Support/Logic/Project File Backups"
            ])
        case .javaJVM:
            return existing([
                "Library/Caches/Java",
                "Library/Application Support/Oracle/Java",
                "Library/Logs/Java",
                "Library/Caches/net.java.openjdk.java"
            ])
        case .pyenvRvmAsdf:
            return existingAbs([
                home.appendingPathComponent(".pyenv/versions"),
                home.appendingPathComponent(".rvm"),
                home.appendingPathComponent(".rubies"),
                home.appendingPathComponent(".asdf/downloads"),
                home.appendingPathComponent(".asdf/installs"),
                home.appendingPathComponent(".local/share/mise/installs"),
                home.appendingPathComponent(".local/share/mise/downloads")
            ])
        case .gcloudKubeColima:
            return existingAbs([
                home.appendingPathComponent(".config/gcloud/logs"),
                home.appendingPathComponent(".config/gcloud/cache"),
                home.appendingPathComponent(".kube/cache"),
                home.appendingPathComponent(".colima/_lima/_cache"),
                home.appendingPathComponent(".lima/cache"),
                home.appendingPathComponent(".orbstack/logs"),
                home.appendingPathComponent(".terraform.d/plugin-cache"),
                home.appendingPathComponent("Library/Caches/terraform"),
                home.appendingPathComponent("Library/Caches/pulumi")
            ])
        case .launcherCaches:
            return existing([
                "Library/Caches/com.runningwithcrayons.Alfred",
                "Library/Application Support/Alfred/Alfred.alfredpreferences/cache",
                "Library/Caches/com.raycast.macos",
                "Library/Application Support/com.raycast.macos/cache",
                "Library/Caches/com.surteesstudios.Bartender",
                "Library/Caches/com.flexibits.fantastical2.mac"
            ])
        case .obsidianNotes:
            var urls = existingAbs([home.appendingPathComponent("Library/Caches/md.obsidian")])
            let obsRoot = home.appendingPathComponent("Library/Application Support/obsidian")
            if let kids = try? fm.contentsOfDirectory(atPath: obsRoot.path) {
                for vault in kids {
                    for sub in ["Cache", "GPUCache", "Code Cache", "IndexedDB", "Service Worker", "blob_storage"] {
                        let p = obsRoot.appendingPathComponent(vault).appendingPathComponent(sub)
                        if fm.fileExists(atPath: p.path) { urls.append(p) }
                    }
                }
            }
            return uniqueURLs(urls)
        case .onePasswordLogs:
            return existing([
                "Library/Logs/1Password",
                "Library/Caches/2BUA8C4S2C.com.1password",
                "Library/Caches/com.1password.1password",
                "Library/Application Support/1Password/logs"
            ])
        case .utmVM:
            return existing([
                "Library/Containers/com.utmapp.UTM/Data/Library/Caches",
                "Library/Containers/com.utmapp.UTM/Data/tmp",
                "Library/Caches/com.utmapp.UTM"
            ])
        case .groupContainerCaches, .documentRevisions, .containerAppCaches:
            return []
        }
    }

    private func goCacheURLs() -> [URL] {
        var urls = [
            home.appendingPathComponent("go/pkg/mod"),
            home.appendingPathComponent("go/pkg/sumdb"),
            home.appendingPathComponent("Library/Caches/go-build")
        ]
        if let mod = shellZsh("go env GOMODCACHE 2>/dev/null") {
            urls.append(URL(fileURLWithPath: mod))
        }
        if let build = shellZsh("go env GOCACHE 2>/dev/null") {
            urls.append(URL(fileURLWithPath: build))
        }
        return existingAbs(urls)
    }

    // MARK: - Clean paths

    private func cleanablePaths(for scan: CategoryScan) -> [String] {
        let expand: Set<CleanCategoryID> = [
            .userCaches, .userLogs, .iosDeviceSupport, .iosBackups,
            .jetbrainsCaches, .aiDevTools, .browserCaches, .messengerCaches,
            .savedState
        ]

        if expand.contains(scan.category) {
            var paths: [String] = []
            for root in scan.paths {
                let children = (try? fm.contentsOfDirectory(atPath: root)) ?? []
                for name in children {
                    if scan.category == .userCaches,
                       bannedCacheNames.contains(name) || shouldExcludeFromUserCaches(name) {
                        continue
                    }
                    let full = (root as NSString).appendingPathComponent(name)
                    if scan.category == .aiDevTools {
                        if ["projects", "logs", "sessions", "cache", "Caches", "tmp", "ai-tracking"].contains(name)
                            || name.hasSuffix(".log")
                            || directorySize(at: URL(fileURLWithPath: full)) > 30_000_000 {
                            paths.append(full)
                        }
                    } else {
                        paths.append(full)
                    }
                }
            }
            return paths
        }

        if scan.category == .temporary {
            var paths: [String] = []
            for root in scan.paths {
                for name in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
                    paths.append((root as NSString).appendingPathComponent(name))
                }
            }
            return paths
        }

        return scan.paths
    }

    private func removeContents(at path: String, category: CleanCategoryID) throws {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }

        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let homePath = home.standardizedFileURL.path
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
        guard standardized.hasPrefix(homePath) || standardized.hasPrefix(tmp) || standardized.contains("/Homebrew") else {
            throw CleanerError.partiallyFailed("Запрещённый путь: \(path)")
        }

        if bannedCacheNames.contains((path as NSString).lastPathComponent) { return }

        if isDir.boolValue {
            let deleteWhole: Set<CleanCategoryID> = [
                .userCaches, .userLogs, .trash, .temporary, .iosDeviceSupport, .iosBackups,
                .aiDevTools, .installerImages, .mailDownloads, .browserCaches, .messengerCaches,
                .savedState, .quickLook, .projectArtifacts, .groupContainerCaches,
                .containerAppCaches, .documentRevisions, .mlModels, .proVideoApps,
                .officeCaches, .whatsappMedia, .cloudStorageCaches, .uvRyeCache, .gitLfsCache,
                .oldLargeDownloads, .chromeProfilesDeep, .orphanedAppSupport,
                .crashReportsDeep, .xcodeOldDeviceSupport, .editorStateBloat, .electronAppJunk,
                .secToolCaches
            ]
            if deleteWhole.contains(category) {
                try fm.removeItem(atPath: path)
            } else {
                for name in try fm.contentsOfDirectory(atPath: path) {
                    try? fm.removeItem(atPath: (path as NSString).appendingPathComponent(name))
                }
            }
        } else {
            try fm.removeItem(atPath: path)
        }
    }

    // MARK: - Special

    private func scanTimeMachineSnapshots(_ id: CleanCategoryID) -> CategoryScan {
        let list = shellZsh("tmutil listlocalsnapshots / 2>/dev/null | sed '1d'") ?? ""
        let lines = list.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        let estimate = Int64(lines.count) * 2_000_000_000
        let items = lines.map {
            CleanItem(path: $0, byteCount: 2_000_000_000, isSelected: id.selectedByDefault)
        }
        return CategoryScan(
            category: id,
            byteCount: lines.isEmpty ? 0 : max(estimate, 1),
            paths: lines,
            items: items,
            isSelected: id.selectedByDefault && !lines.isEmpty,
            exists: !lines.isEmpty,
            detailNote: lines.isEmpty ? nil : "Снимков: \(lines.count) (размер — оценка)"
        )
    }

    private func deleteLocalSnapshots() throws {
        _ = shellZsh("""
        tmutil listlocalsnapshots / 2>/dev/null | sed '1d' | while read -r s; do
          d="${s#com.apple.TimeMachine.}"; d="${d%.local}";
          tmutil deletelocalsnapshots "$d" 2>/dev/null || true
        done
        """)
    }

    private func scanDownloadInstallers(_ id: CleanCategoryID) -> CategoryScan {
        let downloads = home.appendingPathComponent("Downloads")
        guard fm.fileExists(atPath: downloads.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }
        let exts: Set<String> = ["dmg", "pkg", "iso", "zip", "ipsw"]
        let files = (try? fm.contentsOfDirectory(at: downloads, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        var hits: [CleanItem] = []
        var total: Int64 = 0
        for file in files {
            guard exts.contains(file.pathExtension.lowercased()) else { continue }
            let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let age = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                .map { Date().timeIntervalSince($0) } ?? 0
            if size >= 40_000_000 || age > 5 * 24 * 3600 {
                total += size
                hits.append(CleanItem(path: file.path, byteCount: size, isSelected: false))
            }
        }
        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id, byteCount: total, paths: [downloads.path],
            items: hits, isSelected: false, exists: total > 0,
            detailNote: "Только установщики из Загрузок — галочки по файлам"
        )
    }

    private func scanProjectArtifacts(_ id: CleanCategoryID) -> CategoryScan {
        let roots = ["Projects", "Developer", "repos", "dev", "code", "Code", "workspace", "Work",
                     "src", "Sites", "github", "gitlab", "GitHub", "work", "lab", "sandbox"]
            .map { home.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }

        var hits: [CleanItem] = []
        var total: Int64 = 0

        for root in roots {
            if Task.isCancelled { break }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            var depthSkip: [String] = []
            var entryCount = 0
            for case let url as URL in enumerator {
                entryCount += 1
                if entryCount % 500 == 0, Task.isCancelled { break }
                let name = url.lastPathComponent
                if depthSkip.contains(where: { url.path.hasPrefix($0) }) {
                    enumerator.skipDescendants()
                    continue
                }
                guard projectArtifactNames.contains(name) else { continue }
                let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
                if rel.split(separator: "/").count > 6 { continue }

                let size = directorySize(at: url)
                if size > 2_500_000 {
                    total += size
                    hits.append(CleanItem(path: url.path, byteCount: size, isSelected: false))
                    depthSkip.append(url.path)
                    enumerator.skipDescendants()
                }
                if hits.count >= 180 { break }
            }
            if hits.count >= 180 { break }
        }

        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: roots.map(\.path),
            items: hits,
            isSelected: false,
            exists: total > 0,
            detailNote: L10n.t(
                "Check node_modules / .next / target / build…",
                "Отметь нужные node_modules / .next / target…"
            )
        )
    }

    private func scanGroupContainerCaches(_ id: CleanCategoryID) -> CategoryScan {
        let root = home.appendingPathComponent("Library/Group Containers")
        guard fm.fileExists(atPath: root.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        var hits: [CleanItem] = []
        var total: Int64 = 0
        var seen = Set<String>()
        let cacheLeafs = Set(["Caches", "Cache", "GPUCache", "Code Cache", "Service Worker", "tmp"])

        guard let groups = try? fm.contentsOfDirectory(atPath: root.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        for group in groups {
            if Task.isCancelled { break }
            let groupURL = root.appendingPathComponent(group)
            let lib = groupURL.appendingPathComponent("Library")
            guard fm.fileExists(atPath: lib.path) else { continue }

            if let kids = try? fm.contentsOfDirectory(atPath: lib.path) {
                for name in kids where cacheLeafs.contains(name) {
                    let path = lib.appendingPathComponent(name)
                    guard !seen.contains(path.path) else { continue }
                    let size = directorySize(at: path)
                    guard size > 2_000_000 else { continue }
                    seen.insert(path.path)
                    total += size
                    hits.append(CleanItem(
                        path: path.path,
                        byteCount: size,
                        isSelected: id.selectedByDefault && size > 0
                    ))
                }
            }

            let nestedCaches = lib.appendingPathComponent("Caches")
            if fm.fileExists(atPath: nestedCaches.path), !seen.contains(nestedCaches.path) {
                let size = directorySize(at: nestedCaches)
                if size > 2_000_000 {
                    seen.insert(nestedCaches.path)
                    total += size
                    hits.append(CleanItem(
                        path: nestedCaches.path,
                        byteCount: size,
                        isSelected: id.selectedByDefault && size > 0
                    ))
                }
            }
            if hits.count >= 200 { break }
        }

        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: [root.path],
            items: hits,
            isSelected: id.selectedByDefault && total > 0,
            exists: total > 0,
            detailNote: hits.isEmpty ? nil : "Кэши приложений в Group Containers — отметьте нужные"
        )
    }

    private func scanContainerAppCaches(_ id: CleanCategoryID) -> CategoryScan {
        let root = home.appendingPathComponent("Library/Containers")
        guard fm.fileExists(atPath: root.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        var hits: [CleanItem] = []
        var total: Int64 = 0
        let skipBundles: Set<String> = [
            "com.apple.mail", "com.apple.MobileSMS", "com.apple.findmy",
            "com.apple.Home", "com.apple.PassKit"
        ]

        guard let containers = try? fm.contentsOfDirectory(atPath: root.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        var checked = 0
        for bundle in containers {
            checked += 1
            if checked % 40 == 0, Task.isCancelled { break }
            if skipBundles.contains(bundle) { continue }
            let cachePath = root
                .appendingPathComponent(bundle)
                .appendingPathComponent("Data/Library/Caches")
            guard fm.fileExists(atPath: cachePath.path) else { continue }
            let size = directorySize(at: cachePath)
            guard size > 2_000_000 else { continue }
            total += size
            hits.append(CleanItem(
                path: cachePath.path,
                byteCount: size,
                isSelected: id.selectedByDefault && size > 0
            ))
            if hits.count >= 200 { break }
        }

        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: [root.path],
            items: hits,
            isSelected: id.selectedByDefault && total > 0,
            exists: total > 0,
            detailNote: hits.isEmpty ? nil : "Sandbox Caches >2 МБ — часто «съедают» десятки ГБ незаметно"
        )
    }

    private func scanDocumentRevisions(_ id: CleanCategoryID) -> CategoryScan {
        let roots = ["Documents", "Desktop", "Downloads", "Movies", "Music"]
            .map { home.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }

        var hits: [CleanItem] = []
        var total: Int64 = 0

        for root in roots {
            if Task.isCancelled { break }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            var depth = 0
            var entryCount = 0
            for case let url as URL in enumerator {
                entryCount += 1
                if entryCount % 500 == 0, Task.isCancelled { break }
                let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
                depth = rel.split(separator: "/").count
                if depth > 6 {
                    enumerator.skipDescendants()
                    continue
                }
                guard url.lastPathComponent == ".DocumentRevisions-V100" else { continue }
                let size = directorySize(at: url)
                guard size > 1_000_000 else { continue }
                total += size
                hits.append(CleanItem(path: url.path, byteCount: size, isSelected: false))
                enumerator.skipDescendants()
                if hits.count >= 100 { break }
            }
            if hits.count >= 100 { break }
        }

        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: roots.map(\.path),
            items: hits,
            isSelected: false,
            exists: total > 0,
            detailNote: hits.isEmpty ? nil : "Скрытые версии файлов — часто гигабайты в Documents"
        )
    }

    private func scanOldLargeDownloads(_ id: CleanCategoryID) -> CategoryScan {
        let downloads = home.appendingPathComponent("Downloads")
        guard fm.fileExists(atPath: downloads.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }
        let installerExts: Set<String> = ["dmg", "pkg", "iso", "ipsw"]
        let files = (try? fm.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        var hits: [CleanItem] = []
        var folderSizes: [(String, Int64)] = []
        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey])
            if values?.isDirectory == true {
                let size = directorySize(at: file)
                let age = values?.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
                // Папки вроде «Telegram Desktop» в Загрузках
                if size >= 50_000_000 || (size > 10_000_000 && age > 14 * 24 * 3600) {
                    folderSizes.append((file.path, size))
                }
                continue
            }
            guard values?.isRegularFile == true else { continue }
            if installerExts.contains(file.pathExtension.lowercased()) { continue }
            let size = Int64(values?.fileSize ?? 0)
            let age = values?.contentModificationDate.map { Date().timeIntervalSince($0) } ?? 0
            if size >= 20_000_000 || (size > 2_000_000 && age > 7 * 24 * 3600) {
                folderSizes.append((file.path, size))
            }
        }
        let collapsed = PathAccounting.collapseEntries(folderSizes)
        hits = collapsed.map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: false) }
        hits.sort { $0.byteCount > $1.byteCount }
        let total = hits.reduce(0) { $0 + $1.byteCount }
        return CategoryScan(
            category: id, byteCount: total, paths: [downloads.path],
            items: hits, isSelected: false, exists: total > 0,
            detailNote: L10n.t("Large/old Downloads — pick files & folders", "Крупные/старые Загрузки — галочки по файлам и папкам")
        )
    }

    private func scanEditorStateBloat(_ id: CleanCategoryID) -> CategoryScan {
        let editors = ["Cursor", "Code", "Code - Insiders", "Windsurf", "VSCodium"]
        var folderSizes: [(String, Int64)] = []
        var roots: [String] = []

        func consider(_ url: URL, minBytes: Int64 = 5_000_000) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
            let size: Int64
            if isDir.boolValue {
                size = directorySize(at: url)
            } else {
                size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            }
            guard size >= minBytes else { return }
            folderSizes.append((url.path, size))
        }

        for editor in editors {
            let root = home.appendingPathComponent("Library/Application Support/\(editor)")
            guard fm.fileExists(atPath: root.path) else { continue }
            roots.append(root.path)

            for rel in [
                "User/History",
                "User/workspaceStorage",
                "snapshots",
                "logs",
                "Partitions",
                "CachedData",
                "CachedExtensions",
                "CachedExtensionVSIXs",
                "WebStorage",
                "User/globalStorage/anysphere.cursor-agent-worker",
                "User/globalStorage/anysphere.cursor-retrieval"
            ] {
                consider(root.appendingPathComponent(rel))
            }

            let gs = root.appendingPathComponent("User/globalStorage")
            if let kids = try? fm.contentsOfDirectory(atPath: gs.path) {
                for name in kids {
                    let lower = name.lowercased()
                    if lower.hasSuffix(".vscdb")
                        || lower.hasSuffix(".vscdb.backup")
                        || lower.hasSuffix(".vscdb-wal")
                        || lower.contains("cursor-agent")
                        || lower.hasSuffix(".db") && (lower.contains("conversation") || lower.contains("state")) {
                        consider(gs.appendingPathComponent(name), minBytes: 2_000_000)
                    }
                }
            }
        }

        // Agent transcripts / project caches в ~/.cursor
        consider(home.appendingPathComponent(".cursor/projects"), minBytes: 20_000_000)
        consider(home.appendingPathComponent(".cursor/ai-tracking"), minBytes: 5_000_000)

        let collapsed = PathAccounting.collapseEntries(folderSizes)
        let items = collapsed
            .sorted { $0.1 > $1.1 }
            .map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: false) }
        let total = collapsed.reduce(0) { $0 + $1.1 }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: roots,
            items: items,
            isSelected: false,
            exists: total > 0,
            detailNote: items.isEmpty ? nil : L10n.t(
                "Cursor/VS Code state DB can grow to tens of GB — chat history may reset",
                "База Cursor/VS Code может раздуться до десятков ГБ — история чатов может сброситься"
            )
        )
    }

    private func scanElectronAppJunk(_ id: CleanCategoryID) -> CategoryScan {
        let support = home.appendingPathComponent("Library/Application Support")
        guard fm.fileExists(atPath: support.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        // Уже покрыто другими категориями.
        let skipApps: Set<String> = [
            "Cursor", "Code", "Code - Insiders", "Windsurf", "VSCodium",
            "Google", "Chromium", "Arc", "BraveSoftware", "Microsoft Edge", "Firefox",
            "Steam", "Telegram Desktop", "discord", "Slack", "Signal", "Figma",
            "Adobe", "Docker Desktop", "com.apple.wallpaper", "Notion", "Notion Calendar"
        ]
        // Только самые жирные leaf — без глубокого обхода вложенных профилей.
        let leafs = ["Cache", "Caches", "Code Cache", "GPUCache", "Partitions", "logs", "Crashpad"]

        var folderSizes: [(String, Int64)] = []
        guard let apps = try? fm.contentsOfDirectory(atPath: support.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        var checked = 0
        for name in apps {
            if Task.isCancelled { break }
            if skipApps.contains(name) { continue }
            if name.lowercased().hasPrefix("com.apple") { continue }
            let appRoot = support.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: appRoot.path, isDirectory: &isDir), isDir.boolValue else { continue }
            checked += 1
            if checked > 80 { break }

            for leaf in leafs {
                let url = appRoot.appendingPathComponent(leaf)
                guard fm.fileExists(atPath: url.path) else { continue }
                let size = directorySize(at: url)
                guard size >= 40_000_000 else { continue }
                folderSizes.append((url.path, size))
            }
            if folderSizes.count >= 60 { break }
        }

        let collapsed = PathAccounting.collapseEntries(folderSizes)
        let items = collapsed
            .sorted { $0.1 > $1.1 }
            .prefix(100)
            .map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: false) }
        let total = items.reduce(0) { $0 + $1.byteCount }
        return CategoryScan(
            category: id,
            byteCount: total,
            paths: [support.path],
            items: Array(items),
            isSelected: false,
            exists: total > 0,
            detailNote: items.isEmpty ? nil : L10n.t(
                "Electron Partitions/Cache — offline data may re-download",
                "Electron Partitions/Cache — офлайн-данные могут скачаться снова"
            )
        )
    }

    private func scanChromeProfilesDeep(_ id: CleanCategoryID) -> CategoryScan {
        let browserRoots = [
            "Library/Application Support/Google/Chrome",
            "Library/Application Support/Arc",
            "Library/Application Support/Microsoft Edge",
            "Library/Application Support/BraveSoftware/Brave-Browser",
            "Library/Application Support/Chromium",
            "Library/Application Support/Vivaldi"
        ]
        let cacheLeafs = ["Code Cache", "GPUCache", "Service Worker", "ShaderCache",
                          "GrShaderCache", "Cache", "DawnCache", "File System"]
        var hits: [CleanItem] = []
        var paths: [String] = []

        for rel in browserRoots {
            let root = home.appendingPathComponent(rel)
            guard fm.fileExists(atPath: root.path) else { continue }
            paths.append(root.path)
            guard let kids = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for name in kids where name == "Default" || name.hasPrefix("Profile ") || name.hasPrefix("Guest Profile") {
                for leaf in cacheLeafs {
                    let p = root.appendingPathComponent(name).appendingPathComponent(leaf)
                    guard fm.fileExists(atPath: p.path) else { continue }
                    let size = directorySize(at: p)
                    guard size > 1_000_000 else { continue }
                    hits.append(CleanItem(path: p.path, byteCount: size, isSelected: false))
                }
            }
        }
        hits.sort { $0.byteCount > $1.byteCount }
        let collapsed = PathAccounting.collapseEntries(hits.map { ($0.path, $0.byteCount) })
        let items = collapsed.map { CleanItem(path: $0.0, byteCount: $0.1, isSelected: false) }
        let total = collapsed.reduce(0) { $0 + $1.1 }
        return CategoryScan(
            category: id, byteCount: total, paths: paths,
            items: items, isSelected: false, exists: total > 0,
            detailNote: items.isEmpty ? nil : "Кэши всех профилей браузеров — сессии могут сброситься"
        )
    }

    private func scanOrphanedAppSupport(_ id: CleanCategoryID) -> CategoryScan {
        let support = home.appendingPathComponent("Library/Application Support")
        let caches = home.appendingPathComponent("Library/Caches")
        guard fm.fileExists(atPath: support.path) else {
            return CategoryScan(category: id, byteCount: 0, paths: [], items: [], isSelected: false, exists: false, detailNote: nil)
        }

        // Имена установленных приложений (без .app)
        var installed = Set<String>()
        let appDirs = ["/Applications", home.appendingPathComponent("Applications").path]
        for dir in appDirs {
            guard let apps = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for app in apps where app.hasSuffix(".app") {
                installed.insert((app as NSString).deletingPathExtension.lowercased())
            }
        }

        let keep: Set<String> = [
            "apple", "com.apple", "microsoft", "google", "adobe", "mozilla",
            "crashreporter", "addressbook", "ical", "callhistorytransactions",
            "knowledge", "diskimages", "network", "animoji", "callhistorydb"
        ]

        var hits: [CleanItem] = []
        var total: Int64 = 0

        func consider(_ url: URL) {
            let name = url.lastPathComponent
            let lower = name.lowercased()
            if keep.contains(where: { lower.hasPrefix($0) }) { return }
            if installed.contains(where: { lower.contains($0) || $0.contains(lower) }) { return }
            // Bundle-id style folders often map to apps still installed via Containers — skip apple.*
            if lower.hasPrefix("com.apple") || lower.hasPrefix("group.com.apple") { return }
            let size = directorySize(at: url)
            guard size > 15_000_000 else { return }
            // Prefer Cache / Logs / Crashpad subfolders if present
            let prefer = ["Cache", "Caches", "GPUCache", "Code Cache", "logs", "Logs", "Crashpad", "blob_storage"]
            if let kids = try? fm.contentsOfDirectory(atPath: url.path) {
                var foundSub = false
                for kid in kids where prefer.contains(kid) {
                    let sub = url.appendingPathComponent(kid)
                    let subSize = directorySize(at: sub)
                    guard subSize > 10_000_000 else { continue }
                    total += subSize
                    hits.append(CleanItem(path: sub.path, byteCount: subSize, isSelected: false))
                    foundSub = true
                }
                if foundSub { return }
            }
            total += size
            hits.append(CleanItem(path: url.path, byteCount: size, isSelected: false))
        }

        if let supportKids = try? fm.contentsOfDirectory(atPath: support.path) {
            for name in supportKids.prefix(200) {
                if Task.isCancelled { break }
                consider(support.appendingPathComponent(name))
                if hits.count >= 120 { break }
            }
        }
        if hits.count < 120, let cacheKids = try? fm.contentsOfDirectory(atPath: caches.path) {
            for name in cacheKids.prefix(150) {
                if Task.isCancelled { break }
                let lower = name.lowercased()
                if bannedCacheNames.contains(name) { continue }
                if keep.contains(where: { lower.hasPrefix($0) }) { continue }
                if installed.contains(where: { lower.contains($0) }) { continue }
                let url = caches.appendingPathComponent(name)
                let size = directorySize(at: url)
                guard size > 8_000_000 else { continue }
                total += size
                hits.append(CleanItem(path: url.path, byteCount: size, isSelected: false))
                if hits.count >= 120 { break }
            }
        }

        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id, byteCount: total,
            paths: [support.path, caches.path],
            items: hits, isSelected: false, exists: total > 0,
            detailNote: hits.isEmpty ? nil : "Возможные кэши удалённых приложений — проверьте перед удалением"
        )
    }

    private func scanCrashReportsDeep(_ id: CleanCategoryID) -> CategoryScan {
        let roots = [
            home.appendingPathComponent("Library/Logs/DiagnosticReports"),
            home.appendingPathComponent("Library/Logs/CrashReporter"),
            URL(fileURLWithPath: "/Library/Logs/DiagnosticReports")
        ].filter { fm.fileExists(atPath: $0.path) }

        var hits: [CleanItem] = []
        var total: Int64 = 0
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let exts: Set<String> = ["crash", "ips", "spin", "diag", "shutdownStall"]

        for root in roots {
            guard let files = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for file in files {
                let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let ext = file.pathExtension.lowercased()
                guard exts.contains(ext) || file.lastPathComponent.contains(".crash") else { continue }
                if let mod = values?.contentModificationDate, mod > cutoff { continue }
                let size = Int64(values?.fileSize ?? 0)
                guard size > 0 else { continue }
                total += size
                hits.append(CleanItem(path: file.path, byteCount: size, isSelected: id.selectedByDefault))
            }
        }
        hits.sort { $0.byteCount > $1.byteCount }
        if hits.count > 150 {
            hits = Array(hits.prefix(150))
            total = hits.reduce(0) { $0 + $1.byteCount }
        }
        return CategoryScan(
            category: id, byteCount: total,
            paths: roots.map(\.path),
            items: hits,
            isSelected: id.selectedByDefault && total > 0,
            exists: total > 0,
            detailNote: hits.isEmpty ? nil : L10n.tf("Reports older than 7 days — %d files", "Отчёты старше 7 дней — %d файлов", hits.count)
        )
    }

    private func scanXcodeOldDeviceSupport(_ id: CleanCategoryID) -> CategoryScan {
        let roots = [
            "Library/Developer/Xcode/iOS DeviceSupport",
            "Library/Developer/Xcode/watchOS DeviceSupport",
            "Library/Developer/Xcode/tvOS DeviceSupport",
            "Library/Developer/Xcode/visionOS DeviceSupport"
        ].map { home.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }

        // Оставляем самые свежие 2 папки в каждом корне
        var hits: [CleanItem] = []
        var total: Int64 = 0

        for root in roots {
            guard let kids = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            let dirs = kids.compactMap { url -> (URL, Date)? in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
                guard values?.isDirectory == true else { return nil }
                return (url, values?.contentModificationDate ?? .distantPast)
            }.sorted { $0.1 > $1.1 }

            guard dirs.count > 2 else { continue }
            for (url, _) in dirs.dropFirst(2) {
                let size = directorySize(at: url)
                guard size > 50_000_000 else { continue }
                total += size
                hits.append(CleanItem(path: url.path, byteCount: size, isSelected: false))
            }
        }
        hits.sort { $0.byteCount > $1.byteCount }
        return CategoryScan(
            category: id, byteCount: total,
            paths: roots.map(\.path),
            items: hits, isSelected: false, exists: total > 0,
            detailNote: hits.isEmpty ? nil : "Оставлены 2 самых свежих DeviceSupport в каждом корне"
        )
    }

    // MARK: - Helpers

    private func existing(_ relative: [String]) -> [URL] {
        relative.map { home.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }
    }

    private func existingAbs(_ urls: [URL]) -> [URL] {
        urls.filter { fm.fileExists(atPath: $0.path) }
    }

    private func directorySize(at url: URL) -> Int64 {
        let key = url.standardizedFileURL.path
        if let cached = sizeCache.get(key) { return cached }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: key, isDirectory: &isDir) else {
            sizeCache.set(key, 0)
            return 0
        }
        if !isDir.boolValue {
            let size = (try? fm.attributesOfItem(atPath: key)[.size] as? Int64) ?? 0
            sizeCache.set(key, size)
            return size
        }

        // du -sk: на порядки быстрее полного enumerator по кэшам/node_modules.
        if let kb = duKilobytes(at: key) {
            let bytes = kb * 1024
            sizeCache.set(key, bytes)
            return bytes
        }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else {
            sizeCache.set(key, 0)
            return 0
        }

        var total: Int64 = 0
        var entryCount = 0
        for case let fileURL as URL in enumerator {
            entryCount += 1
            if entryCount & 4095 == 0, Task.isCancelled { break }
            if entryCount > 350_000 { break }
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                total += Int64(allocated)
            } else {
                total += Int64(values.fileSize ?? 0)
            }
        }
        sizeCache.set(key, total)
        return total
    }

    private func duKilobytes(at path: String) -> Int64? {
        let process = Process()
        let out = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8) else { return nil }
            let num = text.prefix(while: { $0.isNumber || $0 == " " }).trimmingCharacters(in: .whitespaces)
            return Int64(num)
        } catch {
            return nil
        }
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var out: [URL] = []
        for u in urls {
            let p = u.standardizedFileURL.path
            if seen.insert(p).inserted { out.append(u.standardizedFileURL) }
        }
        return out
    }

    /// Убирает URL, вложенные в другие URL из того же списка.
    private func collapseNestedURLs(_ urls: [URL]) -> [URL] {
        let unique = uniqueURLs(urls)
        let keptPaths = Set(PathAccounting.collapsePaths(unique.map(\.path)))
        return unique.filter { keptPaths.contains($0.standardizedFileURL.path) }
    }

    private func shellZsh(_ command: String) -> String? {
        runProcess(["/bin/zsh", "-lc", command])
    }

    @discardableResult
    private func runProcess(_ args: [String]) -> String? {
        guard let exe = args.first else { return nil }
        let process = Process()
        let out = Pipe()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = Array(args.dropFirst())
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
