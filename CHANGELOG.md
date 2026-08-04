# Changelog

## 3.0.1 build 76 - 2026-08-04

- Fix a Swift type-inference failure in the menu-bar renderer on GitHub's
  macOS CI runner.
- Remove internal upload and friend-testing instructions from the public
  repository and release archive.
- Keep the release archive focused on the signed `LitRun!.app` bundle.

## 3.0.0 build 75 - 2026-08-03

- Allow the final selected menu-bar metric to be unchecked and persist an empty
  selection; the status item hides until a metric is selected again from the
  window settings gear.
- Enlarge one- and two-metric menu-bar layouts to 12pt and 10pt, set the
  four-metric 2x2 layout to 9pt, and tighten only its middle gap to 0.5pt.
- Keep the existing three-row typography and spacing for five- and six-metric
  layouts.

## 3.0.0 build 74 - 2026-08-03

- Tighten only the two-column gap in the four-metric 2x2 menu-bar layout from
  4pt to 2pt while keeping the whole layout centered.
- Keep the five-metric 3+2 gap and the six-metric 3+3 gap unchanged.

## 3.0.0 build 73 - 2026-08-03

- Set the four-metric 2x2 menu-bar layout to a restrained 9.5pt across menu
  bar heights, keeping both rows readable without crowding the status bar.
- Keep the centered origin, column gap, and five-metric 3+2 / six-metric 3+3
  layouts unchanged.

## 3.0.0 build 72 - 2026-08-03

- Reduce the four-metric 2x2 menu-bar layout to 11pt on bars at least 25pt
  tall, while retaining a safe 10pt fallback on compact 22pt bars.
- Keep the centered origin, column gap, and five-metric 3+2 / six-metric 3+3
  layouts unchanged.

## 3.0.0 build 71 - 2026-08-03

- Enlarge only the four-metric 2x2 menu-bar layout using the largest safe font
  for each menu-bar height: 10pt on compact 22pt bars up to 13pt on 30pt bars.
- Preserve the centered origin, column gap, and the existing five-metric 3+2
  and six-metric 3+3 typography and geometry.

## 3.0.0 build 70 - 2026-08-03

- Increase the menu-bar font only for the four-metric 2x2 layout from 8pt to
  9pt while preserving its centered position and existing column spacing.
- Keep the five-metric 3+2 and six-metric 3+3 layouts on their existing
  adaptive font sizes and geometry.

## 3.0.0 build 69 - 2026-08-03

- Reduce the top content inset by 3pt so the header has slightly less empty
  space while preserving the existing telemetry and control spacing.

## 3.0.0 build 68 - 2026-08-03

- Align the custom fan slider track endpoints with the native knob centers so
  the 0% and 100% positions no longer leave a misleading trailing segment.
- Add an optional 100% fan-slider render to the UI smoke test.

## 3.0.0 build 67 - 2026-08-03

- Allow a supported fan slider drag to activate manual fan control directly
  when the switch is off, while keeping the switch as the explicit automatic
  restore action.
- Keep the slider responsive while manual fan authorization is in progress and
  apply the last dragged percentage after manual mode becomes active.

## 3.0.0 build 66 - 2026-08-03

- Allow a supported fan slider drag to activate manual fan control directly
  when the switch is off, while keeping the switch as the explicit automatic
  restore action.

## 3.0.0 build 65 - 2026-08-02

- Tighten the five-metric menu-bar composition: both columns use a shared
  left edge, the column gap is smaller, and the bottom network line spans the
  compact row without forcing a wide empty middle.
- Keep six selected metrics in the existing symmetric 3+3 grid.
- Align the main-window network line with the first primary metric column and
  add regression coverage for both compact status layout and window geometry.
- Add a standard drag-to-Applications DMG alongside the ZIP, with mounted
  structure, bundle version, signature, and checksum verification.

## 3.0.0 build 64 - 2026-08-02

- Add a compact live network-speed line below the five primary window metrics.
- Keep the main power, memory, disk, and temperature values at their readable
  sizes while using a smaller secondary network hierarchy such as
  `网速  ↓2.1k ↑1k`.
