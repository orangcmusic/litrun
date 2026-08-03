# Compatibility

## Baseline

- macOS 13 or later.
- One universal download containing native `arm64` and `x86_64` executables.
- No network account, cloud service, Rosetta requirement, or background installer.

On Apple silicon, macOS selects the native ARM64 slice. Intel compatibility is retained for Intel Macs, but routine Apple-silicon validation does not force the whole App to launch through Rosetta because doing so can trigger macOS's Intel-app retirement notice even though the normal process is native.

## Feature availability

| Mac type | Low power | Lid running | Fan control | Power reading |
| --- | --- | --- | --- | --- |
| Apple Silicon MacBook with controllable fans | Yes | Yes | Enabled only after a read-only capability probe | Usually available |
| Fanless MacBook Air | Yes | Yes | Disabled | Usually available |
| Intel MacBook | x86_64 logic and scheduling verified; physical test pending | Available when a lid is detected; physical test pending | Enabled only when all required SMC keys are readable; physical validation pending | Hardware-dependent |
| Mac mini, iMac, Mac Studio, Mac Pro | Yes | Disabled because no lid is present | Hardware-dependent | May be unavailable without a battery sensor |

Temperature falls back to the macOS thermal state when a reliable Celsius sensor is unavailable. Missing computer-use or total charger-input telemetry displays an unavailable value and is not fabricated. Computer use prefers direct system-load telemetry, then uses normalized signed battery current and voltage to separate charging when needed; older drivers that expose wrapped 32-bit negative current are decoded explicitly. The low-power scheduler can still use temperature and system thermal state.

The status item measures the active menu-bar screen and adapts its one- to three-row vertical two-column grid between 22 and 30 points. One and two selected metrics use larger 12pt and 10pt text; four use 9pt text with a tighter middle gap, while five and six retain the existing three-row typography and spacing. The default five metrics use a centered 3+2 column split; enabling network speed uses a balanced 3+3 split. With no selected metrics, the status item is hidden and the window gear can restore it.

## Verification levels

- Apple Silicon: live verified on the development M1 Pro Mac.
- Intel: x86_64 logic, UI, scheduling, recovery, read-only telemetry, and sparse power-snapshot paths run through Rosetta; both slices package, sign, and declare macOS 13.0. Physical Intel fan, temperature, power, and lid behavior remains pending.
- Fanless and desktop behavior: deterministic capability and UI paths are tested; representative physical Macs remain release gates.

## Distribution

The current public ZIP and drag-to-Applications DMG are ad-hoc signed. They are suitable for technical testing, but a smooth download-and-open experience for unrelated users requires the maintainer's Apple Developer ID signing, hardened runtime, Apple notarization, and stapling. Do not describe the current artifacts as fully verified for every Mac until the physical checks in `RELEASE_CHECKLIST.md` pass.
