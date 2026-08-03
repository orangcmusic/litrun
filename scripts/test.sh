#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/lidrun-tests.XXXXXX")"
trap '/bin/rm -rf "$TMP_ROOT"' EXIT

cd "$ROOT"

SOURCES=(
  AppPaths.swift
  BrightnessManager.swift
  DeferredTerminationCoordinator.swift
  ExitRecoveryWatchdog.swift
  FanControlEngine.swift
  FanControlManager.swift
  FanControlPolicy.swift
  FanTelemetry.swift
  LidState.swift
  LanguageSelectionController.swift
  Localization.swift
  LowPowerSchedulingPolicy.swift
  MainControlView.swift
  MainWindowBehavior.swift
  MenuBarPreferences.swift
  NetworkTelemetry.swift
  ModePolicy.swift
  PowerSettings.swift
  PowerTelemetry.swift
  PrivilegedPowerHelper.swift
  Shell.swift
  SlowLaneManager.swift
  SettingsPanelController.swift
  SingleInstanceGuard.swift
  StatusBarController.swift
  SystemResourceTelemetry.swift
  TemperatureTelemetry.swift
  main.swift
)

before_power=""
before_disabled=""
if [ -x /usr/bin/pmset ]; then
  before_power="$(/usr/bin/pmset -g custom)"
  before_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"
fi