- Update the main window and language refresh paths together with the network
  monitor, and verify the new row stays inside the fixed 456x272 canvas.

## 3.0.0 build 63 - 2026-08-02

- When exactly five metrics include network speed, pin network to the bottom
  of the left column for a deliberate 3+2 vertical composition.
- Keep the six-metric composition symmetrical, with network at the bottom of
  the right column beside the fan metric.
- Add regression coverage for both network placement rules and their stacked
  accessibility text.

## 3.0.0 build 62 - 2026-08-02

- Change the menu-bar layout to a vertical two-column grid: five metrics use
  three rows with a 3+2 column split, and six metrics use three rows with 3+3.
- Keep the third item of a five-metric selection aligned in the left column;
  no status-bar selection uses three columns.

## 3.0.0 build 61 - 2026-08-02

- Keep five selected menu-bar metrics in a compact 3+2 layout and six in 3+3.
- Give each metric an independent fixed display slot so network speed no longer
  expands every column or changes the status-item width as rates vary.
- Shorten menu-bar network values such as `↓2.1k ↑1k` while keeping the full
  download/upload wording in the menu detail and tooltip.

## 3.0.0 - 2026-08-01

- Increase window typography without changing the 456x272 grid: telemetry values use 17pt, mode labels 11.5pt, and fan readouts 9.5-10.5pt.
- Add memory and disk to the menu-bar selection with a centered two-row 3+2 layout; add optional low-cost network speed as a sixth 3+3 metric.
- Sample physical interface byte counters without external commands or network-content logging, with counter-wrap, interface-change, and unavailable-state handling.
- Align the bottom fan switch with the upper mode-switch column and align the slider start with the left mode-switch column; add geometry regression checks for both columns.
- Allow `RELEASE_COPY_DIR` to receive the exact generated ZIP and checksum after package verification, keeping local distribution copies synchronized.
- Complete the mode-row hover surface around native switches and optically align the compact product/status header in both light and dark appearances.
- Rebuild the compact main window from the approved visual target with a restrained `LitRun!` identity, neutral live status, consistent SF Symbols, and native controls.
- Expand the main telemetry row from three to five equal columns: computer use, charger input, memory use, disk use, and chip temperature.
- Read memory and disk use directly through macOS APIs on a lightweight ten-second interval without spawning recurring shell processes.
- Remove the grouped outline, use quiet native separators, pull the fan slider closer to its label, and set the final fixed window to 456x272.
- Refine the production AppKit typography, symbols, separators, and slider to match the approved lighter visual hierarchy, and preserve dynamic metric-title colors across light and dark appearances.
- Add deterministic memory/disk tests and verify the five-column layout in Chinese light, English light, English dark, Reduce Motion, native arm64, and Rosetta x86_64 paths.

## 2.9.2 - 2026-08-01

- Remove the rejected header artwork and keep the product name with its live status directly below, left aligned.
- Tighten the three centered telemetry columns while preserving full Chinese and English labels and one-decimal window power values.
- Restore familiar SF Symbols and place the two native mode switches side by side inside one restrained grouped surface.
- Keep the complete fan control on one row, including the live slider percentage, automatic/manual switch, and compact values such as `3.2k · 3.4k R`.
- Reduce the fixed window to 420x286 and verify the final geometry in Chinese light, English light, English dark, and Reduce Motion rendering.

## 2.9.1 - 2026-07-31

- Preserve the accepted three-column telemetry row while removing the header rule, telemetry dividers, shared trace, state nodes, and decorative separators.
- Derive a genuinely transparent monochrome header mark from the real App icon at runtime; retain the full-color artwork for the Dock and Finder.
- Stack the live status directly beneath the product name, with color reserved for meaningful active, working, and warning states.
- Recompose the controls as two side-by-side native macOS switches above one focused fan surface, using system material, neutral selection feedback, and no generic feature symbols.
- Replace the line slider with a deterministic macOS-style track and knob so the visual position always matches the live percentage in native, Rosetta, light, and dark rendering.

