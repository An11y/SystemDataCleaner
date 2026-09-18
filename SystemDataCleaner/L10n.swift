import Foundation

/// UI language follows macOS preferred languages (English default, Russian when system is Russian).
enum L10n {
    static var isRussian: Bool {
        if let code = Locale.current.language.languageCode?.identifier, code == "ru" {
            return true
        }
        return Locale.preferredLanguages.contains { $0.lowercased().hasPrefix("ru") }
    }

    static func t(_ en: String, _ ru: String) -> String {
        isRussian ? ru : en
    }

    static func tf(_ en: String, _ ru: String, _ args: CVarArg...) -> String {
        let format = t(en, ru)
        return String(format: format, locale: .current, arguments: args)
    }

    // MARK: - App chrome

    static var cancel: String { t("Cancel", "Отмена") }
    static var smart: String { t("Smart", "Умная") }
    static var smartHelp: String { t("Safe + large caution items · ⌘⇧2", "Безопасные + крупные осторожные · ⌘⇧2") }
    static var scan: String { t("Scan", "Сканировать") }
    static var errorTitle: String { t("Error", "Ошибка") }
    static var found: String { t("Found", "Найдено") }
    static var selected: String { t("Selected", "Выбрано") }
    static var free: String { t("Free", "Свободно") }
    static var onDisk: String { t("on disk", "на диске") }
    static var nothing: String { t("nothing", "ничего") }
    static var afterScan: String { t("after scan", "после скана") }
    static var searchPlaceholder: String { t("Search…", "Поиск…") }
    static var selectMenu: String { t("Select", "Выбор") }
    static var smartClean: String { t("Smart Clean", "Умная очистка") }
    static var safeOnly: String { t("Safe only", "Только безопасные") }
    static var selectAllWithSize: String { t("Select all with size", "Выбрать всё с размером") }
    static var deselectAll: String { t("Deselect all", "Снять всё") }
    static var scanning: String { t("Scanning…", "Сканирование…") }
    static var nothingFound: String { t("Nothing found", "Ничего не найдено") }
    static var resetFilter: String { t("Reset filter", "Сбросить фильтр") }
    static var emptyTitle: String { t("Clean up System Data", "Очистка системных данных") }
    static var emptyBody: String {
        t(
            "Find caches, logs, Xcode leftovers, and hidden folders.\nNothing is deleted until you confirm.",
            "Найдём кэши, логи, Xcode и скрытые папки.\nУдаление — только после подтверждения."
        )
    }
    static var scanDisk: String { t("Scan disk", "Сканировать диск") }
    static var toDelete: String { t("To delete", "К удалению") }
    static var pickOrSmart: String {
        t("Select categories or tap Smart", "Выберите категории или нажмите «Умная»")
    }
    static var cleaning: String { t("Cleaning…", "Чищу…") }
    static var delete: String { t("Delete", "Удалить") }
    static var fdaTitle: String { t("Full Disk Access needed", "Нужен Full Disk Access") }
    static var fdaBody: String {
        t("Without it, some folders may appear empty.", "Без доступа часть папок может быть пустой.")
    }
    static var settings: String { t("Settings", "Настройки") }
    static var confirmTitle: String { t("Delete selected?", "Удалить выбранное?") }
    static var confirmSubtitle: String { t("This cannot be undone", "Отменить будет нельзя") }
    static var riskSafe: String { t("Safe", "Безопасно") }
    static var riskCaution: String { t("Caution", "Осторожно") }
    static var riskDanger: String { t("Risk", "Риск") }
    static var removesWhole: String { t("Removed as a whole", "Удаляется целиком") }
    static var pathMissing: String { t("Path not found", "Путь не найден") }
    static var showInFinder: String { t("Show in Finder", "В Finder") }
    static var sortHelpPrefix: String { t("Sort", "Сортировка") }
    static var deleteSelectedMenu: String { t("Delete selected", "Удалить выбранное") }
    static var collapseDetails: String { t("Collapse details", "Свернуть детали") }

    static func categoriesCount(_ n: Int) -> String {
        tf("%d categories", "%d категорий", n)
    }

