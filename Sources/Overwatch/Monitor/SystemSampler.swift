import Foundation
import IOKit
import IOKit.ps
@preconcurrency import Darwin

final class SystemSampler {
    private var previousCPU: [CPUTicks] = []
    private var previousNet: [String: LinkCounters] = [:]
    private var previousNetTime = Date()
    private var previousProcTimes: [Int32: UInt64] = [:]
    private var previousProcStamp = Date()

    private var cpuHistory: [Double] = []
    private var netDownHistory: [Double] = []
    private var netUpHistory: [Double] = []
    private let frequencyReader = CPUFrequencyReader()

    func sample() -> SystemSnapshot {
        var snap = SystemSnapshot()
        snap.clock = Date()
        snap.host = sampleHost()
        snap.cpu = sampleCPU()
        snap.memory = sampleMemory()
        snap.gpu = sampleGPU()
        snap.disks = sampleDisks()
        snap.network = sampleNetwork()
        snap.battery = sampleBattery()
        snap.processes = sampleProcesses()

        append(&cpuHistory, snap.cpu.total)
        append(&netDownHistory, snap.network.downRate)
        append(&netUpHistory, snap.network.upRate)
        snap.cpuHistory = cpuHistory
        snap.netDownHistory = netDownHistory
        snap.netUpHistory = netUpHistory
        return snap
    }

    private func append(_ history: inout [Double], _ value: Double) {
        history.append(value)
        if history.count > 60 {
            history.removeFirst(history.count - 60)
        }
    }

    // MARK: - Host

