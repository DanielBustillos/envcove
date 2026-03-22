import Foundation
import LocalAuthentication
import AppKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    @Published var lastErrorMessage: String?

    /// The authenticated LAContext reused by KeychainStore to avoid a second Touch ID prompt.
    private(set) var context: LAContext?

    // MARK: - Auto-lock

    /// Inactivity timeout in seconds before the app locks itself (default: 5 minutes).
    var inactivityTimeout: TimeInterval = 300

    private var lockTimer: Timer?
    private var activityMonitor: Any?

    init() {
        subscribeToScreenLock()
        subscribeToScreenSleep()
    }

    // MARK: - Authentication

    func authenticate(reason: String) async -> Bool {
        if isAuthenticating { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastErrorMessage = error?.localizedDescription ?? "Authentication unavailable."
            return false
        }

        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok {
                context = ctx
                isUnlocked = true
                lastErrorMessage = nil
                startInactivityTimer()
                startActivityMonitor()
            }
            return ok
        } catch {
            lastErrorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    // MARK: - Lock

    func lock() {
        isUnlocked = false
        context = nil
        stopInactivityTimer()
        stopActivityMonitor()
    }

    // MARK: - Inactivity timer

    private func startInactivityTimer() {
        stopInactivityTimer()
        lockTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    func resetInactivityTimer() {
        guard isUnlocked else { return }
        startInactivityTimer()
    }

    private func stopInactivityTimer() {
        lockTimer?.invalidate()
        lockTimer = nil
    }

    // MARK: - Activity monitor (keyboard + mouse events reset the inactivity timer)

    private func startActivityMonitor() {
        stopActivityMonitor()
        activityMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] event in
            self?.resetInactivityTimer()
            return event
        }
    }

    private func stopActivityMonitor() {
        if let monitor = activityMonitor {
            NSEvent.removeMonitor(monitor)
            activityMonitor = nil
        }
    }

    // MARK: - Screen lock / sleep detection

    private func subscribeToScreenLock() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    private func subscribeToScreenSleep() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }
}
