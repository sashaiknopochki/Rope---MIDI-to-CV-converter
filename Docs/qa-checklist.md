# Rope AUv3 MVP QA Checklist

This checklist is for manual validation of the current MVP in a real host workflow (primarily AUM).

## 1. Build And Load

- Build containing app + extension in Xcode (Debug).
- Launch the containing app once to ensure extension registration.
- Open AUM and add Rope as an instrument.
- Confirm plugin loads without crash.
- Confirm plugin exposes multiple output channels.

Pass criteria:
- AU opens reliably.
- Host shows multi-output routing options.

## 2. Basic Output Routing

- In AUM, route Rope output channels to metering/oscilloscope destinations.
- Verify channels with no active card output are silent (0 DC).
- Verify channels assigned by cards emit a stable DC value.

Pass criteria:
- Unassigned outputs stay silent.
- Assigned outputs reflect card function values.

## 3. Card UI Behavior

- Verify default cards appear (`Gate` and `Pitch` style defaults).
- Add cards up to 16 and verify Add button disables at max.
- Delete cards and verify output assignment is removed/reset.
- Edit each field and verify persistence in UI:
- Source MIDI channel (`All`, `1...16`)
- Function type
- CC number picker visibility only for `CC`
- Hardware output channel

Pass criteria:
- UI stays responsive.
- Every edit updates behavior immediately.

## 4. MIDI Function Validation

For each function below, assign one card to a known output and monitor output value:

- Gate:
- Note on -> high value.
- Note off -> low value.
- Pitch:
- MIDI note changes produce expected stepped CV changes.
- Velocity:
- Low/high velocity differences produce scaled output differences.
- Pitch Bend:
- Center at ~0 offset, bend up/down symmetric behavior.
- Aftertouch:
- Channel pressure changes map to output.
- CC:
- Choose CC number (for example 1 or 74) and move source controller.

Pass criteria:
- Each function maps to expected output change.

## 5. Source MIDI Channel Filtering

- Create separate cards for:
- `All Channels`
- A specific channel (e.g., channel 2)
- Send MIDI on multiple channels and verify:
- Channel-specific card reacts only to its channel.
- All-channel card tracks global/last-event behavior.

Pass criteria:
- Channel filter behavior is correct and deterministic.

## 6. MIDI Input Compatibility

Validate both host/event styles if available:

- Host path delivering MIDI 2.0 UMP (`AURenderEventMIDIEventList`).
- Host/device path delivering MIDI 1.0 byte events (`AURenderEventMIDI`).

Pass criteria:
- Rope responds correctly in both paths (notes + CC + pressure + bend).

## 7. Duplicate Output Assignment

- Assign 2+ cards to the same hardware output.
- Drive multiple values simultaneously.
- Verify summed behavior and output clamp limits.

Pass criteria:
- Output equals combined card value, clamped to `[-1.0, +1.0]`.

## 8. Host State Persistence (Critical Stage 5)

- Configure a non-default card setup (multiple cards, mixed functions, mixed outputs).
- Save AUM session.
- Fully close/reopen AUM and reload session.
- Reopen Rope UI and verify:
- Card list restored correctly.
- All per-card settings restored.
- Output behavior matches pre-save state.

Pass criteria:
- Full state restore works without manual reconfiguration.

## 9. Edge Cases

- Rapid add/remove/edit operations in card list.
- Repeated AU open/close in host session.
- MIDI note-off without matching note-on.
- Very fast CC and pitch bend movement.

Pass criteria:
- No crashes, no stuck UI, no stuck gate in common paths.

## 10. Sign-Off Criteria For MVP POC

MVP is ready for broad use-case testing when:

- Core functions (Gate/Pitch/Velocity/Bend/Aftertouch/CC) are validated.
- Multi-output routing is stable in host.
- Session save/load restoration is reliable.
- Both MIDI event paths (MIDI 1.0 + UMP channel voice) behave correctly.
