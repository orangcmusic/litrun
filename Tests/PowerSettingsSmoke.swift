import Foundation

@main
enum PowerSettingsSmoke {
    static func main() throws {
        let output = """
        Battery Power:
         sleep              1
         disksleep         10
         powernap           1
         tcpkeepalive       1
         womp               0
        AC Power:
         sleep              0
         disksleep         10
         powernap           1
         tcpkeepalive       1
         womp               1
        """
        let globalEnabled = """
        System-wide power settings:
         SleepDisabled        1
        Currently in use:
         sleep                0
        """
        let globalDisabled = globalEnabled.replacingOccurrences(
            of: "SleepDisabled        1",
            with: "SleepDisabled        0"
        )

        let snapshot = try PowerSnapshot.parse(
            pmsetOutput: output,
            globalOutput: globalEnabled
        )
        precondition(snapshot.sleepDisabled == "1")
        precondition(snapshot.batterySleep == "1")
        precondition(snapshot.acSleep == "0")
        precondition(snapshot.restoreArguments == [
            "restore", "1", "1", "0"
        ])

        let disabledSnapshot = try PowerSnapshot.parse(
            pmsetOutput: output,
            globalOutput: globalDisabled
        )
        precondition(disabledSnapshot.sleepDisabled == "0")

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PowerSnapshot.self, from: encoded)
        precondition(decoded == snapshot)

        try expectSafeFailure(
            output.replacingOccurrences(of: " sleep              1\n", with: ""),
            globalOutput: globalEnabled
        )
        try expectSafeFailure(
            output.replacingOccurrences(of: " sleep              0", with: " sleep              never"),
            globalOutput: globalEnabled
        )
        try expectSafeFailure(
            output.replacingOccurrences(of: "Battery Power:", with: "UPS Power:"),
            globalOutput: globalEnabled
        )
        let absentSnapshot = try PowerSnapshot.parse(
            pmsetOutput: output,
            globalOutput: "System-wide power settings:\nCurrently in use:\n sleep 1"
        )
        precondition(absentSnapshot.sleepDisabled == "0")
        let sparseOutput = """
        Battery Power:
         sleep              1
        AC Power:
         sleep              0
        """
        let sparseSnapshot = try PowerSnapshot.parse(
            pmsetOutput: sparseOutput,
            globalOutput: globalDisabled
        )
        precondition(sparseSnapshot == disabledSnapshot)
        let legacyJSON = """
        {
          "sleepDisabled": "1",
          "batterySleep": "1",
          "batteryDiskSleep": "10",
          "batteryPowerNap": "1",
          "batteryTcpKeepAlive": "1",
          "batteryWomp": "0",
          "acSleep": "0",
          "acDiskSleep": "10",
          "acPowerNap": "1",
          "acTcpKeepAlive": "1",
          "acWomp": "1"
        }
        """
        let legacySnapshot = try JSONDecoder().decode(
            PowerSnapshot.self,
            from: Data(legacyJSON.utf8)
        )
        precondition(legacySnapshot == snapshot)
        try expectSafeFailure(
            output,
            globalOutput: globalEnabled.replacingOccurrences(
                of: "SleepDisabled        1",
                with: "SleepDisabled        yes"
            )
        )
        try expectSafeFailure(
            output,
            globalOutput: globalEnabled.replacingOccurrences(
                of: "SleepDisabled        1",
                with: "SleepDisabled        2"
            )
        )

        if ProcessInfo.processInfo.environment["LIDRUN_LIVE_POWER_SNAPSHOT"] == "1" {
            let current = try Shell.run("/usr/bin/pmset", ["-g", "custom"])
            let global = try Shell.run("/usr/bin/pmset", ["-g"])
            _ = try PowerSnapshot.parse(pmsetOutput: current, globalOutput: global)
            print("OK power-snapshot-live=exact")
        } else {
            print("OK power-snapshot=changed-values-exact sparse-intel=accepted")
        }
    }

    private static func expectSafeFailure(_ output: String, globalOutput: String) throws {
        do {
            _ = try PowerSnapshot.parse(pmsetOutput: output, globalOutput: globalOutput)
            preconditionFailure("Incomplete power settings were accepted")
        } catch {
            precondition(error.localizedDescription.contains("系统设置未被更改"))
        }
    }
}
