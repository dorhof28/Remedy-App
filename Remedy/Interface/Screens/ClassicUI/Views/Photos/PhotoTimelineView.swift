//
//  PhotoTimelineView.swift
//  Remedy
//
//  classic photo log: photos by day in a grid, viewer, compare and share
//

import SwiftUI
import SwiftData

// every photo by day
struct PhotoTimelineView: View {

    @Query(sort: \PhotoEntry.takenAt, order: .reverse) private var entries: [PhotoEntry]
    @Query private var checkIns: [CheckIn]
    @Environment(\.dynamicTypeSize) private var typeSize

    // UI only
    @State private var model = PhotoLogViewModel()
    @State private var isAdding = false
    @State private var isComparing = false
    @State private var viewing: ViewerTarget?
    @State private var pdfURL: URL?

    private struct ViewerTarget: Identifiable { let id: UUID }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 2 : 3)
    }

    var body: some View {
        let now = AppClock.now()
        let byDay = PhotoLogLogic.checkInsByDay(checkIns)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.betweenCards) {
                if entries.isEmpty {
                    GroupedCard {
                        Button { isAdding = true } label: {
                            ItemRow(kind: .custom(symbol: "camera", tone: .neutral), title: PhotoLogLogic.addTitle,
                                    detail: PhotoLogLogic.emptyLine) { Chevron() }
                        }
                        .buttonStyle(.plain)
                    }
                    Text(PhotoTrackViewModel.noComment)
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                        .padding(.horizontal, 4)
                } else {
                    ListHeader(title: "All photos", trailing: "Kept only in Remedy")
                    ForEach(PhotoLogLogic.groups(entries, now: now)) { group in
                        ListHeader(title: group.title, trailing: PhotoLogLogic.countText(group.entries.count))
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(group.entries) { entry in
                                cell(entry, checkIn: byDay[group.day], now: now)
                            }
                        }
                        .padding(8)
                        .cardStyle()
                    }
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .remedyBackground()
        .navigationTitle(PhotoTrackViewModel.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // select to compare or share, and the camera, share one capsule
            ToolbarItemGroup(placement: .topBarTrailing) {
                if entries.count >= 2 || model.isPicking {
                    if model.isPicking {
                        Button("Cancel") { model.endPicking() }
                    } else {
                        Button { model.isPicking = true } label: {
                            Label("Select to compare or share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                Button { isAdding = true } label: {
                    Label(PhotoLogLogic.addTitle, systemImage: "camera")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { if model.isPicking { pickBar } }
        .sheet(isPresented: $isAdding) { PhotoQuickAddSheet() }
        .sheet(isPresented: $isComparing) {
            if let pair = model.comparePair(from: entries) {
                PhotoCompareView(first: pair.before, second: pair.after)
            }
        }
        .fullScreenCover(item: $viewing) { PhotoViewer(startID: $0.id) }
        .task(id: model.selectedIDs) { pdfURL = model.pdf(from: entries) }
    }

    private func cell(_ entry: PhotoEntry, checkIn: CheckIn?, now: Date) -> some View {
        Button {
            if model.isPicking { model.toggle(entry) } else { viewing = ViewerTarget(id: entry.id) }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { PhotoThumbView(entry: entry) }
                .overlay(alignment: .bottomLeading) {
                    badge(PhotoLogLogic.timeText(entry.takenAt), note: !entry.note.isEmpty).padding(4)
                }
                .overlay(alignment: .topTrailing) {
                    if let pain = PhotoLogLogic.painChip(checkIn) { badge(pain, note: false).padding(4) }
                }
                .overlay {
                    if model.isPicking {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(model.isSelected(entry) ? Color.accentInk : .clear, lineWidth: 4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if model.isPicking {
                        Image(systemName: model.isSelected(entry) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(.white, model.isSelected(entry) ? Color.accentFill : Color.black.opacity(0.4))
                            .padding(6)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PhotoLogLogic.accessibilityText(entry, checkIn: checkIn, now: now))
        .accessibilityHint(model.isPicking ? "Picks this photo" : "Opens the photo")
        .accessibilityAddTraits(model.isSelected(entry) ? [.isButton, .isSelected] : .isButton)
    }

    private func badge(_ text: String, note: Bool) -> some View {
        HStack(spacing: 3) {
            Text(text).lineLimit(1).minimumScaleFactor(0.7)
            if note { Image(systemName: "text.bubble.fill") }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(.black.opacity(0.65), in: Capsule())
    }

    // pick two to compare or any to share
    private var pickBar: some View {
        VStack(spacing: 10) {
            Text(model.selectedIDs.isEmpty ? PhotoLogLogic.compareInstruction : PhotoLogLogic.compareInstruction + " " + PhotoLogLogic.countText(model.selectedIDs.count) + " picked.")
                .font(.subheadline).foregroundStyle(Color.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Button { isComparing = true } label: {
                    Label("Compare", systemImage: "square.split.2x1")
                }
                .buttonStyle(RemedyButtonStyle(kind: .primary))
                .disabled(model.comparePair(from: entries) == nil)

                if let pdfURL, !model.selectedIDs.isEmpty {
                    ShareLink(item: pdfURL, subject: Text("Photo log")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(RemedyButtonStyle(kind: .secondary))
                } else {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, Spacing.screenEdge).padding(.vertical, 10)
        .background(.bar)
    }
}
