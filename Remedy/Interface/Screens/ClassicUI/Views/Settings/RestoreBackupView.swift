//
//  RestoreBackupView.swift
//  Remedy
//
//  the restore sheet for both looks: what it does, the file, the password,
//  a preview of what comes back, then a yes before anything changes
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// pick a backup file, type its password and restore it
struct RestoreBackupView: View {

    let viewModel: SettingsViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    // UI only the picked file, password and opened backup
    @State private var isPickingFile = false
    @State private var fileData: Data?
    @State private var fileName = ""
    @State private var password = ""
    @State private var snapshot: BackupSnapshot?
    @State private var isWorking = false
    @State private var isConfirming = false
    @State private var isRestored = false
    @State private var message: String?

    private var isSimple: Bool { look == .simple }

    var body: some View {
        NavigationStack {
            FitOrScroll {
                VStack(alignment: .leading, spacing: 20) {
                    if isRestored {
                        restored
                    } else if let snapshot {
                        preview(snapshot)
                    } else if fileData != nil {
                        passwordStep
                    } else {
                        intro
                    }
                    if let message {
                        ToneBox(eyebrow: "Try again", title: message, tone: .caution)
                    }
                }
                .padding(Spacing.screenEdge)
                .animation(Motion.standard, value: stage)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .remedyBackground()
            .navigationTitle(viewModel.restoreBackupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRestored {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(viewModel.cancelTitle) { dismiss() }
                    }
                }
            }
            .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.data]) { result in
                read(result)
            }
            .confirmationDialog(viewModel.restoreButton, isPresented: $isConfirming, titleVisibility: .visible) {
                Button(viewModel.restoreButton, role: viewModel.hasPlan ? .destructive : nil) { replace() }
                Button(viewModel.cancelTitle, role: .cancel) {}
            } message: {
                Text(viewModel.replaceMessage)
            }
            .sensoryFeedback(.success, trigger: isRestored)
        }
        .presentationBackground { RemedyBackground() }
    }

    private var stage: Int { isRestored ? 3 : snapshot != nil ? 2 : fileData != nil ? 1 : 0 }

    // MARK: - Steps

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(symbol: "arrow.counterclockwise.circle.fill", title: viewModel.restoreBackupTitle, text: viewModel.restoreIntro)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(viewModel.restoreSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        ItemIconTile(kind: .custom(symbol: step.symbol, tone: .info), size: isSimple ? 44 : 36)
                        Text("\(index + 1). \(step.text)")
                            .font(isSimple ? .title3 : .body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(isSimple ? 18 : Spacing.insideCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            Label(viewModel.restoreSafeNote, systemImage: "lock.shield")
                .font(isSimple ? .body : .footnote)
                .foregroundStyle(Color.ink2)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header(symbol: "key.fill", title: viewModel.openBackupIntro, text: "")
            if !fileName.isEmpty {
                Label(fileName, systemImage: "doc.fill")
                    .font(isSimple ? .title3 : .subheadline)
                    .foregroundStyle(Color.ink2)
                    .lineLimit(2)
            }
            SecureField(viewModel.passwordPrompt, text: $password)
                .font(isSimple ? .title3 : .body)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { if !password.isEmpty && !isWorking { Task { await open() } } }
                .padding(isSimple ? 18 : Spacing.insideCard)
                .cardStyle()
            Button(viewModel.otherFileTitle) {
                fileData = nil
                password = ""
                message = nil
                isPickingFile = true
            }
            .font(isSimple ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            .frame(minHeight: Spacing.minTarget)
        }
    }

    private func preview(_ snapshot: BackupSnapshot) -> some View {
        let items = viewModel.backupPreview(snapshot.summary)
        return VStack(alignment: .leading, spacing: 16) {
            header(symbol: "doc.text.magnifyingglass", title: viewModel.inBackupTitle, text: "")
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        ItemIconTile(kind: .custom(symbol: item.symbol, tone: .info), size: isSimple ? 40 : 32)
                        Text(item.title)
                            .font(isSimple ? .title3 : .body)
                        Spacer(minLength: 8)
                        Text(item.value)
                            .font((isSimple ? Font.title3 : .body).weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if item.id != items.last?.id { Divider().padding(.leading, isSimple ? 52 : 44) }
                }
            }
            .padding(.horizontal, isSimple ? 18 : Spacing.insideCard)
            .padding(.vertical, 4)
            .cardStyle()
            Label(viewModel.replaceMessage, systemImage: viewModel.hasPlan ? "exclamationmark.triangle.fill" : "info.circle")
                .font(isSimple ? .body : .footnote)
                .foregroundStyle(viewModel.hasPlan ? Tone.caution.color : Color.ink2)
        }
    }

    private var restored: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isSimple ? 80 : 64))
                .foregroundStyle(Tone.good.color)
                .symbolEffect(.bounce, value: isRestored)
                .accessibilityHidden(true)
            Text(viewModel.restoredTitle)
                .font(isSimple ? .largeTitle.bold() : .title.bold())
            Text(viewModel.restoredText)
                .font(isSimple ? .title3 : .body)
                .foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func header(symbol: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: isSimple ? 44 : 36, weight: .semibold))
                .foregroundStyle(Color.accentInk)
                .accessibilityHidden(true)
            Text(title)
                .font(isSimple ? .largeTitle.bold() : .title2.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !text.isEmpty {
                Text(text)
                    .font(isSimple ? .title3 : .body)
                    .foregroundStyle(Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - The one button for each step

    @ViewBuilder
    private var bottomBar: some View {
        VStack {
            if isRestored {
                button(viewModel.doneTitle, symbol: "checkmark") { dismiss() }
            } else if snapshot != nil {
                button(viewModel.restoreButton, symbol: "arrow.counterclockwise", danger: viewModel.hasPlan) { isConfirming = true }
            } else if fileData != nil {
                button(viewModel.openBackupTitle, symbol: "lock.open.fill") { Task { await open() } }
                    .disabled(password.isEmpty)
            } else {
                button(viewModel.chooseBackupTitle, symbol: "folder.fill") { isPickingFile = true }
            }
        }
        .disabled(isWorking)
        .padding(Spacing.screenEdge)
        .onboardingBar()
    }

    @ViewBuilder
    private func button(_ title: String, symbol: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        let label = Group {
            if isWorking {
                ProgressView().tint(Color.onAccent)
            } else {
                Label(title, systemImage: symbol).labelStyle(CenteredLabelStyle())
            }
        }
        if isSimple {
            Button(action: action) { label }
                .buttonStyle(SimpleButtonStyle(kind: danger ? .danger : .primary))
        } else {
            Button(action: action) { label }
                .buttonStyle(RemedyButtonStyle(kind: danger ? .destructive : .primary))
        }
    }

    // MARK: - Work

    private func read(_ result: Result<URL, Error>) {
        message = nil
        guard case .success(let url) = result else { return }
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            fileData = try Data(contentsOf: url)
            fileName = url.lastPathComponent
        } catch {
            message = viewModel.backupErrorText(BackupError.notABackup)
        }
    }

    private func open() async {
        guard let fileData else { return }
        isWorking = true
        message = nil
        do {
            snapshot = try await viewModel.openBackup(fileData, password: password)
        } catch {
            message = viewModel.backupErrorText(error)
            // a file that is not a backup needs another file, not another password
            if (error as? BackupError) != .wrongPassword { self.fileData = nil }
        }
        isWorking = false
    }

    // replaces everything on this phone with the backup
    private func replace() {
        guard let snapshot else { return }
        isWorking = true
        Task {
            do {
                try await viewModel.restore(snapshot, in: context)
                isRestored = true
            } catch {
                message = viewModel.backupErrorText(error)
            }
            isWorking = false
        }
    }
}
