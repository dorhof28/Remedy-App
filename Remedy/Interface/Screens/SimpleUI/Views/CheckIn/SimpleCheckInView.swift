//
//  SimpleCheckInView.swift
//  Remedy
//
//  simple look daily check-in, three short pages: pain, warning signs, a note
//

import SwiftUI
import SwiftData

// simple check-in, one question per page
struct SimpleCheckInView: View {
    let viewModel: CheckInViewModel

    private enum Field: Hashable { case note }
    private typealias Page = CheckInViewModel.SimplePage

    @Environment(\.modelContext) private var context
    // redraws the pain over the last days when a check-in is saved
    @Query private var checkIns: [CheckIn]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the answers before saving
    @State private var page: Page = .pain
    @State private var pain = 0
    @State private var ticked: Set<String> = []
    @State private var note = ""
    @State private var saved = false
    @FocusState private var focus: Field?

    var body: some View {
        SimpleScreen(title: viewModel.simpleTitle(page), showsBack: false,
                     readAloud: viewModel.simpleSpoken(page, pain: pain, ticked: ticked)) {
            Text(viewModel.simplePageText(page))
                .font(.headline)
                .foregroundStyle(Color.ink2)
                .accessibilityHidden(true)

            // a ticked sign keeps its call button on every page after it
            if page != .pain {
                callBars
            }

            Group {
                switch page {
                case .pain:
                    painPage
                    painTrend
                case .signs: signsPage
                case .note: notePage
                }
            }
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 0)
            bottomButtons
        } trailing: {
            Button(viewModel.simpleCloseTitle) { dismiss() }
                .buttonStyle(.plain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 20)
                .frame(minHeight: 56)
                .background(Capsule(style: .continuous).fill(Color.surface2))
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: saved) { _, new in new }
        .onAppear {
            if let today = viewModel.today(in: context) {
                pain = today.pain
                ticked = Set(today.signs)
                note = today.note
            }
        }
    }

    // MARK: - Pain

    // big number buttons, 0 to 5 then 6 to 10 centered under them, both end words on one line under it
    private var painPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            PainGrid(spacing: 8) { ForEach(0...10, id: \.self) { painButton($0) } }
            HStack {
                Text(viewModel.simpleNoPainText)
                Spacer(minLength: 12)
                Text(viewModel.simpleWorstText)
            }
            .padding(.top, 4)
        }
        .font(.body)
        .foregroundStyle(Color.ink2)
        .frame(maxWidth: .infinity)
        .padding(20)
        .simpleCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pain, \(pain) of 10")
        .accessibilityHint(viewModel.painScale)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: pain = min(10, pain + 1)
            case .decrement: pain = max(0, pain - 1)
            @unknown default: break
            }
        }
        .sensoryFeedback(.selection, trigger: pain)
    }

    // pain over the last days as plain big bars, each with its number and day
    @ViewBuilder
    private var painTrend: some View {
        let trend = SimpleCheckInTrend(checkIns: checkIns, surgeryDate: viewModel.plan?.surgeryDate)
        if trend.isShown {
            VStack(alignment: .leading, spacing: 12) {
                Text(SimpleCheckInTrend.title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(trend.points) { point in
                        VStack(spacing: 4) {
                            Text("\(point.pain)")
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(Color.ink)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentFill)
                                .frame(height: 12 + CGFloat(point.pain) * 9)
                            Text(point.label)
                                .font(.footnote)
                                .foregroundStyle(Color.ink2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(SimpleCheckInTrend.note)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .simpleCardStyle()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trend.spoken)
        }
    }

    private func painButton(_ number: Int) -> some View {
        let isOn = number == pain
        return Button { pain = number } label: {
            // a clear square sets the size, so every cell is the same width and round
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text("\(number)")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(isOn ? Color.onAccent : Color.ink)
                }
                .background(Circle().fill(isOn ? Color.accentFill : Color.surface2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Warning signs

    @ViewBuilder
    private var signsPage: some View {
        if viewModel.signs.isEmpty {
            Text(viewModel.noSignsText)
                .font(.title3)
                .foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(viewModel.signsHint)
                .font(.body)
                .foregroundStyle(Color.ink2)
            ForEach(viewModel.signs) { sign in
                signRow(sign)
            }
        }
    }

    // a big toggle row with a picture, ticked is red with a check
    private func signRow(_ sign: WarningSign) -> some View {
        let isOn = ticked.contains(sign.text)
        return Button { toggle(sign.text) } label: {
            HStack(spacing: 14) {
                Image(systemName: WarningSignPicture.symbol(for: sign.text))
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isOn ? Color.dangerInk : Color.ink2)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                Text(sign.text)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isOn ? Color.dangerInk : Color.ink3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple + 8, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                if isOn {
                    shape.fill(Color.dangerSoft).overlay(shape.strokeBorder(Color.dangerInk, lineWidth: 2))
                } else {
                    CardSurface(shape: shape)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // the number the paper names for what was ticked, 911 when it says so
    @ViewBuilder
    private var callBars: some View {
        ForEach(viewModel.calls(ticked: ticked)) { call in
            VStack(alignment: .leading, spacing: 10) {
                Label(viewModel.tickedEyebrow(call.reason), systemImage: "exclamationmark.triangle")
                    .font(.title3.bold())
                    .foregroundStyle(Color.dangerInk)
                Text(viewModel.signs.first { ticked.contains($0.text) }.map { viewModel.paperSays($0.text) } ?? call.reason)
                    .font(.title3)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = call.phoneURL {
                    Link(destination: url) {
                        Label("\(viewModel.callTitle) \(call.phoneText)", systemImage: "phone.fill")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .danger))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .simpleToneCard(.dangerSoft, edge: .dangerInk)
            .accessibilityElement(children: .contain)
        }
        if viewModel.hasUnreachable(ticked: ticked) {
            if let office = viewModel.worriedCall?.phoneURL {
                Link(destination: office) { Label(viewModel.callOfficeInstead, systemImage: "phone.fill") }
                    .buttonStyle(SimpleButtonStyle(kind: .danger))
            } else {
                Text("No phone number was found on your papers. Call your care team.")
                    .font(.title3.bold())
                    .foregroundStyle(Color.dangerInk)
            }
        }
    }

    // MARK: - Note and save

    @ViewBuilder
    private var notePage: some View {
        Text(viewModel.simpleNoteHint)
            .font(.body)
            .foregroundStyle(Color.ink2)
        TextField(viewModel.notePlaceholder, text: $note, axis: .vertical)
            .font(.title3)
            .lineLimit(3...6)
            .focused($focus, equals: .note)
            .padding(16)
            .frame(minHeight: 120, alignment: .topLeading)
            .remedyFieldBackground(focused: focus == .note)
            .accessibilityLabel(viewModel.noteTitle)

        // always there, signs picked by words can miss one
        if let call = viewModel.worriedCall, let url = call.phoneURL {
            Link(destination: url) {
                Label(viewModel.worriedTitle, systemImage: "phone")
            }
            .buttonStyle(SimpleButtonStyle(kind: .gray, height: 56))
            .accessibilityLabel("\(viewModel.worriedLine) \(call.phoneText)")
        } else {
            Text(viewModel.noNumberText)
                .font(.body)
                .foregroundStyle(Color.ink2)
        }

        if saved {
            Label(viewModel.savedText, systemImage: "checkmark.circle.fill")
                .font(.title3.bold())
                .foregroundStyle(Color.accentInk)
        }
    }

    // MARK: - Bottom

    // back and next, save on the last page
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if let previous = Page(rawValue: page.rawValue - 1) {
                Button {
                    focus = nil
                    Motion.perform(reduceMotion) { page = previous }
                } label: {
                    Label(viewModel.simpleBackTitle, systemImage: "chevron.left")
                }
                .buttonStyle(SimpleButtonStyle(kind: .gray))
            }
            if let next = Page(rawValue: page.rawValue + 1) {
                Button {
                    Motion.perform(reduceMotion) { page = next }
                } label: {
                    Label(viewModel.simpleNextTitle, systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(SimpleButtonStyle())
            } else if saved {
                Button(viewModel.doneTitle) { dismiss() }
                    .buttonStyle(SimpleButtonStyle())
            } else {
                Button {
                    focus = nil
                    viewModel.save(pain: pain, ticked: ticked, note: note, in: context)
                    Motion.perform(reduceMotion) { saved = true }
                } label: {
                    Label(viewModel.saveTitle, systemImage: "checkmark")
                }
                .buttonStyle(SimpleButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private func toggle(_ sign: String) {
        if ticked.contains(sign) { ticked.remove(sign) } else { ticked.insert(sign) }
    }
}

// six equal round cells a row, a short last row sits in the middle
struct PainGrid: Layout {
    var spacing: CGFloat = 8
    var columns = 6

    // one cell's side from the width the page gives
    private func side(_ width: CGFloat) -> CGFloat {
        max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let rows = (subviews.count + columns - 1) / columns
        let cell = side(width)
        return CGSize(width: width, height: CGFloat(rows) * cell + CGFloat(max(rows - 1, 0)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = side(bounds.width)
        for index in subviews.indices {
            let row = index / columns
            let inRow = min(columns, subviews.count - row * columns)
            // the space a short row leaves, split evenly on both sides
            let shift = CGFloat(columns - inRow) * (cell + spacing) / 2
            let x = bounds.minX + shift + CGFloat(index % columns) * (cell + spacing)
            let y = bounds.minY + CGFloat(row) * (cell + spacing)
            subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: cell, height: cell))
        }
    }
}
