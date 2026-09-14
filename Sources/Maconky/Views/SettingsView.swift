import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            behaviorTab
                .tabItem { Label("Behavior", systemImage: "desktopcomputer") }
            modulesTab
                .tabItem { Label("Modules", systemImage: "square.grid.2x2") }
        }
        .frame(width: 460, height: 420)
        .onChange(of: settings.showClock) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showSystem) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showCPU) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showMemory) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showGPU) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showDisk) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showNetwork) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showBattery) { _, _ in settings.persistModuleFlags() }
        .onChange(of: settings.showProcesses) { _, _ in settings.persistModuleFlags() }
    }

    private var appearanceTab: some View {
        Form {
            Picker("Accent", selection: $settings.accent) {
                ForEach(AccentPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            Slider(value: $settings.backgroundOpacity, in: 0...0.85, step: 0.01) {
                Text("Background opacity")
            } minimumValueLabel: {
                Text("Clear")
            } maximumValueLabel: {
                Text("Solid")
            }
            Toggle("Frosted glass blur", isOn: $settings.useBlur)
            Slider(value: $settings.panelWidth, in: 260...460, step: 10) {
                Text("Width")
            }
            Slider(value: $settings.fontSize, in: 9...14, step: 0.5) {
                Text("Font size")
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private var behaviorTab: some View {
        Form {
            Picker("Show as", selection: $settings.displayMode) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Text(settings.displayMode.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Click-through (desktop widget)", isOn: $settings.clickThrough)
            Toggle("Launch at login", isOn: $settings.launchesAtLogin)

            Slider(value: $settings.refreshInterval, in: 0.5...3, step: 0.5) {
                Text("Refresh")
            }
            Text("Updates every \(String(format: "%.1f", settings.refreshInterval))s")
                .font(.caption)
                .foregroundStyle(.secondary)

            .onChange(of: settings.displayMode) { _, _ in
                NotificationCenter.default.post(name: .maconkyAppearanceChanged, object: nil)
            }
            .onChange(of: settings.clickThrough) { _, _ in
                NotificationCenter.default.post(name: .maconkyAppearanceChanged, object: nil)
            }

            HStack {
                ForEach(CornerAnchor.allCases) { corner in
                    Button(corner.title) {
                        NotificationCenter.default.post(name: .maconkySnapToCorner, object: corner)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private var modulesTab: some View {
        Form {
            Toggle("Clock", isOn: $settings.showClock)
            Toggle("System", isOn: $settings.showSystem)
            Toggle("CPU", isOn: $settings.showCPU)
            Toggle("Memory", isOn: $settings.showMemory)
            Toggle("GPU", isOn: $settings.showGPU)
            Toggle("Disk", isOn: $settings.showDisk)
            Toggle("Network", isOn: $settings.showNetwork)
            Toggle("Battery", isOn: $settings.showBattery)
            Toggle("Processes", isOn: $settings.showProcesses)
        }
        .formStyle(.grouped)
        .padding(8)
    }
}

extension Notification.Name {
    static let maconkyAppearanceChanged = Notification.Name("maconkyAppearanceChanged")
    static let maconkySnapToCorner = Notification.Name("maconkySnapToCorner")
}
