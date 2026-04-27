// NetworkMonitor.swift
//
// Observes connectivity via NWPathMonitor and exposes a single
// `isOnline` flag that views observe to render the offline banner.
//
// The flag is debounced: we only flip to offline after 1.5 s of
// continuous unsatisfied path. Network blips during cell handoffs and
// VPN reconnects fire .unsatisfied for a few hundred ms; without
// debouncing the banner flickers in and out and trains users to
// ignore it.

import Foundation
import Observation
import Network

@Observable
@MainActor
public final class NetworkMonitor {

    /// True when the device has at least one viable network path.
    /// Defaults to true (optimistic) so the banner doesn't flash on
    /// launch before NWPathMonitor produces its first sample.
    public private(set) var isOnline: Bool = true

    /// Underlying monitor. Lives for the whole app lifetime — there's
    /// no point in starting / stopping it across scenes.
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "io.rosterplus.networkmonitor")

    /// Pending offline-flip task. We coalesce so a transient blip
    /// (.unsatisfied → .satisfied within 1.5 s) never reaches the UI.
    private var flipTask: Task<Void, Never>?

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // The handler runs on `queue`; bounce to MainActor.
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.handlePath(satisfied: satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }

    private func handlePath(satisfied: Bool) {
        if satisfied {
            // Cancel any pending offline flip — connection recovered
            // before the debounce window elapsed.
            flipTask?.cancel()
            flipTask = nil
            if !isOnline { isOnline = true }
            return
        }
        // Already offline + a fresh .unsatisfied — nothing to do.
        if !isOnline { return }
        // Schedule the flip; if connectivity recovers within 1.5 s we
        // cancel above and the user never sees the banner.
        flipTask?.cancel()
        flipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.isOnline = false
        }
    }
}
