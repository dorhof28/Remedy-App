//
//  PaperSourcePicker.swift
//  Remedy
//
//  where the papers come from and, for photos and files, which papers they are
//  one view for both looks, in a sheet on the first screen or inline when adding papers
//

import SwiftUI

// the two parts, sources first then before or after surgery
struct PaperSourcePicker: View {
    @Bindable var viewModel: ScanFlowViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    private var isSimple: Bool { look == .simple }

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.asksPaperKind {
                kindPart
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                sourcePart
                    .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : Motion.standard, value: viewModel.asksPaperKind)
    }

    // MARK: - Sources

    // scanning is the one loud button, the rest is a plain list
    private var sourcePart: some View {
        let items = viewModel.intakeItems
        let camera = items.first { $0.id == PaperIntake.camera.rawValue }
        let others = items.filter { $0.id != PaperIntake.camera.rawValue }
        return VStack(alignment: .leading, spacing: 16) {
            if let camera {
                PrimaryButton(title: camera.title, symbol: "camera") { viewModel.chooseIntake(.camera) }
            }
            VStack(spacing: 0) {
                ForEach(others) { item in
                    if item.id != others.first?.id { Divider().padding(.leading, 60) }
                    Button {
                        if let source = PaperIntake(rawValue: item.id) { viewModel.chooseIntake(source) }
                    } label: {
                        ListRow(symbol: item.symbol, title: item.title, subtitle: item.subtitle, showsChevron: true)
                            .padding(.horizontal, Spacing.insideCard)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
            Label(viewModel.namesHiddenNote, systemImage: "eye.slash")
                .font(.subheadline)
                .foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Before or after surgery

    private var kindPart: some View {
        VStack(spacing: Spacing.betweenCards) {
            Text(viewModel.choosePaperTitle)
                .font(isSimple ? .title2.bold() : .title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            OptionCards(items: viewModel.paperItems.map { item in
                var plain = item
                plain.isSelected = nil
                return plain
            } + [OptionItem(id: "notSure", symbol: "text.magnifyingglass", title: viewModel.sortPapersTitle,
                            subtitle: viewModel.sortPapersDetail)], isSimple: isSimple) { id in
                switch id {
                case PaperKind.beforeSurgery.rawValue: viewModel.chooseKind(.before)
                case PaperKind.afterSurgery.rawValue: viewModel.chooseKind(.after)
                default: viewModel.chooseKind(.notSure)
                }
            }
        }
    }
}

// the sheet on the first screen and from Plan > Papers, only as tall as its choices
struct PaperSourceSheet: View {
    @Bindable var viewModel: ScanFlowViewModel

    @Environment(\.dismiss) private var dismiss
    // UI only the measured height so the sheet fits its content
    @State private var height: CGFloat = 520

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(viewModel.asksPaperKind ? viewModel.choosePaperTitle : viewModel.chooseSourceTitle)
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 8)
                    PaperSourcePicker(viewModel: viewModel)
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 16)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 70 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.screenBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.asksPaperKind {
                        Button(viewModel.backButton) { viewModel.goBack() }
                    } else {
                        Button(viewModel.cancelButton) { dismiss() }
                    }
                }
            }
        }
        .presentationDetents([.height(height), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.screenBackground)
    }
}

extension View {
}
