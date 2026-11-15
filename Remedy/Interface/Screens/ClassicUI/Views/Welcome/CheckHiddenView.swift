//
//  CheckHiddenView.swift
//  Remedy
//
//  what the ai will see: the page with hidden parts blacked out, where it goes, then Send or Keep on This iPhone
//  nothing leaves the phone before Send
//

import SwiftUI

// the hidden pages, checked before anything is sent
struct CheckHiddenView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.redactedPages.indices, id: \.self) { index in
                        Text(viewModel.consentCaption(index))
                            .font(.body)
                            .foregroundStyle(Color.ink2)
                        // a tap on a word hides it, a tap on a bar shows it again
                        PaperWordsText(pieces: viewModel.redactedPages[index].pieces) {
                            viewModel.tapPiece($0, onPage: index)
                        }
                        .font(.subheadline.monospaced())
                        .lineSpacing(4)
                        .tint(Color.ink)
                        .padding(Spacing.insideCard)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline))
                    }
                    if let note = viewModel.rulesOnlyNote {
                        ActionCard(style: .caution, eyebrow: "Check this", eyebrowSymbol: "exclamationmark.triangle", text: note)
                    }
                    if viewModel.showsNamesNotHidden {
                        NavigationLink {
                            NamesToHidePage()
                        } label: {
                            ListRow(symbol: "exclamationmark.triangle", tone: .caution, title: viewModel.namesNotHiddenTitle,
                                    subtitle: viewModel.namesNotHiddenDetail, showsChevron: true)
                                .padding(.horizontal, Spacing.insideCard).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Tone.caution.soft))
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(spacing: 0) {
                        if !viewModel.showsNamesNotHidden {
                            ListRow(symbol: "eye.slash", title: viewModel.hiddenRowTitle, subtitle: viewModel.hiddenRowDetail)
                                .padding(.horizontal, Spacing.insideCard).padding(.vertical, 10)
                                .accessibilityElement(children: .combine)
                            Divider().padding(.leading, 60)
                        }
                        ListRow(symbol: viewModel.whereRowSymbol, title: viewModel.whereRowTitle, subtitle: viewModel.whereRowText)
                            .padding(.horizontal, Spacing.insideCard).padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))

                    // a consent choice, so both answers are full size
                    VStack(spacing: 12) {
                        PrimaryButton(title: viewModel.sheetSendButton) { Task { await viewModel.sendFromConsent() } }
                        if viewModel.offersKeepOnPhone {
                            SecondaryButton(title: viewModel.keepOnPhoneTitle) { Task { await viewModel.useOnPhoneInstead() } }
                        }
                        Text(viewModel.consentFootnoteText)
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 24)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.consentTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}
