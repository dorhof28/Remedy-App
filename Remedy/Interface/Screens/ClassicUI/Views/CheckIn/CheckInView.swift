//
//  CheckInView.swift
//  Remedy
//
//  classic daily check-in sheet: pain as number buttons, the paper's warning signs as tiles, a note
//

import SwiftUI
import SwiftData

// fits on one screen, Save is the tinted toolbar button
struct CheckInView: View {
    let viewModel: CheckInViewModel

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the answers before saving
    @State private var pain: Int?
    @State private var ticked: Set<String> = []
    @State private var note = ""
    @State private var saved = false
    @State private var isAddingPhoto = false
    @State private var isAddingNumber = false
    @FocusState private var noteFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            List {
                // a ticked sign shows who to call, never a rating
                if !viewModel.calls(ticked: ticked).isEmpty || viewModel.hasUnreachable(ticked: ticked) {
                    Section { callBar.plainListRow() }
                }

                Section {
                    PainScaleButtons(pain: $pain, label: viewModel.painTitle)
                        .frame(maxWidth: .infinity)
                        .plainListRow()
                } header: {
                    ListSectionHeader(title: viewModel.painTitle)
                } footer: {
                    // in the footer so the row's round corners never clip it
                    HStack {
                        Text(viewModel.painLow)
                        Spacer()
                        Text(viewModel.painHigh)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .accessibilityHidden(true)
                }

                // 91, the papers' own warning signs as tick boxes
                if !viewModel.signs.isEmpty {
                    Section {
                        ForEach(viewModel.signs) { sign in
                            let isOn = ticked.contains(sign.text)
                            Button {
                                Motion.perform(reduceMotion) {
                                    if isOn { ticked.remove(sign.text) } else { ticked.insert(sign.text) }
                                }
                            } label: {
                                ListRow(title: sign.text) { EmptyView() }
                                    .leadingMark(isOn ? "checkmark.circle.fill" : "circle", isOn: isOn)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    } header: {
                        ListSectionHeader(title: viewModel.signsHeader)
                    } footer: {
                        Text(viewModel.signsFooter).font(.footnote).foregroundStyle(Color.ink2)
                    }
                }

                Section {
                    TextField(viewModel.notePlaceholder2, text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($noteFocused)
                        .frame(minHeight: Spacing.minTarget)
                } header: {
                    ListSectionHeader(title: viewModel.noteHeader)
                }

                Section {
                    Button { isAddingPhoto = true } label: {
                        ListRow(symbol: "photo", title: viewModel.photoTitle, subtitle: viewModel.photoDetail, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } footer: {
                    Text(viewModel.painFooter)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                }

                if viewModel.showsPainCall(pain), let call = viewModel.worriedCall, let phone = call.phoneURL {
                    Section {
                        SecondaryButton(title: viewModel.callOfficeTitle, symbol: "phone.fill") { openURL(phone) }
                            .plainListRow()
                    }
                }
            }
            .remedyList()
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $isAddingPhoto) { PhotoQuickAddSheet(note: note) }
            .sheet(isPresented: $isAddingNumber) { HelpView() }
            .navigationTitle(viewModel.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelTitle) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saved ? viewModel.doneTitle : viewModel.saveShort, action: save)
                        .fontWeight(.semibold)
                        .disabled(pain == nil)
                        .accessibilityHint(pain == nil ? "Pick a pain number first." : "")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { noteFocused = false }
                }
            }
            .sensoryFeedback(.success, trigger: saved) { _, new in new }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    // MARK: - Call bar

    private var callBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.calls(ticked: ticked)) { call in
                Label(viewModel.tickedEyebrow(call.reason), systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dangerInk)
                if let first = viewModel.signs.first(where: { ticked.contains($0.text) && $0.phone == call.phoneText.filter(\.isNumber) })
                    ?? viewModel.signs.first(where: { ticked.contains($0.text) }) {
                    Text(viewModel.paperSays(first.text))
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let url = call.phoneURL {
                    Button { openURL(url) } label: {
                        Label("\(viewModel.callTitle) \(call.phoneText)", systemImage: "phone.fill")
                    }
                    .buttonStyle(RemedyButtonStyle(kind: .destructive))
                }
            }
            if viewModel.hasUnreachable(ticked: ticked) {
                let unreached = viewModel.signs.filter { ticked.contains($0.text) && ($0.phone ?? "").isEmpty }
                Label(viewModel.tickedEyebrow(PlainText.list(unreached.map(\.text))), systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dangerInk)
                if let sign = unreached.first {
                    Text(viewModel.paperSays(sign.text)).font(.body).foregroundStyle(Color.ink)
                }
                if let office = viewModel.worriedCall?.phoneURL {
                    Button { openURL(office) } label: { Label(viewModel.callOfficeInstead, systemImage: "phone.fill") }
                        .buttonStyle(RemedyButtonStyle(kind: .destructive))
                } else {
                    Button { isAddingNumber = true } label: { Label(viewModel.addNumberTitle, systemImage: "phone.fill") }
                        .buttonStyle(RemedyButtonStyle(kind: .destructive))
                }
            }
        }
        .padding(Spacing.insideCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tone.stop.soft, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Save

    private func save() {
        guard let pain else { return }
        if saved {
            dismiss()
            return
        }
        noteFocused = false
        viewModel.save(pain: pain, ticked: ticked, note: note, in: context)
        Motion.perform(reduceMotion) { saved = true }
        // close on its own unless a sign is ticked and the call bar should stay
        if ticked.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                dismiss()
            }
        }
    }

    private func load() {
        guard let today = viewModel.today(in: context) else { return }
        pain = today.pain
        ticked = Set(today.signs)
        note = today.note
    }
}

// MARK: - Pain 0 to 10

// two rows of number buttons, the selected one filled, adjustable for VoiceOver
struct PainScaleButtons: View {
    @Binding var pain: Int?
    let label: String
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = Spacing.painButton

    var body: some View {
        VStack(spacing: 10) {
            // one row of numbers each at accessibility sizes would run off the side, so they wrap
            // both rows centered so 6 to 10 sits under the middle of 0 to 5
            FlowLayout(spacing: 8, centered: true) { ForEach(0...5, id: \.self) { number($0) } }
            FlowLayout(spacing: 8, centered: true) { ForEach(6...10, id: \.self) { number($0) } }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: pain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pain")
        .accessibilityValue(pain.map { "\($0) of 10" } ?? "Not picked")
        .accessibilityHint("Swipe up or down to change. 0 is no pain, 10 is the worst.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pain = min((pain ?? -1) + 1, 10)
            case .decrement: pain = max((pain ?? 1) - 1, 0)
            @unknown default: break
            }
        }
    }

    private func number(_ value: Int) -> some View {
        let selected = pain == value
        return Button { pain = value } label: {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(selected ? Color.onAccent : Color.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(selected ? Color.accentFill : Color.surface2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

