#!/bin/bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/litrun-x86-tests.XXXXXX")"
trap '/bin/rm -rf "$TMP_ROOT"' EXIT

cd "$ROOT"

RUNNER=()
if [ "$(/usr/bin/uname -m)" != "x86_64" ]; then
  if ! /usr/bin/arch -x86_64 /usr/bin/true; then
    echo "x86_64 runtime is unavailable on this Mac" >&2
    exit 1
  fi
  RUNNER=(/usr/bin/arch -x86_64)
fi

run_x86() {
  "${RUNNER[@]}" "$@"
}

compile_x86() {
  xcrun swiftc -warnings-as-errors -target x86_64-apple-macos13.0 "$@"
}

OUTPUT_ROOT="${LIDRUN_X86_OUTPUT_DIR:-$TMP_ROOT}"
/bin/mkdir -p "$OUTPUT_ROOT"

before_power=""
before_disabled=""
if [ -x /usr/bin/pmset ]; then
  before_power="$(/usr/bin/pmset -g custom)"
  before_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"
fi

compile_x86 ModePolicy.swift Tests/ModePolicySmoke.swift \
  -o "$TMP_ROOT/mode-smoke"
compile_x86 DeferredTerminationCoordinator.swift Tests/DeferredTerminationCoordinatorSmoke.swift \
  -o "$TMP_ROOT/deferred-termination-smoke"
compile_x86 LowPowerSchedulingPolicy.swift Tests/LowPowerSchedulingPolicySmoke.swift \
  -o "$TMP_ROOT/low-power-scheduling-smoke"
compile_x86 -framework IOKit \
  Localization.swift PowerTelemetry.swift Tests/PowerTelemetryEstimatorSmoke.swift \
  -o "$TMP_ROOT/power-telemetry-smoke"
compile_x86 \
  SystemResourceTelemetry.swift Tests/SystemResourceTelemetrySmoke.swift \
  -o "$TMP_ROOT/system-resource-telemetry-smoke"
compile_x86 \
  NetworkTelemetry.swift Tests/NetworkTelemetrySmoke.swift \
  -o "$TMP_ROOT/network-telemetry-smoke"
compile_x86 -framework IOKit \
  Localization.swift FanTelemetry.swift Tests/FanTelemetrySmoke.swift \
  -o "$TMP_ROOT/fan-telemetry-smoke"
compile_x86 FanControlPolicy.swift Tests/FanControlPolicySmoke.swift \
  -o "$TMP_ROOT/fan-control-policy-smoke"
compile_x86 -framework IOKit \
  Localization.swift FanControlPolicy.swift FanTelemetry.swift TemperatureTelemetry.swift \
  Tests/TemperatureTelemetrySmoke.swift \
  -o "$TMP_ROOT/temperature-telemetry-smoke"
compile_x86 \
  Localization.swift MenuBarPreferences.swift Tests/MenuBarPreferencesSmoke.swift \
  -o "$TMP_ROOT/menu-bar-preferences-smoke"
compile_x86 \
  Localization.swift MenuBarPreferences.swift SettingsPanelController.swift \
  Tests/SettingsPanelControllerSmoke.swift \
  -o "$TMP_ROOT/settings-panel-smoke"
compile_x86 -framework IOKit \
  Localization.swift PowerTelemetry.swift Tests/LocalizationSmoke.swift \
  -o "$TMP_ROOT/localization-smoke"
compile_x86 ExitRecoveryWatchdog.swift Tests/ExitRecoveryWatchdogSmoke.swift \
  -o "$TMP_ROOT/watchdog-smoke"
compile_x86 \
  Localization.swift LowPowerSchedulingPolicy.swift Shell.swift SlowLaneManager.swift \
  Tests/SlowLaneSmoke.swift \
  -o "$TMP_ROOT/slow-lane-smoke"
compile_x86 \
  Localization.swift LowPowerSchedulingPolicy.swift Shell.swift SlowLaneManager.swift \
  Tests/SlowLaneCrashSmoke.swift \
  -o "$TMP_ROOT/slow-lane-crash-smoke"
compile_x86 Localization.swift Shell.swift Tests/ShellTimeoutSmoke.swift \
  -o "$TMP_ROOT/shell-timeout-smoke"
