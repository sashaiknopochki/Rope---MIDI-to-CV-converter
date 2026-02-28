# Rope — MIDI-to-CV Converter AUv3 Implementation Plan

## Context

Rope is an AUv3 instrument plugin (`aumu` type) that converts incoming MIDI signals into CV (control voltage) output via DC-coupled audio interfaces like the Expert Sleepers ES-8. The plugin runs in host apps like AUM on iPad. AUM handles all device routing — the plugin just outputs numbered audio channels containing DC voltage values.

Currently the plugin builds, loads in AUM, and outputs silence. All infrastructure (MIDI event delivery, audio render loop, parameter system, SwiftUI UI) is wired but stubbed. This plan adds the actual MIDI-to-CV functionality in stages.

---

## Stage 1: Multi-Channel Audio Output

**Goal:** Change from 2-channel stereo to 16-channel output. Verify it loads in AUM.

**Files to modify:**
- `Rope___MIDI_to_CV_converterExtensionAudioUnit.swift` — Change `AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)` to `channels: 16`. Change `maximumChannelCount` to 16.
- `SimplePlayEngine.swift` (containing app) — Change the `stereoFormat` connection (line ~299) to 16 channels so the standalone app also works with multi-channel.

**No kernel changes needed** — `process()` already iterates `outputBufferList->mNumberBuffers` generically.

**Verify:** Build → run containing app → AU loads without crash. Load in AUM → should appear with multiple output channels available for routing.

---

## Stage 2: MIDI Input Parsing

**Goal:** Parse MIDI 2.0 UMP messages in the C++ kernel. Store current MIDI state. Output a hardcoded Gate (ch1) + Pitch (ch2) to prove it works.

**File to modify:** `Rope___MIDI_to_CV_converterExtensionDSPKernel.hpp`

**Add MIDI state members:**
```cpp
bool mGateOn = false;
uint8_t mCurrentNote = 60;
uint8_t mCurrentVelocity = 0;
int16_t mPitchBend = 0;         // -8192..+8191
uint8_t mAftertouch = 0;        // channel pressure
uint8_t mCCValues[128] = {};    // all 128 CC values
```

**Implement `handleMIDIEventList()`** using the `MIDIEventListForEachEvent` visitor pattern (already shown in commented template code). Parse `kMIDICVStatusNoteOn`, `kMIDICVStatusNoteOff`, `kMIDICVStatusPitchBend`, `kMIDICVStatusChannelPressure`, `kMIDICVStatusControlChange`.

**Note:** Verify exact field names in `<CoreMIDI/MIDIMessages.h>` for `MIDIUniversalMessage.channelVoice2` — they may vary across SDK versions.

**Hardcode test output in `process()`:**
- Channel 0: Gate — `1.0` when note on, `0.0` when note off
- Channel 1: Pitch (1V/oct) — `(mCurrentNote - 60) / 120.0f`

**CV Math Reference:**
| Function | Sample Value Formula | Example |
|----------|-------------------|---------|
| Gate | `noteOn ? 1.0 : 0.0` | 1.0 = +10V gate |
| Pitch 1V/oct | `(note - 60) / 120.0` | note 72 → 0.1 → 1V |
| Velocity | `velocity / 127.0` | vel 127 → 1.0 → 10V |
| Pitch Bend | `pitchBend / 8192.0` | center = 0V |
| Aftertouch | `aftertouch / 127.0` | 127 → 1.0 → 10V |
| MIDI CC | `ccValue / 127.0` | CC 127 → 1.0 → 10V |

**Verify:** Send MIDI notes from a sequencer in AUM → channel 1 outputs gate, channel 2 outputs pitch CV. Monitor with oscilloscope or route to ES-8.

---

## Stage 3: Channel Configuration System

**Goal:** Replace hardcoded channel assignments with a configurable system using AU parameters.

**Architecture decision:** Use a fixed pool of AU parameter addresses. 16 "function type" params (addresses 0–15) + 16 "CC number" params (addresses 100–115). This reuses existing `setParameter`/`getParameter` infrastructure without custom synchronization.

Function type encoding: `0=Off, 1=Gate, 2=Pitch, 3=Velocity, 4=PitchBend, 5=Aftertouch, 6=CC`

