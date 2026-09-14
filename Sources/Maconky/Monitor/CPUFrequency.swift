import Foundation
import IOKit

struct CPUFrequencySample {
    var currentHz: Double = 0
    var minHz: Double = 0
    var maxHz: Double = 0
}

final class CPUFrequencyReader {
    private var cachedPStateMHz: [Int]?

    func sample(coreUsage: [Double], packageUsage: Double) -> CPUFrequencySample {
        var sample = CPUFrequencySample()
        let nominal = Double(sysctlUInt64("hw.cpufrequency") ?? 0)
        let sysMin = Double(sysctlUInt64("hw.cpufrequency_min") ?? 0)
        let sysMax = Double(sysctlUInt64("hw.cpufrequency_max") ?? 0)
        let pStates = intelPStateMHz()

        let xcpmMin = mhzRatio("machdep.xcpm.hard_plimit_min_100mhz_ratio")
        let xcpmMax = mhzRatio("machdep.xcpm.hard_plimit_max_100mhz_ratio")
        let xcpmCap = mhzRatio("machdep.xcpm.soft_plimit_max_100mhz_ratio")

        let pMin = pStates.min().map { Double($0) * 1_000_000 }
        let pMax = pStates.max().map { Double($0) * 1_000_000 }

        sample.minHz = xcpmMin ?? pMin ?? (sysMin > 0 ? sysMin : 0)
        sample.maxHz = max(xcpmMax ?? 0, pMax ?? 0, sysMax, nominal)
        let cap = xcpmCap ?? sample.maxHz
        if cap > sample.maxHz { sample.maxHz = cap }

        if sample.minHz <= 0, sample.maxHz > 0 {
            sample.minHz = min(sysMin > 0 ? sysMin : sample.maxHz, sample.maxHz)
        }

        let peakBusy = (coreUsage.max() ?? packageUsage) / 100
        let busy = min(max(peakBusy, 0), 1)
        if cap > 0, sample.minHz > 0, cap >= sample.minHz {
            sample.currentHz = sample.minHz + (cap - sample.minHz) * busy
        } else {
            sample.currentHz = cap > 0 ? cap : nominal
        }
        return sample
    }

    private func mhzRatio(_ name: String) -> Double? {
        guard let ratio = sysctlInt32(name), ratio > 0 else { return nil }
        return Double(ratio) * 100_000_000
    }

    private func intelPStateMHz() -> [Int] {
        if let cachedPStateMHz { return cachedPStateMHz }
        var mhz: [Int] = []
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("X86PlatformPlugin"),
            &iterator
        ) == KERN_SUCCESS else {
            cachedPStateMHz = []
            return []
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
                  let states = props["CPUPStates"] as? [[String: Any]]
            else { continue }
            mhz = states.compactMap { value in
                if let n = value["Frequency"] as? Int { return n }
                if let n = value["Frequency"] as? NSNumber { return n.intValue }
                return nil
            }
            if !mhz.isEmpty { break }
        }
        cachedPStateMHz = mhz
        return mhz
    }

    private func sysctlInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    private func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
