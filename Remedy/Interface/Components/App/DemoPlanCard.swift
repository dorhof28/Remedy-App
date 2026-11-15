//
//  DemoPlanCard.swift
//  Remedy
//
//  one sample patient as a row that opens their plan in one tap, both looks
//

import SwiftUI
import SwiftData

// one fake patient in the demo mode list, with its load state
struct DemoPlanCard: View {
    enum Status { case idle, loading, loaded }

    let scenario: DemoScenario
    let status: Status
    var isSimple = false
    let onTap: () -> Void

    private var words: DemoModeViewModel { DemoModeViewModel() }
    private var tone: Tone { status == .loaded ? .good : .info }

    var body: some View {
        Button(action: onTap) {
            if isSimple {
                SimpleDemoRow(title: scenario.title, subtitle: scenario.detail, status: simpleStatus, statusTone: .good,
                              showsChevron: status == .idle, symbol: scenario.symbol, tone: tone, filled: status == .loaded)
            } else {
                ItemRow(kind: .custom(symbol: scenario.symbol, tone: tone), title: scenario.title, detail: scenario.detail) {
                    trailing
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(status == .loading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status == .loaded ? words.loadedBadge : "")
        .accessibilityHint(status == .loaded ? "Showing now. Tap to start it again." : "Opens this made-up plan")
        .accessibilityIdentifier("demo-\(scenario.rawValue)")
    }

    // simple says it in words under the name, with a check
    private var simpleStatus: String {
        switch status {
        case .loading: return words.loadingText
        case .loaded: return "\u{2713} " + words.loadedBadge
        case .idle: return ""
        }
    }

    // one control on the right: a spinner, the showing badge or the word that loads it
    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .loading:
            ProgressView()
                .controlSize(isSimple ? .large : .regular)
                .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
        case .loaded:
            if !isSimple {
                StatusBadge(text: words.loadedBadge, symbol: "checkmark", tone: .good)
            }
        case .idle:
            Text(words.loadWord)
                .font((isSimple ? Font.title3 : .subheadline).weight(.semibold))
                .foregroundStyle(Color.accentInk)
        }
    }
}

// MARK: - Loading a patient

// UI state of loading a sample patient or leaving demo mode, the work itself is in DemoModeViewModel
@MainActor @Observable
final class DemoLoader {
    // the patient waiting for a yes, the one loading, leaving and a problem message
    var pending: DemoScenario?
    var loading: DemoScenario?
    var isConfirmingExit = false
    var isExiting = false
    var message: String?

    var isWorking: Bool { loading != nil || isExiting }

    func status(_ scenario: DemoScenario, loaded: String) -> DemoPlanCard.Status {
        if loading == scenario { return .loading }
        return loaded == scenario.title ? .loaded : .idle
    }

    // one tap loads, only a real plan waits for a yes first
    func tap(_ scenario: DemoScenario, plans: [CarePlan], in context: ModelContext) {
        guard !isWorking else { return }
        let hasRealPlan = plans.first.map { !$0.isSample } ?? false
        if DemoModeViewModel().asksBeforeLoading(hasRealPlan: hasRealPlan) { pending = scenario } else { load(scenario, in: context) }
    }

    // the whole app redraws after, so the sheet closes and the new plan shows
    func load(_ scenario: DemoScenario, in context: ModelContext) {
        let viewModel = DemoModeViewModel()
        loading = scenario
        Task {
            do {
                try await viewModel.load(scenario, in: context)
                NotificationCenter.default.post(name: .demoClockChanged, object: nil)
            } catch {
                message = viewModel.errorText(error)
            }
            loading = nil
        }
    }

    // the real plan comes back and every screen redraws
    func exit(in context: ModelContext) {
        let viewModel = DemoModeViewModel()
        isExiting = true
        Task {
            do {
                try await viewModel.exit(in: context)
                NotificationCenter.default.post(name: .demoClockChanged, object: nil)
            } catch {
                message = viewModel.errorText(error)
            }
            isExiting = false
        }
    }
}

extension View {
    // the yes before a real plan is replaced, the yes before leaving and any problem
    func demoLoaderDialogs(_ loader: DemoLoader, hasPlan: Bool, context: ModelContext) -> some View {
        modifier(DemoLoaderDialogs(loader: loader, hasPlan: hasPlan, context: context))
    }
}

// the are you sure and error alerts around loading a fake patient
private struct DemoLoaderDialogs: ViewModifier {
    @Bindable var loader: DemoLoader
    let hasPlan: Bool
    let context: ModelContext

    func body(content: Content) -> some View {
        let viewModel = DemoModeViewModel()
        content
            .confirmationDialog(loader.pending.map(viewModel.warningTitle(for:)) ?? "",
                                isPresented: Binding(get: { loader.pending != nil }, set: { if !$0 { loader.pending = nil } }),
                                titleVisibility: .visible, presenting: loader.pending) { scenario in
                Button(viewModel.loadTitle) { loader.load(scenario, in: context) }
                Button(viewModel.cancelTitle, role: .cancel) {}
            } message: { _ in
                Text(viewModel.warningMessage(hasPlan: hasPlan))
            }
            .confirmationDialog(viewModel.exitTitle, isPresented: $loader.isConfirmingExit, titleVisibility: .visible) {
                Button(viewModel.exitTitle, role: .destructive) { loader.exit(in: context) }
                Button(viewModel.cancelTitle, role: .cancel) {}
            } message: {
                Text(viewModel.exitMessage)
            }
            .alert(viewModel.screenTitle, isPresented: Binding(get: { loader.message != nil }, set: { if !$0 { loader.message = nil } })) {
                Button("OK") { loader.message = nil }
            } message: {
                Text(loader.message ?? "")
            }
            .sensoryFeedback(.impact, trigger: loader.loading)
    }
}

// MARK: - Simple row

// a big row like SimpleRowCard, but the sample names keep their day counts ("3 days after surgery")
struct SimpleDemoRow: View {
    let title: String
    var subtitle: String = ""
    var status: String = ""
    var statusTone: Tone = .neutral
    var showsChevron = true
    var symbol: String
    var tone: Tone = .neutral
    var filled = false

    var body: some View {
        HStack(spacing: 16) {
            ItemIconTile(kind: .custom(symbol: symbol, tone: tone), filled: filled, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(statusTone == .neutral ? Color.ink2 : statusTone.color)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple + 16, alignment: .leading)
        .simpleCardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
