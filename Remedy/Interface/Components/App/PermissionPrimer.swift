//
//  PermissionPrimer.swift
//  Remedy
//
//  one plain reason and one Continue before apple's prompt, then a calm way out after a no
//

import SwiftUI
import UIKit

// before the prompt: no cancel, no picture of the alert
struct PermissionPrimerView: View {
    let text: PermissionPrimerText
    let onContinue: () -> Void

    var body: some View {
        HeroScreen(symbol: text.symbol, title: text.title, text: text.detail) {
            PrimaryButton(title: text.continueButton, action: onContinue)
        }
    }
}

// after don't allow: why, open settings, and another way when there is one
struct PermissionOffView: View {
    let text: PermissionPrimerText
    var onOtherWay: (() -> Void)? = nil
    let onBack: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            HeroScreen(symbol: text.symbol, title: text.offTitle, text: text.offDetail) {
                PrimaryButton(title: text.openSettingsButton) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                if let onOtherWay, !text.otherWayButton.isEmpty {
                    SecondaryButton(title: text.otherWayButton, symbol: "doc.text", action: onOtherWay)
                }
            }
            .navigationTitle(text.offNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(text.backButton, action: onBack)
                }
            }
        }
    }
}
