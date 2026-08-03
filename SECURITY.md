# Security Policy

## Privileged component

The root-owned helper is installed at:

`/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-helper`

Its validated fan tool is installed at:

`/Library/PrivilegedHelperTools/io.github.achengbatian.lidrunswitch-fanctl`

The shell helper accepts only fixed power commands and validated fan targets from 0 to 10000 RPM. The fan tool independently rejects invalid values and clamps every accepted target to that fan's reported hardware maximum. The UI requires an explicit warning confirmation below 50%. Every manual speed returns to automatic control at 99°C; low-speed mode also returns to automatic control when macOS reports elevated thermal state. The root-owned `0440` sudoers rule grants the installing user access only to the fixed shell helper path.

Installation compares SHA-256 hashes before and after copying both embedded components, validates the rule with `visudo`, and proves passwordless helper status. Upgrades first back up the existing helper, fan tool, rule, and main sudoers state; any failed step restores the previous installation. Manual and automatic fan changes are accepted only after every detected mode key reads back the requested state. These runtime checks detect copy corruption, incomplete installation, and rejected SMC mode changes; they do not prove who published the downloaded App. Publisher authenticity for a public release requires Developer ID signing, hardened runtime, Apple notarization, and stapling. Removal returns every fan to automatic mode before deleting the privileged files.

## Reporting

Do not publish exploit details in an issue. Ask the maintainer for a private contact channel and share only the affected version and high-level impact publicly.

Security fixes target the latest release.
