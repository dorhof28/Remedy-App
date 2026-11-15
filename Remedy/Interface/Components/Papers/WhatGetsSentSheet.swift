//
//  WhatGetsSentSheet.swift
//  Remedy
//
//  shown once before an ai off the phone reads the papers, for both looks
//  close circle, inline title, where it goes, what goes, then Send
//

import SwiftUI

// shows exactly what leaves the phone before the papers are sent
struct WhatGetsSentSheet: View {
    let viewModel: ScanFlowViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic

    var body: some View {
        let isSimple = look == .simple
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    HStack(spacing: 8) {
                        PrivacyBadge(place: viewModel.destination)
                        Text(viewModel.destinationText)
                            .font(isSimple ? .title3.bold() : .headline)
                            .foregroundStyle(Color.ink)
                    }
                    Text(viewModel.sheetDetail)
                        .font(isSimple ? .title3 : .body)
                        .foregroundStyle(Color.ink2)
                    if viewModel.needsRedactionWarning {
                        ToneBox(eyebrow: "Check this", title: viewModel.sheetNotHiddenWarning, tone: .caution)
                    }
                    GroupedCard {
                        ItemRow(kind: .paper, title: "The text you checked", detail: "Black parts never leave your phone")
                        if viewModel.sendsPhoto {
                            ItemRow(kind: .custom(symbol: "photo", tone: .neutral), title: "A photo of each page",
                                    detail: viewModel.sheetPhotoTitle)
                        }
                    }
                    ForEach(Array(viewModel.previewPictures.enumerated()), id: \.offset) { _, picture in
                        Image(uiImage: picture)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
                            .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Color.hairline))
                    }
                }
                .padding(isSimple ? Spacing.simpleEdge : Spacing.screenEdge)
            }
            .remedyBackground()
            .navigationTitle(viewModel.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetCloseButton { dismiss() } }
            .safeAreaInset(edge: .bottom) {
                buttons(isSimple: isSimple)
                    .padding(isSimple ? Spacing.simpleEdge : Spacing.screenEdge)
                    .background(.bar)
            }
        }
        .presentationCornerRadius(Radius.large)
    }

    // one primary button, the on phone choice under it
    @ViewBuilder
    private func buttons(isSimple: Bool) -> some View {
        VStack(spacing: 10) {
            if isSimple {
                Button { Task { await viewModel.confirmSend() } } label: {
                    Label(viewModel.sheetSendButton, systemImage: "paperplane.fill")
                }
                .buttonStyle(SimpleButtonStyle())
                Button { Task { await viewModel.useOnPhoneInstead() } } label: {
                    Label(viewModel.sheetPhoneButton, systemImage: "iphone")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
            } else {
                Button { Task { await viewModel.confirmSend() } } label: {
                    Text(viewModel.sheetSendButton)
                }
                .buttonStyle(RemedyButtonStyle())
                Button { Task { await viewModel.useOnPhoneInstead() } } label: {
                    Text(viewModel.sheetPhoneButton)
                }
                .buttonStyle(RemedyButtonStyle(kind: .plain))
            }
        }
    }
}
