//
//  SimpleComponents.swift
//  Remedy
//
//  pieces only the simple look uses
//

import SwiftUI

// MARK: - SimpleScreen
// designed to fit on one screen

// big back button title and content
struct SimpleScreen<Content: View>: View {
    let title: String
    var showsBack: Bool = true
    let content: Content

    @Environment(\.dismiss) private var dismiss

    init(title: String, showsBack: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.showsBack = showsBack
        self.content = content()
    }

    var body: some View {
        FitOrScroll {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                if showsBack {
                    Button {
                        dismiss()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.title3.bold())
                            .padding(.horizontal, 20)
                            .frame(minHeight: 52)
                            .background(Capsule().fill(Color.cardBackground))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.remedyTeal)
                }

                if !title.isEmpty {
                    Text(title)
                        .font(.largeTitle.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                }

                content
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - FitOrScroll
// still screen when it fits scrolls when it cant

// still when it fits scrolls when it doesnt
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
// a list that turns pages instead of scrolling

// list split into pages
struct SimplePagedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var perPage: Int = 4
    @ViewBuilder let row: (Item) -> Row

    // UI only which page shows
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let paging = Paging(count: items.count, perPage: perPage, page: page)
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                ForEach(items[paging.range]) { item in
                    row(item)
                }
            }
            .id(paging.page)
            .transition(.push(from: .trailing))

            Spacer(minLength: 0)

            if paging.showsButtons {
                HStack(spacing: 12) {
                    Button {
                        Motion.perform(reduceMotion) { page = paging.page - 1 }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                    .disabled(!paging.hasPrevious)

                    Text(paging.pageText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    Button {
                        Motion.perform(reduceMotion) { page = paging.page + 1 }
                    } label: {
                        Label("More", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                    }
                    .buttonStyle(SimpleButtonStyle(height: 56))
                    .disabled(!paging.hasNext)
                }
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

// MARK: - SimpleGroupButton

// big overview button
struct SimpleGroupButton: View {
    let group: SimpleGroup

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: group.symbol, tone: group.tone, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.title3.bold())
                    .foregroundStyle(group.tone == .neutral ? Color.primary : group.tone.color)
                if !group.preview.isEmpty {
                    Text(group.preview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(group.countText)
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.inactive)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(group.spokenLabel)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SimpleSectionTitle

// section title
struct SimpleSectionTitle: View {
    let title: String
    var tone: Tone = .neutral

    var body: some View {
        Text(title)
            .font(.title2.bold())
            .foregroundStyle(tone == .neutral ? Color.primary : tone.color)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - SimpleTile (Home)

// home screen tile
struct SimpleTile: View {
    enum Style { case plain, teal, red }

    let symbol: String
    let title: String
    var subtitle: String = ""
    var style: Style = .plain

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(style == .plain ? Color.remedyTeal : Color.white)
            Spacer(minLength: 4)
            Text(title)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(style == .plain ? Color.primary : Color.white)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 124, maxHeight: 124, alignment: .leading)
        .cardStyle(fill)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        switch style {
        case .plain: return .cardBackground
        case .teal: return .remedyTeal
        case .red: return .red
        }
    }
}

// MARK: - SimpleRowCard

// big tappable row
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
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tone.color)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.inactive)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - SimpleButtonStyle

// big button
struct SimpleButtonStyle: ButtonStyle {
    enum Kind { case primary, plain, danger }

    var kind: Kind = .primary
    var height: CGFloat = 64

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(kind == .plain ? Color.remedyTeal : Color.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var fill: Color {
        switch kind {
        case .primary: return .remedyTeal
        case .plain: return .cardBackground
        case .danger: return .red
        }
    }
}

// MARK: - ReadAloudButton

// reads text out loud
struct ReadAloudButton: View {
    var title: String = "Read this to me"
    let text: String

    var body: some View {
        Button {
            Speaker.toggle(text)
        } label: {
            Label(title, systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
        .accessibilityHint("Reads the screen out loud. Tap again to stop.")
    }
}

// MARK: - SimpleFactCard (label above, big answer below)

// label and big value
struct SimpleFactCard: View {
    let row: InfoRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(row.value)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