    private func sampleHost() -> HostInfo {
        var info = HostInfo()
        info.computerName = sysctlString("kern.hostname") ?? ProcessInfo.processInfo.hostName
        info.hostname = sysctlString("kern.hostname") ?? ProcessInfo.processInfo.hostName
        info.model = sysctlString("hw.model") ?? ""
        info.cpuBrand = sysctlString("machdep.cpu.brand_string") ?? friendlyChipName()
        info.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "macOS ")
        let ostype = sysctlString("kern.ostype") ?? "Darwin"
        let osrelease = sysctlString("kern.osrelease") ?? ""
        info.kernel = "\(ostype) \(osrelease)"
        info.uptime = ProcessInfo.processInfo.systemUptime
        info.thermalState = ProcessInfo.processInfo.thermalState
        info.physicalCores = Int(sysctlInt32("hw.physicalcpu") ?? Int32(ProcessInfo.processInfo.processorCount))
        info.logicalCores = Int(sysctlInt32("hw.logicalcpu") ?? Int32(ProcessInfo.processInfo.processorCount))

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 {
            info.loadAverage = (loads[0], loads[1], loads[2])
        }
        return info
    }

    private func friendlyChipName() -> String {
        let count = sysctlInt32("hw.nperflevels") ?? 0
        if count > 0 {
            return "Apple Silicon"
        }
        return "CPU"
    }

    // MARK: - CPU

    private struct CPUTicks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private func sampleCPU() -> CPUInfo {
        var info = CPUInfo()
        let pCores = Int(sysctlInt32("hw.perflevel0.physicalcpu") ?? 0)
        let eCores = Int(sysctlInt32("hw.perflevel1.physicalcpu") ?? 0)
        info.performanceCount = pCores
        info.efficiencyCount = eCores

        var processorCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &infoArray,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let infoArray else { return info }
        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoArray), size)
        }

        let coreCount = Int(processorCount)
        var ticks = [CPUTicks](repeating: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), count: coreCount)
        for i in 0..<coreCount {
            let base = i * Int(CPU_STATE_MAX)
            ticks[i] = CPUTicks(
                user: UInt32(infoArray[base + Int(CPU_STATE_USER)]),
                system: UInt32(infoArray[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(infoArray[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(infoArray[base + Int(CPU_STATE_NICE)])
            )
        }

        var cores: [CPUCoreSample] = []
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        if previousCPU.count == coreCount {
            for i in 0..<coreCount {
                let dUser = delta(ticks[i].user, previousCPU[i].user)
                let dSystem = delta(ticks[i].system, previousCPU[i].system)
                let dIdle = delta(ticks[i].idle, previousCPU[i].idle)
                let dNice = delta(ticks[i].nice, previousCPU[i].nice)
                let sum = dUser + dSystem + dIdle + dNice
                let usage = sum > 0 ? Double(dUser + dSystem + dNice) / Double(sum) * 100 : 0
                let isP = pCores > 0 ? i < pCores : true
                cores.append(CPUCoreSample(id: i, usage: usage, isPerformance: isP))
                totalUser += Double(dUser)
                totalSystem += Double(dSystem)
                totalIdle += Double(dIdle + dNice)
            }
            let all = totalUser + totalSystem + totalIdle
            if all > 0 {
                info.user = totalUser / all * 100
                info.system = totalSystem / all * 100
                info.idle = totalIdle / all * 100
                info.total = info.user + info.system
            }
        } else {
            cores = (0..<coreCount).map { i in
                CPUCoreSample(id: i, usage: 0, isPerformance: pCores > 0 ? i < pCores : true)
            }
        }

        previousCPU = ticks
        info.cores = cores
        let freq = frequencyReader.sample(coreUsage: cores.map(\.usage), packageUsage: info.total)
        info.frequencyHz = freq.currentHz
        info.frequencyMinHz = freq.minHz
        info.frequencyMaxHz = freq.maxHz
        return info
    }

    private func delta(_ now: UInt32, _ then: UInt32) -> UInt32 {
        now >= then ? now - then : now
    }

    // MARK: - Memory

    private func sampleMemory() -> MemoryInfo {
        var info = MemoryInfo()
        info.total = sysctlUInt64("hw.memsize") ?? 0

        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &vm) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return info }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize == 0 ? vm_size_t(getpagesize()) : pageSize)
        info.wired = UInt64(vm.wire_count) * page
        info.active = UInt64(vm.active_count) * page
        info.compressed = UInt64(vm.compressor_page_count) * page
        info.cached = UInt64(vm.external_page_count) * page
        info.free = UInt64(vm.free_count + vm.speculative_count) * page
        let internalMem = UInt64(vm.internal_page_count) * page
        let purgeable = UInt64(vm.purgeable_count) * page
        let app = internalMem > purgeable ? internalMem - purgeable : internalMem
        // Match Activity Monitor "Memory Used": App + Wired + Compressed.
        // File cache is reclaimable and is not treated as used.
        info.used = app + info.wired + info.compressed

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            info.swapUsed = UInt64(swap.xsu_used)
            info.swapTotal = UInt64(swap.xsu_total)
        }
        return info
    }

    // MARK: - GPU

    private func sampleGPU() -> GPUInfo {
        var info = GPUInfo()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return info
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = propsRef?.takeRetainedValue() as? [String: Any],
                  let perf = props["PerformanceStatistics"] as? [String: Any]
            else { continue }

            let util = number(perf, "Device Utilization %")
                ?? number(perf, "GPU Device Utilization %")
                ?? number(perf, "Renderer Utilization %")
            if let util {
                info.utilization = max(info.utilization, util)
                info.available = true
            }
            if let renderer = number(perf, "Renderer Utilization %") {
                info.renderer = max(info.renderer, renderer)
                info.available = true
            }
            if let tiler = number(perf, "Tiler Utilization %") {
                info.tiler = max(info.tiler, tiler)
                info.available = true
            }
            if let mem = number(perf, "In use system memory") ?? number(perf, "Alloc system memory") {
                info.memoryUsed = UInt64(mem)
            }
        }
        return info
    }

    private func number(_ dict: [String: Any], _ key: String) -> Double? {
        if let n = dict[key] as? NSNumber { return n.doubleValue }
        if let i = dict[key] as? Int { return Double(i) }
        if let d = dict[key] as? Double { return d }
        return nil
    }

    // MARK: - Disks

    private func sampleDisks() -> [DiskInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsBrowsableKey,
            .volumeUUIDStringKey,
            .volumeIsRootFileSystemKey
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var seen = Set<String>()
        var disks: [DiskInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.volumeIsBrowsable == false && url.path != "/" { continue }
            let uuid = values.volumeUUIDString ?? url.path
            if seen.contains(uuid) { continue }
            seen.insert(uuid)
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let important = values.volumeAvailableCapacityForImportantUsage ?? 0
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            // Network shares often report important-usage capacity as 0.
            let free = UInt64(important > 0 ? important : max(available, 0))
            guard total > 0 else { continue }
            let used = total > free ? total - free : 0
            let name = values.volumeName?.isEmpty == false ? values.volumeName! : url.path
            disks.append(DiskInfo(name: name, path: url.path, total: total, used: used, free: free))
        }
        return disks.sorted { lhs, rhs in
            if lhs.path == "/" { return true }
            if rhs.path == "/" { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Network

    private struct LinkCounters {
        var bytesIn: UInt64
        var bytesOut: UInt64
    }

    private func sampleNetwork() -> NetworkInfo {
        var info = NetworkInfo()
        let now = Date()
        let dt = max(now.timeIntervalSince(previousNetTime), 0.001)
        let (counters, ipMap) = interfaceSnapshot()

        let preferred = preferredInterface(from: counters, addresses: ipMap)
        info.interface = preferred ?? "—"
        if let preferred {
            info.ipAddress = ipMap[preferred] ?? "—"
            if let current = counters[preferred] {
                info.bytesIn = current.bytesIn
                info.bytesOut = current.bytesOut
                if let old = previousNet[preferred] {
                    let down = Double(wrappingDelta(current.bytesIn, old.bytesIn)) / dt
                    let up = Double(wrappingDelta(current.bytesOut, old.bytesOut)) / dt
                    info.downRate = max(0, down)
                    info.upRate = max(0, up)
                }
            }
        }

        previousNet = counters
        previousNetTime = now
        return info
    }

    private func wrappingDelta(_ now: UInt64, _ then: UInt64) -> UInt64 {
        now >= then ? now - then : now
    }

    private func trafficVolume(_ counters: LinkCounters?) -> UInt64 {
        (counters?.bytesIn ?? 0) + (counters?.bytesOut ?? 0)
    }

    private func preferredInterface(from counters: [String: LinkCounters], addresses: [String: String]) -> String? {
        let skipPrefixes = ["lo", "awdl", "llw", "utun", "gif", "stf", "anpi", "bridge", "ap", "p2p"]
        let usable = counters.keys.filter { name in
            !skipPrefixes.contains { name.hasPrefix($0) }
        }
        if let en = usable.filter({ $0.hasPrefix("en") && addresses[$0] != nil }).sorted().first {
            return en
        }
        if let named = usable.first(where: { addresses[$0] != nil }) {
            return named
        }
        return usable.max { a, b in
            trafficVolume(counters[a]) < trafficVolume(counters[b])
        }
    }

    private func interfaceSnapshot() -> ([String: LinkCounters], [String: String]) {
        var counters: [String: LinkCounters] = [:]
        var addresses: [String: String] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (counters, addresses) }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let name = String(cString: current.pointee.ifa_name)
            if let data = current.pointee.ifa_data, (flags & IFF_UP) == IFF_UP {
                let ifdata = data.assumingMemoryBound(to: if_data.self).pointee
                let incoming = UInt64(ifdata.ifi_ibytes)
                let outgoing = UInt64(ifdata.ifi_obytes)
                if incoming > 0 || outgoing > 0 || counters[name] == nil {
                    counters[name] = LinkCounters(bytesIn: incoming, bytesOut: outgoing)
                }
            }
            if (flags & IFF_UP) == IFF_UP,
               (flags & IFF_LOOPBACK) == 0,
               let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    addresses[name] = cString(hostname)
                }
            }
            ptr = current.pointee.ifa_next
        }
        return (counters, addresses)
    }

    // MARK: - Battery

    private func sampleBattery() -> BatteryInfo {
        var info = BatteryInfo()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            info.powerSource = "AC Power"
            return info
        }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = desc[kIOPSTypeKey] as? String
            if type != kIOPSInternalBatteryType { continue }
            info.present = true
            if let cap = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                info.percent = Double(cap) / Double(max) * 100
            }
            info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let state = desc[kIOPSPowerSourceStateKey] as? String
            info.isPluggedIn = state == kIOPSACPowerValue
            info.powerSource = info.isPluggedIn ? "AC Power" : "Battery"
            if let minutes = desc[kIOPSTimeToEmptyKey] as? Int, minutes > 0, !info.isCharging {
                info.timeRemaining = TimeInterval(minutes * 60)
            } else if let minutes = desc[kIOPSTimeToFullChargeKey] as? Int, minutes > 0, info.isCharging {
                info.timeRemaining = TimeInterval(minutes * 60)
            }
            info.cycleCount = desc["CycleCount"] as? Int
            if let maxCap = desc[kIOPSMaxCapacityKey] as? Double, maxCap > 0,
               let design = desc["DesignCapacity"] as? Double, design > 0 {
                info.healthPercent = maxCap / design * 100
            }
            break
        }

        if !info.present {
            info.powerSource = "AC Power"
        }
        return info
    }

    // MARK: - Processes

    private func sampleProcesses() -> [ProcessInfoRow] {
        let now = Date()
        let dt = max(now.timeIntervalSince(previousProcStamp), 0.001)
        let pids = listPIDs()
        var currentTimes: [Int32: UInt64] = [:]
        var rows: [ProcessInfoRow] = []

        for pid in pids {
            guard pid > 0 else { continue }
            var pti = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.stride
            let got = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &pti, Int32(size))
            guard got == Int32(size) else { continue }
            let totalNs = pti.pti_total_user + pti.pti_total_system
            currentTimes[pid] = totalNs
            var cpu = 0.0
            if let prev = previousProcTimes[pid] {
                let deltaNs = totalNs >= prev ? totalNs - prev : 0
                cpu = (Double(deltaNs) / 1_000_000_000.0) / dt * 100.0
            }
            var nameBuf = [CChar](repeating: 0, count: 64)
            _ = proc_name(pid, &nameBuf, 64)
            let name = cString(nameBuf)
            if name.isEmpty { continue }
            rows.append(ProcessInfoRow(pid: pid, name: name, cpu: cpu, memory: pti.pti_resident_size))
        }

        previousProcTimes = currentTimes
        previousProcStamp = now
        return rows.sorted { $0.cpu > $1.cpu }.prefix(6).map { $0 }
    }

    private func listPIDs() -> [Int32] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(bytes) / MemoryLayout<Int32>.size)
        let filled = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard filled > 0 else { return [] }
        let count = Int(filled) / MemoryLayout<Int32>.size
        return Array(pids.prefix(count))
    }

    // MARK: - sysctl helpers

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return cString(buffer)
    }

    private func sysctlInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    private func cString(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

private let PROC_ALL_PIDS: Int32 = 1
private let PROC_PIDTASKINFO: Int32 = 4

@_silgen_name("proc_listpids")
private func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_pidinfo")
private func proc_pidinfo(_ pid: Int32, _ flavor: Int32, _ arg: UInt64, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_name")
private func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: UInt32) -> Int32

private struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}
