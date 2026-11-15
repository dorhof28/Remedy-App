//
//  SimpleComponents.swift
//  Remedy
//
//  pieces only the simple look uses
//

import SwiftUI
import SwiftData

// MARK: - SimpleScreen
// big back top left, read to me top right, big title, content that scrolls only when it has to

// every simple page: big title, back, read aloud and one column
struct SimpleScreen<Content: View, Trailing: View>: View {
    let title: String
    var showsBack: Bool = true
    // what read to me says after the title
    var readAloud: String = ""
    // title sits between back and read to me to save space
    var inlineTitle: Bool = false
    let content: Content
    let trailing: Trailing

    @Environment(\.dismiss) private var dismiss

    init(title: String, showsBack: Bool = true, readAloud: String = "", inlineTitle: Bool = false,
         @ViewBuilder content: () -> Content, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.inlineTitle = inlineTitle
        self.showsBack = showsBack
        self.readAloud = readAloud
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        SimpleFitScroll {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                SimpleTopBar(showsBack: showsBack, title: inlineTitle ? title : nil, spoken: spoken, onBack: { dismiss() }) { trailing }

                if !title.isEmpty && !inlineTitle {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                }

                content
            }
            .padding(.horizontal, Spacing.simpleEdge)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .remedyBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onDisappear { Speaker.stop() }
    }

    // no read aloud button when the page gives nothing to read, like screens 80 to 83
    private var spoken: String {
        readAloud.isEmpty ? "" : [title, readAloud].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

extension SimpleScreen where Trailing == EmptyView {
    init(title: String, showsBack: Bool = true, readAloud: String = "", inlineTitle: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(title: title, showsBack: showsBack, readAloud: readAloud, inlineTitle: inlineTitle, content: content) { EmptyView() }
    }
}

// MARK: - SimpleTopBar

// back on the left, anything extra and read to me on the right
struct SimpleTopBar<Trailing: View>: View {
    var showsBack = true
    var backTitle = "Back"
    // a title here sits between back and read to me, very big text puts it on its own row
    var title: String? = nil
    let spoken: String
    var onBack: () -> Void = {}
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: Spacing.betweenCards) {
            HStack(spacing: 10) {
                if showsBack {
                    SimpleBackPill(title: backTitle, action: onBack)
                }
                if let title, !stacked {
                    titleText(title)
                } else {
                    Spacer(minLength: 0)
                }
                trailing
                if !spoken.isEmpty { SimpleReadToMeButton(text: spoken) }
            }
            if let title, stacked { titleText(title) }
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .font(.largeTitle.bold())
            .foregroundStyle(Color.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: stacked ? .leading : .center)
            .accessibilityAddTraits(.isHeader)
    }

    private var stacked: Bool { typeSize.isAccessibilitySize }
}

extension SimpleTopBar where Trailing == EmptyView {
    init(showsBack: Bool = true, backTitle: String = "Back", title: String? = nil, spoken: String, onBack: @escaping () -> Void = {}) {
        self.init(showsBack: showsBack, backTitle: backTitle, title: title, spoken: spoken, onBack: onBack) { EmptyView() }
    }
}

// MARK: - SimpleBackPill

// big back capsule on glass, accent chevron and word so it reads as active
struct SimpleBackPill: View {
    let title: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 56

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentInk)
                .padding(.horizontal, 20)
                .frame(minHeight: max(height, 56))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .glassStyle(cornerRadius: 40)
        .accessibilityLabel(title)
    }
}

// MARK: - Read to me

// 56pt glass circle, reads the screen, tap again to stop
struct SimpleReadToMeButton: View {
    let text: String
    var size: CGFloat = 56

    private var speaker: SpeakerState { Speaker.state }

    var body: some View {
        Button {
            Speaker.toggle(text)
        } label: {
            Image(systemName: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.ink)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassStyle(cornerRadius: size / 2)
        .accessibilityLabel(speaker.isSpeaking ? "Stop reading" : "Read to me")
        .accessibilityHint("Reads this screen out loud.")
    }
}

// MARK: - FitOrScroll
// still when it fits scrolls when it doesnt

// fits on screen when it can, scrolls when it cannot
struct FitOrScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            ScrollView {
                content
            }
        }
    }
}

