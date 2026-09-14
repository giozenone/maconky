import Foundation
import Combine

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()

    private let sampler = SystemSampler()
    private var timer: Timer?
    private var interval: TimeInterval = 1

    func start(interval: TimeInterval) {
        self.interval = max(0.5, interval)
        snapshot = sampler.sample()
        restartTimer()
    }

    func setInterval(_ interval: TimeInterval) {
        let clamped = max(0.5, interval)
        guard abs(clamped - self.interval) > 0.01 else { return }
        self.interval = clamped
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func restartTimer() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        snapshot = sampler.sample()
    }
}
