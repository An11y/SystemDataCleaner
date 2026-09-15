import Foundation

enum CleanCategoryID: String, CaseIterable, Identifiable, Codable {
    // Система / пользователь
    case userCaches, userLogs, temporary, trash, quickLook, fontCaches, savedState, mediaAnalysis
    case appleIntelligence, iosSoftwareUpdates

    // Xcode / Apple Dev
    case xcodeDerivedData, xcodeArchives, iosDeviceSupport, simulatorCaches
    case unavailableSimulators, swiftPMCache, xcodeCaches, carthage

    // Бэкапы
    case iosBackups, timeMachineSnapshots

    // Языки / пакеты
    case homebrew, brewCleanup, npm, bun, deno, cocoapods
    case gradle, maven, pip, poetry, conda, goCache, cargo, flutter, composer, nuget

    // Тесты / контейнеры
    case docker, playwright, cypress, puppeteer

    // IDE / AI / медиа-приложения
    case jetbrainsCaches, vscodeCaches, androidStudio
    case aiDevTools, mlModels
    case browserCaches, messengerCaches, spotifyCache, adobeCache, zoomCache
    case steamCache, unityCache, unrealCache, blenderCache, figmaCache
    case teamsCache, notionCache, dropboxCache, iMessageAttachments
    case bazelCache, sbtCache, electronApps, nvmCache

    // Скрытые / малоизвестные
    case webkitCache, iconServices, coreSuggestions, iCloudDaemonCache
    case spotlightIndexer, appleMediaApps, mapsCache, screenTimeKnowledge
    case mailCaches, booksCache, mobileAssetCache, speechVoicePacks
    case parallelsVM, proVideoApps, javaJVM, pyenvRvmAsdf
    case gcloudKubeColima, launcherCaches, obsidianNotes, onePasswordLogs, utmVM
    case groupContainerCaches, documentRevisions, containerAppCaches

    // Новые источники мусора
    case oldLargeDownloads, chromeProfilesDeep, officeCaches, whatsappMedia
    case cloudStorageCaches, orphanedAppSupport, uvRyeCache, gitLfsCache
    case crashReportsDeep, xcodeOldDeviceSupport

