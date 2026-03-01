import Foundation

enum MIDICCNames {
    static let names: [Int: String] = [
        0: "Bank Select",
        1: "Mod Wheel",
        2: "Breath Controller",
        4: "Foot Controller",
        5: "Portamento Time",
        6: "Data Entry",
        7: "Channel Volume",
        8: "Balance",
        10: "Pan",
        11: "Expression",
        64: "Sustain Pedal",
        65: "Portamento",
        66: "Sostenuto",
        67: "Soft Pedal",
        68: "Legato Footswitch",
        69: "Hold 2",
        71: "Resonance",
        72: "Release",
        73: "Attack",
        74: "Cutoff / Brightness",
        75: "Decay",
        76: "Vibrato Rate",
        77: "Vibrato Depth",
        78: "Vibrato Delay",
        84: "Portamento Control",
        91: "Reverb Send",
        92: "Tremolo Depth",
        93: "Chorus Send",
        94: "Detune Depth",
        95: "Phaser Depth",
        120: "All Sound Off",
        121: "Reset All Controllers",
        123: "All Notes Off"
    ]

    static func displayName(for ccNumber: Int) -> String {
        guard let name = names[ccNumber] else {
            return "CC \(ccNumber)"
        }
        return "CC \(ccNumber) - \(name)"
    }
}
