import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Toggle("Show widget", isOn: visibilityBinding)
        Toggle("Edit / move", isOn: $appState.isEditMode)
            .onChange(of: appState.isEditMode) { _, editing in
                if editing {
                    settings.clickThrough = false
                }
                NotificationCenter.default.post(name: .overwatchAppearanceChanged, object: nil)
            }

        Divider()

        Picker("Display", selection: $settings.displayMode) {
            ForEach(DisplayMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .onChange(of: settings.displayMode) { _, _ in
            NotificationCenter.default.post(name: .overwatchAppearanceChanged, object: nil)
        }

        Toggle("Click-through", isOn: $settings.clickThrough)
            .onChange(of: settings.clickThrough) { _, _ in
                NotificationCenter.default.post(name: .overwatchAppearanceChanged, object: nil)
            }

        Menu("Snap to corner") {
            ForEach(CornerAnchor.allCases) { corner in
                Button(corner.title) {
                    NotificationCenter.default.post(name: .overwatchSnapToCorner, object: corner)
                }
            }
        }

        Divider()

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Overwatch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var visibilityBinding: Binding<Bool> {
        Binding(
            get: { appState.isVisible },
            set: { newValue in
                appState.isVisible = newValue
                NotificationCenter.default.post(name: .overwatchVisibilityChanged, object: newValue)
            }
        )
    }
}
