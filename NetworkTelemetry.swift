import Darwin
import Foundation

struct NetworkInterfaceByteCounters: Equatable {
    let receivedBytes: UInt64
    let transmittedBytes: UInt64
}

struct NetworkTelemetryReading: Equatable {
    enum State: Equatable {
        case initializing
        case ready
        case unavailable
    }

    let downloadBytesPerSecond: Double?
    let uploadBytesPerSecond: Double?
    let interfaceCount: Int
    let state: State

    var isReady: Bool {
        state == .ready
    }

    // These are deliberately separate from L10n so this module can be smoke-tested alone.
    var compactTextChinese: String {
        compactText(downLabel: "下", upLabel: "上", unavailable: "网络 --", starting: "网络初始化")
    }

    var compactTextEnglish: String {
        compactText(downLabel: "D", upLabel: "U", unavailable: "Net --", starting: "Net starting")
    }

    var menuBarText: String {
        switch state {
        case .initializing:
            return "…"
        case .unavailable:
            return "--"
        case .ready:
            return "↓\(Self.formatMenuBarRate(downloadBytesPerSecond ?? 0)) "
                + "↑\(Self.formatMenuBarRate(uploadBytesPerSecond ?? 0))"
        }
    }

    var detailTextChinese: String {
        detailText(downLabel: "下载", upLabel: "上传", unavailable: "网络不可用", starting: "网络初始化中")
    }

    var detailTextEnglish: String {
        detailText(downLabel: "Download", upLabel: "Upload", unavailable: "Network unavailable", starting: "Network starting")
    }

    private func compactText(
        downLabel: String,
        upLabel: String,
        unavailable: String,
        starting: String
    ) -> String {
        switch state {
        case .initializing:
            return starting
        case .unavailable:
            return unavailable
        case .ready:
            return "\(downLabel) \(Self.formatRate(downloadBytesPerSecond ?? 0)) · "
                + "\(upLabel) \(Self.formatRate(uploadBytesPerSecond ?? 0))"
        }
    }

    private func detailText(
        downLabel: String,
        upLabel: String,
        unavailable: String,
        starting: String
    ) -> String {
        switch state {
        case .initializing:
            return starting
        case .unavailable:
            return unavailable
        case .ready:
            return "\(downLabel) \(Self.formatRate(downloadBytesPerSecond ?? 0)) · "
                + "\(upLabel) \(Self.formatRate(uploadBytesPerSecond ?? 0))"
        }
    }

    private static func formatRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "--" }

        let units = ["B/s", "kB/s", "MB/s", "GB/s", "TB/s"]
        var value = bytesPerSecond
        var unitIndex = 0
        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }

        let format = value >= 100 || unitIndex == 0 ? "%.0f %@" : "%.1f %@"
        return String(
            format: format,
            locale: Locale(identifier: "en_US_POSIX"),
            value,
            units[unitIndex]
        )
    }

    private static func formatMenuBarRate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "--" }

        let units = ["B", "k", "M", "G", "T"]
        var value = bytesPerSecond
        var unitIndex = 0
        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }

        let isWholeValue = abs(value.rounded() - value) < 0.0001
        let format = value >= 100 || unitIndex == 0 || isWholeValue
            ? "%.0f%@"
            : "%.1f%@"
        return String(
            format: format,
            locale: Locale(identifier: "en_US_POSIX"),
            value,
            units[unitIndex]
        )
    }
}

enum NetworkTelemetryReader {
    static func currentCounters() -> [String: NetworkInterfaceByteCounters] {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else { return [:] }
        defer { freeifaddrs(firstAddress) }

        var counters: [String: NetworkInterfaceByteCounters] = [:]
        var address: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = address {
            let interface = current.pointee
            address = interface.ifa_next

            guard let namePointer = interface.ifa_name else { continue }
            let name = String(cString: namePointer)
            guard Self.isPreferredPhysicalInterface(name),
                  Self.isActive(interface.ifa_flags),
                  counters[name] == nil,
                  let dataPointer = interface.ifa_data
            else {
                continue
            }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = NetworkInterfaceByteCounters(
                receivedBytes: UInt64(data.ifi_ibytes),
                transmittedBytes: UInt64(data.ifi_obytes)
            )
        }
        return counters
    }

    private static func isActive(_ flags: UInt32) -> Bool {
        let signedFlags = Int32(bitPattern: flags)
        return (signedFlags & IFF_UP) != 0 && (signedFlags & IFF_RUNNING) != 0
    }

    private static func isPreferredPhysicalInterface(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        let excludedPrefixes = [
            "lo", "utun", "tun", "tap", "ppp", "gif", "stf", "bridge", "awdl",
            "llw", "p2p", "vlan", "bond", "ipsec", "wg", "docker", "vmnet", "vmenet",
            "anpi", "ap"
        ]
        guard !excludedPrefixes.contains(where: { lowercased.hasPrefix($0) }) else {
            return false
        }
        return lowercased.hasPrefix("en")
            || lowercased.hasPrefix("eth")
            || lowercased.hasPrefix("wl")
    }
}

struct NetworkTelemetrySampler {
    typealias CounterProvider = () -> [String: NetworkInterfaceByteCounters]

    private static let maximumPlausibleBytesPerSecond = 100_000_000_000.0
    private static let wrapWindow: UInt64 = 1 << 20

    private let counterProvider: CounterProvider
    private var previousCounters: [String: NetworkInterfaceByteCounters] = [:]
    private var previousDate: Date?

