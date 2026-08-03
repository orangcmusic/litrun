# Privacy

LitRun! works locally on the Mac.

## Data it reads

- Current macOS power settings.
- Local power and battery telemetry exposed by IOKit/IORegistry.
- Local process IDs, CPU use, user IDs, and command paths for slow-lane selection.
- Lid state, thermal state, and built-in display brightness.

## Data it stores

The app stores only recovery information under:

`~/Library/Application Support/LidRunSwitch/`

This includes the power profile needed for restoration, an active-session marker, and temporary brightness recovery state.

## Network use

The app does not make network requests, upload telemetry, create accounts, or include analytics or advertising SDKs.