    // Файлы
    case installerImages, mailDownloads, projectArtifacts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userCaches: return "Кэши приложений"
        case .userLogs: return "Логи"
        case .temporary: return "Временные файлы"
        case .trash: return "Корзина"
        case .quickLook: return "Quick Look thumbnails"
        case .fontCaches: return "Кэш шрифтов"
        case .savedState: return "Saved Application State"
        case .mediaAnalysis: return "Photos media analysis"
        case .appleIntelligence: return "Apple Intelligence / Siri TTS"
        case .iosSoftwareUpdates: return "Прошивки iOS (кэш)"
        case .xcodeDerivedData: return "Xcode DerivedData"
        case .xcodeArchives: return "Xcode Archives"
        case .iosDeviceSupport: return "iOS DeviceSupport"
        case .simulatorCaches: return "Кэш симуляторов"
        case .unavailableSimulators: return "Мёртвые симуляторы"
        case .swiftPMCache: return "SwiftPM cache"
        case .xcodeCaches: return "Кэши Xcode"
        case .carthage: return "Carthage"
        case .iosBackups: return "Бэкапы iPhone/iPad"
        case .timeMachineSnapshots: return "Снапшоты Time Machine"
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
        case .aiDevTools: return "AI-агенты"
        case .mlModels: return "ML-модели (Ollama и др.)"
        case .browserCaches: return "Кэши браузеров"
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
        case .iMessageAttachments: return "Вложения Сообщений"
        case .bazelCache: return "Bazel cache"
        case .sbtCache: return "SBT / Ivy cache"
        case .electronApps: return "Electron / helper caches"
        case .nvmCache: return "nvm / fnm старые Node"
        case .webkitCache: return "WebKit (общий кэш)"
        case .iconServices: return "IconServices / иконки"
        case .coreSuggestions: return "Siri Suggestions"
        case .iCloudDaemonCache: return "bird / cloudd кэш"
        case .spotlightIndexer: return "Spotlight индекс"
        case .appleMediaApps: return "Music / TV / Podcasts"
        case .mapsCache: return "Карты / геоаналитика"
        case .screenTimeKnowledge: return "Screen Time / Knowledge"
        case .mailCaches: return "Кэш Mail.app"
        case .booksCache: return "Apple Books"
        case .mobileAssetCache: return "MobileAsset кэш"
        case .speechVoicePacks: return "Голоса / диктовка"
        case .parallelsVM: return "Parallels кэш"
        case .proVideoApps: return "Final Cut / Logic"
        case .javaJVM: return "Java / JVM"
        case .pyenvRvmAsdf: return "Старые Python / Ruby"
        case .gcloudKubeColima: return "gcloud / kube / Colima"
        case .launcherCaches: return "Raycast / Alfred"
        case .obsidianNotes: return "Obsidian cache"
        case .onePasswordLogs: return "1Password logs"
        case .utmVM: return "UTM cache"
        case .groupContainerCaches: return "Group Containers Cache"
        case .documentRevisions: return ".DocumentRevisions-V100"
        case .containerAppCaches: return "Sandbox app Caches"
        case .oldLargeDownloads: return "Крупные/старые Загрузки"
        case .chromeProfilesDeep: return "Профили Chrome / Arc / Edge"
        case .officeCaches: return "Microsoft Office / Outlook"
        case .whatsappMedia: return "WhatsApp Media"
        case .cloudStorageCaches: return "Облачные кэши"
        case .orphanedAppSupport: return "Сироты Application Support"
        case .uvRyeCache: return "uv / rye cache"
        case .gitLfsCache: return "Git LFS / GitHub Desktop"
        case .crashReportsDeep: return "Старые crash-отчёты"
        case .xcodeOldDeviceSupport: return "Старый DeviceSupport"
        case .installerImages: return "DMG / PKG в Загрузках"
        case .mailDownloads: return "Вложения Mail"
        case .projectArtifacts: return "Артефакты в ~/Projects"
        }
    }

    var subtitle: String {
        switch self {
        case .userCaches: return "~/Library/Caches"
        case .userLogs: return "~/Library/Logs + DiagnosticReports"
        case .temporary: return "NSTemporaryDirectory"
        case .trash: return "~/.Trash"
        case .quickLook: return "com.apple.QuickLook.thumbnailcache"
        case .fontCaches: return "ATS / Font caches"
        case .savedState: return "Saved Application State"
        case .mediaAnalysis: return "mediaanalysisd / Photos"
        case .appleIntelligence: return "SiriTTS, model caches"
        case .iosSoftwareUpdates: return "iPhone Software Updates"
        case .xcodeDerivedData: return "сборки Xcode"
        case .xcodeArchives: return ".xcarchive"
        case .iosDeviceSupport: return "символы устройств"
        case .simulatorCaches: return "CoreSimulator/Caches"
        case .unavailableSimulators: return "simctl delete unavailable"
        case .swiftPMCache: return "org.swift.swiftpm"
        case .xcodeCaches: return "ModuleCache, IB Support…"
        case .carthage: return "CarthageKit + Checkouts"
        case .iosBackups: return "MobileSync/Backup"
        case .timeMachineSnapshots: return "tmutil local"
        case .homebrew: return "Library/Caches/Homebrew"
        case .brewCleanup: return "brew cleanup -as"
        case .npm: return "npm / yarn / pnpm stores"
        case .bun: return "~/.bun/install/cache"
        case .deno: return "deno cache dirs"
        case .cocoapods: return "CocoaPods caches"
        case .gradle: return ".gradle + Android"
        case .maven: return "~/.m2/repository"
        case .pip: return "pip cache"
        case .poetry: return "pypoetry cache"
        case .conda: return "pkgs / .conda/pkgs"
        case .goCache: return "GOMODCACHE / pkg/mod"
        case .cargo: return "registry + git"
        case .flutter: return "pub-cache + Flutter caches"
        case .composer: return "~/.composer/cache"
        case .nuget: return ".nuget/packages"
        case .docker: return "docker system prune"
        case .playwright: return "ms-playwright"
        case .cypress: return "Cypress binary cache"
        case .puppeteer: return "puppeteer chrome"
        case .jetbrainsCaches: return "Caches + Logs JetBrains"
        case .vscodeCaches: return "Code / Cursor / Windsurf"
        case .androidStudio: return "Google/AndroidStudio*"
        case .aiDevTools: return "claude / codex / cursor worker"
        case .mlModels: return "ollama / huggingface / torch"
        case .browserCaches: return "Chrome / Firefox / Edge / Brave / Arc"
        case .messengerCaches: return "мессенджеры"
        case .spotifyCache: return "Spotify Persistence"
        case .adobeCache: return "Adobe cache"
        case .zoomCache: return "Zoom data cache"
        case .steamCache: return "Steam appcache / shadercache"
        case .unityCache: return "Unity Hub + Library caches"
        case .unrealCache: return "Unreal DerivedDataCache"
        case .blenderCache: return "Blender caches"
        case .figmaCache: return "Figma Desktop cache"
        case .teamsCache: return "Teams Cache / GPUCache"
        case .notionCache: return "Notion Cache"
        case .dropboxCache: return "Dropbox cache"
        case .iMessageAttachments: return "~/Library/Messages/Attachments"
        case .bazelCache: return "~/.cache/bazel"
        case .sbtCache: return ".ivy2 / .sbt"
        case .electronApps: return "общие Electron Cache"
        case .nvmCache: return ".nvm/versions (старые)"
        case .webkitCache: return "Library/Caches/WebKit"
        case .iconServices: return "iconservices.store"
        case .coreSuggestions: return "proactive / suggestions"
        case .iCloudDaemonCache: return "iCloud sync daemon"
        case .spotlightIndexer: return "Metadata / CoreSpotlight"
        case .appleMediaApps: return "Podcasts / Music / TV"
        case .mapsCache: return "group.com.apple.Maps"
        case .screenTimeKnowledge: return "Knowledge / remindd"
        case .mailCaches: return "Mail WebKit / Caches"
        case .booksCache: return "iBooksX caches"
        case .mobileAssetCache: return "com.apple.MobileAsset"
        case .speechVoicePacks: return "speech.synthesis"
        case .parallelsVM: return "Parallels / Downloads"
        case .proVideoApps: return "Render Files / ProApps"
        case .javaJVM: return "Oracle / OpenJDK"
        case .pyenvRvmAsdf: return "pyenv / rvm / asdf / mise"
        case .gcloudKubeColima: return "облако / контейнеры"
        case .launcherCaches: return "лаунчеры macOS"
        case .obsidianNotes: return "IndexedDB / GPUCache"
        case .onePasswordLogs: return "1Password / 2BUA8C4S2C"
        case .utmVM: return "UTM Documents cache"
        case .groupContainerCaches: return "скан GC */Library/Caches"
        case .documentRevisions: return "версии файлов macOS"
        case .containerAppCaches: return "Containers */Data/Caches"
        case .oldLargeDownloads: return ">50 МБ или старше 14 дней"
        case .chromeProfilesDeep: return "Profile */Code Cache, GPU…"
        case .officeCaches: return "Office / Outlook / OneDrive"
        case .whatsappMedia: return "WhatsApp Media folders"
        case .cloudStorageCaches: return "iCloud / Drive / OneDrive"
        case .orphanedAppSupport: return "кэши удалённых приложений"
        case .uvRyeCache: return "uv / rye Python caches"
        case .gitLfsCache: return "LFS + GitHub Desktop"
        case .crashReportsDeep: return "DiagnosticReports старше 14 дней"
        case .xcodeOldDeviceSupport: return "DeviceSupport без активного Xcode"
        case .installerImages: return "Downloads *.dmg *.pkg"
        case .mailDownloads: return "Mail Downloads"
        case .projectArtifacts: return "node_modules, .next, target, build…"
        }
    }

    var systemImage: String {
        switch self {
        case .userCaches: return "internaldrive"
        case .userLogs: return "doc.text"
        case .temporary: return "clock"
        case .trash: return "trash"
        case .quickLook: return "eye"
        case .fontCaches: return "textformat"
        case .savedState: return "rectangle.stack"
        case .mediaAnalysis: return "photo.on.rectangle"
        case .appleIntelligence: return "sparkles"
        case .iosSoftwareUpdates: return "arrow.down.app"
        case .xcodeDerivedData: return "hammer"
        case .xcodeArchives: return "shippingbox"
        case .iosDeviceSupport: return "apple.logo"
        case .simulatorCaches: return "iphone"
        case .unavailableSimulators: return "xmark.iphone"
        case .swiftPMCache: return "shippingbox.circle"
        case .xcodeCaches: return "gearshape.2"
        case .carthage: return "basket"
        case .iosBackups: return "ipod"
        case .timeMachineSnapshots: return "clock.arrow.circlepath"
        case .homebrew, .brewCleanup: return "mug"
        case .npm, .bun, .deno: return "square.stack.3d.up"
        case .cocoapods: return "leaf"
        case .gradle, .androidStudio: return "hammer.fill"
        case .maven: return "archivebox"
        case .pip, .poetry, .conda: return "chevron.left.forwardslash.chevron.right"
        case .goCache: return "tortoise"
        case .cargo: return "gearshape"
        case .flutter: return "leaf.circle"
        case .composer: return "globe"
        case .nuget: return "shippingbox.fill"
        case .docker: return "shippingbox.fill"
        case .playwright, .cypress, .puppeteer: return "globe"
        case .jetbrainsCaches, .vscodeCaches: return "laptopcomputer"
        case .aiDevTools: return "brain.head.profile"
        case .mlModels: return "cpu"
        case .browserCaches: return "safari"
        case .messengerCaches: return "message"
        case .spotifyCache: return "music.note"
        case .adobeCache: return "paintbrush"
        case .zoomCache: return "video"
        case .steamCache: return "gamecontroller"
        case .unityCache, .unrealCache: return "cube"
        case .blenderCache: return "circle.grid.cross"
        case .figmaCache: return "paintpalette"
        case .teamsCache: return "person.3"
        case .notionCache: return "doc.richtext"
        case .dropboxCache: return "externaldrive.badge.icloud"
        case .iMessageAttachments: return "message.fill"
        case .bazelCache, .sbtCache: return "shippingbox.circle"
        case .electronApps: return "memorychip"
        case .nvmCache: return "square.stack.3d.down.right"
        case .webkitCache: return "globe.americas"
        case .iconServices: return "app.dashed"
        case .coreSuggestions: return "lightbulb"
        case .iCloudDaemonCache: return "icloud"
        case .spotlightIndexer: return "magnifyingglass.circle"
        case .appleMediaApps: return "play.tv"
        case .mapsCache: return "map"
        case .screenTimeKnowledge: return "hourglass"
        case .mailCaches: return "envelope.badge"
        case .booksCache: return "book.closed"
        case .mobileAssetCache: return "arrow.down.circle.dotted"
        case .speechVoicePacks: return "waveform"
        case .parallelsVM: return "rectangle.on.rectangle"
        case .proVideoApps: return "film"
        case .javaJVM: return "cup.and.saucer"
        case .pyenvRvmAsdf: return "tortoise.fill"
        case .gcloudKubeColima: return "cloud"
        case .launcherCaches: return "command"
        case .obsidianNotes: return "note.text"
        case .onePasswordLogs: return "key.horizontal"
        case .utmVM: return "desktopcomputer"
        case .groupContainerCaches: return "square.grid.3x3.square"
        case .documentRevisions: return "clock.arrow.circlepath"
        case .containerAppCaches: return "shippingbox"
        case .oldLargeDownloads: return "arrow.down.doc"
        case .chromeProfilesDeep: return "person.2.crop.square.stack"
        case .officeCaches: return "doc.richtext.fill"
        case .whatsappMedia: return "phone.bubble"
        case .cloudStorageCaches: return "cloud.fill"
        case .orphanedAppSupport: return "app.badge.checkmark"
        case .uvRyeCache: return "leaf.arrow.triangle.circlepath"
        case .gitLfsCache: return "arrow.triangle.branch"
        case .crashReportsDeep: return "exclamationmark.triangle"
        case .xcodeOldDeviceSupport: return "iphone.slash"
        case .installerImages: return "opticaldiscdrive"
        case .mailDownloads: return "envelope"
        case .projectArtifacts: return "folder.badge.gearshape"
        }
    }

    var riskNote: String {
        switch self {
        case .xcodeArchives, .iosBackups, .docker, .mlModels, .mailDownloads, .maven, .conda,
             .projectArtifacts, .iosSoftwareUpdates, .iMessageAttachments, .nvmCache,
             .parallelsVM, .utmVM, .pyenvRvmAsdf, .proVideoApps,
             .screenTimeKnowledge, .groupContainerCaches, .containerAppCaches,
             .oldLargeDownloads, .whatsappMedia, .orphanedAppSupport, .xcodeOldDeviceSupport:
            return "Осторожно: проверьте подпункты перед удалением."
        case .trash:
            return "Файлы из корзины исчезнут безвозвратно."
        case .browserCaches, .messengerCaches, .spotifyCache, .teamsCache, .chromeProfilesDeep:
            return "Сессии могут сброситься; кэш скачается снова."
        case .timeMachineSnapshots:
            return "Локальные снимки TM. Внешний бэкап не трогаем."
        case .appleIntelligence, .mediaAnalysis:
            return "Индексы пересоздадутся; Photos/Siri могут подольше «думать»."
        case .iCloudDaemonCache, .mobileAssetCache, .cloudStorageCaches:
            return "iCloud/система перекачает данные; возможен трафик."
        case .spotlightIndexer:
            return "Spotlight переиндексирует диск — поиск может тормозить сутки."
        case .documentRevisions:
            return "Пропадёт история версий «Revert To» в Finder."
        case .mailCaches:
            return "Mail перекачает превью писем."
        case .crashReportsDeep:
            return "Удалятся старые .crash / .ips — свежие отчёты останутся."
        default:
            return "Можно снять галочки с отдельных папок внутри категории."
        }
    }

    var selectedByDefault: Bool {
        switch self {
        case .xcodeArchives, .iosBackups, .trash, .docker, .mlModels, .mailDownloads,
             .installerImages, .maven, .conda, .projectArtifacts, .iosSoftwareUpdates,
             .browserCaches, .messengerCaches, .spotifyCache, .adobeCache, .savedState,
             .iMessageAttachments, .nvmCache, .steamCache, .dropboxCache,
             .unityCache, .unrealCache, .teamsCache, .sbtCache,
             .documentRevisions, .parallelsVM, .utmVM, .pyenvRvmAsdf, .proVideoApps,
             .screenTimeKnowledge, .groupContainerCaches, .containerAppCaches,
             .spotlightIndexer, .iCloudDaemonCache, .mobileAssetCache,
             .oldLargeDownloads, .chromeProfilesDeep, .officeCaches, .whatsappMedia,
             .cloudStorageCaches, .orphanedAppSupport, .xcodeOldDeviceSupport:
            return false
        default:
            return true
        }
    }

    var strategy: CleanStrategy {
        switch self {
        case .unavailableSimulators:
            return .shell(["/usr/bin/xcrun", "simctl", "delete", "unavailable"])
        case .timeMachineSnapshots:
            return .timeMachineSnapshots
        case .docker:
            return .shell(["/bin/zsh", "-lc", "command -v docker >/dev/null && docker system prune -af --volumes || true"])
        case .brewCleanup:
            return .shell(["/bin/zsh", "-lc", "command -v brew >/dev/null && brew cleanup -as || true"])
        case .goCache:
            return .shell(["/bin/zsh", "-lc", "command -v go >/dev/null && go clean -modcache || true"])
        case .installerImages:
            return .downloadInstallers
        case .oldLargeDownloads:
            return .oldLargeDownloads
        case .chromeProfilesDeep:
            return .chromeProfilesDeep
        case .orphanedAppSupport:
            return .orphanedAppSupport
        case .crashReportsDeep:
            return .crashReportsDeep
        case .xcodeOldDeviceSupport:
            return .xcodeOldDeviceSupport
        case .projectArtifacts:
            return .projectArtifacts
        case .groupContainerCaches:
            return .groupContainerCaches
        case .documentRevisions:
            return .documentRevisions
        case .containerAppCaches:
            return .containerAppCaches
        default:
            return .files
        }
    }

    var section: CleanSection {
        switch self {
        case .userCaches, .userLogs, .temporary, .trash, .quickLook, .fontCaches, .savedState,
             .mediaAnalysis, .appleIntelligence, .iosSoftwareUpdates, .webkitCache, .iconServices,
             .coreSuggestions, .iCloudDaemonCache, .spotlightIndexer, .mapsCache,
             .screenTimeKnowledge, .mailCaches, .booksCache, .mobileAssetCache, .speechVoicePacks,
             .appleMediaApps, .timeMachineSnapshots:
            return .system
        case .xcodeDerivedData, .xcodeArchives, .iosDeviceSupport, .simulatorCaches,
             .unavailableSimulators, .swiftPMCache, .xcodeCaches, .carthage, .iosBackups,
             .homebrew, .brewCleanup, .npm, .bun, .deno, .cocoapods, .gradle, .maven, .pip,
             .poetry, .conda, .goCache, .cargo, .flutter, .composer, .nuget, .docker,
             .playwright, .cypress, .puppeteer, .jetbrainsCaches, .vscodeCaches, .androidStudio,
             .aiDevTools, .mlModels, .bazelCache, .sbtCache, .nvmCache, .javaJVM, .pyenvRvmAsdf,
             .gcloudKubeColima, .projectArtifacts, .uvRyeCache, .gitLfsCache, .xcodeOldDeviceSupport:
            return .developer
        case .browserCaches, .messengerCaches, .spotifyCache, .adobeCache, .zoomCache,
             .steamCache, .unityCache, .unrealCache, .blenderCache, .figmaCache, .teamsCache,
             .notionCache, .dropboxCache, .iMessageAttachments, .electronApps, .parallelsVM,
             .proVideoApps, .launcherCaches, .obsidianNotes, .onePasswordLogs, .utmVM,
             .installerImages, .mailDownloads, .oldLargeDownloads, .chromeProfilesDeep,
             .officeCaches, .whatsappMedia, .cloudStorageCaches:
            return .apps
        case .groupContainerCaches, .documentRevisions, .containerAppCaches,
             .orphanedAppSupport, .crashReportsDeep:
            return .hidden
        }
    }

    var risk: RiskLevel {
        if !selectedByDefault {
            switch self {
            case .trash, .iosBackups, .xcodeArchives, .documentRevisions, .mlModels,
                 .iMessageAttachments, .projectArtifacts, .docker, .oldLargeDownloads,
                 .whatsappMedia, .orphanedAppSupport, .xcodeOldDeviceSupport:
                return .danger
            default:
                return .caution
            }
        }
        return .safe
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return title.lowercased().contains(q)
            || subtitle.lowercased().contains(q)
            || rawValue.lowercased().contains(q)
            || section.title.lowercased().contains(q)
    }
}

