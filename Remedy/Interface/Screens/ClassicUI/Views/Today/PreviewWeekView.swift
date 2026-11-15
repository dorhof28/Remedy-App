//
//  PreviewWeekView.swift
//  Remedy
//
//  classic preview of days 1 to 7 after surgery, pushed from Today, with a day strip and Back and Next
//

import SwiftUI

// classic first week preview
struct PreviewWeekView: View {
    @State private var viewModel: PreviewWeekViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(plan: CarePlan?) {
        _viewModel = State(initialValue: PreviewWeekViewModel(plan: plan))
    }

    var body: some View {
        let day = viewModel.current
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                strip

                ListHeader(title: viewModel.dayHeader)
                Group {
                    if day.isEmpty {
                        GroupedCard {
                            ItemRow(kind: .custom(symbol: "sun.max", tone: .neutral), title: viewModel.emptyText)
                        }
                    } else {
                        GroupedCard {
                            ForEach(day.medicines) { line in row(.medicine, line) }
                            ForEach(day.asNeeded) { line in row(.asNeeded, line) }
                            ForEach(day.rules) { line in row(.instruction, line) }
                            ForEach(day.visits) { line in row(.visit, line) }
                        }
                    }
                }
                .id(day.day)
                .transition(.opacity)

                Text(viewModel.footer)
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .remedyBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Speaker.toggle(viewModel.spokenLabel(for: day)) } label: {
                    Label("Read to me", systemImage: "speaker.wave.2")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { backNext }
    }

    // fri 20 to thu 26, tap a day
    private var strip: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.strip) { item in
                let selected = item.id == viewModel.index
                Button {
                    Motion.perform(reduceMotion) { viewModel.select(item.id) }
                } label: {
                    VStack(spacing: 2) {
                        Text(item.weekday).font(.caption.weight(.semibold))
                        Text(item.number).font(.title3.weight(.bold)).monospacedDigit()
                        Circle()
                            .fill(item.hasSomething ? Color.accentInk : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .foregroundStyle(selected ? Color.onAccent : Color.ink)
                    .frame(maxWidth: .infinity, minHeight: Spacing.tapMin + 16)
                    .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .fill(selected ? Color.accentFill : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.spokenLabel)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func row(_ kind: ItemKind, _ line: PreviewLine) -> some View {
        ItemRow(kind: kind, title: line.title, detail: line.detail)
            .accessibilityElement(children: .combine)
    }

    // "< Friday" and "Sunday >" capsules
    private var backNext: some View {
        HStack(spacing: 12) {
            Button {
                Motion.perform(reduceMotion) { viewModel.back() }
            } label: {
                Label(viewModel.backLabel.isEmpty ? viewModel.backTitle : viewModel.backLabel, systemImage: "chevron.left")
            }
            .buttonStyle(RemedyButtonStyle(kind: .plain))
            .disabled(viewModel.isFirst)

            Button {
                if viewModel.isLast { dismiss() } else { Motion.perform(reduceMotion) { viewModel.next() } }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.nextLabel)
                    if !viewModel.isLast { Image(systemName: "chevron.right") }
                }
            }
            .buttonStyle(RemedyButtonStyle(kind: .primary))
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
    }
}
