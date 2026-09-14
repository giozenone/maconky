import SwiftUI

enum ZenTheme {
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.48)
    static let mute = Color.white.opacity(0.28)
    static let warn = Color(red: 1.00, green: 0.72, blue: 0.28)
    static let crit = Color(red: 1.00, green: 0.38, blue: 0.38)
    static let barTrack = Color.white.opacity(0.12)

    static func font(_ size: Double, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func color(forPercent value: Double, accent: Color) -> Color {
        if value >= 90 { return crit }
        if value >= 75 { return warn }
        return accent
    }
}

enum Format {
    static func bytes(_ value: UInt64, decimals: Int = 1) -> String {
        let units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var size = Double(value)
        var idx = 0
        while size >= 1024 && idx < units.count - 1 {
            size /= 1024
            idx += 1
        }
        if idx == 0 {
            return "\(value) B"
        }
        return String(format: "%.\(decimals)f \(units[idx])", size)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1 {
            return "0 B/s"
        }
        return "\(bytes(UInt64(bytesPerSecond.rounded()), decimals: bytesPerSecond < 1024 * 1024 ? 0 : 1))/s"
    }

    static func percent(_ value: Double, digits: Int = 0) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m \(total % 60)s"
    }

    static func ghz(_ hz: Double) -> String {
        if hz <= 0 { return "—" }
        return String(format: "%.2f GHz", hz / 1_000_000_000)
    }
}