enum CleanSection: String, CaseIterable, Identifiable {
    case system, developer, apps, hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Система"
        case .developer: return "Разработка"
        case .apps: return "Приложения"
        case .hidden: return "Скрытое"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "gearshape.2"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .apps: return "app.badge"
        case .hidden: return "eye.slash"
        }
    }
}

enum RiskLevel: String {
    case safe, caution, danger

    var label: String {
        switch self {
        case .safe: return "безопасно"
        case .caution: return "осторожно"
        case .danger: return "риск"
        }
    }
}

enum ListFilter: String, CaseIterable, Identifiable {
    case withSize, selected, all, risky

    var id: String { rawValue }

    var title: String {
        switch self {
        case .withSize: return "С размером"
        case .selected: return "Выбранные"
        case .all: return "Все"
        case .risky: return "Рискованные"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case size, name, risk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: return "Размер"
        case .name: return "Имя"
        case .risk: return "Риск"
        }
    }

    var symbol: String {
        switch self {
        case .size: return "arrow.down.circle"
        case .name: return "textformat"
        case .risk: return "exclamationmark.shield"
        }
    }
}

enum CleanStrategy: Equatable {
    case files
    case shell([String])
    case timeMachineSnapshots
    case downloadInstallers
    case oldLargeDownloads
    case chromeProfilesDeep
    case orphanedAppSupport
    case crashReportsDeep
    case xcodeOldDeviceSupport
    case projectArtifacts
    case groupContainerCaches
    case documentRevisions
    case containerAppCaches
}