/usr/bin/plutil -lint Info.plist
/usr/bin/plutil -lint Resources/en.lproj/InfoPlist.strings
/usr/bin/plutil -lint Resources/zh-Hans.lproj/InfoPlist.strings
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' Info.plist)" = "true" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' Info.plist)" = "false" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Info.plist)" = "13.0" ]
/bin/sh -n Resources/lid-run-switch-helper.sh
/usr/sbin/visudo -cf Tests/90_lidrunswitch
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck Resources/lid-run-switch-helper.sh scripts/*.sh
fi

xcrun swiftc -warnings-as-errors -typecheck "${SOURCES[@]}"
xcrun swiftc -warnings-as-errors -target arm64-apple-macos13.0 -typecheck "${SOURCES[@]}"
xcrun swiftc -warnings-as-errors -target x86_64-apple-macos13.0 -typecheck "${SOURCES[@]}"

xcrun swiftc -warnings-as-errors ModePolicy.swift Tests/ModePolicySmoke.swift \
    -o "$TMP_ROOT/mode-smoke"
xcrun swiftc -warnings-as-errors \
  DeferredTerminationCoordinator.swift Tests/DeferredTerminationCoordinatorSmoke.swift \
  -o "$TMP_ROOT/deferred-termination-smoke"
xcrun swiftc -warnings-as-errors \
  LowPowerSchedulingPolicy.swift Tests/LowPowerSchedulingPolicySmoke.swift \
  -o "$TMP_ROOT/low-power-scheduling-smoke"
xcrun swiftc -warnings-as-errors -framework IOKit \
  Localization.swift PowerTelemetry.swift Tests/PowerTelemetryEstimatorSmoke.swift \
  -o "$TMP_ROOT/power-telemetry-smoke"
xcrun swiftc -warnings-as-errors \
  SystemResourceTelemetry.swift Tests/SystemResourceTelemetrySmoke.swift \
  -o "$TMP_ROOT/system-resource-telemetry-smoke"
xcrun swiftc -warnings-as-errors \
  NetworkTelemetry.swift Tests/NetworkTelemetrySmoke.swift \
  -o "$TMP_ROOT/network-telemetry-smoke"
xcrun swiftc -warnings-as-errors -framework IOKit \
  Localization.swift FanTelemetry.swift Tests/FanTelemetrySmoke.swift \
  -o "$TMP_ROOT/fan-telemetry-smoke"
xcrun swiftc -warnings-as-errors \
  FanControlPolicy.swift Tests/FanControlPolicySmoke.swift \
  -o "$TMP_ROOT/fan-control-policy-smoke"
xcrun swiftc -warnings-as-errors -framework IOKit \
  Localization.swift FanControlPolicy.swift FanTelemetry.swift TemperatureTelemetry.swift \
  Tests/TemperatureTelemetrySmoke.swift \
  -o "$TMP_ROOT/temperature-telemetry-smoke"
xcrun swiftc -warnings-as-errors \
  Localization.swift MenuBarPreferences.swift Tests/MenuBarPreferencesSmoke.swift \
  -o "$TMP_ROOT/menu-bar-preferences-smoke"
xcrun swiftc -warnings-as-errors \
  Localization.swift MenuBarPreferences.swift SettingsPanelController.swift \
  Tests/SettingsPanelControllerSmoke.swift \
  -o "$TMP_ROOT/settings-panel-smoke"
xcrun swiftc -warnings-as-errors -framework IOKit \
  Localization.swift PowerTelemetry.swift Tests/LocalizationSmoke.swift \
  -o "$TMP_ROOT/localization-smoke"
xcrun swiftc -warnings-as-errors ExitRecoveryWatchdog.swift Tests/ExitRecoveryWatchdogSmoke.swift \
  -o "$TMP_ROOT/watchdog-smoke"
xcrun swiftc -warnings-as-errors \
  Localization.swift LowPowerSchedulingPolicy.swift Shell.swift SlowLaneManager.swift Tests/SlowLaneSmoke.swift \
  -o "$TMP_ROOT/slow-lane-smoke"
xcrun swiftc -warnings-as-errors \
  Localization.swift LowPowerSchedulingPolicy.swift Shell.swift SlowLaneManager.swift Tests/SlowLaneCrashSmoke.swift \
  -o "$TMP_ROOT/slow-lane-crash-smoke"
xcrun swiftc -warnings-as-errors Localization.swift Shell.swift Tests/ShellTimeoutSmoke.swift \
  -o "$TMP_ROOT/shell-timeout-smoke"
xcrun swiftc -warnings-as-errors Localization.swift Shell.swift Tests/PowerSnapshotStub.swift \
  PrivilegedPowerHelper.swift Tests/InstallerScriptSmoke.swift \
  -o "$TMP_ROOT/installer-smoke"
xcrun swiftc -warnings-as-errors \
  AppPaths.swift ExitRecoveryWatchdog.swift Localization.swift Shell.swift PrivilegedPowerHelper.swift \
  PowerSettings.swift Tests/PowerSettingsSmoke.swift \
  -o "$TMP_ROOT/power-settings-smoke"
xcrun swiftc -warnings-as-errors -framework IOKit \
  Localization.swift FanControlPolicy.swift FanTelemetry.swift PowerTelemetry.swift TemperatureTelemetry.swift \
  SystemResourceTelemetry.swift NetworkTelemetry.swift MainWindowBehavior.swift MainControlView.swift \
  Tests/MainControlViewSmoke.swift \
  -o "$TMP_ROOT/main-control-view-smoke"
xcrun swiftc -warnings-as-errors MainWindowBehavior.swift Tests/MainWindowBehaviorSmoke.swift \
  -o "$TMP_ROOT/main-window-behavior-smoke"

"$TMP_ROOT/mode-smoke"
"$TMP_ROOT/deferred-termination-smoke"
"$TMP_ROOT/low-power-scheduling-smoke"
"$TMP_ROOT/power-telemetry-smoke"
"$TMP_ROOT/system-resource-telemetry-smoke"
"$TMP_ROOT/network-telemetry-smoke"
"$TMP_ROOT/fan-telemetry-smoke"
"$TMP_ROOT/fan-control-policy-smoke"
"$TMP_ROOT/temperature-telemetry-smoke"
"$TMP_ROOT/menu-bar-preferences-smoke"
"$TMP_ROOT/settings-panel-smoke"
"$TMP_ROOT/localization-smoke"
"$TMP_ROOT/watchdog-smoke"
"$TMP_ROOT/slow-lane-smoke"
"$TMP_ROOT/slow-lane-crash-smoke"
"$TMP_ROOT/shell-timeout-smoke"
"$TMP_ROOT/installer-smoke"
"$TMP_ROOT/power-settings-smoke"
"$TMP_ROOT/main-control-view-smoke"
"$TMP_ROOT/main-window-behavior-smoke"

if [ "${RUN_LIVE_TESTS:-0}" = "1" ]; then
  LIDRUN_LIVE_POWER_SNAPSHOT=1 "$TMP_ROOT/power-settings-smoke"
  xcrun swiftc -warnings-as-errors -framework AppKit -framework IOKit \
    AppPaths.swift BrightnessManager.swift ExitRecoveryWatchdog.swift \
    FanControlPolicy.swift FanTelemetry.swift LidState.swift \
  Localization.swift MenuBarPreferences.swift NetworkTelemetry.swift PowerTelemetry.swift Shell.swift StatusBarController.swift \
  SystemResourceTelemetry.swift TemperatureTelemetry.swift \
    Tests/ComponentSmoke.swift \
    -o "$TMP_ROOT/component-smoke"
  "$TMP_ROOT/component-smoke"
fi

if [ -n "$before_power" ]; then
  after_power="$(/usr/bin/pmset -g custom)"
  after_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"
  [ "$before_power" = "$after_power" ]
  [ "$before_disabled" = "$after_disabled" ]
fi

if rg -n '/Users/[^/]+/(Documents|Desktop)/' README.md CHANGELOG.md PRIVACY.md SECURITY.md docs .github; then
  echo "Public files contain a private local path" >&2
  exit 1
fi

echo "PASS tests"