## 2.9.0 - 2026-07-31

- Rebuild the main window around one product-specific `signal as trace` gesture: a continuous line links lid running, low power, and fan control as three visible states.
- Remove the generic laptop, leaf, and fan symbols; replace them with precise active, inactive, unavailable, and warning nodes on the shared trace.
- Replace the native pill switches and fan slider with accessible line controls while retaining AppKit state, targets, actions, keyboard behavior, tooltips, and safety logic.
- Refine telemetry as three measured columns with hairline dividers, smaller units, a stronger header rule, and a compact 420x304 fixed canvas.
- Keep the palette monochrome except for meaningful status and thermal warning colors, with deterministic Chinese, English, light, dark, and Reduce Motion rendering.

## 2.8.3 - 2026-07-31

- Rebuild the main window as a compact 420x312 borderless utility instead of a framed settings card.
- Reduce the real App artwork to a quiet 30-point brand mark and place the product name, status dot, and status text on one line.
- Present computer use, charging input, and chip temperature as a precise three-column telemetry row with separate labels and values.
- Remove large active washes and decorative borders; use neutral symbols, native switches, a single accent path, and hairline row separation.
- Tighten mode rows, fan controls, typography, and bottom spacing while preserving every control, warning, tooltip, accessibility label, and behavior.
- Settle disabled-motion control opacity immediately so fan state remains fully legible when Reduce Motion is enabled or deterministic previews are rendered.

## 2.8.2 - 2026-07-31

- Replace the generic header symbol with the real LitRun! App artwork and apply the same continuous rounded mask used by macOS icons.
- Align the status dot and text as one compact status line under the product name, with improved optical centering and active-state depth.
- Refine the header hierarchy, telemetry spacing, settings-button hover, group border, separators, and light/dark surfaces without adding controls or explanatory text.
- Extend the deterministic UI smoke to verify the real color artwork, stable 44-point icon frame, status-group geometry, bilingual layouts, and appearance contrast.

## 2.8.1 - 2026-07-31

- Add a repeatable x86_64 runtime suite that exercises logic, UI, telemetry, scheduling, recovery, and the read-only fan tool without launching the whole App through Rosetta.
- Fix the GitHub Actions artifact path after the product rename so CI uploads `LitRun-*.zip` and its checksum.
- Narrow the privileged power protocol to the three values lid mode actually changes, allowing Intel and Rosetta `pmset` output that omits unrelated legacy keys while preserving exact restoration.
- Upgrade the restricted helper to version 9; legacy snapshot JSON remains readable.

## 2.8.0 - 2026-07-31

- Rename the product to `不熄！` in Chinese and `LitRun!` in English while retaining the existing bundle ID, helper protocol, and recovery state.
- Add a one-time language choice on first launch and an immediate Chinese/English switch in Settings.
- Move the compact status dot and text from the window footer to the left edge directly below the product name.
- Localize the main window, menu bar, settings, telemetry details, safety warnings, recovery messages, and accessibility labels.
- Keep the universal App native on both Apple silicon and Intel; avoid launching the whole App through Rosetta during routine Apple-silicon verification.

## 2.7.0 - 2026-07-30

- Protect the frontmost App's complete process tree and bundle helpers from low-power pauses.
- Make each pause guardian verify process identity before resuming and restore on normal exit, App exit, or termination signals.
- Queue a requested App quit until an in-flight power or fan transition finishes instead of silently ignoring it.
- Recover stale manual-fan sessions before starting a new one and verify every manual/automatic SMC mode change by reading it back.
- Add an independent brightness recovery watchdog so an unexpected exit cannot leave the built-in display at zero after the lid reopens.
- Prefer direct system-load telemetry when available and decode wrapped signed battery current used by some older drivers.
- Re-probe temporarily unavailable lid capability instead of permanently disabling lid mode from one startup sample.
- Make privileged-component upgrades transactional and roll back the previous helper, fan tool, rule, and main sudoers file on failure.
- Upgrade the restricted helper to version 8 and the fan tool to version 3.

