import Foundation

@main
struct InstallerScriptSmoke {
    static func main() throws {
        let helper = PrivilegedPowerHelper()
        let snapshot = PowerSnapshot(
            sleepDisabled: "1",
            batterySleep: "1",
            acSleep: "0"
        )
        let recovery = helper.recoveryCommand(for: snapshot)
        guard recovery.executable == "/usr/bin/sudo",
              Array(recovery.arguments.prefix(3)) == [
                  "-n",
                  "/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper",
                  "restore"
              ],
              Array(recovery.arguments.dropFirst(3)) == Array(snapshot.restoreArguments.dropFirst())
        else {
            fatalError("Power recovery command did not preserve the exact snapshot")
        }

        let username = "test.user-name"
        let sourcePath = "/tmp/LidRun Switch's Helper/helper script"
        let fanSourcePath = "/tmp/LidRun Switch's Helper/fan tool"
        let script = helper.installationScriptForTesting(
            username: username,
            sourceURL: URL(fileURLWithPath: sourcePath),
            expectedHash: String(repeating: "a", count: 64),
            fanSourceURL: URL(fileURLWithPath: fanSourcePath),
            fanExpectedHash: String(repeating: "b", count: 64)
        )

        guard script.contains("NOPASSWD: /Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper"),
              script.contains("/etc/sudoers.d/90_lidrunswitch"),
              !script.contains("install -o root -g wheel -m 0440 \"$sudoers_tmp\" '/etc/sudoers.d/local.codex.lidrunswitch'"),
              script.contains("@includedir /private/etc/sudoers.d"),
              script.contains("sudo -n /Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper status"),
              script.contains("/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-fanctl"),
              script.contains(String(repeating: "b", count: 64)),
              script.contains("/Library/PrivilegedHelperTools/local.codex.lidrunswitch-helper"),
              script.contains("fan_expected_hash"),
              script.contains("rollback_install"),
              script.contains("main_sudoers_changed"),
              script.contains("committed=1"),
              script.contains("target_user=\(Shell.quoteForShell(username))"),
              script.contains("source_path=\(Shell.quoteForShell(sourcePath))"),
              script.contains("fan_source_path=\(Shell.quoteForShell(fanSourcePath))"),
              PrivilegedPowerHelper.isSafeAuthorizationUsername(username),
              !PrivilegedPowerHelper.isSafeAuthorizationUsername("test user"),
              !PrivilegedPowerHelper.isSafeAuthorizationUsername("test'user")
        else {
            fatalError("Installer script is missing its fixed authorization checks")
        }

        let assignmentPrefixes = [
            "target_user=",
            "source_path=",
            "fan_source_path="
        ]
        let assignments = script.split(separator: "\n").compactMap { rawLine -> String? in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            return assignmentPrefixes.contains(where: line.hasPrefix) ? line : nil
        }
        let assignmentProbe = """
        #!/bin/sh
        set -eu
        \(assignments.joined(separator: "\n"))
        /usr/bin/printf '%s\\n' "$target_user" "$source_path" "$fan_source_path"
        """
        let assignmentURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lid run switch's assignment probe.sh")
        try assignmentProbe.write(to: assignmentURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: assignmentURL) }
        let assignmentOutput = try Shell.run("/bin/sh", [assignmentURL.path])
            .split(separator: "\n")
            .map(String.init)
        guard assignmentOutput == [username, sourcePath, fanSourcePath] else {
            fatalError("Installer path or username quoting changed the original value")
        }

        let sudoersRuleURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lid-run-switch-sudoers-\(UUID().uuidString)")
        let sudoersRule = "\(username) ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper\n"
        try sudoersRule.write(to: sudoersRuleURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sudoersRuleURL) }
        _ = try Shell.run("/usr/sbin/visudo", ["-cf", sudoersRuleURL.path])

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lid-run-switch-installer-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try Shell.run("/bin/sh", ["-n", url.path])

        let helperScript = try String(
            contentsOfFile: "Resources/lid-run-switch-helper.sh",
            encoding: .utf8
        )
        guard try Shell.run(
            "/bin/sh",
            ["Resources/lid-run-switch-helper.sh", "version"]
        ).trimmingCharacters(in: .whitespacesAndNewlines) == "9",
              helperScript.contains("[ \"$#\" -eq 3 ] || exit 64"),
              helperScript.contains("[ \"$(\"$fan_control_path\" version)\" = \"3\" ]"),
              helperScript.contains("disablesleep \"$sleep_disabled\""),
              helperScript.contains("/usr/bin/pmset -a sleep 0"),
              !helperScript.contains("tcpkeepalive"),
              !helperScript.contains("disablesleep 0")
        else {
            fatalError("Helper restore protocol is stale or loses SleepDisabled")
        }

        let removalScript = helper.removalScriptForTesting()
        guard removalScript.contains("/etc/sudoers.d/90_lidrunswitch"),
              removalScript.contains("/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper"),
              removalScript.contains("/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-fanctl"),
              removalScript.contains("visudo -cf /etc/sudoers")
        else {
            fatalError("Removal script is incomplete")
        }
        let removalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lid-run-switch-removal-\(UUID().uuidString).sh")
        try removalScript.write(to: removalURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: removalURL) }
        _ = try Shell.run("/bin/sh", ["-n", removalURL.path])

        print("OK installer=valid special-paths=quoted dotted-hyphen-user=valid uninstaller=valid")
    }
}
