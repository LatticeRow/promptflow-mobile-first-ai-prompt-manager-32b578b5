import CloudKit
import CoreData
import Foundation
import Network
import SwiftUI
import WidgetKit

@MainActor
final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let repository: PromptRepository
    let router = AppRouter()
    let syncMonitor: SyncMonitor
    private var hasHandledInitialActivation = false
    private var lastObservedCaptureToken: TimeInterval

    init() {
        let controller = if ProcessInfo.processInfo.arguments.contains("-promptatelier-ui-testing") {
            PersistenceController(target: .mainApp, inMemory: true)
        } else {
            PersistenceController.sharedApp
        }
        persistenceController = controller
        repository = PromptRepository(container: controller.container)
        syncMonitor = SyncMonitor(
            container: controller.container,
            configuration: controller.syncConfiguration
        )
        lastObservedCaptureToken = AppGroupPaths.latestSharedCaptureToken()
    }

    func handleForegroundActivation() {
        syncMonitor.refresh()

        let latestToken = AppGroupPaths.latestSharedCaptureToken()
        let shouldRefreshFromSharedStore = !hasHandledInitialActivation || latestToken > lastObservedCaptureToken

        if shouldRefreshFromSharedStore {
            persistenceController.container.viewContext.refreshAllObjects()
            lastObservedCaptureToken = latestToken
        }

        let enrichedPromptCount = repository.enrichPendingPrompts(limit: 50)
        if shouldRefreshFromSharedStore || enrichedPromptCount > 0 {
            persistenceController.container.viewContext.refreshAllObjects()
            WidgetCenter.shared.reloadAllTimelines()
        }

        hasHandledInitialActivation = true
    }
}

struct SyncStatusSnapshot {
    enum Tone {
        case positive
        case warning
        case critical
        case neutral
    }

    let symbolName: String
    let title: String
    let message: String
    let tone: Tone
    let lastSyncDate: Date?
    let showsProgress: Bool
}

@MainActor
final class SyncMonitor: ObservableObject {
    @Published private(set) var snapshot = SyncStatusSnapshot(
        symbolName: "icloud",
        title: "Checking sync",
        message: "Prompt Atelier is checking whether your prompts can sync right now.",
        tone: .neutral,
        lastSyncDate: nil,
        showsProgress: true
    )

    private let container: NSPersistentCloudKitContainer
    private let configuration: PersistenceController.SyncConfiguration
    private var accountStatus: CKAccountStatus?
    private var isNetworkAvailable = true
    private var isSyncing = false
    private var isCheckingAccount = false
    private var lastSyncDate: Date?
    private var lastErrorMessage: String?
    private var eventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?
    private let pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.codex.promptatelier.sync.path-monitor")
    private let overrideState: OverrideState?

