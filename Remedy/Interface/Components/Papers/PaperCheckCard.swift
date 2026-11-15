//
//  PaperCheckCard.swift
//  Remedy
//
//  papers disagree in both looks: the slim banner, the three line card, the sort it out sheet,
//  and the small blue updated note
//  never dismissible, never animated, it goes away only when the patient sorts it out
//

import SwiftUI
import SwiftData

// MARK: - Card

// three lines and two buttons, several disagreements stack into one card
struct DisagreementCard: View {
    let cards: [PaperCheckCardData]

    @State private var isSorting = false

    var body: some View {
        if let first = cards.first {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(PaperCheckViewModel.stackHeadline(count: cards.count), systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(Color.dangerInk)
                    Text(cards.count == 1 ? first.question : cards.map(\.finding.medicine).joined(separator: ", "))
                        .font(.body)
                        .foregroundStyle(Color.ink)
                    Text(cards.count == 1 ? "\(first.followLine) \(first.askByText)" : first.askByText)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { buttons(first) }
                    VStack(spacing: 10) { buttons(first) }
                }
            }
            .padding(Spacing.insideCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disagreementSurface(radius: Radius.card)
            .accessibilityElement(children: .contain)
            .sheet(isPresented: $isSorting) { SortItOutSheet(cards: cards) }
        }
    }

    @ViewBuilder
    private func buttons(_ first: PaperCheckCardData) -> some View {
        // one office to call goes straight there, several open the sheet with a button each
        let calls = Array(Set(cards.flatMap(\.calls).map(\.url)))
        if calls.count == 1, let url = calls.first {
            Link(destination: url) { Label(PaperCheckViewModel.callTitle, systemImage: "phone") }
                .buttonStyle(DangerOutlineButtonStyle())
                .accessibilityLabel(first.calls.first?.title ?? PaperCheckViewModel.callTitle)
        } else if calls.count > 1 {
            Button { isSorting = true } label: { Label(PaperCheckViewModel.callTitle, systemImage: "phone") }
                .buttonStyle(DangerOutlineButtonStyle())
        }
        Button(PaperCheckViewModel.sortItOutTitle) { isSorting = true }
            .buttonStyle(RemedyButtonStyle(kind: .plain))
    }
}

// the old name the other screens use, now the three line card
struct PaperCheckCard: View {
    let card: PaperCheckCardData

    var body: some View {
        DisagreementCard(cards: [card])
    }
}

// MARK: - Sort it out sheet

// both quotes with doctor, role and date, what Remedy follows meanwhile, They told me…, a call per doctor and Explain this
struct SortItOutSheet: View {
    let cards: [PaperCheckCardData]
    var large = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(cards) { card in
                        SortItOutBlock(card: card, large: large)
                    }
                }
                .padding(.horizontal, large ? Spacing.simpleEdge : Spacing.screenEdge)
                .padding(.bottom, 24)
            }
            .background(Color.surface)
            .formSheetChrome(title: PaperCheckViewModel.disagreeTitle, saveTitle: "Done",
                             onClose: { dismiss() }, onSave: { dismiss() })
        }
        .presentationDetents(large ? [.large] : [.medium, .large])
        .presentationCornerRadius(Radius.large)
    }
}

// one medicine's part of the sheet
struct SortItOutBlock: View {
    let card: PaperCheckCardData
    var large = false

    @State private var isResolving = false
    @State private var explain = ExplainViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.finding.medicine)
                    .font(large ? .title.bold() : .title2.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(card.question)
                    .font(large ? .title3 : .body)
                    .foregroundStyle(Color.ink2)
            }
            CheckQuoteList(quotes: card.quotes, large: large)
            if !card.followingPaper.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    StatusBadge(text: PaperCheckViewModel.followingBadge, symbol: "checkmark", tone: .good)
                    Text([card.followingPaper, card.followingMeaning].filter { !$0.isEmpty }.joined(separator: " \u{2014} "))
                        .font(large ? .body : .subheadline)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(card.followLine)
                    .font(large ? .body : .subheadline)
                    .foregroundStyle(Color.ink2)
            }
            if !card.noDateLine.isEmpty {
                Label(card.noDateLine, systemImage: "calendar.badge.exclamationmark")
                    .font(large ? .body : .subheadline)
                    .foregroundStyle(Color.ink2)
            }
            if !card.askByText.isEmpty {
                Label(card.askByText, systemImage: "calendar")
                    .font(large ? .body : .subheadline)
                    .foregroundStyle(Color.ink2)
            }

            Button(card.resolveButton) { isResolving = true }
                .buttonStyle(primaryStyle)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { callButtons }
                VStack(spacing: 10) { callButtons }
            }
            if explain.isAvailable {
                Button {
                    Task { await explain.explain(card) }
                } label: {
                    Label(ExplainViewModel.buttonTitle, systemImage: "sparkle")
                        .font((large ? Font.title3 : .body).weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                        .frame(maxWidth: .infinity, minHeight: Spacing.tapMin)
                }
                .buttonStyle(.plain)
                .disabled(explain.isWorking)
            }
            ExplainNote(viewModel: explain, large: large)
        }
        .sheet(isPresented: $isResolving) { ResolveSheet(card: card, large: large) }
    }

    private var primaryStyle: AnyButtonStyle {
        large ? AnyButtonStyle(SimpleButtonStyle()) : AnyButtonStyle(RemedyButtonStyle(kind: .primary))
    }

    @ViewBuilder
    private var callButtons: some View {
        ForEach(card.calls) { call in
            Link(destination: call.url) { Label(call.title, systemImage: "phone") }
                .buttonStyle(large ? AnyButtonStyle(SimpleButtonStyle(kind: .plain)) : AnyButtonStyle(RemedyButtonStyle(kind: .plain)))
        }
    }
}