    init(counterProvider: @escaping CounterProvider = NetworkTelemetryReader.currentCounters) {
        self.counterProvider = counterProvider
    }

    mutating func sample(at date: Date = Date()) -> NetworkTelemetryReading {
        sample(counters: counterProvider(), at: date)
    }

    mutating func sample(
        counters: [String: NetworkInterfaceByteCounters],
        at date: Date
    ) -> NetworkTelemetryReading {
        guard !counters.isEmpty else {
            resetBaseline()
            return NetworkTelemetryReading(
                downloadBytesPerSecond: nil,
                uploadBytesPerSecond: nil,
                interfaceCount: 0,
                state: .unavailable
            )
        }

        guard let previousDate else {
            previousCounters = counters
            self.previousDate = date
            return initializingReading(interfaceCount: counters.count)
        }

        let elapsed = date.timeIntervalSince(previousDate)
        guard elapsed > 0, elapsed.isFinite else {
            self.previousCounters = counters
            self.previousDate = date
            return initializingReading(interfaceCount: counters.count)
        }

        guard Set(counters.keys) == Set(previousCounters.keys) else {
            previousCounters = counters
            self.previousDate = date
            return initializingReading(interfaceCount: counters.count)
        }

        var receivedDelta: UInt64 = 0
        var transmittedDelta: UInt64 = 0
        for name in counters.keys {
            guard let previous = previousCounters[name],
                  let current = counters[name],
                  let interfaceReceivedDelta = Self.safeDelta(
                      current: current.receivedBytes,
                      previous: previous.receivedBytes
                  ),
                  let interfaceTransmittedDelta = Self.safeDelta(
                      current: current.transmittedBytes,
                      previous: previous.transmittedBytes
                  )
            else {
                previousCounters = counters
                self.previousDate = date
                return initializingReading(interfaceCount: counters.count)
            }

            let receivedSum = receivedDelta.addingReportingOverflow(interfaceReceivedDelta)
            let transmittedSum = transmittedDelta.addingReportingOverflow(interfaceTransmittedDelta)
            guard !receivedSum.overflow, !transmittedSum.overflow else {
                previousCounters = counters
                self.previousDate = date
                return initializingReading(interfaceCount: counters.count)
            }
            receivedDelta = receivedSum.partialValue
            transmittedDelta = transmittedSum.partialValue
        }

        guard Self.isPlausible(delta: receivedDelta, elapsed: elapsed),
              Self.isPlausible(delta: transmittedDelta, elapsed: elapsed)
        else {
            previousCounters = counters
            self.previousDate = date
            return initializingReading(interfaceCount: counters.count)
        }

        previousCounters = counters
        self.previousDate = date
        return NetworkTelemetryReading(
            downloadBytesPerSecond: Double(receivedDelta) / elapsed,
            uploadBytesPerSecond: Double(transmittedDelta) / elapsed,
            interfaceCount: counters.count,
            state: .ready
        )
    }

    // A lower counter is accepted only when it is close to a known counter boundary.
    static func counterDelta(
        current: UInt64,
        previous: UInt64,
        counterMaximum: UInt64 = UInt64.max
    ) -> UInt64? {
        guard current <= counterMaximum, previous <= counterMaximum else { return nil }
        if current >= previous {
            return current - previous
        }

        let window = min(wrapWindow, max(counterMaximum / 4, 1))
        guard previous >= counterMaximum - window, current <= window else { return nil }
        return counterMaximum - previous + 1 + current
    }

    private static func safeDelta(current: UInt64, previous: UInt64) -> UInt64? {
        counterDelta(current: current, previous: previous)
            ?? counterDelta(
                current: current,
                previous: previous,
                counterMaximum: UInt64(UInt32.max)
            )
    }

    private static func isPlausible(delta: UInt64, elapsed: TimeInterval) -> Bool {
        let maximum = maximumPlausibleBytesPerSecond * elapsed
        guard maximum.isFinite, maximum >= 0 else { return false }
        return Double(delta) <= maximum
    }

    private mutating func resetBaseline() {
        previousCounters = [:]
        previousDate = nil
    }

    private func initializingReading(interfaceCount: Int) -> NetworkTelemetryReading {
        NetworkTelemetryReading(
            downloadBytesPerSecond: nil,
            uploadBytesPerSecond: nil,
            interfaceCount: interfaceCount,
            state: .initializing
        )
    }
}

final class NetworkTelemetryMonitor {
    var onUpdate: ((NetworkTelemetryReading) -> Void)?

    private let interval: TimeInterval
    private let queue = DispatchQueue(
        label: "io.github.achengbatian.lidrunswitch.network-telemetry",
        qos: .utility
    )
    private var sampler = NetworkTelemetrySampler()
    private var timer: Timer?
    private var sampleInProgress = false
    private var generation = 0

    init(interval: TimeInterval = 1) {
        self.interval = max(interval, 0.25)
    }

    func start() {
        stop()
        sampler = NetworkTelemetrySampler()
        generation += 1
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        generation += 1
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard !sampleInProgress else { return }
        sampleInProgress = true
        let activeGeneration = generation

        queue.async { [weak self] in
            guard let self else { return }
            let reading = self.sampler.sample()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sampleInProgress = false
                guard self.generation == activeGeneration else { return }
                self.onUpdate?(reading)
            }
        }
    }
}
