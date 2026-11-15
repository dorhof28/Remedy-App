//
//  SimpleFamilyShareView.swift
//  Remedy
//
//  simple share plan (51, 102): big choices, one day or week picker, then the preview (103)
//

import SwiftUI
import SwiftData

// simple share plan
struct SimpleFamilyShareView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the kind, the day and what is left off
    @State private var choice: ShareChoice = .fullPlan
    @State private var day = AppClock.now()
    @State private var leftOff: Set<PrintPart> = FamilyShareViewModel.planStartsOff
    @State private var isPreviewing = false

    var body: some View {
        let viewModel = SharePlanViewModel(plan: plans.first, now: AppClock.now(), choice: choice, day: day, leftOff: leftOff)
        SimpleScreen(title: viewModel.title) {
            Text(viewModel.pickHeader)
                .font(.title3.weight(.semibold))
            VStack(spacing: 12) {
                ForEach(ShareChoice.allCases) { item in
                    Button { choice = item } label: {
                        HStack(spacing: 14) {
                            Image(systemName: choice == item ? "largecircle.fill.circle" : "circle")
                                .font(.title2)
                                .foregroundStyle(Color.accentInk)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.title3.weight(.semibold))
                                if let subtitle = item.subtitle {
                                    Text(subtitle).font(.body).foregroundStyle(Color.ink2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple, alignment: .leading)
                        .padding(.horizontal, Spacing.insideCard)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .cardStyle()
                    .accessibilityAddTraits(choice == item ? .isSelected : [])
                }
            }

            if viewModel.showsDayRow || viewModel.showsWeekRow || viewModel.showsPhonesSwitch || viewModel.printedName != nil {
                VStack(spacing: 0) {
                    if viewModel.showsDayRow || viewModel.showsWeekRow {
                        DatePicker(viewModel.showsWeekRow ? viewModel.weekTitle : viewModel.dayTitle,
                                   selection: $day, in: viewModel.dayRange, displayedComponents: .date)
                            .font(.title3.weight(.semibold))
                            .tint(Color.accentInk)
                            .frame(minHeight: Spacing.tapSimple)
                    }
                    if viewModel.showsPhonesSwitch {
                        bigToggle(.phones)
                    }
                    if viewModel.printedName != nil {
                        bigToggle(.name)
                    }
                }
                .padding(.horizontal, Spacing.insideCard)
                .cardStyle()
            }

            Button { isPreviewing = true } label: {
                Label(viewModel.makePDFTitle, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SimpleButtonStyle())
        }
        .navigationDestination(isPresented: $isPreviewing) {
            SharePreviewPage(viewModel: viewModel, isSimple: true)
        }
    }

    private func bigToggle(_ part: PrintPart) -> some View {
        Toggle(isOn: Binding(get: { !leftOff.contains(part) },
                             set: { if $0 { leftOff.remove(part) } else { leftOff.insert(part) } })) {
            Text(part.title).font(.title3)
        }
        .tint(Color.accentFill)
        .frame(minHeight: Spacing.tapSimple)
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleFamilyShareView() }
}