// MARK: - Quotes

// the quotes from each paper in a soft box, doctor, role and printed date under each
struct CheckQuoteList: View {
    let quotes: [CardQuote]
    var compact: Bool = false
    var large: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            ForEach(quotes) { quote in
                VStack(alignment: .leading, spacing: 4) {
                    // what this paper means in plain words, then its own words
                    if !quote.plainLead.isEmpty && !compact {
                        Text("\(Text(quote.plainLead).bold())\(quote.plainRest.isEmpty ? "" : " " + quote.plainRest)")
                            .font(large ? .title3 : .body)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\u{201C}\(quote.text)\u{201D}")
                        .font(large ? .title3 : (compact ? .footnote : .body))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(quote.byline)
                        .font(large ? .body : .footnote)
                        .foregroundStyle(Color.ink2)
                }
                .padding(compact ? 10 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface2))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Explain this

// the phone ai's simpler words, labelled so it never reads as advice
struct ExplainNote: View {
    let viewModel: ExplainViewModel
    var large: Bool = false

    var body: some View {
        if viewModel.isWorking {
            Label { Text(ExplainViewModel.workingText) } icon: { ProgressView() }
                .font(large ? .title3 : .subheadline)
                .foregroundStyle(Color.ink2)
        } else if let text = viewModel.text {
            VStack(alignment: .leading, spacing: 8) {
                Label(ExplainViewModel.label, systemImage: "sparkle")
                    .font((large ? Font.body : .footnote).weight(.semibold))
                    .foregroundStyle(Color.ink2)
                Text(text)
                    .font(large ? .title3 : .body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ExplainViewModel.note)
                    .font(large ? .body : .footnote)
                    .foregroundStyle(Color.ink2)
            }
            .padding(large ? 18 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface2))
            .accessibilityElement(children: .combine)
        } else if viewModel.failed {
            Text(ExplainViewModel.failedText)
                .font(large ? .title3 : .subheadline)
                .foregroundStyle(Color.ink2)
        }
    }
}

// MARK: - Updated note

// blue: a newer paper replaced an older one, the patient sorted one out, or the surgery papers
// don't mention a medicine with a button to mark it asked. "See both" opens the quotes.
struct PaperCheckNoteCard: View {
    let card: PaperCheckCardData
    // big text and a big button for the simple look
    var simple = false

    @Environment(\.modelContext) private var context
    @State private var showsBoth = false

    var body: some View {
        VStack(alignment: .leading, spacing: simple ? 12 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(simple ? .title3 : .body)
                    .foregroundStyle(Color.infoInk)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Text(card.noteLead).bold().foregroundStyle(Color.infoInk))\(card.noteLead.isEmpty ? "" : " ")\(Text(card.noteText).foregroundStyle(Color.ink))")
                        .font(simple ? .title3 : .subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    if card.canMarkAsked, !card.message.detail.isEmpty {
                        Text(card.message.detail)
                            .font(simple ? .body : .footnote)
                            .foregroundStyle(Color.ink2)
                    }
                    if !card.quotes.isEmpty {
                        Button(card.quotes.count > 1 ? PaperCheckViewModel.seeBothTitle : "See the paper") { showsBoth = true }
                            .font((simple ? Font.title3 : .subheadline).weight(.semibold))
                            .foregroundStyle(Color.accentInk)
                            .buttonStyle(.plain)
                            .frame(minHeight: simple ? Spacing.tapSimple : Spacing.tapMin, alignment: .leading)
                    }
                }
            }
            if card.canMarkAsked {
                if simple {
                    Button(card.markAskedTitle) { PaperCheckViewModel.markAsked(card, in: context) }
                        .buttonStyle(SimpleButtonStyle(kind: .plain))
                } else {
                    Button(card.markAskedTitle) { PaperCheckViewModel.markAsked(card, in: context) }
                        .buttonStyle(RemedyButtonStyle(kind: .secondary))
                }
            }
        }
        .padding(simple ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.infoSoft))
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showsBoth) {
            NavigationStack {
                ScrollView {
                    CheckQuoteList(quotes: card.quotes, large: simple)
                        .padding(.horizontal, simple ? Spacing.simpleEdge : Spacing.screenEdge)
                }
                .background(Color.surface)
                .formSheetChrome(title: PaperCheckViewModel.whereFromTitle, saveTitle: "Done",
                                 onClose: { showsBoth = false }, onSave: { showsBoth = false })
            }
            .presentationDetents([.medium, .large])
        }
    }
}

// the old name for the blue note

// MARK: - Pieces

// a type-erased button style so one view can pick classic or simple
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// the calm call button inside the disagreement card: danger ink outline on the card
struct DangerOutlineButtonStyle: ButtonStyle {
    var compact = false
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((large ? Font.title3 : (compact ? .subheadline : .body)).weight(.semibold))
            .foregroundStyle(Color.dangerInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? 14 : 18)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: large ? Spacing.tapSimple : (compact ? 40 : Spacing.buttonHeight))
            .background(Capsule().fill(Color.surface))
            .overlay(Capsule().strokeBorder(Color.dangerInk, lineWidth: 1.5))
            .contentShape(Capsule())
            .frame(minHeight: Spacing.tapMin)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    // danger soft fill with a 1.5pt danger ink edge, never glass and never animated
    func disagreementSurface(radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(Color.dangerSoft))
            .overlay(shape.strokeBorder(Color.dangerInk, lineWidth: 1.5))
    }
}