## 2.6.10 - 2026-07-30

- Reduce the second-row gap by sizing the power group to its content.
- Align the right edge of the temperature with the visible right edge of computer use.

## 2.6.9 - 2026-07-30

- Keep the power group on the right while aligning the left edges of `电脑用电` and `充电输入`.

## 2.6.8 - 2026-07-30

- Remove the `用` prefix from compact menu-bar power, leaving values such as `23 W`.
- Right-align the main-window computer-use and charging-input text within the header.

## 2.6.7 - 2026-07-30

- Restore the compact menu-bar power line to computer use only, such as `用20 W`.
- Shorten the window label to `充电输入` while retaining total charger-input telemetry.
- Left-align `电脑用电` and `充电输入` on the same leading edge.

## 2.6.6 - 2026-07-29

- Show total charger input into the Mac instead of only the portion entering the battery.
- Label the main-window values as `电脑用电` and `充电器输入`, with no approximation symbol.
- Put charger input beside computer use on the first menu-bar line while retaining the existing temperature and fan lines.
- Move temperature to the far right of the compact secondary row and add total-input, fallback, status-line, and layout checks.

## 2.6.5 - 2026-07-29

- Update the fan percentage continuously while the slider is dragged, then submit only the settled target after a short debounce.
- Show battery charging power separately below computer power in the main window.
- Derive charging power from signed battery current and voltage; show an explicit unavailable or not-charging state instead of reusing adapter input.
- Keep Codex/ChatGPT render and graphics services responsive in low-power mode while their external workers remain eligible for slowing.
- Exclude LidRun Switch's own verification harnesses from low-power pauses.
- Add deterministic charging-power, continuous-slider, percentage-label, and light/dark layout checks.

## 2.6.4 - 2026-07-28

- Preserve and restore the original `SleepDisabled` value instead of always forcing it off, so an existing lid-awake utility is not silently disabled.
- Recover a stale lid session before taking a new snapshot, preventing a helper upgrade from overwriting the only original recovery record.
- Persist brightness recovery state before dimming the built-in display, closing the crash window that could leave brightness at zero without a record.
- Upgrade the restricted helper restore protocol and add exact enabled, disabled, absent-default, malformed, recovery-command, and installer checks.

## 2.6.3 - 2026-07-28

- Put whole-watt power first in the menu-bar stack, followed by temperature and fan speed.
- Match the settings checkboxes and expanded status menu to the same power-temperature-fan order.
- Re-run native arm64 and Rosetta x86_64 logic/UI checks before friend testing.

## 2.6.2 - 2026-07-28

- Round only the menu-bar power value to a whole watt while retaining one decimal place in the main window and detailed telemetry.
- Resolve every custom layer color against the view's effective appearance so light/dark changes cannot leave white text on a stale light background.
- Add a light-to-dark-to-light contrast regression check for the main window.

## 2.6.1 - 2026-07-27

- Probe every required SMC key before enabling manual fan control, avoiding unnecessary authorization on fanless, read-only, or unsupported hardware.
- Support one, two, and more than two readable fans without presenting every Mac as a dual-fan model.
- Disable lid-running on Macs without a detectable clamshell while leaving low-power and available telemetry usable.
- Fail closed before changing power settings when the exact original battery and AC restore values cannot be read.
- Adapt the status-bar canvas and three-line font to 22-30 point menu bars while retaining the preferred 8-point layout on taller screens.
- Verify both universal slices target macOS 13.0 and document feature-level hardware compatibility.
- Test dotted and hyphenated account names plus installer source paths containing spaces or apostrophes.
- Re-verify the extracted release archive, its checksum, signatures, architectures, deployment targets, and executable hashes.

## 2.6.0 - 2026-07-27

- Replace the old single-choice menu-bar mode with independent temperature, power, and fan checkboxes.
- Keep at least one metric visible, persist the selection, migrate legacy preferences, and preserve the canonical temperature-power-fan order.
- Add restrained 160-220 ms motion for window show/hide, active mode feedback, fan automatic/manual transitions, and busy state.
- Restore native yellow-button minimization and native settings-popover animation.
- Respect the macOS Reduce Motion accessibility preference.

