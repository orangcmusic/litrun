import Foundation

@main
enum NetworkTelemetrySmoke {
    static func main() {
        var sampler = NetworkTelemetrySampler()
        let first = sampler.sample(
            counters: ["en0": counters(received: 1_000, transmitted: 2_000)],
            at: Date(timeIntervalSince1970: 100)
        )
        precondition(first.state == .initializing)
        precondition(!first.isReady)
        precondition(first.compactTextChinese == "网络初始化")
        precondition(first.compactTextEnglish == "Net starting")

        let second = sampler.sample(
            counters: ["en0": counters(received: 3_000, transmitted: 3_000)],
            at: Date(timeIntervalSince1970: 102)
        )
        precondition(second.state == .ready)
        precondition(second.downloadBytesPerSecond == 1_000)
        precondition(second.uploadBytesPerSecond == 500)
        precondition(second.compactTextChinese == "下 1.0 kB/s · 上 500 B/s")
        precondition(second.compactTextEnglish == "D 1.0 kB/s · U 500 B/s")
        precondition(second.menuBarText == "↓1k ↑500B")
        precondition(second.detailTextChinese == "下载 1.0 kB/s · 上传 500 B/s")
        precondition(second.detailTextEnglish == "Download 1.0 kB/s · Upload 500 B/s")

        let backwards = sampler.sample(
            counters: ["en0": counters(received: 4_000, transmitted: 4_000)],
            at: Date(timeIntervalSince1970: 101)
        )
        precondition(backwards.state == .initializing)
        let afterBackwards = sampler.sample(
            counters: ["en0": counters(received: 5_000, transmitted: 4_200)],
            at: Date(timeIntervalSince1970: 103)
        )
        precondition(afterBackwards.downloadBytesPerSecond == 500)
        precondition(afterBackwards.uploadBytesPerSecond == 100)

        let noInterfaces = sampler.sample(counters: [:], at: Date(timeIntervalSince1970: 104))
        precondition(noInterfaces.state == .unavailable)
        precondition(noInterfaces.interfaceCount == 0)
        precondition(noInterfaces.compactTextChinese == "网络 --")
        precondition(noInterfaces.detailTextEnglish == "Network unavailable")

        precondition(NetworkTelemetrySampler.counterDelta(
            current: 8,
            previous: UInt64.max - 5
        ) == 14)
        precondition(NetworkTelemetrySampler.counterDelta(
            current: 10,
            previous: UInt64.max - 1_000_000_001
        ) == nil)
        precondition(NetworkTelemetrySampler.counterDelta(
            current: 3,
            previous: UInt64(UInt32.max - 5),
            counterMaximum: UInt64(UInt32.max)
        ) == 9)

        var wrappedSampler = NetworkTelemetrySampler()
        _ = wrappedSampler.sample(
            counters: ["en0": counters(
                received: UInt64(UInt32.max - 5),
                transmitted: UInt64(UInt32.max - 5)
            )],
            at: Date(timeIntervalSince1970: 150)
        )
        let wrapped = wrappedSampler.sample(
            counters: ["en0": counters(received: 3, transmitted: 3)],
            at: Date(timeIntervalSince1970: 151)
        )
        precondition(wrapped.state == .ready)
        precondition(wrapped.downloadBytesPerSecond == 9)
        precondition(wrapped.uploadBytesPerSecond == 9)

        var multiInterfaceSampler = NetworkTelemetrySampler()
        _ = multiInterfaceSampler.sample(
            counters: [
                "en0": counters(received: 100, transmitted: 200),
                "en1": counters(received: 300, transmitted: 400)
            ],
            at: Date(timeIntervalSince1970: 160)
        )
        let multiInterface = multiInterfaceSampler.sample(
            counters: [
                "en0": counters(received: 300, transmitted: 500),
                "en1": counters(received: 700, transmitted: 800)
            ],
            at: Date(timeIntervalSince1970: 162)
        )
        precondition(multiInterface.downloadBytesPerSecond == 300)
        precondition(multiInterface.uploadBytesPerSecond == 350)
        let interfaceChanged = multiInterfaceSampler.sample(
            counters: ["en0": counters(received: 400, transmitted: 600)],
            at: Date(timeIntervalSince1970: 163)
        )
        precondition(interfaceChanged.state == .initializing)

        var anomalous = NetworkTelemetrySampler()
        _ = anomalous.sample(
            counters: ["en0": counters(received: 10_000, transmitted: 10_000)],
            at: Date(timeIntervalSince1970: 200)
        )
        let reset = anomalous.sample(
            counters: ["en0": counters(received: 100, transmitted: 100)],
            at: Date(timeIntervalSince1970: 201)
        )
        precondition(reset.state == .initializing)

        let live = NetworkTelemetryReader.currentCounters()
        precondition(live.values.allSatisfy { $0.receivedBytes >= 0 && $0.transmittedBytes >= 0 })
        precondition(live.keys.allSatisfy { name in
            let lowercased = name.lowercased()
            return lowercased.hasPrefix("en")
                || lowercased.hasPrefix("eth")
                || lowercased.hasPrefix("wl")
        })

        print(
            "OK network-telemetry=counter-delta-and-interface-filter "
                + "live-interfaces=\(live.count)"
        )
    }

    private static func counters(
        received: UInt64,
        transmitted: UInt64
    ) -> NetworkInterfaceByteCounters {
        NetworkInterfaceByteCounters(
            receivedBytes: received,
            transmittedBytes: transmitted
        )
    }
}
