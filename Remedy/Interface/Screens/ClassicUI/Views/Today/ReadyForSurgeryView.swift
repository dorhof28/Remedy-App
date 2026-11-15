//
//  ReadyForSurgeryView.swift
//  Remedy
//
//  classic ready for surgery, pushed from Today the day before: stops, eating and drinking, tonight, bring
//

import SwiftUI
import SwiftData

// classic ready for surgery list
struct ReadyForSurgeryView: View {
    let plan: CarePlan?

    @Environment(\.modelContext) private var context
    // UI only lines ticked on this screen, saved for today
    @State private var ticked: Set<String> = ChecklistStore.checked(now: AppClock.now())

    var body: some View {
        let list = ReadyList(plan: plan)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                if !list.lead.isEmpty {
                    Text(list.lead)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                        .padding(.horizontal, 4)
                }

                if !list.items.isEmpty {
                    ListHeader(title: list.medicinesHeader, symbol: "pill", tone: .good)
                    GroupedCard {
                        ForEach(list.items) { item in
                            HStack(spacing: 12) {
                                mark(for: item.status)
                                rowText(item.name, item.text)
                            }
                            .padding(.vertical, 10)
                            .frame(minHeight: Spacing.rowMin)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.spokenLabel)
                        }
                    }
                }

                if !list.foodLines.isEmpty {
                    ListHeader(title: list.foodHeader, symbol: "fork.knife", tone: .caution)
                    GroupedCard {
                        ForEach(list.foodLines, id: \.self) { line in
                            tickRow(id: ReadyList.tickID(line), title: line)
                        }
                    }
                }

                if !list.tonight.isEmpty {
                    ListHeader(title: list.tonightHeader, symbol: "moon", tone: .info)
                    GroupedCard {
                        ForEach(list.tonight) { task in taskRow(task) }
                    }
                }

                if !list.bring.isEmpty {
                    ListHeader(title: list.bringHeader, symbol: "bag", tone: .info)
                    GroupedCard {
                        ForEach(list.bring) { task in taskRow(task) }
                    }
                }

                Text(list.footer)
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .remedyBackground()
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Speaker.toggle(list.spokenText) } label: {
                    Label("Read to me", systemImage: "speaker.wave.2")
                }
            }
        }
    }

    private func rowText(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(Color.ink)
            if !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    // filled check when stopped on time, a warning when taken late, an open circle with no answer
    @ViewBuilder
    private func mark(for status: ReadyItem.Status) -> some View {
        switch status {
        case .stoppedOnTime:
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(Color.accentInk)
        case .tookLate:
            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(Color.cautionInk)
        case .noAnswer:
            Image(systemName: "questionmark.circle").font(.title).foregroundStyle(Color.ink3)
        }
    }

    private func tickRow(id: String, title: String) -> some View {
        let done = ticked.contains(id)
        return Button {
            ChecklistStore.setChecked(id, !done, now: AppClock.now())
            ticked = ChecklistStore.checked(now: AppClock.now())
        } label: {
            HStack(spacing: 12) {
                TodayTaskCheck(isDone: done, font: .title)
                rowText(title, "")
            }
            .padding(.vertical, 10)
            .frame(minHeight: Spacing.rowMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(done ? "Checked" : "Not checked")
        .sensoryFeedback(.success, trigger: done) { _, new in new }
    }

    private func taskRow(_ task: CareTask) -> some View {
        Button {
            TaskActions.toggle(task, now: AppClock.now(), in: context)
        } label: {
            HStack(spacing: 12) {
                TodayTaskCheck(isDone: task.isDone, font: .title)
                rowText(task.title, "")
            }
            .padding(.vertical, 10)
            .frame(minHeight: Spacing.rowMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.title)
        .accessibilityValue(task.isDone ? "Done" : "Not done")
        .sensoryFeedback(.success, trigger: task.isDone) { _, new in new }
    }
}
