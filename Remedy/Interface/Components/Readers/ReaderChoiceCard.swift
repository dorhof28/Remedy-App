//
//  ReaderChoiceCard.swift
//  Remedy
//
//  the pieces of the "how your papers are read" sheet: a step header, a choice card,
//  a where-it-goes tag and the download card with live progress, used by both looks
//

import SwiftUI

// "Stays on this iPhone" in a small coloured capsule
struct PrivacyTag: View {
    let place: PrivacyPlace
    var isSimple = false

    var body: some View {
        Label(place.label, systemImage: place.symbol)
            .font((isSimple ? Font.subheadline : .caption).weight(.semibold))
            .foregroundStyle(place.tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(place.tone.soft))
            .fixedSize()
    }
}

// one choice: icon, name, badges, a line about it, and the download card when it needs one
struct ReaderChoiceCardView: View {
    let card: ReaderCard
    var isSimple = false
    let store: LocalModelStore
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onPick) {
                HStack(alignment: .top, spacing: isSimple ? 14 : 12) {
                    ItemIconTile(kind: .goal(symbol: card.symbol), filled: card.isSelected, size: isSimple ? 48 : Spacing.iconTile)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.title)
                            .font(isSimple ? .title3.bold() : .body.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Text(card.detail)
                            .font(isSimple ? .body : .subheadline)
                            .foregroundStyle(card.isReady ? Color.ink2 : Tone.caution.color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { tags }
                            VStack(alignment: .leading, spacing: 6) { tags }
                        }
                    }
                    Spacer(minLength: 4)
                    RadioMark(isOn: card.isSelected, size: isSimple ? 32 : 26)
                        .opacity(card.isReady ? 1 : 0.4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!card.isReady)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(card.isSelected ? .isSelected : [])
            .accessibilityHint(card.isReady ? "" : "Not ready yet")

            if let model = card.model, !card.isReady {
                ModelDownloadView(model: model, store: store, isSimple: isSimple)
            }
        }
        .padding(isSimple ? 18 : Spacing.insideCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.accentInk, lineWidth: card.isSelected ? 2 : 0)
        }
        .sensoryFeedback(.selection, trigger: card.isSelected)
    }

    @ViewBuilder
    private var tags: some View {
        if card.isRecommended {
            Label(ReaderSetupViewModel.recommendedText, systemImage: "star.fill")
                .font((isSimple ? Font.subheadline : .caption).weight(.bold))
                .foregroundStyle(Color.onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentFill))
                .fixedSize()
        }
        PrivacyTag(place: card.privacy, isSimple: isSimple)
    }
}

// a model download: the size and a button, then a live bar with percent and MB, then done or a retry
struct ModelDownloadView: View {
    let model: LocalModel
    let store: LocalModelStore
    var isSimple = false

    var body: some View {
        let state = store.state(model)
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .notDownloaded:
                Button {
                    store.download(model)
                } label: {
                    Label(ReaderSetupViewModel.downloadButton(model), systemImage: "arrow.down.circle.fill")
                        .labelStyle(CenteredLabelStyle())
                }
                .modifier(DownloadButtonLook(isSimple: isSimple, prominent: true))
                .accessibilityLabel("Download \(model.displayName), \(model.sizeText)")

            case .downloading(let fraction):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(ReaderSetupViewModel.percentText(fraction))
                            .font((isSimple ? Font.title3 : .headline).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: fraction))
                        Spacer()
                        Text(ReaderSetupViewModel.amountText(fraction, of: model))
                            .font(isSimple ? .body : .footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    ProgressView(value: min(max(fraction, 0), 1))
                        .tint(Color.accentInk)
                        .animation(.smooth, value: fraction)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Downloading \(model.displayName)")
                .accessibilityValue(ReaderSetupViewModel.percentText(fraction))
                Button(role: .cancel) {
                    store.cancel(model)
                } label: {
                    Label(ReaderSetupViewModel.cancelButton, systemImage: "xmark")
                        .labelStyle(CenteredLabelStyle())
                }
                .modifier(DownloadButtonLook(isSimple: isSimple, prominent: false))

            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(isSimple ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(Tone.stop.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    store.download(model)
                } label: {
                    Label(ReaderSetupViewModel.retryButton, systemImage: "arrow.clockwise")
                        .labelStyle(CenteredLabelStyle())
                }
                .modifier(DownloadButtonLook(isSimple: isSimple, prominent: true))

            case .ready:
                Label(ReaderSetupViewModel.readyText, systemImage: "checkmark.circle.fill")
                    .font(isSimple ? .body.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(Tone.good.color)
                    .symbolEffect(.bounce, value: state)
            }
        }
        .animation(Motion.standard, value: state)
    }
}

// the download and cancel buttons, capsules in Classic and big buttons in Simple
private struct DownloadButtonLook: ViewModifier {
    let isSimple: Bool
    let prominent: Bool

    func body(content: Content) -> some View {
        if isSimple {
            content.buttonStyle(SimpleButtonStyle(kind: prominent ? .primary : .plain, height: 56))
        } else {
            content.buttonStyle(RemedyButtonStyle(kind: prominent ? .secondary : .plain))
        }
    }
}

// MARK: - One reader as a row

// a choice inside a grouped card: radio mark, name, one line, the privacy badge, and the download when it needs one
struct ReaderChoiceRow: View {
    let card: ReaderCard
    let store: LocalModelStore
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onPick) {
                HStack(alignment: .top, spacing: 12) {
                    RadioMark(isOn: card.isSelected)
                        .padding(.top, 2)
                        .opacity(card.isReady ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.leading)
                        Text(card.detail)
                            .font(.subheadline)
                            .foregroundStyle(card.isReady ? Color.ink2 : Tone.caution.color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PrivacyBadge(place: card.privacy)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!card.isReady)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(card.isSelected ? .isSelected : [])
            .accessibilityHint(card.isReady ? "" : "Not ready yet")

            if let model = card.model, !card.isReady {
                ModelDownloadView(model: model, store: store)
                    .padding(.leading, 38)
            }
        }
        .padding(.vertical, 12)
        .sensoryFeedback(.selection, trigger: card.isSelected)
    }
}