**Files to modify:**
- `Rope___MIDI_to_CV_converterExtensionParameterAddresses.h` — Replace old enum with 32 addresses (or use raw address ranges without named enum entries).
- `Rope___MIDI_to_CV_converterExtensionDSPKernel.hpp` — Add `mChannelFunctions[16]` and `mChannelCCNumbers[16]` arrays. Update `setParameter()`/`getParameter()`. Replace hardcoded `process()` with `cvValueForChannel(ch)` dispatch.
- `Parameters.swift` — Build parameter tree with 32 parameters. May need to bypass the DSL and use `AUParameterTree.createTree(withChildren:)` directly if the `@resultBuilder` is awkward for this many params.

**Verify:** Hardcode a config in `initialize()`, confirm correct CV output per channel.

---

## Stage 4: SwiftUI Card List UI

**Goal:** Build the user-facing card management interface.

**New files to create:**
- `UI/OutputCardView.swift` — Single card with function picker, CC number picker (when CC selected), output channel picker (1–16), delete button.
- `UI/OutputCardListModel.swift` — `@Observable` model holding `[OutputCard]` array. Methods: `addCard()`, `removeCard()`, `pushConfigToKernel()`. The model pushes card config to the kernel via parameter tree.
- `Common/Data/MIDICCNames.swift` — Static dictionary of CC numbers to human-readable names.

**Files to modify:**
- `Rope___MIDI_to_CV_converterExtensionMainView.swift` — Replace slider+button UI with card list + "Add Output Channel" button.
- `Common/UI/AudioUnitViewController.swift` — Create `OutputCardListModel`, connect it to the audio unit, pass to SwiftUI view.

**MIDI CC names for the picker (partial list):**
1=Mod Wheel, 2=Breath Controller, 4=Foot Pedal, 5=Portamento Time, 7=Volume, 10=Pan, 11=Expression, 64=Sustain, 65=Portamento, 71=Resonance, 72=Release, 73=Attack, 74=Cutoff/Brightness, etc.

**Verify:** Add/remove cards in the UI. Assign functions and channels. Send MIDI → correct CV on assigned channels.

---

## Stage 5: State Persistence

**Goal:** Save/restore card configuration when host saves/loads sessions.

**File to modify:** `Rope___MIDI_to_CV_converterExtensionAudioUnit.swift`

Override `fullState` getter/setter:
- **Getter:** Encode `[OutputCard]` as JSON, store in state dictionary under a custom key.
- **Setter:** Decode JSON, restore cards into model, push config to kernel.

`OutputCard` is already `Codable` (designed in Stage 4).

**Important:** `fullState` setter may be called before the view loads. Store restored cards in the audio unit; the view controller reads them when creating the model.

**Verify:** In AUM: configure cards → save session → reload → cards restored with correct CV output.

---

## Stage 6: Cleanup & Polish

- Remove old `ParameterSlider.swift`, `MomentaryButton.swift`, `sendNote`/`midiNoteNumber` remnants
- Prevent duplicate channel assignments (filter available channels in picker, or allow with last-write-wins)
- Handle hosts that allocate fewer than 16 channels gracefully (UI warning)
- Compact card layout for AUM's limited AU window size
- Optional: drag-to-reorder cards, color-coded function types

---

## Key Files Reference

| File | Role |
|------|------|
| `DSP/Rope___MIDI_to_CV_converterExtensionDSPKernel.hpp` | MIDI parsing, CV generation, render-thread processing |
| `Common/Audio Unit/Rope___MIDI_to_CV_converterExtensionAudioUnit.swift` | Multi-channel bus setup, parameter tree, state persistence |
| `Parameters/Rope___MIDI_to_CV_converterExtensionParameterAddresses.h` | Parameter address enum |
| `Parameters/Parameters.swift` | Parameter tree specification |
| `UI/Rope___MIDI_to_CV_converterExtensionMainView.swift` | Main SwiftUI view (card list) |
| `Common/UI/AudioUnitViewController.swift` | AUViewController, creates AU + connects SwiftUI |
| `Common/UI/ObservableAUParameter.swift` | Observable parameter wrapper (reuse existing) |
| `Common/Parameters/ParameterSpecBase.swift` | Parameter tree DSL (reuse or bypass) |

## Risks

1. **16-channel output in AUM** — AUM supports multi-output instruments but needs testing early (Stage 1). May need to override `channelCapabilities`.
2. **MIDI 2.0 UMP field names** — Verify against actual Xcode 26 SDK `<CoreMIDI/MIDIMessages.h>` headers. The template's commented visitor pattern is the starting point.
3. **Parameter tree DSL for 32 params** — The `@resultBuilder` may not handle 32 params cleanly. Fallback: build `AUParameterTree` manually.
