//
//  PapersDisagreeView.swift
//  Remedy
//
//  screen 16 both papers side by side, remedy never picks, the office does
//

import SwiftUI

// both papers' words for a red card and a call button
struct PapersDisagreeView: View {
    let card: PaperCheckCardData

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    // UI only the office's answer sheet
    @State private var isResolving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(card.finding.medicine)
                    .font(.title.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(DisagreeWords.lead(card))
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(card.quotes) { quote in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(DisagreeWords.byline(quote), systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentInk)
                        if !quote.plainLead.isEmpty {
                            Text("\(Text(quote.plainLead).bold())\(quote.plainRest.isEmpty ? "" : " " + quote.plainRest)")
                                .font(.body)
                                .foregroundStyle(Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("\u{201C}\(quote.text)\u{201D}")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.insideCard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
                let why = [DisagreeWords.whyNotPicked(card), card.askByText].filter { !$0.isEmpty }.joined(separator: " ")
                if !why.isEmpty {
                    Text(why)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // at big sizes the buttons scroll with the words
                if typeSize.isAccessibilitySize { buttons.padding(.top, 8) }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.sectionGap)
        }
        .background(Color.screenBackground)
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                buttons
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.bottom, 8)
                    .background(Color.screenBackground)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(DisagreeWords.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isResolving) { ResolveSheet(card: card) }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            ForEach(Array(card.calls.enumerated()), id: \.element.id) { index, call in
                if index == 0 {
                    PrimaryButton(title: call.title, symbol: "phone.fill") { openURL(call.url) }
                } else {
                    SecondaryButton(title: call.title, symbol: "phone.fill") { openURL(call.url) }
                }
            }
            SecondaryButton(title: DisagreeWords.toldMe) { isResolving = true }
        }
    }
}
