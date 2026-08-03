# Architecture

## Components

- `main.swift`: compact AppKit UI and mode orchestration.
- `PowerSettings.swift`: fail-closed exact power snapshot, session marker, and restore.
- `PrivilegedPowerHelper.swift`: restricted helper install, use, and removal.
- `ExitRecoveryWatchdog.swift`: restores power settings if the App exits.
- `SlowLaneManager.swift`: reversible scheduling and pause guardians.
- `LowPowerSchedulingPolicy.swift`: power/temperature-aware pause depth with a guaranteed run window.
- `PowerTelemetry.swift`: direct system-load or charge-corrected computer-use telemetry, total charger-input telemetry, and an honest input-only fallback using normalized signed battery flow when available.
- `SystemResourceTelemetry.swift`: lightweight physical-memory and startup-volume usage sampled directly through macOS APIs.
- `FanTelemetry.swift`: variable fan-count telemetry and read-only manual-control capability probing.
- `TemperatureTelemetry.swift`: conservative peak chip temperature with macOS thermal-state fallback.
- `FanControlPolicy.swift`, `FanControlEngine.swift`, `FanControlManager.swift`: bounded 0-100% targets, low-speed warning policy, and crash-safe automatic restoration.
+ `MenuBarPreferences.swift`, `SettingsPanelController.swift`: persisted six-metric selection, legacy preference migration, and the compact gear popover.
+ `NetworkTelemetry.swift`: low-cost physical-interface byte-counter sampling for optional download/upload speed display.
- `Localization.swift`, `LanguageSelectionController.swift`: persisted Chinese/English choice, first-launch selection, and immediate in-App language updates.
- `MainWindowBehavior.swift`, `MainControlView.swift`: native window policy and restrained interaction motion with Reduce Motion support.
- `DeferredTerminationCoordinator.swift`: queues quit requests made during a reversible system transition.
- `BrightnessManager.swift`: built-in display dim and recovery.
+ `LidState.swift`, `ModePolicy.swift`, `StatusBarController.swift`: lid state, mode policy, and the adaptive one- to three-row menu-bar grid, including its hidden empty state.
- `SingleInstanceGuard.swift`: activates the existing App and prevents competing control processes.

## Recovery model

Enabling lid mode saves the exact current values that it changes: effective `SleepDisabled`, battery sleep, and AC sleep. It then marks the session active, arms an external watchdog, and changes only those values. Normal disable restores before clearing recovery state. An unexpected exit triggers the watchdog; the next launch retries any unfinished recovery. A stale session is restored before a new snapshot can replace it.

The snapshot parser requires every value used by the restricted restore command. It does not require or rewrite unrelated keys that older Intel hardware or an x86_64 `pmset` may omit. Missing or malformed changed values stop the enable path before any privileged setting changes. Macs without a detectable clamshell never expose lid-running as an available control.

Low-power mode is independent. It adapts each five-second cycle from a 3.5-second pause up to a 4.4-second pause based on reliable computer power and chip temperature, always leaving at least approximately 0.6 seconds for forward progress. The frontmost App's full descendant tree and same-bundle helper commands are protected. Each brief task pause has its own guardian, which verifies launch time and command identity before signaling the PID and restores scheduling on normal completion, App exit, or termination signals.

Manual fan mode is also independent. It accepts bounded targets from stopped to each fan's reported hardware maximum, warns before entering the lower half, marks the session active, and arms a separate EOF watchdog before entering manual mode. A stale session is restored before a new one starts, and every manual or automatic mode write is confirmed by reading every fan's mode key back. When automatic mode is visible, dragging the supported slider starts the same manual transition as the switch; the slider remains responsive during authorization and the final dragged percentage is applied once manual mode is ready. Slider movement updates the visible percentage continuously but debounces privileged writes until the value settles. Every manual speed restores automatic control at 99°C. Low-speed mode also restores automatic control when macOS reports elevated thermal state; disable, quit, serious thermal escalation, command failure, unexpected exit, and next launch attempt to return every fan to automatic control.

Brightness recovery is also fail-closed. The original value is persisted and a user-level EOF watchdog is armed before the display is set to zero. If the App exits or cannot restore while the lid is closed, the recovery process waits for the built-in display to return, restores the saved value, and removes the record.

Before the switch is enabled, a read-only probe requires a valid fan count, readable limits and targets, and a recognized manual-mode key for every fan. Fanless and telemetry-only Macs therefore degrade without an administrator prompt or an attempted write.

## Privilege boundary

Only the validated helper and fan control tool run as root. UI, telemetry, lid state, brightness, process scheduling, and watchdog supervision run as the user. The helper accepts only fixed commands, numeric power restore values, and bounded fan targets. Upgrades back up the previous privileged files and sudoers state first; failed installation or verification restores the previous version.
