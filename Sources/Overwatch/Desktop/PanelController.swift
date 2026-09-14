import AppKit
import SwiftUI

final class DesktopWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override var acceptsFirstResponder: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: DesktopWidgetPanel?
    private var hostingView: NSHostingView<DashboardRoot>?
    private let settings: AppSettings
    private let monitor: SystemMonitor
    private var levelKeepAlive: Timer?

    init(settings: AppSettings, monitor: SystemMonitor) {
        self.settings = settings
        self.monitor = monitor
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(visibilityChanged(_:)),
            name: .overwatchVisibilityChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        applyAppearance()
        snap(to: .topLeft)
        panel?.orderFrontRegardless()
        startLevelKeepAlive()
    }

    func hide() {
        panel?.orderOut(nil)
        levelKeepAlive?.invalidate()
        levelKeepAlive = nil
    }

    func applyAppearance() {
        guard let panel else { return }
        panel.ignoresMouseEvents = settings.clickThrough && !AppState.shared.isEditMode
        panel.level = windowLevel(for: settings.displayMode)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hasShadow = false
        applySize()
        if !settings.hasSavedPosition {
            snap(to: .topLeft)
        } else {
            clampToVisible()
        }
    }

    private let edgeMargin: CGFloat = 16

    func snap(to corner: CornerAnchor) {
        guard let panel, let screen = screen(for: corner) else { return }
        applySize(on: screen)
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin: CGPoint
        switch corner {
        case .topRight:
            origin = CGPoint(x: visible.maxX - size.width - edgeMargin, y: visible.minY)
        case .topLeft:
            origin = CGPoint(x: visible.minX + edgeMargin, y: visible.minY)
        case .bottomRight:
            origin = CGPoint(x: visible.maxX - size.width - edgeMargin, y: visible.minY)
        case .bottomLeft:
            origin = CGPoint(x: visible.minX + edgeMargin, y: visible.minY)
        }
        panel.setFrameOrigin(origin)
        settings.savePosition(origin)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        settings.savePosition(panel.frame.origin)
    }

    @objc private func visibilityChanged(_ note: Notification) {
        if let visible = note.object as? Bool, visible {
            show()
        } else if AppState.shared.isVisible {
            show()
        } else {
            hide()
        }
    }

    @objc private func screensChanged() {
        clampToVisible()
        applyAppearance()
    }

    private func createPanel() {
        let screen = screen(for: .topLeft) ?? NSScreen.main ?? NSScreen.screens.first
        let size = fittedSize(on: screen)
        let root = DashboardRoot(settings: settings, monitor: monitor)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]

        let panel = DesktopWidgetPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .none
        panel.delegate = self
        panel.contentView = hosting
        self.panel = panel
        self.hostingView = hosting

        if settings.hasSavedPosition {
            panel.setFrameOrigin(NSPoint(x: settings.windowX, y: settings.windowY))
        }

        applySize()
    }

    func applySize() {
        let screen = panel.flatMap { screenContaining($0.frame.origin) }
            ?? screen(for: .topLeft)
            ?? NSScreen.main
            ?? NSScreen.screens.first
        applySize(on: screen)
    }

    private func applySize(on screen: NSScreen?) {
        guard let panel else { return }
        let size = fittedSize(on: screen)
        if abs(settings.panelHeight - size.height) > 0.5 {
            settings.panelHeight = size.height
        }
        let x = panel.frame.minX
        let visibleMinY = screen?.visibleFrame.minY ?? panel.frame.minY
        if panel.frame.size != size {
            panel.setContentSize(size)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: visibleMinY))
        hostingView?.frame = panel.contentView?.bounds ?? NSRect(origin: .zero, size: size)
    }

    private func fittedSize(on screen: NSScreen?) -> NSSize {
        let height = screen?.visibleFrame.height ?? CGFloat(settings.panelHeight)
        return NSSize(width: settings.panelWidth, height: height)
    }

    private func clampToVisible() {
        guard let panel else { return }
        let screen = screenContaining(panel.frame.origin)
            ?? screen(for: .topLeft)
            ?? NSScreen.main
            ?? NSScreen.screens.first
        applySize(on: screen)
        guard let screen else { return }
        var x = panel.frame.origin.x
        let visible = screen.visibleFrame
        let width = panel.frame.width
        if x + width > visible.maxX { x = visible.maxX - width - edgeMargin }
        if x < visible.minX { x = visible.minX + edgeMargin }
        panel.setFrameOrigin(NSPoint(x: x, y: visible.minY))
        settings.savePosition(panel.frame.origin)
    }

    private func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func screen(for corner: CornerAnchor) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        switch corner {
        case .topLeft, .bottomLeft:
            return screens.min(by: { $0.visibleFrame.minX < $1.visibleFrame.minX })
        case .topRight, .bottomRight:
            return screens.max(by: { $0.visibleFrame.maxX < $1.visibleFrame.maxX })
        }
    }

    private func windowLevel(for mode: DisplayMode) -> NSWindow.Level {
        switch mode {
        case .desktop:
            let desktopIcons = Int(CGWindowLevelForKey(.desktopIconWindow))
            return NSWindow.Level(rawValue: desktopIcons + 1)
        case .overlay:
            return .floating
        case .alwaysOnTop:
            return .statusBar
        }
    }

    private func startLevelKeepAlive() {
        levelKeepAlive?.invalidate()
        levelKeepAlive = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, AppState.shared.isVisible, let panel = self.panel else { return }
                panel.level = self.windowLevel(for: self.settings.displayMode)
                if self.settings.displayMode == .desktop {
                    panel.orderFrontRegardless()
                }
            }
        }
        if let levelKeepAlive {
            RunLoop.main.add(levelKeepAlive, forMode: .common)
        }
    }
}

struct DashboardRoot: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        DashboardView(snapshot: monitor.snapshot, settings: settings, editMode: appState.isEditMode)
            .frame(width: settings.panelWidth, height: settings.panelHeight, alignment: .topLeading)
            .transaction { $0.animation = nil }
    }
}
