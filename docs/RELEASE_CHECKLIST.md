# Release Checklist

## Automated

- [ ] `RUN_LIVE_TESTS=1 RUN_LAUNCH_SMOKE=1 ./scripts/package_release.sh`
- [ ] `./scripts/test_x86_64.sh` passes natively on Intel or through Rosetta without launching the whole App as x86_64.
- [ ] ZIP and DMG checksums, signatures, `arm64`/`x86_64`, bundle ID, and private-path checks pass.
- [ ] DMG mounts cleanly with `LitRun!.app` and an `Applications` alias pointing to `/Applications`.
- [ ] Both App and fan-tool slices report a macOS 13.0 minimum deployment target.
- [ ] Missing or malformed changed power fields fail before any privileged power change; omitted unrelated Intel power keys remain untouched.
- [ ] Original `SleepDisabled` values 0 and 1 restore exactly; an omitted default is treated as off, while a malformed value fails closed.
- [ ] A stale active-session marker is restored before a new snapshot can be written.
- [ ] A stale fan-session marker is restored before another manual session can start.
- [ ] Privileged helper upgrades roll back the previous helper, fan tool, sudoers rule, and any changed main sudoers file on failure.
- [ ] Simulated single-, dual-, multi-, read-only, and fanless paths render without enabling unsupported control.
- [ ] Simulated 22-, 25-, and 30-point menu bars keep the default two-row and optional six-metric grid inside the canvas.
- [ ] Wrapped unsigned battery current decodes as signed, and direct system-load telemetry wins over charge subtraction when available.
- [ ] Frontmost process descendants and same-bundle helpers are protected from low-power pauses.
- [ ] Pause guardians restore on normal completion, App exit, and termination signals, and verify PID identity before signaling.
- [ ] First-launch language choice persists, and Settings switches the visible UI immediately between Chinese and English.
- [ ] The 456x272 main view keeps its compact bottom spacing without clipping the fan slider, percentage, or mode label.
- [ ] The one-line `LitRun!` header, native switches, consistent SF Symbols, quiet separators, and refined fan slider remain crisp in light, dark, and Reduce Motion rendering.
- [ ] Memory and disk telemetry read directly through macOS APIs, stay within physical bounds, and refresh without recurring shell processes.
- [ ] Disabled-motion rendering settles control opacity immediately without leaving the manual fan controls faded.

## Physical Mac

- [ ] All controls off: power and fan telemetry remain visible and match live system readings.
- [ ] Both languages display the compact `LitRun!` window identity while Finder and the Dock retain the localized product name and color icon.
- [ ] The window shows `电脑用电`, `充电输入`, `内存占用`, `磁盘占用`, and `芯片温度` as five clear columns with separate labels and values, no overlap, and no approximation symbol.
- [ ] Bottom spacing is compact while the fan slider, live percentage, and automatic/manual label remain fully visible.
- [ ] No decorative trace, state node, header artwork, or telemetry divider remains; enabled, disabled, unavailable, and warning states stay clear through native controls and text.
- [ ] Each native switch responds to row clicks, direct clicks, keyboard activation, and accessibility inspection with the same state as its corresponding menu command.
- [ ] Charging input means total power entering the Mac, not only battery charging; battery use shows `未连接充电器` and unavailable input shows `充电输入 -- W`.
- [ ] Chip temperature matches readable SMC sensors, and the no-sensor path shows macOS thermal state without a fabricated Celsius value.
- [ ] The gear shows independent checked items for power, temperature, fan, memory, disk, and network; any selection, including empty, persists.
- [ ] The final selected metric can be unchecked, the status item hides when empty, and selecting an item again from the gear restores it.
- [ ] Selected metrics keep a stable order regardless of the order clicked; five metrics use 3+2 and six use 3+3.
- [ ] One-, two-, and three-row vertical two-column layouts remain centered and unclipped at the measured menu-bar height; optional network speed remains compact.
- [ ] The dedicated 30-point canvas shows every selected line fully without top or bottom clipping.
- [ ] Compact menu-bar power omits the approximation symbol and selected-state text keeps one system color.
- [ ] Compact menu-bar power shows only `N W` on both AC and battery.
- [ ] Compact fan telemetry uses short units such as `3.5k R` and `0 R`, while the menu retains exact per-fan `RPM` readings.
- [ ] Launching a second App copy activates the existing process without creating another controller.
- [ ] The running App shows a Dock indicator and the Dock menu provides `退出`.
- [ ] On Apple silicon, a live process sample reports ARM64 rather than an x86_64 Rosetta process.
- [ ] Red close hides the window without quitting; clicking the Dock icon or menu-bar show restores the window.
- [ ] Launch/show fades in with a slight rise, and red close fades out with a slight drop.
- [ ] Yellow minimize uses the native macOS animation and restores normally.
- [ ] Mode surfaces, fan automatic/manual state, disabled controls, busy status text, and settings popover provide restrained feedback without layout movement.
- [ ] Enabling macOS Reduce Motion removes custom movement while preserving state changes.
- [ ] The window places `合盖运行` and `低功耗` side by side above `风扇控制`; the fan switch shows `自动` or `手动` directly below it.
- [ ] Manual fan at 65% reaches every detected target, slider updates work, and off restores mode 0/system automatic.
- [ ] Every fan mode key reads back 1 after manual enable and 0 after automatic restore.
- [ ] The fan percentage follows every slider movement without locking the drag; only the settled value is written after the short debounce.
- [ ] With the fan switch off, dragging the supported slider starts manual mode through the same warning/authorization path; clicking the switch off restores automatic control.
- [ ] Manual fan at 0% shows the critical warning, writes zero targets, reaches stopped state when hardware conditions allow, and off restores every fan to system automatic.
- [ ] Low-speed manual mode returns to automatic control when macOS thermal state rises from nominal.
- [ ] A nominal-state reading below 99°C does not block manual adjustment.
- [ ] A simulated 99°C reading restores automatic control at both 0% and 100% manual settings.
- [ ] Force-quit during manual fan mode restores both fans to automatic control.
- [ ] Low power only: disposable test work slows and restores.
- [ ] Adaptive low power reaches the expected 3.5-4.4 second pause range while every five-second cycle still makes forward progress.
- [ ] Lid mode only, on a desk: task, Wi-Fi, brightness, and full-speed behavior are correct.
- [ ] Both on: slow-running continues across close and open.
- [ ] Force-quit tests restore `SleepDisabled` and continue the controlled task.
- [ ] A simulated exit after brightness recovery state is saved restores the original built-in display brightness when the lid reopens.
- [ ] Requesting quit during a power or fan transition automatically continues after that transition completes.
- [ ] Helper removal and one clean reinstall succeed.

## Distribution

- [ ] Test a fanless Apple Silicon Mac and confirm fan control is disabled without authorization.
- [ ] Test a desktop Mac and confirm lid-running is disabled while low-power remains available.
- [ ] Test one 22-25 point non-notch or external-display menu bar for unclipped two-row telemetry.
- [ ] Run temperature and manual-fan checks on at least one supported Intel Mac before advertising full Intel hardware compatibility.
- [ ] Use Developer ID signing and notarization for general-user distribution.
- [ ] Upload the ZIP, DMG, and both matching `.sha256` files with notes from `CHANGELOG.md`.

Do not call the release fully verified until the physical checks pass.
