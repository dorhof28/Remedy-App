//
//  MacConnectionPanel.swift
//  Remedy
//
//  name field, connect button and the model list for an ai on the patient's Mac, in both looks
//

import SwiftUI

// type the mac's name, connect and pick a model
struct MacConnectionPanel: View {
    @State private var viewModel = MacConnectionViewModel()
    var isSimple = false

    var body: some View {
        VStack(alignment: .leading, spacing: isSimple ? 16 : 12) {
            HStack(spacing: 12) {
                ItemIconTile(kind: .custom(symbol: "desktopcomputer", tone: .neutral), size: isSimple ? 48 : Spacing.iconTile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.title).font(isSimple ? .title3.bold() : .headline)
                    Text(viewModel.subtitle)
                        .font(isSimple ? .body : .subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                TextField(viewModel.namePrompt, text: $viewModel.name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit { Task { await viewModel.check() } }
                Button {
                    Task { await viewModel.check() }
                } label: {
                    if viewModel.isChecking {
                        ProgressView()
                    } else {
                        Text(viewModel.checkButton).fontWeight(.semibold)
                    }
                }
                .buttonStyle(RemedyButtonStyle(kind: .secondary))
                .fixedSize()
                .disabled(!viewModel.canCheck)
            }
            SecureField(viewModel.keyPrompt, text: $viewModel.key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
            Text(viewModel.nameHint)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let connected = viewModel.connectedText {
                Label(connected, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Tone.good.color)
                    .transition(.opacity)
                modelList
            }
            if let error = viewModel.errorText {
                Label(error, systemImage: "wifi.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(Tone.caution.color)
                    .fixedSize(horizontal: false, vertical: true)
                setup
            }
        }
        .animation(.snappy, value: viewModel.state)
        .sensoryFeedback(.success, trigger: viewModel.connectedText)
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.modelTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            ForEach(viewModel.models, id: \.self) { model in
                Button {
                    viewModel.pick(model)
                } label: {
                    HStack {
                        Text(viewModel.shortName(model))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if model == viewModel.recommended {
                            Text(viewModel.recommendedTag)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Tone.good.soft, in: Capsule())
                                .foregroundStyle(Tone.good.color)
                        }
                        Spacer()
                        if model == viewModel.model {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentInk).fontWeight(.semibold)
                        }
                    }
                    .frame(minHeight: isSimple ? 52 : 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model == viewModel.model ? .isSelected : [])
                if model != viewModel.models.last { Divider() }
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.setupTitle).font(.footnote.weight(.semibold))
            ForEach(Array(viewModel.setupSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(Color.accentInk)
                    Text(step).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