// MARK: - SimplePagedList
// simple lists scroll now, so this is one plain list of big rows

// a long list a few rows at a time with next and back
struct SimplePagedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    // kept so callers still compile, lists no longer turn pages
    var perPage: Int = 4
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: Spacing.betweenCards) {
            ForEach(items) { item in
                row(item)
            }
        }
    }
}

// "More ›" with the arrow after the word
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - SimpleSectionTitle

// small calm header over a group of big rows, like "After that"
struct SimpleSectionTitle: View {
    let title: String
    var tone: Tone = .neutral
    var symbol: String = ""
    var count: String = ""

    var body: some View {
        HStack(spacing: 10) {
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            if !count.isEmpty { CountPill(text: count, tone: tone) }
        }
        .padding(.top, Spacing.sectionGap - Spacing.betweenCards)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - SimpleRowCard

// big tappable row: icon, title, one line under it, a chevron
struct SimpleRowCard<Icon: View>: View {
    let title: String
    var subtitle: String = ""
    var status: String = ""
    var tone: Tone = .neutral
    var showsChevron: Bool = true
    let icon: Icon

    init(title: String, subtitle: String = "", status: String = "", tone: Tone = .neutral,
         showsChevron: Bool = true, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.tone = tone
        self.showsChevron = showsChevron
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 16) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(SimpleWording.plain(title))
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !SimpleWording.plain(subtitle).isEmpty {
                    DetailLine(text: SimpleWording.plain(subtitle), tone: status.isEmpty ? tone : .neutral, font: .body)
                        .multilineTextAlignment(.leading)
                }
                if !SimpleWording.plain(status).isEmpty {
                    Text(SimpleWording.plain(status))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple + 16, alignment: .leading)
        .simpleCardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - SimpleButtonStyle

// big capsule button, 64pt
struct SimpleButtonStyle: ButtonStyle {
    // primary the one filled action, secondary tinted, plain white on a card, gray on the page, danger red
    enum Kind { case primary, secondary, plain, gray, danger }

    var kind: Kind = .primary
    var height: CGFloat = Spacing.tapSimple

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .background {
                let shape = Capsule(style: .continuous)
                if kind == .plain {
                    CardSurface(shape: shape)
                } else {
                    shape.fill(fill)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    // red stays white text in dark mode too
    private var foreground: Color {
        switch kind {
        case .primary: return .onAccent
        case .secondary: return .accentInk
        case .plain, .gray: return .ink
        case .danger: return .white
        }
    }

    private var fill: Color {
        switch kind {
        case .primary: return .accentFill
        case .secondary: return .accentSoft
        case .plain: return .clear
        case .gray: return .surface2
        case .danger: return .emergencyRed
        }
    }
}

// MARK: - Simple card

extension View {
    // simple's big cards: the plain card surface with the large corner
    func simpleCardStyle(_ fill: Color? = nil) -> some View {
        background(CardSurface(shape: RoundedRectangle(cornerRadius: Radius.large, style: .continuous), tint: fill))
    }

    // a tinted big card with an optional edge, like do this now or do this first
    func simpleToneCard(_ fill: Color, edge: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        return background(shape.fill(fill))
            .overlay {
                if let edge { shape.strokeBorder(edge, lineWidth: 2) }
            }
    }
}

// MARK: - ReadAloudButton

// a wide read this to me button, the round one is SimpleReadToMeButton
struct ReadAloudButton: View {
    var title: String = "Read this to me"
    let text: String

    var body: some View {
        Button {
            Speaker.toggle(text)
        } label: {
            Label(Speaker.state.isSpeaking ? "Stop reading" : title,
                  systemImage: Speaker.state.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
        }
        .buttonStyle(SimpleButtonStyle(kind: .gray, height: 56))
        .accessibilityHint("Reads the screen out loud. Tap again to stop.")
    }
}

// MARK: - SimplePaperCheckCard
// moved to Components/MedicinesKit.swift

