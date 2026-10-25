//
//  SimpleHelpView.swift
//  Remedy
//
//  simple get help and warning signs
//

import SwiftUI
import SwiftData

struct SimpleHelpView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only is the full list of numbers open
    @State private var isShowingAllNumbers = false

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        SimpleScreen(title: viewModel.title) {
            if let url = viewModel.emergencyURL {
                Link(destination: url) {
                    Label(viewModel.emergencyTitle, systemImage: "phone.fill")
                        .font(.title.bold())
                }
                .buttonStyle(SimpleButtonStyle(kind: .danger, height: 84))
                .accessibilityHint(viewModel.emergencyDetail)
            }
            Text(viewModel.emergencyDetail)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.85)

            if viewModel.showsContacts {
                ForEach(viewModel.simpleContacts) { row in
                    SimpleCallButton(row: row)
                }
                if viewModel.showsAllNumbers {
                    Button(viewModel.allNumbersTitle) { isShowingAllNumbers = true }
                        .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                }
            } else {
                Text(viewModel.noContactsText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            NavigationLink(value: SimpleRoute.warningSigns) {
                Label(viewModel.warningButtonTitle, systemImage: "exclamationmark.triangle.fill")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))

            NavigationLink(value: SimpleRoute.shareWithFamily) {
                Label(viewModel.shareWithFamilyTitle, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))

            ReadAloudButton(title: "Read to me", text: viewModel.spokenHelp)
        }
        .sheet(isPresented: $isShowingAllNumbers) { HelpView() }
    }
}

// MARK: - Warning signs, on their own screen

// when to call
struct SimpleWarningSignsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        SimpleScreen(title: viewModel.warningTitle) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.warningSigns, id: \.self) { sign in
                    Label {
                        Text(sign)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Tone.caution.color)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            Text(viewModel.warningFootnote)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let row = viewModel.surgeonRow {
                SimpleCallButton(row: row)
            }
            ReadAloudButton(title: "Read to me", text: viewModel.spokenWarnings)
        }
    }
}

// MARK: - One big "tap to call" button

// big tap to call row
struct SimpleCallButton: View {
    let row: ContactRow

    var body: some View {
        if let url = row.phoneURL {
            Link(destination: url) {
                SimpleRowCard(title: row.name, subtitle: row.phoneText, status: "Tap to call",
                              tone: .info, showsChevron: false) {
                    Image(systemName: row.symbol)
                        .font(.title)
                        .foregroundStyle(Color.remedyTeal)
                        .frame(width: 44)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Call \(row.spokenLabel)")
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleHelpView() }
}