    init(
        container: NSPersistentCloudKitContainer,
        configuration: PersistenceController.SyncConfiguration
    ) {
        self.container = container
        self.configuration = configuration
        overrideState = OverrideState(arguments: ProcessInfo.processInfo.arguments)

        if let overrideState {
            pathMonitor = nil
            applyOverrideState(overrideState)
            return
        }

        if configuration.cloudKitEnabled {
            let monitor = NWPathMonitor()
            pathMonitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                Task { @MainActor in
                    self?.isNetworkAvailable = path.status == .satisfied
                    self?.publishSnapshot()
                }
            }
            monitor.start(queue: pathMonitorQueue)

            eventObserver = NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.handleCloudKitEvent(notification)
                }
            }

            accountObserver = NotificationCenter.default.addObserver(
                forName: .CKAccountChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        } else {
            pathMonitor = nil
        }

        publishSnapshot()
        refresh()
    }

    func refresh() {
        guard overrideState == nil else {
            return
        }

        guard configuration.cloudKitEnabled else {
            publishSnapshot()
            return
        }

        isCheckingAccount = true
        publishSnapshot()

        CKContainer(identifier: AppGroupPaths.cloudKitContainerIdentifier).accountStatus { [weak self] status, error in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.isCheckingAccount = false
                self.accountStatus = status
                if let error {
                    self.lastErrorMessage = self.userVisibleMessage(for: error)
                }
                self.publishSnapshot()
            }
        }
    }

    private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
            return
        }

        isSyncing = event.endDate == nil

        guard event.endDate != nil else {
            publishSnapshot()
            return
        }

        if event.succeeded {
            if event.type == .import || event.type == .export {
                lastSyncDate = event.endDate
            }
            lastErrorMessage = nil
        } else if let error = event.error {
            AppLogger.persistence.error("Sync event failed: \(error.localizedDescription)")
            lastErrorMessage = userVisibleMessage(for: error)
            if isAuthenticationFailure(error) {
                accountStatus = .noAccount
            }
        }

        publishSnapshot()
    }

    private func publishSnapshot() {
        snapshot = makeSnapshot()
    }

    private func makeSnapshot() -> SyncStatusSnapshot {
        if !configuration.cloudKitRequested {
            return SyncStatusSnapshot(
                symbolName: "internaldrive.fill",
                title: "This iPhone only",
                message: "Your prompts are saved on this iPhone.",
                tone: .neutral,
                lastSyncDate: nil,
                showsProgress: false
            )
        }

        if !configuration.cloudKitEnabled {
            return SyncStatusSnapshot(
                symbolName: "internaldrive.fill",
                title: "This iPhone only",
                message: "Your prompts stay available here even when iCloud is unavailable.",
                tone: .warning,
                lastSyncDate: nil,
                showsProgress: false
            )
        }

        if isCheckingAccount, accountStatus == nil {
            return SyncStatusSnapshot(
                symbolName: "icloud",
                title: "Checking sync",
                message: "Checking whether sync is available.",
                tone: .neutral,
                lastSyncDate: lastSyncDate,
                showsProgress: true
            )
        }

        if let accountStatus {
            switch accountStatus {
            case .noAccount:
                return SyncStatusSnapshot(
                    symbolName: "person.crop.circle.badge.exclamationmark",
                    title: "Sync is off",
                    message: "Your prompts stay on this iPhone until iCloud is turned on.",
                    tone: .warning,
                    lastSyncDate: nil,
                    showsProgress: false
                )
            case .restricted:
                return SyncStatusSnapshot(
                    symbolName: "lock.icloud.fill",
                    title: "Sync is unavailable",
                    message: "This iPhone can keep working locally, but iCloud sync is restricted.",
                    tone: .warning,
                    lastSyncDate: nil,
                    showsProgress: false
                )
            case .temporarilyUnavailable:
                return SyncStatusSnapshot(
                    symbolName: "icloud.slash.fill",
                    title: "Sync will resume soon",
                    message: "Your prompts stay available here and will sync once iCloud is ready again.",
                    tone: .warning,
                    lastSyncDate: lastSyncDate,
                    showsProgress: false
                )
            case .couldNotDetermine:
                break
            case .available:
                break
            @unknown default:
                break
            }
        }

        if !isNetworkAvailable {
            return SyncStatusSnapshot(
                symbolName: "wifi.slash",
                title: "Offline right now",
                message: "Your prompts stay usable here and sync when your connection returns.",
                tone: .warning,
                lastSyncDate: lastSyncDate,
                showsProgress: false
            )
        }

        if isSyncing {
            return SyncStatusSnapshot(
                symbolName: "arrow.triangle.2.circlepath.icloud.fill",
                title: "Syncing to iCloud",
                message: "Recent changes are moving across your devices.",
                tone: .positive,
                lastSyncDate: lastSyncDate,
                showsProgress: true
            )
        }

        if let lastErrorMessage {
            return SyncStatusSnapshot(
                symbolName: "exclamationmark.icloud.fill",
                title: "Sync is delayed",
                message: lastErrorMessage,
                tone: .warning,
                lastSyncDate: lastSyncDate,
                showsProgress: false
            )
        }

        if let lastSyncDate {
            return SyncStatusSnapshot(
                symbolName: "checkmark.icloud.fill",
                title: "Synced to iCloud",
                message: "Your prompts are saved here and synced to your other devices.",
                tone: .positive,
                lastSyncDate: lastSyncDate,
                showsProgress: false
            )
        }

        return SyncStatusSnapshot(
            symbolName: "icloud.fill",
            title: "Ready to sync",
            message: "New prompts will sync automatically when iCloud is available.",
            tone: .neutral,
            lastSyncDate: nil,
            showsProgress: false
        )
    }

    private func userVisibleMessage(for error: Error) -> String {
        if let code = ckErrorCode(from: error) {
            switch code {
            case .networkUnavailable, .networkFailure:
                return "Your prompts stay available here and will sync when your connection returns."
            case .notAuthenticated:
                return "Your prompts stay on this iPhone until iCloud is turned on."
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "Sync is taking longer than usual. Prompt Atelier will keep trying in the background."
            case .quotaExceeded:
                return "Sync needs more iCloud storage before it can continue."
            case .partialFailure:
                return "Some changes are taking longer to sync. Prompt Atelier will keep trying."
            default:
                break
            }
        }

        return "Your prompts stay available here while Prompt Atelier keeps trying to sync."
    }

    private func isAuthenticationFailure(_ error: Error) -> Bool {
        ckErrorCode(from: error) == .notAuthenticated
    }

    private func ckErrorCode(from error: Error) -> CKError.Code? {
        if let ckError = error as? CKError {
            return ckError.code
        }

        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain else {
            return (nsError.userInfo[NSUnderlyingErrorKey] as? Error).flatMap(ckErrorCode(from:))
        }

        return CKError.Code(rawValue: nsError.code)
    }

    private func applyOverrideState(_ overrideState: OverrideState) {
        if overrideState.forceLocalOnly {
            snapshot = SyncStatusSnapshot(
                symbolName: "internaldrive.fill",
                title: "This iPhone only",
                message: "Your prompts stay available here even when iCloud is unavailable.",
                tone: .warning,
                lastSyncDate: nil,
                showsProgress: false
            )
            return
        }

        if overrideState.forceNoAccount {
            snapshot = SyncStatusSnapshot(
                symbolName: "person.crop.circle.badge.exclamationmark",
                title: "Sync is off",
                message: "Your prompts stay on this iPhone until iCloud is turned on.",
                tone: .warning,
                lastSyncDate: nil,
                showsProgress: false
            )
            return
        }

        if overrideState.forceOffline {
            snapshot = SyncStatusSnapshot(
                symbolName: "wifi.slash",
                title: "Offline right now",
                message: "Your prompts stay usable here and sync when your connection returns.",
                tone: .warning,
                lastSyncDate: overrideState.forceSynced ? Date().addingTimeInterval(-120) : nil,
                showsProgress: false
            )
            return
        }

        if overrideState.forceDelayed {
            snapshot = SyncStatusSnapshot(
                symbolName: "exclamationmark.icloud.fill",
                title: "Sync is delayed",
                message: "Sync is taking longer than usual. Prompt Atelier will keep trying in the background.",
                tone: .warning,
                lastSyncDate: overrideState.forceSynced ? Date().addingTimeInterval(-120) : nil,
                showsProgress: false
            )
            return
        }

        if overrideState.forceSyncing {
            snapshot = SyncStatusSnapshot(
                symbolName: "arrow.triangle.2.circlepath.icloud.fill",
                title: "Syncing to iCloud",
                message: "Recent changes are moving across your devices.",
                tone: .positive,
                lastSyncDate: nil,
                showsProgress: true
            )
            return
        }

        if overrideState.forceSynced {
            snapshot = SyncStatusSnapshot(
                symbolName: "checkmark.icloud.fill",
                title: "Synced to iCloud",
                message: "Your prompts are saved here and synced to your other devices.",
                tone: .positive,
                lastSyncDate: Date().addingTimeInterval(-120),
                showsProgress: false
            )
            return
        }

        snapshot = SyncStatusSnapshot(
            symbolName: "icloud.fill",
            title: "Ready to sync",
            message: "New prompts will sync automatically when iCloud is available.",
            tone: .neutral,
            lastSyncDate: nil,
            showsProgress: false
        )
    }
}

