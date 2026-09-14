import SwiftUI

struct DashboardView: View {
    let snapshot: SystemSnapshot
    @ObservedObject var settings: AppSettings
    var editMode: Bool

    private var accent: Color { settings.accent.color }
    private var baseFont: CGFloat { settings.fontSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if settings.showClock { clockSection }
            if settings.showSystem { systemSection }
            if settings.showCPU { cpuSection }
            if settings.showMemory { memorySection }
            if settings.showGPU { gpuSection }
            if settings.showDisk { diskSection }
            if settings.showNetwork { networkSection }
            if settings.showBattery { batterySection }
            if settings.showProcesses { processSection }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: settings.panelWidth, height: settings.panelHeight, alignment: .topLeading)
        .background(panelBackground)
        .overlay(editBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var panelBackground: some View {
        if settings.useBlur {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(settings.backgroundOpacity * 0.65))
                )
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(settings.backgroundOpacity))
        }
    }

    @ViewBuilder
    private var editBorder: some View {
        if editMode {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.7), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("MACONKY")
                .font(ZenTheme.font(baseFont + 1, weight: .bold))
                .foregroundStyle(accent)
                .tracking(2.4)
            Spacer()
            Text(snapshot.host.computerName)
                .font(ZenTheme.font(baseFont - 1))
                .foregroundStyle(ZenTheme.dim)
                .lineLimit(1)
        }
    }

    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.clock, format: .dateTime.hour().minute().second())
                .font(ZenTheme.font(baseFont + 8, weight: .medium))
                .foregroundStyle(ZenTheme.text)
                .monospacedDigit()
                .frame(height: baseFont + 12, alignment: .leading)
            Text(snapshot.clock, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                .font(ZenTheme.font(baseFont))
                .foregroundStyle(ZenTheme.dim)
                .monospacedDigit()
                .lineLimit(1)
                .frame(height: baseFont + 4, alignment: .leading)
        }
    }

    private var systemSection: some View {
        ConkySection(title: "SYSTEM", accent: accent, fontSize: baseFont) {
            InfoRow(label: "Host", value: snapshot.host.hostname, fontSize: baseFont)
            InfoRow(label: "Model", value: snapshot.host.model, fontSize: baseFont)
            InfoRow(label: "CPU", value: snapshot.host.cpuBrand, fontSize: baseFont)
            InfoRow(label: "OS", value: snapshot.host.osVersion, fontSize: baseFont)
            InfoRow(label: "Kernel", value: snapshot.host.kernel, fontSize: baseFont)
            InfoRow(label: "Uptime", value: Format.duration(snapshot.host.uptime), fontSize: baseFont)
            InfoRow(
                label: "Load",
                value: String(
                    format: "%.2f  %.2f  %.2f",
                    snapshot.host.loadAverage.0,
                    snapshot.host.loadAverage.1,
                    snapshot.host.loadAverage.2
                ),
                fontSize: baseFont
            )
            InfoRow(label: "Thermal", value: thermalLabel, valueColor: thermalColor, fontSize: baseFont)
        }
    }

    private var thermalLabel: String {
        switch snapshot.host.thermalState {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    private var thermalColor: Color {
        switch snapshot.host.thermalState {
        case .nominal: accent
        case .fair: ZenTheme.warn
        case .serious, .critical: ZenTheme.crit
        @unknown default: ZenTheme.dim
        }
    }

    private var cpuSpeedLabel: String {
        let current = snapshot.cpu.frequencyHz
        let max = snapshot.cpu.frequencyMaxHz
        if current <= 0 && max <= 0 { return "—" }
        if max > 0, abs(max - current) > 20_000_000 {
            return "\(Format.ghz(current)) / \(Format.ghz(max))"
        }
        return Format.ghz(current > 0 ? current : max)
    }

    private var cpuSection: some View {
        ConkySection(title: "CPU", accent: accent, fontSize: baseFont) {
            MeterRow(
                label: String(format: "Total  usr %.0f  sys %.0f", snapshot.cpu.user, snapshot.cpu.system),
                percent: snapshot.cpu.total,
                accent: accent,
                fontSize: baseFont
            )
            InfoRow(label: "Speed", value: cpuSpeedLabel, fontSize: baseFont)
            Sparkline(values: snapshot.cpuHistory, tint: accent)
                .frame(height: 22)
            CoreGrid(cores: paddedCores, accent: accent)
            HStack {
                Text("P-cores \(snapshot.cpu.performanceCount)")
                Spacer()
                Text("E-cores \(snapshot.cpu.efficiencyCount)")
            }
            .font(ZenTheme.font(baseFont - 1))
            .foregroundStyle(ZenTheme.dim)
            .frame(height: baseFont + 2)
        }
    }

    private var memorySection: some View {
        ConkySection(title: "MEMORY", accent: accent, fontSize: baseFont) {
            MeterRow(
                label: "\(Format.bytes(snapshot.memory.used)) / \(Format.bytes(snapshot.memory.total))",
                percent: snapshot.memory.usedPercent,
                accent: accent,
                fontSize: baseFont
            )
            InfoRow(label: "Wired", value: Format.bytes(snapshot.memory.wired), fontSize: baseFont)
            InfoRow(label: "Active", value: Format.bytes(snapshot.memory.active), fontSize: baseFont)
            InfoRow(label: "Compressed", value: Format.bytes(snapshot.memory.compressed), fontSize: baseFont)
            InfoRow(label: "Cached", value: Format.bytes(snapshot.memory.cached), fontSize: baseFont)
            InfoRow(
                label: "Swap",
                value: snapshot.memory.swapTotal == 0
                    ? "0"
                    : "\(Format.bytes(snapshot.memory.swapUsed)) / \(Format.bytes(snapshot.memory.swapTotal))",
                fontSize: baseFont
            )
        }
    }

    private var gpuSection: some View {
        ConkySection(title: "GPU", accent: accent, fontSize: baseFont) {
            MeterRow(label: "Device", percent: snapshot.gpu.utilization, accent: accent, fontSize: baseFont)
            InfoRow(label: "Renderer", value: Format.percent(snapshot.gpu.renderer), fontSize: baseFont)
            InfoRow(label: "Tiler", value: Format.percent(snapshot.gpu.tiler), fontSize: baseFont)
            InfoRow(
                label: "Memory",
                value: snapshot.gpu.memoryUsed > 0 ? Format.bytes(snapshot.gpu.memoryUsed) : "—",
                fontSize: baseFont
            )
        }
    }

    private var diskSection: some View {
        ConkySection(title: "DISK", accent: accent, fontSize: baseFont) {
            ForEach(paddedDisks) { disk in
                VStack(alignment: .leading, spacing: 3) {
                    MeterRow(
                        label: disk.name == "—"
                            ? "—"
                            : "\(disk.name)  \(Format.bytes(disk.used)) / \(Format.bytes(disk.total))",
                        percent: disk.usedPercent,
                        accent: accent,
                        fontSize: baseFont
                    )
                    Text(disk.path)
                        .font(ZenTheme.font(baseFont - 1))
                        .foregroundStyle(ZenTheme.mute)
                        .lineLimit(1)
                        .frame(height: baseFont)
                }
            }
        }
    }

    private var networkSection: some View {
        ConkySection(title: "NETWORK", accent: accent, fontSize: baseFont) {
            InfoRow(label: "Iface", value: snapshot.network.interface, fontSize: baseFont)
            InfoRow(label: "IPv4", value: snapshot.network.ipAddress, fontSize: baseFont)
            HStack {
                Text("↓ \(Format.rate(snapshot.network.downRate))")
                    .foregroundStyle(accent)
                Spacer()
                Text("↑ \(Format.rate(snapshot.network.upRate))")
                    .foregroundStyle(ZenTheme.text)
            }
            .font(ZenTheme.font(baseFont))
            DualSparkline(down: snapshot.netDownHistory, up: snapshot.netUpHistory, downTint: accent)
                .frame(height: 22)
            InfoRow(label: "RX", value: Format.bytes(snapshot.network.bytesIn), fontSize: baseFont)
            InfoRow(label: "TX", value: Format.bytes(snapshot.network.bytesOut), fontSize: baseFont)
        }
    }

    private var batterySection: some View {
        ConkySection(title: "BATTERY", accent: accent, fontSize: baseFont) {
            MeterRow(
                label: batteryLabel,
                percent: snapshot.battery.percent,
                accent: accent,
                fontSize: baseFont
            )
            InfoRow(label: "Source", value: snapshot.battery.present ? snapshot.battery.powerSource : "—", fontSize: baseFont)
            InfoRow(
                label: "Cycles",
                value: snapshot.battery.cycleCount.map(String.init) ?? "—",
                fontSize: baseFont
            )
            InfoRow(
                label: "Health",
                value: snapshot.battery.healthPercent.map { Format.percent($0) } ?? "—",
                fontSize: baseFont
            )
        }
    }

    private var batteryLabel: String {
        var parts = [Format.percent(snapshot.battery.percent)]
        if snapshot.battery.isCharging {
            parts.append("charging")
        }
        if let remaining = snapshot.battery.timeRemaining {
            parts.append(Format.duration(remaining))
        }
        return parts.joined(separator: "  ")
    }

    private var processSection: some View {
        ConkySection(title: "PROCESSES", accent: accent, fontSize: baseFont) {
            HStack {
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU").frame(width: 58, alignment: .trailing)
                Text("MEM").frame(width: 72, alignment: .trailing)
            }
            .font(ZenTheme.font(baseFont - 1, weight: .medium))
            .foregroundStyle(ZenTheme.dim)

            ForEach(paddedProcesses) { proc in
                HStack(spacing: 6) {
                    Text(proc.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(proc.name == "—" ? "    —" : String(format: "%5.1f%%", proc.cpu))
                        .foregroundStyle(ZenTheme.color(forPercent: proc.cpu, accent: accent))
                        .frame(width: 58, alignment: .trailing)
                    Text(proc.name == "—" ? "—" : Format.bytes(proc.memory, decimals: 0))
                        .frame(width: 72, alignment: .trailing)
                }
                .font(ZenTheme.font(baseFont))
                .foregroundStyle(ZenTheme.text)
                .monospacedDigit()
                .frame(height: baseFont + 4)
            }
        }
    }

    private var paddedCores: [CPUCoreSample] {
        let existing = snapshot.cpu.cores
        let count = max(existing.count, snapshot.host.logicalCores, 1)
        if existing.count >= count { return existing }
        return existing + (existing.count..<count).map { index in
            CPUCoreSample(id: index, usage: 0, isPerformance: true)
        }
    }

    private var paddedDisks: [DiskInfo] {
        var disks = Array(snapshot.disks.prefix(2))
        while disks.count < 2 {
            disks.append(DiskInfo(name: "—", path: " ", total: 1, used: 0, free: 1))
        }
        return disks
    }

    private var paddedProcesses: [ProcessInfoRow] {
        var rows = Array(snapshot.processes.prefix(6))
        var placeholder = Int32(-1)
        while rows.count < 6 {
            rows.append(ProcessInfoRow(pid: placeholder, name: "—", cpu: 0, memory: 0))
            placeholder -= 1
        }
        return rows
    }
}

struct ConkySection<Content: View>: View {
    let title: String
    let accent: Color
    let fontSize: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(ZenTheme.font(fontSize - 1, weight: .semibold))
                    .foregroundStyle(accent)
                    .tracking(1.2)
                Rectangle()
                    .fill(accent.opacity(0.35))
                    .frame(height: 1)
            }
            content
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = ZenTheme.text
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(ZenTheme.dim)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(ZenTheme.font(fontSize))
        .frame(height: fontSize + 4)
    }
}

