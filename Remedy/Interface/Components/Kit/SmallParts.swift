//
//  SmallParts.swift
//  Remedy
//
//  small reusable ui pieces
//

import SwiftUI
import SwiftData

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
            .foregroundStyle(filled ? (tone == .info ? Color.onAccent : Color.white) : tone.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(filled ? tone.color : tone.color.opacity(0.15))
            )
            .accessibilityHidden(true)   // decoration: the text next to it is what VoiceOver reads
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
            .cardStyle()
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            IconTile(symbol: "nosign", tone: .stop)
        }
        SegmentBar(total: 3, filled: 1)
        PaperQuoteCard(quote: "Motrin or Advil (ibuprofen)", source: "Before-surgery papers, page 1")
    }
    .padding()
}

// MARK: - RemedyButtonStyle
// one button look for the classic screens: same height whatever the text size, label wraps inside

// uniform button
struct RemedyButtonStyle: ButtonStyle {
    // primary is the one filled action, secondary is tinted, plain is grey, destructive is call 911
    enum Kind { case primary, secondary, plain, destructive }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
            .padding(.horizontal, 18)
            .foregroundStyle(foreground)
            .background(Capsule(style: .continuous).fill(fill))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .contentShape(Capsule(style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .onAccent
        case .secondary: return .accentInk
        case .plain: return .ink
        case .destructive: return .white
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return .accentFill
        case .secondary: return .accentSoft
        case .plain: return .surface2
        case .destructive: return .emergencyRed
        }
    }
}

// MARK: - SampleDataBanner

// quiet grey tag so nobody mistakes fake data for their own, grey because red means danger
struct SampleDataBanner: View {
    @Query private var plans: [CarePlan]

    // only for sample plans, a real scan never shows it
    private var isShown: Bool {
        SampleDataMark.isShown(plan: plans.first)
    }

    var body: some View {
        if isShown {
            Label(SampleDataMark.text, systemImage: "testtube.2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AdaptiveMaterial(shape: Capsule()))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityLabel(SampleDataMark.text)
        }
    }
}

// where the sample label goes: under the nav title in classic, a small tag at the bottom in simple
private struct SampleDataMark: ViewModifier {
    static let text = "Sample data"

    // the sample data banner shows only for demo data, never on a real scan
    static func isShown(plan: CarePlan?) -> Bool {
        guard LaunchOptions.isSampleData else { return false }
        guard let plan else { return true }
        return plan.isSample
    }

    @Query private var plans: [CarePlan]
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    func body(content: Content) -> some View {
        if look == .classic {
            if Self.isShown(plan: plans.first) {
                content.navigationSubtitle(Self.text)
            } else {
                content
            }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { SampleDataBanner() }
        }
    }
}

extension View {
    // the one place the sample label is added on a main screen
    // off for now, dorron brings it back later: return modifier(SampleDataMark()) again
    func sampleDataFooter() -> some View {
        self
    }
}

