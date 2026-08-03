import Foundation

@main
enum SystemResourceTelemetrySmoke {
    static func main() {
        let pageSize: UInt64 = 16_384
        let used = SystemResourceTelemetryEstimator.memoryUsedBytes(
            activePages: 800_000,
            wiredPages: 160_000,
            compressedPages: 100_000,
            pageSize: pageSize
        )
        precondition(used == 17_367_040_000)

        let diskUsed = SystemResourceTelemetryEstimator.diskUsedBytes(
            totalBytes: 500_000_000_000,
            availableBytes: 40_000_000_000
        )
        precondition(diskUsed == 460_000_000_000)

        let reading = SystemResourceReading(
            memoryUsedBytes: used,
            physicalMemoryBytes: 34_359_738_368,
            diskUsedBytes: diskUsed,
            diskTotalBytes: 500_000_000_000
        )
        precondition(abs((reading.memoryUsedGigabytes ?? 0) - 16.1743) < 0.001)
        precondition(reading.diskUsedPercentage == 92)

        let clamped = SystemResourceTelemetryEstimator.diskUsedBytes(
            totalBytes: 100,
            availableBytes: 120
        )
        precondition(clamped == 0)

        let live = SystemResourceTelemetryReader.currentReading()
        precondition((live.memoryUsedBytes ?? 0) > 0)
        precondition((live.physicalMemoryBytes ?? 0) > 0)
        precondition((live.diskTotalBytes ?? 0) > 0)
        precondition((live.diskUsedPercentage ?? -1) >= 0)
        precondition((live.diskUsedPercentage ?? 101) <= 100)

        print("OK system-resource-telemetry=memory-and-disk")
    }
}
