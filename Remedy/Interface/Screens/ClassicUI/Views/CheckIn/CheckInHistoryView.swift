//
//  CheckInHistoryView.swift
//  Remedy
//
//  classic check-ins page: pain over time on top, then each day's check-in with its photos
//

import SwiftUI
import SwiftData
import Charts

// classic check-ins page: pain chart, photos and past days
struct CheckInHistoryView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query private var checkIns: [CheckIn]
    @Query(sort: \PhotoEntry.takenAt, order: .reverse) private var photos: [PhotoEntry]
    @Environment(\.dynamicTypeSize) private var typeSize

    // UI only which sheet or viewer is open
    @State private var isAddingPhoto = false
    @State private var isCheckingIn = false
    @State private var viewing: ViewerTarget?
    @State private var isSharing = false
    @State private var pastDay: Int?

    private struct ViewerTarget: Identifiable { let id: UUID }

    var body: some View {
        let now = AppClock.now()
        let points = CheckInViewModel.painPoints(checkIns)
        let notes = CheckInViewModel.notes(checkIns, plan: plans.first)
        let canCheckIn = (plans.first.flatMap { DoseSchedule.today(for: $0, now: now) } ?? 0) > 0
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // no chart until there is a check-in, the sentence says so
                    if !points.isEmpty { chart(points, now: now) }
                    Text(CheckInViewModel.trendSentence(points, now: now))
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                }
                .padding(.vertical, 8)
            } header: {
                ListSectionHeader(title: CheckInViewModel.painTitle)
            }
            Section {
                if !photos.isEmpty {
                    photoGrid.plainListRow()
                }
                Button { isAddingPhoto = true } label: {
                    ListRow(symbol: "camera", title: CheckInViewModel.addPhotoTitle)
                }
                .buttonStyle(.plain)
                if photos.count > 1 {
                    NavigationLink { PhotoTimelineView() } label: {
                        ListRow(symbol: "square.split.2x1", title: CheckInViewModel.comparePhotosTitle,
                                subtitle: PhotoLogLogic.countText(photos.count))
                    }
                }
            } header: {
                ListSectionHeader(title: CheckInViewModel.photosTitle)
            } footer: {
                Text(PhotoTrackViewModel.noComment).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                ForEach(notes, id: \.id) { note in
                    Button { pastDay = Int(note.id) } label: {
                        ListRow(symbol: "heart", title: note.title, subtitle: note.text, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                if canCheckIn {
                    Button { isCheckingIn = true } label: {
                        ListRow(symbol: ItemKind.checkIn.symbol, title: CheckInViewModel.checkInRowTitle)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                ListSectionHeader(title: CheckInViewModel.notesTitle)
            }
        }
        .remedyList()
        .navigationTitle(CheckInViewModel.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(CheckInViewModel.shareTitle) { isSharing = true }
            }
        }
        .sheet(isPresented: $isAddingPhoto) { PhotoQuickAddSheet() }
        .sheet(isPresented: $isSharing) { SharePlanSheet(startsOff: [.doseLog, .name]) }
        .sheet(isPresented: $isCheckingIn) {
            CheckInView(viewModel: CheckInViewModel(plan: plans.first, now: now))
        }
        .fullScreenCover(item: $viewing) { PhotoViewer(startID: $0.id) }
        .sheet(item: Binding(get: { pastDay.map(PastDay.init) }, set: { pastDay = $0?.id })) { day in
            if let checkIn = checkIns.first(where: { $0.day == day.id }) {
                PastCheckInSheet(checkIn: checkIn, plan: plans.first)
            }
        }
    }

    // newest photos three across, each with its weekday
    private var photoGrid: some View {
        let across = typeSize.isAccessibilitySize ? 2 : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: across), spacing: 10) {
            ForEach(photos.prefix(across * 2)) { entry in
                Button { viewing = ViewerTarget(id: entry.id) } label: {
                    Color.surface2
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { PhotoThumbView(entry: entry) }
                        .overlay(alignment: .bottomLeading) {
                            Text(entry.takenAt.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.cardBackground.opacity(0.85)))
                                .padding(8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PhotoLogLogic.accessibilityText(entry, checkIn: nil, now: AppClock.now()))
                .accessibilityHint("Opens the photo")
            }
        }
    }

    // MARK: - Pain chart

    // the chart always shows so the place is known, with a line of words until the first check-in
    private func chart(_ points: [CheckInPoint], now: Date) -> some View {
        Chart(points) { point in
            LineMark(x: .value("Day", point.date, unit: .day), y: .value("Pain", point.pain))
                .foregroundStyle(Color.accentInk)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Day", point.date, unit: .day), y: .value("Pain", point.pain))
                .foregroundStyle(Color.accentInk)
                .symbolSize(40)
                .annotation(position: .top) {
                    Text("\(point.pain)").font(.subheadline).foregroundStyle(Color.ink)
                }
        }
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(values: [0, 5, 10]) { _ in
                AxisGridLine().foregroundStyle(Color.hairline)
                AxisValueLabel().foregroundStyle(Color.ink2)
            }
        }
        .chartXAxis(points.isEmpty ? .hidden : .automatic)
        .chartYAxis(points.isEmpty ? .hidden : .automatic)
        .overlay {
            if points.isEmpty {
                Text(CheckInViewModel.chartEmpty)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        // short until there is something to draw
        .frame(height: points.isEmpty ? 70 : 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CheckInViewModel.chartSummary(points, now: now))
    }

}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { CheckInHistoryView() }
}