struct CleanItem: Identifiable, Hashable {
    let id: UUID
    let path: String
    let byteCount: Int64
    var isSelected: Bool

    init(path: String, byteCount: Int64, isSelected: Bool) {
        self.id = UUID()
        self.path = path
        self.byteCount = byteCount
        self.isSelected = isSelected
    }

    var name: String {
        let ns = path as NSString
        let last = ns.lastPathComponent
        let parent = (ns.deletingLastPathComponent as NSString).lastPathComponent
        if parent.isEmpty || parent == "/" || parent == "Caches" || parent == "Library" {
            return last
        }
        // Для одинаковых имён (Cache/GPUCache) показываем родителя
        if ["Cache", "Caches", "GPUCache", "Code Cache", "Service Worker", "tmp", "logs"].contains(last) {
            return "\(parent)/\(last)"
        }
        return last
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

struct CategoryScan: Identifiable {
    var id: CleanCategoryID { category }
    let category: CleanCategoryID
    var byteCount: Int64
    var paths: [String]
    /// Подпункты с отдельными галочками (папки/файлы внутри категории).
    var items: [CleanItem]
    var isSelected: Bool
    var exists: Bool
    var detailNote: String?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    var selectedBytes: Int64 {
        if items.isEmpty { return isSelected ? byteCount : 0 }
        return items.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    var hasSelection: Bool {
        if items.isEmpty { return isSelected && (byteCount > 0 || exists) }
        return items.contains(where: \.isSelected)
    }

    var selectedItemCount: Int {
        if items.isEmpty { return isSelected ? 1 : 0 }
        return items.filter(\.isSelected).count
    }

    mutating func setAllItems(selected: Bool) {
        for i in items.indices { items[i].isSelected = selected }
        isSelected = selected
    }

    mutating func syncParentFromItems() {
        guard !items.isEmpty else { return }
        isSelected = items.contains(where: \.isSelected)
    }
}

enum CleanerError: LocalizedError {
    case nothingSelected
    case partiallyFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingSelected: return "Нечего чистить — выберите категории или подпапки."
        case .partiallyFailed(let msg): return msg
        }
    }
}