    static func categoriesShare(_ n: Int, _ pct: Int) -> String {
        tf("%d cat. · %d%%", "%d кат. · %d%%", n, pct)
    }

    static func scanningProgress(_ pct: Int) -> String {
        tf("Scanning… %d%%", "Сканирование… %d%%", pct)
    }

    static func freed(_ size: String) -> String {
        tf("Freed %@", "Освобождено %@", size)
    }

    static func toDeleteSize(_ size: String) -> String {
        tf("To delete · %@", "К удалению · %@", size)
    }

    static func andMore(_ n: Int) -> String {
        tf("and %d more…", "и ещё %d…", n)
    }

    static func showingOf(_ shown: Int, _ total: Int) -> String {
        tf("Showing %d of %d", "Показаны %d из %d", shown, total)
    }

    // MARK: - Status / VM

    static var readyStatus: String {
        t("Ready to scan System Data.", "Готов к сканированию «Системных данных».")
    }

    static var scanCancelled: String { t("Scan cancelled", "Скан отменён") }
    static var operationCancelled: String { t("Cancelled", "Операция отменена") }
    static var scanningStatus: String { t("Scanning…", "Сканирование…") }
    static var cleaningStatus: String { t("Cleaning…", "Очистка…") }
    static var recalculating: String { t("Recalculating…", "Пересчёт…") }
    static var cleanInterrupted: String { t("Cleaning interrupted", "Очистка прервана") }
    static var diskLooksGood: String { t("Almost nothing extra — disk looks good", "Лишнего почти нет — диск в порядке") }
    static var smartEmpty: String { t("Not enough safe junk for Smart Clean yet", "Для умной очистки пока мало безопасного мусора") }
    static var donePrefix: String { t("Done.", "Готово.") }

    static func smartSelected(_ size: String) -> String {
        tf("Smart Clean: %@", "Умная очистка: %@", size)
    }

    static func cancelledFound(_ size: String) -> String {
        tf("Cancelled · found %@", "Операция отменена · найдено %@", size)
    }

    static func scanningItem(_ done: Int, _ total: Int, _ name: String, _ found: String) -> String {
        tf("Scanning %d/%d: %@%@", "Сканирую %d/%d: %@%@", done, total, name, found)
    }

    static func cleaningItem(_ done: Int, _ total: Int, _ name: String) -> String {
        tf("Cleaning %d/%d: %@", "Чищу %d/%d: %@", done, total, name)
    }

    static func recalculatingItem(_ done: Int, _ total: Int, _ name: String) -> String {
        tf("Recalculating %d/%d: %@", "Пересчёт %d/%d: %@", done, total, name)
    }

    static func foundSummary(_ size: String, _ count: Int) -> String {
        tf("Found %@ · %d categories with data", "Найдено %@ · %d категорий с данными", size, count)
    }

    static func nothingSelectedError() -> String {
        t(
            "Nothing to clean — select categories or subfolders.",
            "Нечего чистить — выберите категории или подпапки."
        )
    }

    // MARK: - Sections / filters / sort / risk

    static func section(_ id: CleanSection) -> String {
        switch id {
        case .system: return t("System", "Система")
        case .developer: return t("Developer", "Разработка")
        case .apps: return t("Apps", "Приложения")
        case .hidden: return t("Hidden", "Скрытое")
        }
    }

    static func risk(_ id: RiskLevel) -> String {
        switch id {
        case .safe: return t("safe", "безопасно")
        case .caution: return t("caution", "осторожно")
        case .danger: return t("risk", "риск")
        }
    }

    static func riskTitle(_ id: RiskLevel) -> String {
        switch id {
        case .safe: return riskSafe
        case .caution: return riskCaution
        case .danger: return riskDanger
        }
    }

    static func filter(_ id: ListFilter) -> String {
        switch id {
        case .withSize: return t("With size", "С размером")
        case .selected: return t("Selected", "Выбранные")
        case .all: return t("All", "Все")
        case .risky: return t("Risky", "Рискованные")
        }
    }

    static func filterShort(_ id: ListFilter) -> String {
        switch id {
        case .withSize: return t("With size", "С размером")
        case .selected: return t("Selected", "Выбрано")
        case .all: return t("All", "Все")
        case .risky: return t("Risk", "Риск")
        }
    }