## 2.5.14 - 2026-07-27

- Restore normal Dock identity so the running indicator appears and the Dock menu provides `退出`.
- Keep the red window control as a hide action so closing the window does not stop active background work.
- Retain menu-bar `退出软件` as the other explicit safe-exit path.

## 2.5.13 - 2026-07-27

- Shorten compact menu-bar fan units from `RPM` to `R`, such as `3.5k R` and `0 R`.
- Keep exact dual-fan details in the window, menu, and tooltip labeled with the full `RPM` unit.

## 2.5.12 - 2026-07-27

- Put temperature above power and fan in the menu-bar stack.
- Use the same 8-point medium-weight font for all three menu-bar lines.
- Move the stack 1 point higher and reduce baseline spacing from 8.5 to 8 points.
- Move fan control below the two system modes, rename it to `风扇控制`, and show `自动` or `手动` below its switch.

## 2.5.11 - 2026-07-27

- Reduce all three combined menu-bar fonts by another one point.
- Tighten baseline spacing from 9.5 to 8.5 points.
- Anchor the first line 0.5 points higher and use the compressed spacing to give the temperature line more bottom clearance.

## 2.5.10 - 2026-07-27

- Reduce all three combined menu-bar fonts by one point so the temperature line remains fully visible.
- Compensate the explicit baselines so the first line keeps the same visual top position.
- Preserve the wider 9.5-point line spacing and compact `3.5k RPM` format.

## 2.5.9 - 2026-07-27

- Replace AppKit's unreliable multiline title positioning with a dedicated 30-point three-line canvas.
- Reserve explicit top space and lower the complete group so the power line remains fully visible.
- Increase the baseline spacing to 9.5 points for clearly separated power, fan, and temperature lines.
- Shorten compact fan telemetry to one-decimal thousands such as `3.5k RPM`, while preserving exact dual-fan values in the menu.

## 2.5.8 - 2026-07-27

- Increase all three combined menu-bar lines by another two points.
- Move the complete three-line readout visibly lower to use the real menu-bar space more evenly.
- Increase the spacing between all three lines while keeping the stack within the observed menu-bar area.

## 2.5.7 - 2026-07-27

- Keep the combined power, fan, and temperature readout on three centered lines.
- Increase the three-line typography to a visibly more readable size.
- Move the complete three-line group lower while retaining a bounded 22-point layout.

## 2.5.6 - 2026-07-27

- Enlarge all three combined menu-bar lines while keeping their total height below the 22-point status bar.
- Move the three-line baseline slightly lower for improved visual centering.

## 2.5.5 - 2026-07-27

- Fit the combined three-line layout inside the real 22-point macOS status-bar height.
- Use fixed 6.8-point line slots, smaller glyphs, wrapping, and a slight downward baseline adjustment so the first power line remains visible.
- Add a regression check that combined text height never exceeds the active status-bar thickness.

## 2.5.4 - 2026-07-27

- Arrange combined menu-bar telemetry as three centered lines: power, fan RPM, and temperature.
- Add dedicated three-line typography with tighter spacing while preserving readable two-line single modes.
- Update live component checks for exact three-line order and alignment.

## 2.5.3 - 2026-07-27

- Rebalance combined menu-bar telemetry as power plus temperature above fan RPM.
- Remove the approximation symbol from compact menu-bar power while retaining honest detail text.
- Use the system label color on both lines to prevent the selected-state orange shift.
- Tighten two-line typography and add layout-specific regression checks.

## 2.5.2 - 2026-07-27

- Restore automatic fan control at 99°C at every manual fan setting.
- Keep manual adjustment available below 99°C while retaining earlier macOS thermal-state recovery.
- Add boundary tests for 98.9°C, 99°C at 0%, and 99°C at 100%.

## 2.5.1 - 2026-07-27