private struct OverrideState {
    let forceLocalOnly: Bool
    let forceNoAccount: Bool
    let forceOffline: Bool
    let forceDelayed: Bool
    let forceSyncing: Bool
    let forceSynced: Bool

    private init(
        forceLocalOnly: Bool,
        forceNoAccount: Bool,
        forceOffline: Bool,
        forceDelayed: Bool,
        forceSyncing: Bool,
        forceSynced: Bool
    ) {
        self.forceLocalOnly = forceLocalOnly
        self.forceNoAccount = forceNoAccount
        self.forceOffline = forceOffline
        self.forceDelayed = forceDelayed
        self.forceSyncing = forceSyncing
        self.forceSynced = forceSynced
    }

    init?(arguments: [String]) {
        let state = OverrideState(
            forceLocalOnly: arguments.contains("-promptatelier-sync-local-only"),
            forceNoAccount: arguments.contains("-promptatelier-sync-no-account"),
            forceOffline: arguments.contains("-promptatelier-sync-offline"),
            forceDelayed: arguments.contains("-promptatelier-sync-delayed"),
            forceSyncing: arguments.contains("-promptatelier-sync-syncing"),
            forceSynced: arguments.contains("-promptatelier-sync-synced")
        )

        if !state.forceLocalOnly, !state.forceNoAccount, !state.forceOffline, !state.forceDelayed, !state.forceSyncing, !state.forceSynced {
            return nil
        }

        self = state
    }
}