    static func sort(_ id: SortMode) -> String {
        switch id {
        case .size: return t("Size", "Размер")
        case .name: return t("Name", "Имя")
        case .risk: return t("Risk", "Риск")
        }
    }

    // MARK: - Categories

    static func categoryTitle(_ id: CleanCategoryID) -> String {
        switch id {
        case .userCaches: return t("App Caches", "Кэши приложений")
        case .userLogs: return t("Logs", "Логи")
        case .temporary: return t("Temporary files", "Временные файлы")
        case .trash: return t("Trash", "Корзина")
        case .quickLook: return "Quick Look thumbnails"
        case .fontCaches: return t("Font caches", "Кэш шрифтов")
        case .savedState: return "Saved Application State"
        case .mediaAnalysis: return "Photos media analysis"
        case .appleIntelligence: return "Apple Intelligence / Siri TTS"
        case .iosSoftwareUpdates: return t("iOS firmware cache", "Прошивки iOS (кэш)")
        case .xcodeDerivedData: return "Xcode DerivedData"
        case .xcodeArchives: return "Xcode Archives"
        case .iosDeviceSupport: return "iOS DeviceSupport"
        case .simulatorCaches: return t("Simulator caches", "Кэш симуляторов")
        case .unavailableSimulators: return t("Dead simulators", "Мёртвые симуляторы")
        case .swiftPMCache: return "SwiftPM cache"
        case .xcodeCaches: return t("Xcode caches", "Кэши Xcode")
        case .carthage: return "Carthage"
        case .iosBackups: return t("iPhone/iPad backups", "Бэкапы iPhone/iPad")
        case .timeMachineSnapshots: return t("Time Machine snapshots", "Снапшоты Time Machine")
        case .homebrew: return "Homebrew cache"
        case .brewCleanup: return "brew cleanup"
        case .npm: return "npm / yarn / pnpm"
        case .bun: return "Bun"
        case .deno: return "Deno cache"
        case .cocoapods: return "CocoaPods"
        case .gradle: return "Gradle / Android"
        case .maven: return "Maven (.m2)"
        case .pip: return "pip"
        case .poetry: return "Poetry cache"
        case .conda: return "Conda / pkgs"
        case .goCache: return "Go module cache"
        case .cargo: return "Rust / Cargo"
        case .flutter: return "Flutter / Dart pub"
        case .composer: return "PHP Composer"
        case .nuget: return "NuGet cache"
        case .docker: return "Docker prune"
        case .playwright: return "Playwright"
        case .cypress: return "Cypress cache"
        case .puppeteer: return "Puppeteer / Chrome for Testing"
        case .jetbrainsCaches: return "JetBrains"
        case .vscodeCaches: return "VS Code / Cursor / Windsurf"
        case .androidStudio: return "Android Studio caches"
        case .aiDevTools: return t("AI agents", "AI-агенты")
        case .mlModels: return t("ML models (Ollama, etc.)", "ML-модели (Ollama и др.)")
        case .browserCaches: return t("Browser caches", "Кэши браузеров")
        case .messengerCaches: return "Telegram / Discord / Slack"
        case .spotifyCache: return "Spotify cache"
        case .adobeCache: return "Adobe cache"
        case .zoomCache: return "Zoom cache"
        case .steamCache: return "Steam / shaders"
        case .unityCache: return "Unity cache"
        case .unrealCache: return "Unreal Engine cache"
        case .blenderCache: return "Blender cache"
        case .figmaCache: return "Figma cache"
        case .teamsCache: return "Microsoft Teams"
        case .notionCache: return "Notion cache"
        case .dropboxCache: return "Dropbox cache"
        case .iMessageAttachments: return t("Messages attachments", "Вложения Сообщений")
        case .bazelCache: return "Bazel cache"
        case .sbtCache: return "SBT / Ivy cache"
        case .electronApps: return "Electron / helper caches"
        case .nvmCache: return t("nvm / fnm old Node", "nvm / fnm старые Node")
        case .webkitCache: return t("WebKit shared cache", "WebKit (общий кэш)")
        case .iconServices: return t("IconServices / icons", "IconServices / иконки")
        case .coreSuggestions: return "Siri Suggestions"
        case .iCloudDaemonCache: return t("bird / cloudd cache", "bird / cloudd кэш")
        case .spotlightIndexer: return t("Spotlight index", "Spotlight индекс")
        case .appleMediaApps: return "Music / TV / Podcasts"
        case .mapsCache: return t("Maps / geo analytics", "Карты / геоаналитика")
        case .screenTimeKnowledge: return "Screen Time / Knowledge"
        case .mailCaches: return t("Mail.app cache", "Кэш Mail.app")
        case .booksCache: return "Apple Books"
        case .mobileAssetCache: return t("MobileAsset cache", "MobileAsset кэш")
        case .speechVoicePacks: return t("Voices / dictation", "Голоса / диктовка")
        case .parallelsVM: return t("Parallels cache", "Parallels кэш")
        case .proVideoApps: return "Final Cut / Logic"
        case .javaJVM: return "Java / JVM"
        case .pyenvRvmAsdf: return t("Old Python / Ruby", "Старые Python / Ruby")
        case .gcloudKubeColima: return "gcloud / kube / Colima"
        case .launcherCaches: return "Raycast / Alfred"
        case .obsidianNotes: return "Obsidian cache"
        case .onePasswordLogs: return "1Password logs"
        case .utmVM: return "UTM cache"
        case .groupContainerCaches: return "Group Containers Cache"
        case .documentRevisions: return ".DocumentRevisions-V100"
        case .containerAppCaches: return "Sandbox app Caches"
        case .oldLargeDownloads: return t("Large/old Downloads", "Крупные/старые Загрузки")
        case .chromeProfilesDeep: return t("Chrome / Arc / Edge profiles", "Профили Chrome / Arc / Edge")
        case .officeCaches: return "Microsoft Office / Outlook"
        case .whatsappMedia: return "WhatsApp Media"
        case .cloudStorageCaches: return t("Cloud storage caches", "Облачные кэши")
        case .orphanedAppSupport: return t("Orphaned Application Support", "Сироты Application Support")
        case .uvRyeCache: return "uv / rye cache"
        case .gitLfsCache: return "Git LFS / GitHub Desktop"
        case .crashReportsDeep: return t("Old crash reports", "Старые crash-отчёты")
        case .xcodeOldDeviceSupport: return t("Old DeviceSupport", "Старый DeviceSupport")
        case .installerImages: return t("DMG / PKG in Downloads", "DMG / PKG в Загрузках")
        case .mailDownloads: return t("Mail attachments", "Вложения Mail")
        case .projectArtifacts: return t("Artifacts in ~/Projects", "Артефакты в ~/Projects")
        case .homeDotCache: return t("Home ~/.cache", "Домашний ~/.cache")
        case .xcodePreviews: return t("Xcode Previews cache", "Кэш Xcode Previews")
        case .coreSimulatorLogs: return t("Simulator logs", "Логи симуляторов")
        case .androidSDKCaches: return t("Android SDK / AVD caches", "Кэши Android SDK / AVD")
        case .ccacheSccache: return t("ccache / sccache", "ccache / sccache")
        case .rubyGemsCache: return t("RubyGems / CocoaPods repos", "RubyGems / CocoaPods repos")
        case .jupyterCache: return t("Jupyter / notebook caches", "Jupyter / кэши ноутбуков")
        case .systemUpdateLeftovers: return t("Software Update leftovers", "Остатки обновлений macOS")
        case .instrumentsTraces: return t("Instruments traces", "Трассы Instruments")
        case .metalShaderCaches: return t("Metal / GPU shader caches", "Metal / GPU shader-кэши")
        case .loomMiroCaches: return t("Loom / Miro caches", "Кэши Loom / Miro")
        case .telegramMediaDeep: return t("Telegram media cache", "Медиа-кэш Telegram")
        case .dockerDesktopData: return t("Docker Desktop data", "Данные Docker Desktop")
        case .xcodeDocCaches: return t("Xcode docs / downloads", "Доки / загрузки Xcode")
        case .voltaAsdfNode: return t("Volta / asdf / n Node versions", "Volta / asdf / n версии Node")
        }
    }
}