compile_x86 \
  Localization.swift Shell.swift Tests/PowerSnapshotStub.swift PrivilegedPowerHelper.swift \
  Tests/InstallerScriptSmoke.swift \
  -o "$TMP_ROOT/installer-smoke"
compile_x86 \
  AppPaths.swift ExitRecoveryWatchdog.swift Localization.swift Shell.swift \
  PrivilegedPowerHelper.swift PowerSettings.swift Tests/PowerSettingsSmoke.swift \
  -o "$TMP_ROOT/power-settings-smoke"
compile_x86 -framework IOKit \
  Localization.swift FanControlPolicy.swift FanTelemetry.swift PowerTelemetry.swift \
  TemperatureTelemetry.swift SystemResourceTelemetry.swift NetworkTelemetry.swift MainWindowBehavior.swift MainControlView.swift \
  Tests/MainControlViewSmoke.swift \
  -o "$TMP_ROOT/main-control-view-smoke"
compile_x86 MainWindowBehavior.swift Tests/MainWindowBehaviorSmoke.swift \
  -o "$TMP_ROOT/main-window-behavior-smoke"
compile_x86 -framework AppKit -framework IOKit \
  AppPaths.swift BrightnessManager.swift ExitRecoveryWatchdog.swift \
  FanControlPolicy.swift FanTelemetry.swift LidState.swift Localization.swift \
  MenuBarPreferences.swift NetworkTelemetry.swift PowerTelemetry.swift Shell.swift StatusBarController.swift \
  SystemResourceTelemetry.swift TemperatureTelemetry.swift Tests/ComponentSmoke.swift \
  -o "$TMP_ROOT/component-smoke"
compile_x86 -O \
  Localization.swift FanTelemetry.swift FanControlPolicy.swift FanControlEngine.swift \
  FanHelper/FanControlToolMain.swift \
  -o "$TMP_ROOT/fanctl"

for binary in "$TMP_ROOT"/*-smoke "$TMP_ROOT/fanctl"; do
  [ "$(/usr/bin/lipo -archs "$binary")" = "x86_64" ]
done

run_x86 "$TMP_ROOT/mode-smoke"
run_x86 "$TMP_ROOT/deferred-termination-smoke"
run_x86 "$TMP_ROOT/low-power-scheduling-smoke"
run_x86 "$TMP_ROOT/power-telemetry-smoke"
run_x86 "$TMP_ROOT/system-resource-telemetry-smoke"
run_x86 "$TMP_ROOT/network-telemetry-smoke"
run_x86 "$TMP_ROOT/fan-telemetry-smoke"
run_x86 "$TMP_ROOT/fan-control-policy-smoke"
run_x86 "$TMP_ROOT/temperature-telemetry-smoke"
run_x86 "$TMP_ROOT/menu-bar-preferences-smoke"
run_x86 "$TMP_ROOT/settings-panel-smoke" "$OUTPUT_ROOT/settings.png"
run_x86 "$TMP_ROOT/localization-smoke"
run_x86 "$TMP_ROOT/watchdog-smoke"
run_x86 "$TMP_ROOT/slow-lane-smoke"
run_x86 "$TMP_ROOT/slow-lane-crash-smoke"
run_x86 "$TMP_ROOT/shell-timeout-smoke"
run_x86 "$TMP_ROOT/installer-smoke"
LIDRUN_LIVE_POWER_SNAPSHOT=1 run_x86 "$TMP_ROOT/power-settings-smoke"
run_x86 "$TMP_ROOT/main-control-view-smoke" \
  "$OUTPUT_ROOT/main-zh.png" \
  "$OUTPUT_ROOT/main-en.png" \
  "$OUTPUT_ROOT/main-en-dark.png"
run_x86 "$TMP_ROOT/main-window-behavior-smoke"
LIDRUN_STATUS_PREVIEW_PATH="$OUTPUT_ROOT/status.png" \
  run_x86 "$TMP_ROOT/component-smoke"
[ "$(run_x86 "$TMP_ROOT/fanctl" version)" = "3" ]
run_x86 "$TMP_ROOT/fanctl" status

if [ -n "$before_power" ]; then
  after_power="$(/usr/bin/pmset -g custom)"
  after_disabled="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2 }')"
  [ "$before_power" = "$after_power" ]
  [ "$before_disabled" = "$after_disabled" ]
fi

echo "PASS x86_64 runtime tests"