private struct PastDay: Identifiable { let id: Int }

// 99, one day's check-in read-only, Edit opens the check-in for that day
struct PastCheckInSheet: View {
    let checkIn: CheckIn
    let plan: CarePlan?

    @Query(sort: \PhotoEntry.takenAt) private var photos: [PhotoEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    private var dayDate: Date? {
        plan?.surgeryDate.map { DayMath.calendar.date(byAdding: .day, value: checkIn.day, to: DayMath.calendar.startOfDay(for: $0))! }
    }

    var body: some View {
        let dayPhotos = photos.filter { photo in dayDate.map { DayMath.calendar.isDate(photo.takenAt, inSameDayAs: $0) } ?? false }
        NavigationStack {
            List {
                Section {
                    ListRow(symbol: "clock", title: CheckInWords.savedAt(checkIn.createdAt),
                            subtitle: checkIn.editedAt.map { CheckInWords.editedAt($0) } ?? "")
                    ListRow(symbol: "heart", title: CheckInWords.pain, value: CheckInWords.painValue(checkIn.pain))
                    if checkIn.signs.isEmpty {
                        ListRow(symbol: "checkmark.circle", tone: .good, title: CheckInWords.signs, subtitle: CheckInWords.noneTicked)
                    } else {
                        ListRow(symbol: "exclamationmark.triangle", tone: .caution, title: CheckInWords.signs,
                                subtitle: PlainText.list(checkIn.signs))
                    }
                }
                if !checkIn.note.isEmpty {
                    Section {
                        Text("\u{201C}\(checkIn.note)\u{201D}").font(.body).foregroundStyle(Color.ink)
                    } header: {
                        ListSectionHeader(title: CheckInWords.note)
                    }
                }
                if !dayPhotos.isEmpty {
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(dayPhotos) { entry in
                                Color.surface2
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay { PhotoThumbView(entry: entry) }
                                    .overlay(alignment: .bottomLeading) {
                                        Text(entry.takenAt.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.headline).foregroundStyle(Color.ink).padding(8)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                            }
                        }
                        .plainListRow()
                    } header: {
                        ListSectionHeader(title: CheckInWords.photo)
                    }
                }
            }
            .remedyList()
            .navigationTitle(dayDate.map { DayMath.shortDate($0) } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(CheckInWords.done) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(CheckInWords.edit) { isEditing = true } }
            }
            .sheet(isPresented: $isEditing) {
                // that day's check-in sheet, the day comes from the date it is opened on
                CheckInView(viewModel: CheckInViewModel(plan: plan, now: (dayDate ?? AppClock.now()).addingTimeInterval(12 * 3600)))
            }
        }
        .presentationDetents([.large])
    }
}

// words on the check-in pages
enum CheckInWords {
    static let pain = "Pain"
    static func painValue(_ pain: Int) -> String { "\(pain) of 10" }
    static let signs = "Warning signs"
    static let noneTicked = "None ticked"
    static let note = "Note"
    static let photo = "Photo"
    static let done = "Done"
    static let edit = "Edit"
    // "Checked in at 9:12 AM", "Edited Tue, Nov 17"
    static func savedAt(_ date: Date) -> String { "Checked in at \(DayMath.timeText(of: date))" }
    static func editedAt(_ date: Date) -> String { "Edited \(DayMath.shortDate(date))" }
}