- Remove the fixed 80°C automatic-fan cutoff so Celsius telemetry no longer blocks manual adjustment.
- Keep automatic restoration when macOS reports elevated thermal state, and retain serious/critical thermal recovery at every manual fan speed.
- Update the low-speed warning, tests, architecture, security notes, and release checklist to match the new policy.

## 2.5.0 - 2026-07-26

- Stack power and a smaller temperature value in the window header.
- Add the smaller temperature as a second line in every menu-bar display mode, without an icon or approximation symbol.
- Make low-power scheduling adaptive: pause high-load background work for 3.5-4.4 seconds per five-second cycle based on reliable power and chip temperature.
- Add single-instance protection so two App processes cannot compete for power or fan control.
- Clarify that the universal Intel build is compile/package verified but still requires physical Intel fan and sensor validation.

## 2.4.0 - 2026-07-26

- Add a compact live chip-temperature readout to the window footer and menu.
- Use the highest readable chip sensor and fall back to macOS thermal state when Celsius telemetry is unavailable.
- Connect the temperature monitor to low-speed fan safety, restoring automatic control at approximately 80°C or elevated system thermal state.
- Keep window tooltips and menu fan details synchronized with the real automatic/manual control mode.

## 2.3.0 - 2026-07-26

- Extend the synchronized manual fan slider to a real 0-100% range.
- Add a critical confirmation before entering the lower half; 0% explicitly requests stopped fans.
- Restore automatic fan control at the first elevated macOS thermal state while running below 50%.
- Upgrade the restricted helper and fan tool to validate zero-RPM targets without widening the fixed privilege boundary.

## 2.2.0 - 2026-07-26

- Hide the window instead of minimizing it, and keep the App as a menu-bar background utility without a Dock icon.
- Add live dual-fan RPM telemetry to the window and menu.
- Add guarded manual fan control with one synchronized 50-100% slider and immediate automatic-mode restoration.
- Restore automatic fan control on disable, normal quit, thermal escalation, failed updates, interrupted sessions, and unexpected App exit.
- Add a gear popover for selecting power, fan, or combined menu-bar readouts.
- Upgrade the restricted helper to install a validated root-owned fan control tool.

## 2.1.0 - 2026-07-25

- Replace the basic window with a refined adaptive AppKit control panel.
- Keep the interface minimal while adding native symbols, stronger hierarchy, hover feedback, and clearer status tones.
- Minimize the window when its red close control is clicked; use the menu-bar command to quit the App.
- Add a UI smoke test and deterministic offscreen rendering path.

## 2.0.3 - 2026-07-22

- Keep the window responsive while lid-mode shutdown and quit recovery run.
- Bound stalled system commands so mode controls cannot remain disabled forever.
- Disable both window and menu-bar mode controls consistently during a transition.
- Add a timeout regression test that proves later commands still work normally.

## 2.0.2 - 2026-07-20

- Fix charging-state power estimates that could still substantially overstate computer use.
- Prefer the system's direct computer-power reading and fall back to adapter input minus real-time battery current and voltage.
- Label unsplittable adapter input honestly instead of presenting it as computer power.
- Add deterministic charging, battery-assist, battery, and fallback telemetry tests.

## 2.0.1 - 2026-07-20

- Replace the detailed window with a compact two-switch interface.
- Keep power details in the menu and tooltip while showing only the short watt value in the window.
- Simplify public and bundled instructions without removing safety or recovery behavior.

## 2.0.0 - 2026-07-20

- Separate lid-running continuity from low-power slow-running.
- Add crash-safe task pause guardians and a lid-session exit recovery watchdog.
- Restore the exact saved power profile instead of rewriting battery sleep to a fixed value.
- Recover interrupted lid sessions on the next launch when the helper is available.
- Move user state to `~/Library/Application Support/LidRunSwitch/` with legacy-file migration.
- Add a complete privileged-component removal path.
- Adopt the public bundle identifier `io.github.achengbatian.lidrunswitch`.
- Add a universal macOS build, tests, release packaging, CI, public documentation, and app icon.
