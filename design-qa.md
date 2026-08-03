# LitRun! 3.0.0 Build 58 Design QA

final result: passed

## Evidence

- Source visual truth: `design/creative-v6/06-final-tight.png`
- Chinese light implementation: `build/ui-previews/litrun-v300-hoverfix2-zh-light.png`
- English light implementation: `build/ui-previews/litrun-v300-hoverfix2-en-light.png`
- English dark implementation: `build/ui-previews/litrun-v300-hoverfix2-en-dark.png`
- Dark idle hover: `build/ui-previews/litrun-v300-hoverfix2-zh-dark-idle-hover.png`
- User screenshot comparison: `build/ui-previews/litrun-v300-user-hoverfix-comparison.png`
- Header and mode focus: `build/ui-previews/litrun-v300-user-hoverfix-focus.png`
- Viewport: 456x272 logical points at 2x, producing 912x544 images.
- State: lid mode active, low power off, manual fan at 65%, dual-fan sample.

The source includes concept window chrome while the deterministic implementation
capture is the full-size content view. The production window supplies native
traffic lights over the same full-size content area.

## Blocking Review

- P0: none.
- P1: none.
- P2: none.
- Typography matches the approved light native hierarchy. The final pass raises
  the product identity from 16.5pt to 17pt while preserving medium weight.
- Five telemetry columns share equal centers and remain readable in Chinese,
  English, light, and dark appearances.
- Both horizontal separators share exact endpoints. Mode and fan symbols and
  titles share their leading columns.
- The two mode clusters have no center divider, and the fan row reads as one
  continuous control axis.
- Header, metric, mode, fan, and bottom spacing follow the approved compact
  456x272 grid without clipping.
- Mode-row hover surfaces extend past the native switch drawing with a visible,
  complete trailing inset in both clusters.
- The product, status dot, and status label form one tighter optically centered
  header group in idle and active states.

## Accepted Native Drift

- Native `NSSwitch` controls are slightly wider than the generated concept.
- SF Symbols have small outline and optical-width differences from the concept
  illustration.
- These P3 differences preserve native behavior, accessibility, and cross-Mac
  rendering and are not replaced with custom controls.

## Interaction And Accessibility Checks

- Native switches respond to direct and whole-row clicks.
- Slider percentage follows the live value, and the refined track retains the
  native slider control.
- Chinese, English, light, dark, and Reduce Motion states render without clipping.
- Metric titles retain dynamic system colors after appearance changes.
- Accessibility switch roles and labels remain present.

## Residual Physical Checks

- Inspect the installed window on one standard and one short/external menu bar.
- Confirm VoiceOver reading order and keyboard focus rings in the installed App.
