import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let settings = AppSettings()
    let monitor = SystemMonitor()

    @Published var isVisible = true
    @Published var isEditMode = false

    private init() {}

    func toggleVisibility() {
        isVisible.toggle()
        NotificationCenter.default.post(name: .overwatchVisibilityChanged, object: isVisible)
    }
}

extension Notification.Name {
    static let overwatchVisibilityChanged = Notification.Name("overwatchVisibilityChanged")
}
