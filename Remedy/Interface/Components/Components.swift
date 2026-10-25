//
//  Components.swift
//  Remedy
//
//  small reusable ui pieces
//

import SwiftUI

// MARK: - IconTile

// symbol in a rounded square
struct IconTile: View {
    let symbol: String
    var tone: Tone = .info
    var size: CGFloat = 32
    // filled = solid colour + white icon
    var filled: Bool = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(filled ? Color.white : tone.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(filled ? tone.color : tone.color.opacity(0.15))
            )
            .accessibilityHidden(true)   // decoration: the text next to it is what VoiceOver reads
    }
}

// MARK: - PillPicture
// many people know their pills by colour and shape not by name

// drawing of the pill
struct PillPicture: View {
    let shape: String
    let color: String
    // the width
    var size: CGFloat = 32

    var body: some View {
        drawing
            .frame(width: size, height: size)       // every pill takes the same space in a list
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var drawing: some View {
        switch shape {
        case "oval":
            Capsule()
                .fill(fillColor)
                .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 1.5))
                .frame(width: size, height: size * 0.56)
        case "capsule":
            // two-tone capsule coloured half + pale half
            HStack(spacing: 0) {
                Rectangle().fill(fillColor)
                Rectangle().fill(fillColor.opacity(0.35))
            }
            .frame(width: size, height: size * 0.46)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.25), lineWidth: 1.5))
        default:
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1.5))
                .frame(width: size * 0.75, height: size * 0.75)
        }
    }

    private var fillColor: Color {
        switch color {
        case "yellow": return Color(red: 0.95, green: 0.83, blue: 0.42)
        case "orange": return Color(red: 0.95, green: 0.63, blue: 0.35)
        case "pink": return Color(red: 0.89, green: 0.42, blue: 0.55)
        case "blue": return Color(red: 0.61, green: 0.76, blue: 0.93)
        default: return Color(white: 0.97)        // white
        }
    }
}

// MARK: - MedicineIcon
// pill picture if we know it otherwise an icon

// pill picture or icon
struct MedicineIcon: View {
    let pillShape: String
    let pillColor: String
    let symbol: String
    var tone: Tone = .neutral
    var size: CGFloat = 32

    var body: some View {
        if pillShape.isEmpty {
            IconTile(symbol: symbol, tone: tone, size: size)
        } else {
            PillPicture(shape: pillShape, color: pillColor, size: size)
        }
    }
}

// MARK: - CheckCircle
// the round dose tick empty teal ring green tick red cross

// tick circle
struct CheckCircle: View {
    let state: DoseSlotState
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(state.color, lineWidth: 2)
                .background(Circle().fill(isFilled ? state.color : Color.clear))
            if let symbol = symbolName {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var isFilled: Bool {
        state == .taken || state == .missed || state == .skipped
    }

    private var symbolName: String? {
        switch state {
        case .taken: return "checkmark"
        case .missed, .skipped: return "xmark"
        case .upcoming, .due: return nil
        }
    }
}

// MARK: - ToneBadge
// "Due now" "in 25 min" "5 h late" in a soft capsule

// coloured circle with a symbol
struct ToneBadge: View {
    let text: String
    var tone: Tone = .info

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tone.color.opacity(0.15)))
            .contentTransition(.numericText())
    }
}

// MARK: - SegmentBar
// "1 of 3" drawn as three little bars with one filled

// row of segments for progress
struct SegmentBar: View {
    let total: Int
    let filled: Int
    var tone: Tone = .info

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { (index: Int) in
                Capsule()
                    .fill(index < filled ? tone.color : Color.tileBackground)
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - PaperQuoteCard
// "FROM your PAPERS" + the exact line + where it is

// quote from the paper and where its from
struct PaperQuoteCard: View {
    let quote: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("From your papers", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("“\(quote)”")
                .font(.subheadline)
                .italic()
                .fixedSize(horizontal: false, vertical: true)   // wrap, never cut off
            Text(source)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card
// a plain rounded card for things that don't need to shrink

// plain card
struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.insideCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color.cardBackground)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            IconTile(symbol: "nosign", tone: .stop)
            PillPicture(shape: "oval", color: "white")
            PillPicture(shape: "round", color: "orange")
            CheckCircle(state: .taken)
            CheckCircle(state: .missed)
            CheckCircle(state: .due)
            ToneBadge(text: "in 25 min")
        }
        SegmentBar(total: 3, filled: 1)
        PaperQuoteCard(quote: "Motrin or Advil (ibuprofen)", source: "Before-surgery papers, page 1")
    }
    .padding()
}

// MARK: - RedactedText

// page text with each blacked out part shown as a dark hidden tag
struct RedactedText: View {
    let text: String

    var body: some View {
        Text(styled)
    }

    // splits on runs of █ so normal words stay normal
    private var styled: AttributedString {
        var result = AttributedString()
        var normal = ""
        var inBlock = false
        for character in text {
            let isBlock = character == "\u{2588}"
            if isBlock && !inBlock {
                result += AttributedString(normal)
                normal = ""
                var tag = AttributedString(" hidden ")
                tag.swiftUI.font = Font.caption.bold()
                tag.swiftUI.foregroundColor = Color(UIColor.systemBackground)
                tag.swiftUI.backgroundColor = Color.primary
                result += tag
            }
            if !isBlock { normal.append(character) }
            inBlock = isBlock
        }
        result += AttributedString(normal)
        return result
    }
}
