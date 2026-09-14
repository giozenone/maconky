import Foundation
import ServiceManagement
import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable, Sendable {
    case desktop
    case overlay
    case alwaysOnTop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: "Desktop"
        case .overlay: "Overlay"
        case .alwaysOnTop: "Always on top"
        }
    }

    var detail: String {
        switch self {
        case .desktop: "Sits on the desktop, covered by other windows"
        case .overlay: "Floats above windows"
        case .alwaysOnTop: "Stays above almost everything"
        }
    }
}

enum AccentPreset: String, CaseIterable, Identifiable, Sendable {
    case cyan
    case green
    case amber
    case ice
    case magenta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: "Conky cyan"
        case .green: "Matrix"
        case .amber: "Amber"
        case .ice: "Ice"
        case .magenta: "Magenta"
        }
    }

    var color: Color {
        switch self {
        case .cyan: Color(red: 0.15, green: 0.90, blue: 0.78)
        case .green: Color(red: 0.35, green: 0.95, blue: 0.40)
        case .amber: Color(red: 1.00, green: 0.75, blue: 0.20)
        case .ice: Color(red: 0.55, green: 0.82, blue: 1.00)
        case .magenta: Color(red: 0.95, green: 0.40, blue: 0.85)
        }
    }
}

enum CornerAnchor: String, CaseIterable, Identifiable, Sendable {
    case topRight, topLeft, bottomRight, bottomLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topRight: "Top right"
        case .topLeft: "Top left"
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: "displayMode") }
    }

    @Published var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: "clickThrough") }
    }

    @Published var backgroundOpacity: Double {
        didSet { defaults.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }

    @Published var useBlur: Bool {
        didSet { defaults.set(useBlur, forKey: "useBlur") }
    }

    @Published var panelWidth: Double {
        didSet { defaults.set(panelWidth, forKey: "panelWidth") }
    }

    @Published var panelHeight: Double {
        didSet { defaults.set(panelHeight, forKey: "panelHeight") }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "fontSize") }
    }

    @Published var accent: AccentPreset {
        didSet { defaults.set(accent.rawValue, forKey: "accent") }
    }

    @Published var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: "refreshInterval") }
    }

    @Published var showClock = true
    @Published var showSystem = true
    @Published var showCPU = true
    @Published var showMemory = true
    @Published var showGPU = true
    @Published var showDisk = true
    @Published var showNetwork = true
    @Published var showBattery = true
    @Published var showProcesses = true

    @Published var windowX: Double {
        didSet { defaults.set(windowX, forKey: "windowX") }
    }

    @Published var windowY: Double {
        didSet { defaults.set(windowY, forKey: "windowY") }
    }

    @Published var hasSavedPosition: Bool {
        didSet { defaults.set(hasSavedPosition, forKey: "hasSavedPosition") }
    }

    @Published var launchesAtLogin: Bool {
        didSet { updateLoginItem(launchesAtLogin) }
    }

    init() {
        displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .desktop
        clickThrough = defaults.object(forKey: "clickThrough") as? Bool ?? true
        backgroundOpacity = defaults.object(forKey: "backgroundOpacity") as? Double ?? 0.42
        useBlur = defaults.object(forKey: "useBlur") as? Bool ?? false
        panelWidth = defaults.object(forKey: "panelWidth") as? Double ?? 340
        panelHeight = defaults.object(forKey: "panelHeight") as? Double ?? 1000
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 11
        accent = AccentPreset(rawValue: defaults.string(forKey: "accent") ?? "") ?? .cyan
        let storedInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 3.0
        refreshInterval = storedInterval <= 1.0 ? 3.0 : storedInterval
        if storedInterval <= 1.0 {
            defaults.set(3.0, forKey: "refreshInterval")
        }
        windowX = defaults.double(forKey: "windowX")
        windowY = defaults.double(forKey: "windowY")
        hasSavedPosition = defaults.bool(forKey: "hasSavedPosition")
        launchesAtLogin = SMAppService.mainApp.status == .enabled

        showClock = defaults.object(forKey: "showClock") as? Bool ?? true
        showSystem = defaults.object(forKey: "showSystem") as? Bool ?? true
        showCPU = defaults.object(forKey: "showCPU") as? Bool ?? true
        showMemory = defaults.object(forKey: "showMemory") as? Bool ?? true
        showGPU = defaults.object(forKey: "showGPU") as? Bool ?? true
        showDisk = defaults.object(forKey: "showDisk") as? Bool ?? true
        showNetwork = defaults.object(forKey: "showNetwork") as? Bool ?? true
        showBattery = defaults.object(forKey: "showBattery") as? Bool ?? true
        showProcesses = defaults.object(forKey: "showProcesses") as? Bool ?? true
    }

    func persistModuleFlags() {
        defaults.set(showClock, forKey: "showClock")
        defaults.set(showSystem, forKey: "showSystem")
        defaults.set(showCPU, forKey: "showCPU")
        defaults.set(showMemory, forKey: "showMemory")
        defaults.set(showGPU, forKey: "showGPU")
        defaults.set(showDisk, forKey: "showDisk")
        defaults.set(showNetwork, forKey: "showNetwork")
        defaults.set(showBattery, forKey: "showBattery")
        defaults.set(showProcesses, forKey: "showProcesses")
    }

    func savePosition(_ origin: CGPoint) {
        windowX = origin.x
        windowY = origin.y
        hasSavedPosition = true
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
