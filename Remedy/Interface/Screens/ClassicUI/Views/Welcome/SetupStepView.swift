//
//  SetupStepView.swift
//  Remedy
//
//  classic look of the lock calendar and reminder questions before the first plan is saved
//  one question per screen, a real system prompt behind the button and a Not now
//

import SwiftUI
import SwiftData

// one setup step before the first plan
struct SetupStepView: View {
    @Bindable var viewModel: ScanFlowViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var setup: OnboardingViewModel { viewModel.setup }

    var body: some View {
        FitOrScroll {
            if let step = setup.current {
                VStack(spacing: 20) {
                    Spacer(minLength: 24)
                    SetupSymbol(symbol: setup.symbol(step), size: 84)
                    VStack(spacing: 10) {
                        Text(setup.title(step))
                            .font(.title.bold())
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(setup.reason(step))
                            .font(.body)
                            .foregroundStyle(Color.ink2)
                            .multilineTextAlignment(.center)
                    }
                    SetupInputs(setup: setup, step: step)
                    if let message = setup.message {
                        ToneBox(eyebrow: "Lock stays off", title: message, tone: .caution)
                    }
                    Spacer(minLength: 12)
                }
                .id(step)
                .transition(.slideIn(reduceMotion: reduceMotion))
                .padding(.horizontal, 32)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if setup.current != nil {
                SheetCapsuleButton(title: "Skip", placement: .primaryAction) { setup.notNow() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let step = setup.current {
                VStack(spacing: 10) {
                    if !setup.progressText.isEmpty {
                        SetupDots(total: setup.steps.count, current: setup.index)
                            .padding(.bottom, 6)
                    }
                    Button {
                        Task { await setup.allow() }
                    } label: {
                        if setup.isWorking {
                            ProgressView().tint(Color.onAccent)
                        } else {
                            Text(setup.allowButton(step))
                        }
                    }
                    .buttonStyle(RemedyButtonStyle())
                    .disabled(setup.isWorking)
                    .accessibilityIdentifier("setup-allow")

                    Button(setup.notNowButton(step)) { setup.notNow() }
                        .font(.headline)
                        .foregroundStyle(Color.accentInk)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                        .disabled(setup.isWorking)
                        .accessibilityIdentifier("setup-not-now")

                    Text(setup.settingsNote(step))
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                }
                .padding(Spacing.screenEdge)
            }
        }
        .sensoryFeedback(.success, trigger: setup.doneCount)
        .onChange(of: setup.isFinished) { _, done in
            // the last answer saves the plan, the tabs then appear by themselves
            if done { _ = viewModel.save(in: context) }
        }
    }
}

// the big symbol at the top of a setup step, shared by both looks
struct SetupSymbol: View {
    let symbol: String
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(Color.accentInk)
            .symbolRenderingMode(.hierarchical)
            .frame(width: size * 1.45, height: size * 1.45)
            .background(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).fill(Color.accentSoft))
            .symbolEffect(.bounce, value: appeared)
            .onAppear { if !reduceMotion { appeared = true } }
            .accessibilityHidden(true)
    }
}

// the name field and the time wheel for the two profile steps, both looks
struct SetupInputs: View {
    @Bindable var setup: OnboardingViewModel
    let step: SetupStep

    var body: some View {
        switch step {
        case .name:
            TextField("First name", text: $setup.nameText)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(.title3)
                .padding(14)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("setup-name")
        case .checkIn:
            CheckInTimeWheel(minute: $setup.checkInMinute)
                .frame(maxHeight: 160)
        default:
            EmptyView()
        }
    }
}
