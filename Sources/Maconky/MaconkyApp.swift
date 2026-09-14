import AppKit
import SwiftUI
import Combine

@main
struct MaconkyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Maconky", systemImage: "gauge.with.dots.needle.67percent") {
            MenuBarView(settings: AppState.shared.settings, appState: AppState.shared)
        }

        Settings {
            SettingsView(settings: AppState.shared.settings, appState: AppState.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = AppState.shared
        state.monitor.start(interval: state.settings.refreshInterval)

        let controller = PanelController(settings: state.settings, monitor: state.monitor)
        panelController = controller
        controller.show()

        state.settings.$refreshInterval
            .receive(on: RunLoop.main)
            .sink { interval in
                AppState.shared.monitor.setInterval(interval)
            }
            .store(in: &cancellables)

        state.settings.$displayMode
            .combineLatest(state.settings.$clickThrough)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.panelController?.applyAppearance()
            }
            .store(in: &cancellables)

        state.settings.$panelWidth
            .combineLatest(state.settings.$panelHeight)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.panelController?.applySize()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .maconkyAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.panelController?.applyAppearance()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .maconkySnapToCorner,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let corner = note.object as? CornerAnchor
            Task { @MainActor in
                if let corner {
                    self?.panelController?.snap(to: corner)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
