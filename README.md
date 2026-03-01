# Rope - MIDI to CV converter

Rope is an AUv3 instrument plugin for iOS/iPadOS that converts incoming MIDI into DC-coupled CV audio signals.  
It is designed to run inside hosts like AUM and route CV to hardware outputs (for example Expert Sleepers ES-8 style workflows).

## What The Plugin Does

- Receives MIDI from the host.
- Converts MIDI performance/control data into normalized CV values.
- Emits CV on up to 16 plugin output channels.
- Lets users assign each output channel via a card-based configuration UI.
- Supports saving/restoring configuration via host state (session/preset restore path).

## Current MVP Functionalities

- AUv3 instrument extension (`aumu`) with multi-output bus.
- 16-channel audio output configured with a discrete channel layout.
- MIDI parsing in DSP for:
- MIDI 2.0 UMP Channel Voice events (`AURenderEventMIDIEventList`).
- MIDI 1.0 byte-stream events (`AURenderEventMIDI`) for host compatibility.
- Configurable output cards with:
- Source MIDI channel (`All` or channel `1...16`).
- Function type: `Off`, `Gate`, `Pitch`, `Velocity`, `Pitch Bend`, `Aftertouch`, `CC`.
- CC number (`0...127`) when `CC` function is selected.
- Target hardware output channel (`1...16`).
- Runtime behavior:
- Duplicate target outputs are allowed.
- Multiple cards targeting the same output are summed and clamped to `[-1.0, +1.0]`.
- "All channels" behavior follows last-event tracking.
- Host state persistence:
- Output cards are encoded as JSON in `fullState`.
- State is restored even if host restore happens before UI creation.

## CV Mapping

- Gate: `0.0` (off) or `1.0` (on)
- Pitch (1V/oct scaling reference): `(note - 60) / 120.0`
- Velocity: `velocity / 127.0`
- Pitch Bend: `bend / 8192.0`
- Aftertouch: `pressure / 127.0`
- CC: `ccValue / 127.0`

These normalized values are intended for DC-coupled outputs where host/hardware scaling maps audio sample values to physical voltage ranges.

## Engineering Decisions

- DSP in C++ (`Rope___MIDI_to_CV_converterExtensionDSPKernel.hpp`)
- Keeps real-time processing in a predictable, allocation-free path.
- Single shared kernel state for MIDI + card routing.
- Swift/SwiftUI for AU integration and UI
- `AUAudioUnit` handles bus config, parameter tree integration, and host state.
- SwiftUI card UI prioritizes quick mapping edits in small AU windows.
- Parameter-driven card configuration
- Card settings are written through `AUParameterTree`, keeping UI and DSP in sync through existing AU parameter plumbing.
- Multi-output architecture
- 16 discrete outputs from the AU bus so hosts can route each CV lane independently.
- Host state strategy
- Card list is serialized in `fullState` for robust session restore independent of UI timing.
- Compatibility-first MIDI ingest
- Supports both UMP Channel Voice 2 and MIDI 1.0 event types to avoid host-specific blind spots.
- Monophonic-first behavior for MVP
- Last-note/all-channel behavior is intentionally simple for initial validation.
- Polyphonic voice allocation/stealing is planned as a later stage.

## Project Structure

- `Docs/implementation-plan.md` - staged implementation roadmap.
- `Docs/qa-checklist.md` - manual QA pass for MVP validation.
- `Rope - MIDI to CV converter/...Extension/DSP` - real-time MIDI/CV processing kernel.
- `Rope - MIDI to CV converter/...Extension/Parameters` - AU parameter addresses + tree.
- `Rope - MIDI to CV converter/...Extension/UI` - SwiftUI configuration UI.
- `Rope - MIDI to CV converter/...Extension/Common/Audio Unit` - AUAudioUnit integration and persistence.

## Known MVP Constraints

- Designed around monophonic/last-note behavior for now.
- No advanced polyphonic voice management yet.
- UI currently allows duplicate output assignment by design (sum+clamp behavior).
- Real-world validation should be done in host (AUM) with hardware routing.
