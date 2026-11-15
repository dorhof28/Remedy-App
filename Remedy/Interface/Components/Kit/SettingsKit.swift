//
//  SettingsKit.swift
//  Remedy
//
//  small pieces for Ask, Help, Emergency and Settings in both looks
//

import SwiftUI

// MARK: - Sheet buttons

// the tinted capsule Done at the top right of a sheet
struct SheetDoneButton: View {
    var title = "Done"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule().fill(Color.accentSoft))
                .frame(minHeight: Spacing.tapMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
}

// MARK: - Wallet card

// makes the printable card when asked, then offers it to share or print
struct WalletCardButton: View {
    let viewModel: EmergencyInfoViewModel
    var large = false

    // UI only the made card and the failed flag
    @State private var cardURL: URL?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cardURL {
                ShareLink(item: cardURL) {
                    Label(viewModel.walletTitle, systemImage: "square.and.arrow.up")
                }
                .modifier(WalletStyle(large: large))
            } else {
                Button {
                    cardURL = viewModel.makeCardPDF()
                    failed = cardURL == nil
                } label: {
                    Label(viewModel.walletTitle, systemImage: "creditcard")
                }
                .modifier(WalletStyle(large: large))
            }
            if failed {
                Text(viewModel.walletFailedText)
                    .font(.footnote)
                    .foregroundStyle(Color.dangerInk)
            }
        }
    }
}

// the wallet card look for a theme
private struct WalletStyle: ViewModifier {
    let large: Bool

    func body(content: Content) -> some View {
        if large {
            content.buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
        } else {
            content.buttonStyle(RemedyButtonStyle(kind: .plain))
        }
    }
}

// MARK: - Help words

extension HelpViewModel {

    // who to call for a sign
    func callWho(_ item: WarningSignItem) -> String {
        item.tone == .stop ? "Call 911" : "Call your surgeon"
    }
}
