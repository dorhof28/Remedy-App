//
//  LockScreenView.swift
//  Remedy
//
//  covers the app until Face ID or the passcode works
//

import SwiftUI

// covers the app until face id or the passcode unlocks it
struct LockScreenView: View {
    let failed: Bool
    let unlock: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)
                Text(LockWords.title)
                    .font(.title.bold())
                    .foregroundStyle(Color.ink)
                Text(failed ? LockWords.failed : LockWords.text)
                    .font(.body)
                    .foregroundStyle(failed ? Tone.stop.color : Color.ink2)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                PrimaryButton(title: LockWords.unlock, symbol: "faceid", action: unlock)
                SecondaryButton(title: LockWords.call911, symbol: "phone") {
                    if let url = URL(string: "tel://911") { openURL(url) }
                }
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // solid so nothing of the plan shows through
        .background(RemedyBackground().ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

// words on the lock screen
enum LockWords {
    static let title = "Remedy is locked"
    static let text = "Your medicines and papers stay private."
    static let failed = "It did not unlock. Please try again."
    static let unlock = "Unlock With Face ID"
    static let call911 = "Call 911"
}

#Preview {
    LockScreenView(failed: false) {}
}