struct MeterRow: View {
    let label: String
    let percent: Double
    let accent: Color
    var fontSize: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .foregroundStyle(ZenTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text(Format.percent(percent))
                    .foregroundStyle(ZenTheme.color(forPercent: percent, accent: accent))
            }
            .font(ZenTheme.font(fontSize))
            MeterBar(percent: percent, accent: accent)
        }
        .frame(minHeight: fontSize + 14)
    }
}

struct MeterBar: View {
    let percent: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ZenTheme.barTrack)
                Capsule()
                    .fill(ZenTheme.color(forPercent: percent, accent: accent))
                    .frame(width: max(2, geo.size.width * CGFloat(min(max(percent, 0), 100) / 100)))
            }
        }
        .frame(height: 6)
    }
}

struct CoreGrid: View {
    let cores: [CPUCoreSample]
    let accent: Color

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: max(1, min(cores.count, 8)))
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(cores) { core in
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(ZenTheme.barTrack)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(core.isPerformance ? accent : accent.opacity(0.55))
                                .frame(height: max(1, geo.size.height * CGFloat(core.usage / 100)))
                        }
                    }
                    .frame(height: 14)
                }
            }
        }
        .frame(height: CGFloat((max(cores.count, 1) + 7) / 8) * 17)
    }
}

struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let maxVal = max(values.max() ?? 1, 1)
            var path = Path()
            for (i, value) in values.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
                let y = size.height - size.height * CGFloat(value / maxVal)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .color(tint.opacity(0.18)))
            context.stroke(path, with: .color(tint), lineWidth: 1.2)
        }
        .background(ZenTheme.barTrack.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

struct DualSparkline: View {
    let down: [Double]
    let up: [Double]
    let downTint: Color

    var body: some View {
        Canvas { context, size in
            let maxVal = max(down.max() ?? 0, up.max() ?? 0, 1)
            if let downPath = linePath(down, size: size, maxVal: maxVal) {
                context.stroke(downPath, with: .color(downTint), lineWidth: 1.1)
            }
            if let upPath = linePath(up, size: size, maxVal: maxVal) {
                context.stroke(upPath, with: .color(ZenTheme.text.opacity(0.7)), lineWidth: 1.1)
            }
        }
        .background(ZenTheme.barTrack.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func linePath(_ values: [Double], size: CGSize, maxVal: Double) -> Path? {
        guard values.count > 1 else { return nil }
        var path = Path()
        for (i, value) in values.enumerated() {
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height - size.height * CGFloat(value / maxVal)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
