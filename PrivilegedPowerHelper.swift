import Foundation

final class PrivilegedPowerHelper {
    private let helperPath = "/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper"
    private let fanControlPath = "/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-fanctl"
    private let sudoersPath = "/etc/sudoers.d/90_lidrunswitch"
    private let obsoleteSudoersPath = "/etc/sudoers.d/local.codex.lidrunswitch"
    private let obsoleteHelperPath = "/Library/PrivilegedHelperTools/local.codex.lidrunswitch-helper"
    private let expectedVersion = "9"

    static func isSafeAuthorizationUsername(_ username: String) -> Bool {
        username.range(
            of: "^[A-Za-z_][A-Za-z0-9._-]*$",
            options: .regularExpression
        ) != nil
    }

    var isReadyWithoutInstallation: Bool {
        isReady()
    }

    func prepare() throws {
        try ensureInstalled()
    }

    func enable() throws {
        try ensureInstalled()
        try enablePrepared()
    }

    func enablePrepared() throws {
        _ = try runPrivileged(["enable"])
    }

    func restore(_ snapshot: PowerSnapshot) throws {
        try ensureInstalled()
        try restorePrepared(snapshot)
    }

    func restorePrepared(_ snapshot: PowerSnapshot) throws {
        _ = try runPrivileged(snapshot.restoreArguments)
    }

    func recoveryCommand(for snapshot: PowerSnapshot) -> (executable: String, arguments: [String]) {
        ("/usr/bin/sudo", ["-n", helperPath] + snapshot.restoreArguments)
    }

    func setFansManual(targets: [Int]) throws {
        try ensureInstalled()
        _ = try runPrivileged(["fan-set"] + targets.map(String.init), timeout: 30)
    }

    func setFansAutomatic() throws {
        try ensureInstalled()
        _ = try runPrivileged(["fan-auto"], timeout: 30)
    }

    func fanRecoveryCommand() -> (executable: String, arguments: [String]) {
        ("/usr/bin/sudo", ["-n", helperPath, "fan-auto"])
    }

    func removeInstallation() throws {
        try Shell.runAdminScript(removalScriptForTesting())
    }

    private func ensureInstalled() throws {
        if isReady() {
            return
        }
        try install()
        guard isReady() else {
            throw helperError(
                L10n.text(
                    "一次授权助手安装后仍不可用。",
                    "The privileged helper is still unavailable after installation."
                )
            )
        }
    }

    private func isReady() -> Bool {
        guard FileManager.default.isExecutableFile(atPath: helperPath),
              let version = try? Shell.run(helperPath, ["version"])
                .trimmingCharacters(in: .whitespacesAndNewlines),
              version == expectedVersion
        else {
            return false
        }
        return (try? runPrivileged(["status"])) != nil
    }

    private func install() throws {
        let username = NSUserName()
        guard Self.isSafeAuthorizationUsername(username) else {
            throw helperError(
                L10n.text(
                    "当前用户名不能安全写入授权规则。",
                    "The current account name cannot be written safely to the authorization rule."
                )
            )
        }
        guard let sourceURL = Bundle.main.url(
            forResource: "lid-run-switch-helper",
            withExtension: "sh"
        ) else {
            throw helperError(
                L10n.text(
                    "App 内缺少一次授权助手文件。",
                    "The privileged helper is missing from the App."
                )
            )
        }
        guard let fanSourceURL = Bundle.main.url(
            forResource: "lid-run-switch-fanctl",
            withExtension: nil
        ) else {
            throw helperError(
                L10n.text(
                    "App 内缺少风扇控制组件。",
                    "The fan-control component is missing from the App."
                )
            )
        }

        let hashOutput = try Shell.run("/usr/bin/shasum", ["-a", "256", sourceURL.path])
        guard let expectedHash = hashOutput.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
              expectedHash.count == 64
        else {
            throw helperError(
                L10n.text(
                    "无法校验一次授权助手。",
                    "The privileged helper could not be verified."
                )
            )
        }
        let fanHashOutput = try Shell.run(
            "/usr/bin/shasum",
            ["-a", "256", fanSourceURL.path]
        )
        guard let fanExpectedHash = fanHashOutput
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .first,
              fanExpectedHash.count == 64
        else {
            throw helperError(
                L10n.text(
                    "无法校验风扇控制组件。",
                    "The fan-control component could not be verified."
                )
            )
        }

        try Shell.runAdminScript(installationScriptForTesting(
            username: username,
            sourceURL: sourceURL,
            expectedHash: String(expectedHash),
            fanSourceURL: fanSourceURL,
            fanExpectedHash: String(fanExpectedHash)
        ))
    }

