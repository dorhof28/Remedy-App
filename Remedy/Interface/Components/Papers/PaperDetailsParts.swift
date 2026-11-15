//
//  PaperDetailsParts.swift
//  Remedy
//
//  the choice rows, the doctor kind list and the before or after question
//  of "About this paper", used by both looks
//

import SwiftUI

// one choice with a tick, drawn with the same option card as every other list
struct DetailChoiceRow: View {
    let title: String
    var detail: String = ""
    let symbol: String?
    let isChosen: Bool
    var isSimple = false
    let action: () -> Void

    var body: some View {
        OptionCards(items: [OptionItem(id: title, symbol: symbol ?? "circle", title: title, subtitle: detail,
                                       isSelected: isChosen)],
                    isSimple: isSimple) { _ in action() }
    }
}

// MARK: - Before or after

// what the rules decided about before or after surgery, the patient can change it
struct PaperKindQuestion: View {
    @Bindable var viewModel: ScanFlowViewModel
    var isSimple = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(viewModel.kindNote, systemImage: "text.magnifyingglass")
                .font(isSimple ? .title3 : .subheadline)
                .foregroundStyle(.secondary)
            OptionCards(items: viewModel.paperItems, isSimple: isSimple) { viewModel.pickPaper($0) }
        }
    }
}
