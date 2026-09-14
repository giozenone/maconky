import Foundation

struct SystemSnapshot {
    var clock = Date()
    var host = HostInfo()
    var cpu = CPUInfo()
    var memory = MemoryInfo()
    var gpu = GPUInfo()
    var disks: [DiskInfo] = []
    var network = NetworkInfo()
    var battery = BatteryInfo()
    var processes: [ProcessInfoRow] = []
    var cpuHistory: [Double] = []
    var netDownHistory: [Double] = []
    var netUpHistory: [Double] = []
}

struct HostInfo {
    var computerName = "Mac"
    var hostname = "localhost"
    var model = ""
    var cpuBrand = ""
    var osVersion = ""
    var kernel = ""
    var uptime: TimeInterval = 0
    var loadAverage: (Double, Double, Double) = (0, 0, 0)
    var thermalState = ProcessInfo.ThermalState.nominal
    var physicalCores = 0
    var logicalCores = 0
}

struct CPUCoreSample: Identifiable {
    var id: Int
    var usage: Double
    var isPerformance: Bool
}

struct CPUInfo {
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 0
    var cores: [CPUCoreSample] = []
    var performanceCount = 0
    var efficiencyCount = 0
    var frequencyHz: Double = 0
    var frequencyMinHz: Double = 0
    var frequencyMaxHz: Double = 0
}

struct MemoryInfo {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var wired: UInt64 = 0
    var active: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0

    var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct GPUInfo {
    var utilization: Double = 0
    var renderer: Double = 0
    var tiler: Double = 0
    var memoryUsed: UInt64 = 0
    var available = false
}

struct DiskInfo: Identifiable {
    var id: String { path }
    var name: String
    var path: String
    var total: UInt64
    var used: UInt64
    var free: UInt64

    var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct NetworkInfo {
    var interface = "—"
    var ipAddress = "—"
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var downRate: Double = 0
    var upRate: Double = 0
}

struct BatteryInfo {
    var present = false
    var percent: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var timeRemaining: TimeInterval?
    var cycleCount: Int?
    var healthPercent: Double?
    var powerSource = "Unknown"
}

struct ProcessInfoRow: Identifiable {
    var id: Int32 { pid }
    var pid: Int32
    var name: String
    var cpu: Double
    var memory: UInt64
}