    func installationScriptForTesting(
        username: String,
        sourceURL: URL,
        expectedHash: String,
        fanSourceURL: URL,
        fanExpectedHash: String
    ) -> String {
        let sudoersRule = "\(username) ALL=(root) NOPASSWD: \(helperPath)"
        let verificationCommand = "/usr/bin/sudo -n \(helperPath) status"

        return """
        #!/bin/sh
        set -eu

        target_user=\(Shell.quoteForShell(username))
        source_path=\(Shell.quoteForShell(sourceURL.path))
        expected_hash=\(Shell.quoteForShell(expectedHash))
        fan_source_path=\(Shell.quoteForShell(fanSourceURL.path))
        fan_expected_hash=\(Shell.quoteForShell(fanExpectedHash))
        verification_command=\(Shell.quoteForShell(verificationCommand))
        actual_hash=$(/usr/bin/shasum -a 256 "$source_path" | /usr/bin/awk '{print $1}')
        [ "$actual_hash" = "$expected_hash" ]
        fan_actual_hash=$(/usr/bin/shasum -a 256 "$fan_source_path" | /usr/bin/awk '{print $1}')
        [ "$fan_actual_hash" = "$fan_expected_hash" ]

        backup_dir=$(/usr/bin/mktemp -d /tmp/io.github.achengbatian.lidrunswitch-install.XXXXXX)
        had_helper=0
        had_fan=0
        had_rule=0
        committed=0
        main_sudoers_changed=0
        sudoers_tmp=""
        main_tmp=""
        if [ -e \(Shell.quoteForShell(helperPath)) ]; then
            /bin/cp -p \(Shell.quoteForShell(helperPath)) "$backup_dir/helper"
            had_helper=1
        fi
        if [ -e \(Shell.quoteForShell(fanControlPath)) ]; then
            /bin/cp -p \(Shell.quoteForShell(fanControlPath)) "$backup_dir/fanctl"
            had_fan=1
        fi
        if [ -e \(Shell.quoteForShell(sudoersPath)) ]; then
            /bin/cp -p \(Shell.quoteForShell(sudoersPath)) "$backup_dir/rule"
            had_rule=1
        fi
        /bin/cp -p /etc/sudoers "$backup_dir/sudoers-main"
        rollback_install() {
            status=$?
            trap - EXIT HUP INT TERM
            set +e
            if [ "$committed" -ne 1 ]; then
                if [ "$had_helper" -eq 1 ]; then
                    /usr/bin/install -o root -g wheel -m 0755 "$backup_dir/helper" \(Shell.quoteForShell(helperPath))
                else
                    /bin/rm -f \(Shell.quoteForShell(helperPath))
                fi
                if [ "$had_fan" -eq 1 ]; then
                    /usr/bin/install -o root -g wheel -m 0755 "$backup_dir/fanctl" \(Shell.quoteForShell(fanControlPath))
                else
                    /bin/rm -f \(Shell.quoteForShell(fanControlPath))
                fi
                if [ "$had_rule" -eq 1 ]; then
                    /usr/bin/install -o root -g wheel -m 0440 "$backup_dir/rule" \(Shell.quoteForShell(sudoersPath))
                else
                    /bin/rm -f \(Shell.quoteForShell(sudoersPath))
                fi
                if [ "$main_sudoers_changed" -eq 1 ]; then
                    /usr/bin/install -o root -g wheel -m 0440 "$backup_dir/sudoers-main" /etc/sudoers
                fi
            fi
            if [ -n "$sudoers_tmp" ]; then
                /bin/rm -f "$sudoers_tmp"
            fi
            if [ -n "$main_tmp" ]; then
                /bin/rm -f "$main_tmp"
            fi
            /bin/rm -rf "$backup_dir"
            exit "$status"
        }
        trap rollback_install EXIT
        trap 'exit 129' HUP
        trap 'exit 130' INT
        trap 'exit 143' TERM

        /usr/bin/install -d -o root -g wheel -m 0755 /Library/PrivilegedHelperTools
        /usr/bin/install -o root -g wheel -m 0755 "$source_path" \(Shell.quoteForShell(helperPath))
        /usr/bin/install -o root -g wheel -m 0755 "$fan_source_path" \(Shell.quoteForShell(fanControlPath))
        installed_hash=$(/usr/bin/shasum -a 256 \(Shell.quoteForShell(helperPath)) | /usr/bin/awk '{print $1}')
        [ "$installed_hash" = "$expected_hash" ]
        fan_installed_hash=$(/usr/bin/shasum -a 256 \(Shell.quoteForShell(fanControlPath)) | /usr/bin/awk '{print $1}')
        [ "$fan_installed_hash" = "$fan_expected_hash" ]

        sudoers_tmp=$(/usr/bin/mktemp /tmp/io.github.achengbatian.lidrunswitch.XXXXXX)
        /usr/bin/printf '%s\n' \(Shell.quoteForShell(sudoersRule)) > "$sudoers_tmp"
        /bin/chmod 0440 "$sudoers_tmp"
        /usr/sbin/visudo -cf "$sudoers_tmp"
        /usr/bin/install -o root -g wheel -m 0440 "$sudoers_tmp" \(Shell.quoteForShell(sudoersPath))
        /usr/sbin/visudo -cf \(Shell.quoteForShell(sudoersPath))
        /bin/rm -f \(Shell.quoteForShell(obsoleteSudoersPath))

        if ! /usr/bin/su -l "$target_user" -c "$verification_command"; then
            if ! /usr/bin/grep -Eq '^[[:space:]]*(@|#)includedir[[:space:]]+(/private)?/etc/sudoers[.]d([[:space:]]|$)' /etc/sudoers; then
                main_tmp=$(/usr/bin/mktemp /tmp/io.github.achengbatian.sudoers-main.XXXXXX)
                /bin/cat /etc/sudoers > "$main_tmp"
                /usr/bin/printf '\n%s\n' '@includedir /private/etc/sudoers.d' >> "$main_tmp"
                /bin/chmod 0440 "$main_tmp"
                /usr/sbin/visudo -cf "$main_tmp"
                if [ ! -e /etc/sudoers.lidrunswitch.backup ]; then
                    /bin/cp -p /etc/sudoers /etc/sudoers.lidrunswitch.backup
                fi
                /bin/cp -p /etc/sudoers "$backup_dir/sudoers-main"
                main_sudoers_changed=1
                /usr/bin/install -o root -g wheel -m 0440 "$main_tmp" /etc/sudoers
                /usr/sbin/visudo -cf /etc/sudoers
            fi
        fi

        /usr/bin/su -l "$target_user" -c "$verification_command"
        /bin/rm -f \(Shell.quoteForShell(obsoleteHelperPath))
        /bin/rm -f \(Shell.quoteForShell(obsoleteSudoersPath))
        committed=1
        """
    }

    func removalScriptForTesting() -> String {
        """
        #!/bin/sh
        set -eu

        if [ -x \(Shell.quoteForShell(fanControlPath)) ]; then
            \(Shell.quoteForShell(fanControlPath)) auto >/dev/null 2>&1 || true
        fi
        /bin/rm -f \(Shell.quoteForShell(helperPath))
        /bin/rm -f \(Shell.quoteForShell(fanControlPath))
        /bin/rm -f \(Shell.quoteForShell(sudoersPath))
        /bin/rm -f \(Shell.quoteForShell(obsoleteHelperPath))
        /bin/rm -f \(Shell.quoteForShell(obsoleteSudoersPath))
        /usr/sbin/visudo -cf /etc/sudoers
        """
    }

    private func runPrivileged(
        _ arguments: [String],
        timeout: TimeInterval = 15
    ) throws -> String {
        try Shell.run("/usr/bin/sudo", ["-n", helperPath] + arguments, timeout: timeout)
    }

    private func helperError(_ message: String) -> NSError {
        NSError(
            domain: "LidRunSwitch.PrivilegedHelper",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
