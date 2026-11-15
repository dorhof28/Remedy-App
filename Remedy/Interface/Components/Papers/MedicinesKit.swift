//
//  MedicinesKit.swift
//  Remedy
//
//  medicines pieces both looks share: the jump chips, a medicine row, arrange sections,
//  the source quote sheet and the simple "Do this first" disagreement card
//

import SwiftUI
import SwiftData

// MARK: - Source quote sheet

// where a fact came from: the exact quote, the paper, who and when, See the page and Report a mistake
struct SourceQuoteSheet: View {
    let data: SourceQuoteData
    let report: MistakeReport
    var title: String = "Where this came from"
    var large = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !data.quote.isEmpty {
                        Text("\u{201C}\(data.quote)\u{201D}")
                            .font(large ? .title2 : .body)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(large ? 18 : 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface2))
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(data.rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                            FactValueRow(label: row.label, value: row.value, large: large)
                        }
                    }
                    .padding(.horizontal, 4)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { buttons }
                        VStack(spacing: 10) { buttons }
                    }
                }
                .padding(.horizontal, large ? Spacing.simpleEdge : Spacing.screenEdge)
                .padding(.bottom, 24)
            }
            .background(Color.surface)
            .formSheetChrome(title: title, saveTitle: "Done", onClose: { dismiss() }, onSave: { dismiss() })
            .toolbar {
                if large {
                    ToolbarItem(placement: .principal) {
                        Button { Speaker.toggle(spoken) } label: {
                            Label("Read to me", systemImage: "speaker.wave.2")
                        }
                        .accessibilityHint("Reads the paper's words out loud. Tap again to stop.")
                    }
                }
            }
        }
        .presentationDetents(large ? [.large] : [.medium, .large])
        .presentationCornerRadius(Radius.large)
    }

    private var spoken: String {
        ([data.quote] + data.rows.map { "\($0.label): \($0.value)" }).joined(separator: ". ")
    }

    @ViewBuilder
    private var buttons: some View {
        let style = large ? AnyButtonStyle(SimpleButtonStyle(kind: .plain)) : AnyButtonStyle(RemedyButtonStyle(kind: .plain))
        if !data.pageText.isEmpty {
            NavigationLink {
                PageTextView(text: data.pageText, quote: data.quote, large: large)
            } label: {
                Label("See the page", systemImage: "doc.text")
            }
            .buttonStyle(style)
        }
        ShareLink(item: report.text, subject: Text(report.subject)) {
            Label("Report a mistake", systemImage: "flag")
        }
        .buttonStyle(style)
    }
}

// a label left and value right, the facts card and the source sheet
struct FactValueRow: View {
    let label: String
    let value: String
    var large = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize || large
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            Text(label)
                .font(large ? .body : .subheadline)
                .foregroundStyle(Color.ink2)
                .frame(minWidth: large ? nil : 96, alignment: .leading)
            Text(value)
                .font(large ? .title3.weight(.semibold) : .body)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(minHeight: Spacing.rowMin, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// the page's words with hidden parts still hidden, the quote marked
struct PageTextView: View {
    let text: String
    let quote: String
    var large = false

    var body: some View {
        ScrollView {
            Text(highlighted)
                .font(large ? .title3 : .body)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(large ? Spacing.simpleEdge : Spacing.screenEdge)
                .textSelection(.enabled)
        }
        .background(Color.surface)
        .navigationTitle("The page")
        .navigationBarTitleDisplayMode(.inline)
    }

    // the quote gets the accent soft fill and an underline
    private var highlighted: AttributedString {
        var result = AttributedString(text)
        let needle = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !needle.isEmpty, let range = result.range(of: needle, options: [.caseInsensitive]) {
            result[range].backgroundColor = .accentSoft
            result[range].underlineStyle = .single
        }
        return result
    }
}

// MARK: - Simple: do this first

// papers disagree in the simple look, phrased as the thing to do first:
// "Do this first · Call about Eliquis", a big Call and They told me…, never dismissible
struct SimpleDisagreementCard: View {
    let cards: [PaperCheckCardData]
    // home on a small screen: no body sentence, the buttons stay
    var compact = false

    @State private var isResolving = false
    @State private var isSorting = false

    var body: some View {
        if let card = cards.first {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: PaperCheckViewModel.doThisFirst, tone: .stop, symbol: "exclamationmark.triangle")
                        .font(.body)
                    Text(card.simpleTitle)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !compact {
                        Text("\(PaperCheckViewModel.disagreeTitle). \(card.question) \(card.askByText)")
                            .font(.title3)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if cards.count > 1 {
                        Text("Also: \(cards.dropFirst().map(\.finding.medicine).joined(separator: ", "))")
                            .font(.body)
                            .foregroundStyle(Color.ink2)
                    }
                }
                .accessibilityElement(children: .combine)

                if let call = card.calls.first {
                    Link(destination: call.url) { Label(call.title, systemImage: "phone.fill") }
                        .buttonStyle(SimpleButtonStyle(kind: .danger))
                }
                Button(card.resolveButton) { isResolving = true }
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
                Button { isSorting = true } label: {
                    Text(cards.count > 1 ? "See all \(cards.count)" : "See both papers")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentInk)
                        .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.simpleEdge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disagreementSurface(radius: Radius.large)
            .accessibilityElement(children: .contain)
            .sheet(isPresented: $isResolving) { ResolveSheet(card: card, large: true) }
            .sheet(isPresented: $isSorting) { SortItOutSheet(cards: cards, large: true) }
        }
    }
}

// the old name simple home uses, one card
struct SimplePaperCheckCard: View {
    let card: PaperCheckCardData
    var compact = false

    var body: some View {
        SimpleDisagreementCard(cards: [card], compact: compact)
    }
}

