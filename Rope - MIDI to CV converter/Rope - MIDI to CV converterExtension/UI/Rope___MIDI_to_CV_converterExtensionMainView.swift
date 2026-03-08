//___FILEHEADER___

import SwiftUI

struct Rope___MIDI_to_CV_converterExtensionMainView: View {
    @ObservedObject var model: OutputCardListModel

    private let gold = Color(red: 201.0 / 255.0, green: 162.0 / 255.0, blue: 39.0 / 255.0)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    titleRow
                    contentPanel
                    footer
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("rope")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text("MIDI to CV Converter")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(gold)
        }
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 32) {
            outputHeader
            Group {
                switch model.hostOutputState {
                case .none:
                    OutputDisabledMessageCardView(
                        message: "Select a hardware output in the host application."
                    )
                case .single, .stereo:
                    cardContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(gold, lineWidth: 1)
        )
    }

    private var outputHeader: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(gold.opacity(0))
                .frame(height: 1)
            outputMarker(label: "A")
            Rectangle()
                .fill(gold)
                .frame(height: 1)
            Text("OUTPUT")
                .font(.system(size: 15, weight: .regular))
                .tracking(0.9)
                .foregroundStyle(gold)
            Rectangle()
                .fill(gold)
                .frame(height: 1)
            outputMarker(label: "B")
            Rectangle()
                .fill(gold.opacity(0))
                .frame(height: 1)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
    }

    private func outputMarker(label: String) -> some View {
        ZStack {
            Circle()
                .fill(gold)
                .frame(width: 32, height: 32)
            Text(label)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.black)
        }
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: 24) {
            cardSlot(for: 0)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            cardSlot(for: 1)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 8)
        .overlay(alignment: .center) {
            Rectangle()
                .fill(gold)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
    }

    private var footer: some View {
        Text("Grace Scale Devices")
            .font(.system(size: 15, weight: .regular))
            .tracking(0.9)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func cardSlot(for slotIndex: Int) -> some View {
        if model.hostOutputState == .single && slotIndex == 1 {
            OutputDisabledMessageCardView(
                message: "Select a second hardware output in the host application to enable this output."
            )
        } else if let card = model.cards.first(where: { $0.slotIndex == slotIndex }) {
            OutputCardView(card: card, onChange: model.updateCard)
        } else {
            EmptyView()
        }
    }
}
