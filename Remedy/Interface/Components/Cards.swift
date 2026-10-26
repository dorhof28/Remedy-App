//
//  Cards.swift
//  Remedy
//
//  section cards rings and tags
//

import SwiftUI

// MARK: - Extra spacing used by these cards

extension Spacing {
    static let rowVertical: CGFloat = 12     // top/bottom padding of a row inside a card
    static let scrollBottom: CGFloat = 32    // space under the last card
}

// MARK: - SectionCard

// card that folds
struct SectionCard<Content: View>: View {

    let title: String
    let symbol: String
    let detail: String          // small text on the right ("2", "1 of 3 taken"); "" = none
    let tone: Tone              // .neutral = grey header, .stop = red header...
    let collapsible: Bool
    let content: Content

    // open or folded
    @AppStorage private var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // rememberAs give each card its own key so it stays folded next time
    init(title: String,
         symbol: String,
         detail: String = "",
         tone: Tone = .neutral,
         collapsible: Bool = true,
         startsExpanded: Bool = true,
         rememberAs key: String,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.detail = detail
        self.tone = tone
        self.collapsible = collapsible
        self.content = content()
        self._isExpanded = AppStorage(wrappedValue: startsExpanded, "card." + key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if collapsible {
                Button {
                    Motion.perform(reduceMotion) { isExpanded.toggle() }
                } label: {
                    header
                }
                .buttonStyle(.plain)
                .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
                .accessibilityValue(isExpanded ? "Open" : "Closed")
                .accessibilityHint(isExpanded ? "Folds this section" : "Shows this section")
            } else {
                header
            }

            // folded = only the header shows
            if isExpanded || !collapsible {
                Divider()
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.insideCard)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.cardBackground)
        )
    }

    // icon + title + detail + chevron
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
                .textCase(.uppercase)
            Spacer(minLength: 8)
            if !detail.isEmpty {
                Text(detail)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            if collapsible {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.inactive)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(tone.color)
        .frame(minHeight: 24)
        .contentShape(Rectangle())      // the whole header row is tappable
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - ProgressRing (0...1)

// progress circle
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 4
    var tone: Tone = .info

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tileBackground, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tone.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))      // start at 12 o'clock
        }
        .accessibilityHidden(true)
    }
}

// MARK: - StatusTag

// small coloured tag
struct StatusTag: View {
    let text: String
    let symbol: String
    var tone: Tone = .info

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tone.color.opacity(0.14)))
    }
}

// MARK: - InfoRows

// one "Label.. value" line
struct InfoRow: Identifiable {
    let id: String
    let label: String
    let value: String
}

// label and value rows
struct InfoRows: View {
    let rows: [InfoRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                if row.id != rows.first?.id {
                    Divider()
                }
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 104, alignment: .leading)
                    Text(row.value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.subheadline)
                .padding(.vertical, Spacing.rowVertical)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - CardFootnote

// small text under a card
struct CardFootnote: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }
}

// MARK: - DateTile

// month and day tile
struct DateTile: View {
    let month: String       // "OCT"
    let day: String         // "24"
    let weekday: String     // "Fri"
    var size: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            Text(month)
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
            Text(day)
                .font(.system(size: size * 0.45, weight: .semibold))
            Text(weekday)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: size)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.tileBackground)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - BulletList

// simple bullet list
struct BulletList: View {
    let items: [String]
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.self) { text in
                Label {
                    Text(text)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(Color.remedyTeal)
                }
            }
        }
        .padding(.vertical, 14)
    }
}

// MARK: - CallButton (opens the Phone app; does nothing in the Simulator)

// opens the phone app
struct CallButton: View {
    let title: String
    let phoneURL: URL?
    var prominent: Bool = false

    var body: some View {
        if let phoneURL {
            if prominent {
                Link(destination: phoneURL) { label }
                    .buttonStyle(.glassProminent)
            } else {
                Link(destination: phoneURL) { label }
                    .buttonStyle(.glass)
            }
        }
    }

    private var label: some View {
        Label(title, systemImage: "phone.fill")
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Card background

extension View {
    // the rounded fill every card uses
    func cardStyle(_ fill: Color = .cardBackground) -> some View {
        background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(fill))
    }
}

// MARK: - TopCard

// big card at the top of a screen
struct TopCard<Icon: View>: View {
    let title: String
    var subtitle: String = ""
    var caption: String = ""
    let icon: Icon

    init(title: String, subtitle: String = "", caption: String = "", @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.caption = caption
        self.icon = icon()
    }

    var body: some View {
        VStack(spacing: 10) {
            icon
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.remedyTeal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - CardEyebrow (⛔ STOP TODAY)

// small coloured label above a title
struct CardEyebrow: View {
    let text: String
    let symbol: String
    var tone: Tone = .info

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tone.color)
            .textCase(.uppercase)
    }
}

// MARK: - ToneBox

// coloured box with a title and text
struct ToneBox: View {
    let eyebrow: String
    let title: String
    var tone: Tone = .info

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tone.color)
            Text(title)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.insideCard)
        .cardStyle(tone.color.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - StatTile

// small number tile
struct StatTile: View {
    let title: String
    let value: String
    let caption: String
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .textCase(.uppercase)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .contentTransition(.numericText())
            if let progress {
                ProgressView(value: progress)
                    .tint(Color.remedyTeal)
            }
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.insideCard)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chevron (›)

// the > arrow
struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inactive)
            .accessibilityHidden(true)
    }
}

// MARK: - IconRow

// icon title and detail row
struct IconRow: View {
    let symbol: String
    var tone: Tone = .info
    let title: String
    var subtitle: String = ""
    var showsChevron: Bool = false
    var iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tone: tone, size: iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            if showsChevron { Chevron() }
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - DividedList
// rows with a hairline between them

// list with dividers
struct DividedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var inset: CGFloat = 0          // how far the hairline starts from the left
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                if item.id != items.first?.id {
                    Divider().padding(.leading, inset)
                }
                row(item)
            }
        }
    }
}
