import Darwin
import Foundation

struct SystemResourceReading: Equatable {
    let memoryUsedBytes: UInt64?
    let physicalMemoryBytes: UInt64?
    let diskUsedBytes: UInt64?
    let diskTotalBytes: UInt64?

    var memoryUsedGigabytes: Double? {
        memoryUsedBytes.map { Double($0) / 1_073_741_824.0 }
    }

    var diskUsedPercentage: Int? {
        guard let diskUsedBytes,
              let diskTotalBytes,
              diskTotalBytes > 0
        else { return nil }

        return Int(
            min(
                100,
                max(0, (Double(diskUsedBytes) / Double(diskTotalBytes) * 100).rounded())
            )
        )
    }
}

enum SystemResourceTelemetryEstimator {
    static func memoryUsedBytes(
        activePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64
    ) -> UInt64? {
        let (activeAndWired, firstOverflow) = activePages.addingReportingOverflow(wiredPages)
        let (usedPages, secondOverflow) = activeAndWired.addingReportingOverflow(compressedPages)
        let (usedBytes, multiplicationOverflow) = usedPages.multipliedReportingOverflow(
            by: pageSize
        )
        guard !firstOverflow, !secondOverflow, !multiplicationOverflow else { return nil }
        return usedBytes
    }

    static func diskUsedBytes(totalBytes: UInt64, availableBytes: UInt64) -> UInt64? {
        guard totalBytes > 0 else { return nil }
        return totalBytes - min(totalBytes, availableBytes)
    }
}

enum SystemResourceTelemetryReader {
    static func currentReading() -> SystemResourceReading {
        let memory = currentMemoryUsage()
        let disk = currentDiskUsage()
        return SystemResourceReading(
            memoryUsedBytes: memory?.used,
            physicalMemoryBytes: memory?.total,
            diskUsedBytes: disk?.used,
            diskTotalBytes: disk?.total
        )
    }

    private static func currentMemoryUsage() -> (used: UInt64, total: UInt64)? {
        let host = mach_host_self()
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                host_statistics64(
                    host,
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        guard let used = SystemResourceTelemetryEstimator.memoryUsedBytes(
            activePages: UInt64(statistics.active_count),
            wiredPages: UInt64(statistics.wire_count),
            compressedPages: UInt64(statistics.compressor_page_count),
            pageSize: UInt64(pageSize)
        ) else { return nil }

        return (used, ProcessInfo.processInfo.physicalMemory)
    }

    private static func currentDiskUsage() -> (used: UInt64, total: UInt64)? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? FileManager.default.homeDirectoryForCurrentUser
            .resourceValues(forKeys: keys),
              let totalCapacity = values.volumeTotalCapacity,
              let availableCapacity = values.volumeAvailableCapacity,
              totalCapacity > 0,
              availableCapacity >= 0
        else { return nil }

        let total = UInt64(totalCapacity)
        let available = UInt64(availableCapacity)
        guard let used = SystemResourceTelemetryEstimator.diskUsedBytes(
            totalBytes: total,
            availableBytes: available
        ) else { return nil }
        return (used, total)
    }
}

final class SystemResourceMonitor {
    var onUpdate: ((SystemResourceReading) -> Void)?
    private var timer: Timer?

    func start() {
        stop()
        publish()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.publish()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func publish() {
        onUpdate?(SystemResourceTelemetryReader.currentReading())
    }
}
