//
//  Cards.swift
//  Remedy
//
//  section cards rings and tags
//

import SwiftUI

// MARK: - Extra spacing used by these cards

extension Spacing {
    static let scrollBottom: CGFloat = 32    // space under the last card
}

// MARK: - CardHeader
// the one section header in the app: tinted icon tile, title in sentence case, small detail on the right

// MARK: - InfoRows

// one "Label.. value" line
struct InfoRow: Identifiable {
    let id: String
    let label: String
    let value: String
}

// MARK: - Material with a solid fallback

// shared fill for any translucent surface: material normally, solid card colour with Reduce Transparency or Increase Contrast
struct AdaptiveMaterial<S: Shape>: View {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased {
            shape.fill(Color.cardBackground)
        } else {
            shape.fill(.regularMaterial)
        }
    }
}

// MARK: - Card background

// solid surface with a soft shadow in light and a faint rim in dark
// with Increase Contrast the edge becomes a clear line
struct CardSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color? = nil          // nil = plain card, a colour = tinted fill on top

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let dark = scheme == .dark
        let strong = contrast == .increased
        ZStack {
            shape.fill(Color.surface)
            if let tint { shape.fill(tint) }
        }
        .overlay {
            if strong {
                shape.strokeBorder(Color.ink3, lineWidth: 1.5)
            } else if dark {
                shape.strokeBorder(Color.hairline, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 10, y: 6)
        .shadow(color: .black.opacity(dark ? 0 : 0.04), radius: 1, y: 1)
    }
}

extension View {
    // the layered surface every card uses, a fill colour goes on top of it
    func cardStyle(_ fill: Color? = nil) -> some View {
        background(CardSurface(shape: RoundedRectangle(cornerRadius: Radius.card, style: .continuous), tint: fill.flatMap { $0 == .cardBackground ? nil : $0 }))
    }

    // the one highlighted card look in both looks: the plain card with a soft tone wash and a thin tone edge
    func toneCardStyle(_ tone: Tone) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return background(CardSurface(shape: shape, tint: tone.color.opacity(0.09)))
            .overlay(shape.strokeBorder(tone.color.opacity(0.45), lineWidth: 1.5))
    }

    // the plain card for neutral things, the tone card when it means something
    func cardStyle(tone: Tone, highlighted: Bool = true) -> some View {
        modifier(ToneOrPlainCard(tone: tone, highlighted: highlighted && tone != .neutral))
    }

    // glass for floating things like bars and banners: Liquid Glass, solid with Reduce Transparency
    func glassStyle(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}

// a tinted card for a tone, or a plain one
private struct ToneOrPlainCard: ViewModifier {
    let tone: Tone
    let highlighted: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        content
            .background(CardSurface(shape: shape, tint: highlighted ? tone.color.opacity(0.09) : nil))
            .overlay(shape.strokeBorder(highlighted ? tone.color.opacity(0.45) : Color.clear, lineWidth: 1.5))
    }
}

// liquid glass, or a solid card when reduce transparency is on
private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency || contrast == .increased {
            content
                .background(CardSurface(shape: shape))
        } else {
            content
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        }
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tone.color)
            Text(title)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.insideCard)
        .toneCardStyle(tone)
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

// MARK: - WarningSignList
// each warning sign as a row with its own picture, the same in both looks

// MARK: - BrandFooter
// the app name and motto, quiet, at the end of settings and about

// the remedy name and motto at the bottom of a page
struct BrandFooter: View {
    let motto: String
    var large: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            // the real app icon, not a drawn symbol
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: large ? 64 : 40, height: large ? 64 : 40)
                .clipShape(RoundedRectangle(cornerRadius: large ? 15 : 10, style: .continuous))
                .padding(.bottom, 4)
            Text("Remedy")
                .font(large ? .title3.bold() : .headline)
                .foregroundStyle(.primary)
            Text(motto)
                .font(large ? .body : .footnote)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Remedy. \(motto)")
    }
}
