//
//  PhotoLogParts.swift
//  Remedy
//
//  thumbnail, full screen viewer and compare used by both looks
//

import SwiftUI
import SwiftData

// a square picture made small off the main thread, shows a calm box while it loads
struct PhotoThumbView: View {
    let entry: PhotoEntry
    // pixels of the longest side, kept the same so the cache is reused
    var pixels: CGFloat = 360
    var corner: CGFloat = 10

    // UI only
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemFill)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .task(id: entry.id) {
                image = PhotoImageCache.cache.object(forKey: PhotoImageCache.key(entry.id, pixels))
                if image == nil { image = await PhotoTrackViewModel.loadImage(entry, maxPixel: pixels) }
            }
    }
}

// MARK: - Full screen viewer

// a photo that pinches to zoom
private struct PhotoZoomImage: View {
    let entry: PhotoEntry

    // UI only
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var settled: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(zoom)
                    .gesture(settled > 1 ? pan : nil)
                    .onTapGesture(count: 2) { reset(zoomed: settled == 1) }
                    .accessibilityAddTraits(.isImage)
                    .accessibilityAction(named: "Zoom") { reset(zoomed: settled == 1) }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: entry.id) { image = await PhotoTrackViewModel.loadImage(entry, maxPixel: 1800) }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { scale = min(max(settled * $0.magnification, 1), 5) }
            .onEnded { _ in
                settled = scale
                if settled <= 1 { reset(zoomed: false) }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { offset = CGSize(width: settledOffset.width + $0.translation.width,
                                         height: settledOffset.height + $0.translation.height) }
            .onEnded { _ in settledOffset = offset }
    }

    // double tap zooms in or back to fit
    private func reset(zoomed: Bool) {
        withAnimation(.snappy) {
            scale = zoomed ? 2.5 : 1
            settled = scale
            offset = .zero
            settledOffset = .zero
        }
    }
}

// one page: picture, date, check-in line and a note field
private struct PhotoViewerPage: View {
    let entry: PhotoEntry
    let checkIn: CheckIn?

    @Environment(\.modelContext) private var context
    // UI only
    @State private var note: String
    @FocusState private var focused: Bool

    init(entry: PhotoEntry, checkIn: CheckIn?) {
        self.entry = entry
        self.checkIn = checkIn
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        VStack(spacing: 12) {
            PhotoZoomImage(entry: entry)
                .accessibilityLabel(PhotoLogLogic.accessibilityText(entry, checkIn: checkIn, now: AppClock.now()))
            VStack(alignment: .leading, spacing: 6) {
                Text(PhotoTrackViewModel.dateText(entry)).font(.headline)
                if let track = entry.track?.name, !track.isEmpty {
                    Text(track).font(.subheadline).foregroundStyle(.secondary)
                }
                if let checkIn {
                    Text(PhotoTrackViewModel.checkInText(checkIn))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                TextField("Add a note", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { save() }
                    .onChange(of: focused) { _, isFocused in if !isFocused { save() } }
                    .padding(12)
                    .frame(minHeight: 44)
                    .remedyFieldBackground(focused: focused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 8)
        }
    }

    private func save() {
        let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean != entry.note else { return }
        entry.note = clean
        context.saveNow()
    }
}

// full screen photos, swipe between them
struct PhotoViewer: View {
    let startID: UUID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoEntry.takenAt, order: .reverse) private var entries: [PhotoEntry]
    @Query private var checkIns: [CheckIn]

    // UI only
    @State private var currentID: UUID?
    @State private var isConfirmingDelete = false

    var body: some View {
        let byDay = PhotoLogLogic.checkInsByDay(checkIns)
        NavigationStack {
            TabView(selection: $currentID) {
                ForEach(entries) { entry in
                    PhotoViewerPage(entry: entry, checkIn: byDay[Calendar.current.startOfDay(for: entry.takenAt)])
                        .tag(Optional(entry.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(current.map { PhotoLogLogic.shortDate($0.takenAt, now: AppClock.now()) } ?? "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    if let current, let image = PhotoTrackViewModel.thumbnail(current, side: 1400) {
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview("Photo from \(PhotoTrackViewModel.dateText(current))", image: Image(uiImage: image))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete photo", role: .destructive) { deleteCurrent() }
                Button("Keep", role: .cancel) {}
            }
        }
        .onAppear { currentID = startID }
        .onChange(of: entries.isEmpty) { _, empty in if empty { dismiss() } }
    }

    private var current: PhotoEntry? { entries.first { $0.id == currentID } }

    private func deleteCurrent() {
        guard let current, let index = entries.firstIndex(where: { $0.id == current.id }) else { return }
        let next = entries.indices.contains(index + 1) ? entries[index + 1] : (index > 0 ? entries[index - 1] : nil)
        currentID = next?.id
        context.delete(current)
        context.saveNow()
    }
}

// MARK: - Compare

// two photos side by side or with a slider
struct PhotoCompareView: View {
    let before: PhotoEntry
    let after: PhotoEntry

    @Environment(\.dismiss) private var dismiss
    // UI only
    @State private var mode: Mode = .sideBySide
    @State private var split: CGFloat = 0.5
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    private enum Mode: String, CaseIterable, Identifiable {
        case sideBySide = "Side by side"
        case slider = "Slider"
        var id: String { rawValue }
    }

    init(first: PhotoEntry, second: PhotoEntry) {
        let pair = PhotoLogLogic.beforeAfter(first, second)
        before = pair.before
        after = pair.after
    }

    private var now: Date { AppClock.now() }
    private var beforeLabel: String { "Before \u{00B7} " + PhotoLogLogic.shortDate(before.takenAt, now: now) }
    private var afterLabel: String { "After \u{00B7} " + PhotoLogLogic.shortDate(after.takenAt, now: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text(PhotoLogLogic.gapText(before.takenAt, after.takenAt))
                        .font(.headline)

                    switch mode {
                    case .sideBySide: sideBySide
                    case .slider: slider
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                // the photos are saved models so they are read on the main actor, the decoding runs off it
                beforeImage = await PhotoTrackViewModel.loadImage(before, maxPixel: 1400)
                afterImage = await PhotoTrackViewModel.loadImage(after, maxPixel: 1400)
            }
        }
    }

    private var sideBySide: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) { side(before, beforeImage, beforeLabel); side(after, afterImage, afterLabel) }
            VStack(spacing: 14) { side(before, beforeImage, beforeLabel); side(after, afterImage, afterLabel) }
        }
    }

    private func side(_ entry: PhotoEntry, _ image: UIImage?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(label)
            Text(label).font(.subheadline.bold())
            if !entry.note.isEmpty { Text(entry.note).font(.footnote).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var slider: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    fill(afterImage)
                    fill(beforeImage)
                        .mask(alignment: .leading) { Rectangle().frame(width: width * split) }
                    Rectangle().fill(.white).frame(width: 3)
                        .shadow(radius: 2)
                        .offset(x: width * split - 1.5)
                    Circle().fill(.white).frame(width: 44, height: 44)
                        .shadow(radius: 3)
                        .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(.black))
                        .offset(x: width * split - 22)
                }
                .frame(width: width, height: proxy.size.height)
                .overlay(alignment: .topLeading) { chip(beforeLabel).padding(8) }
                .overlay(alignment: .topTrailing) { chip(afterLabel).padding(8) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / max(width, 1), 0), 1) })
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel("\(beforeLabel) and \(afterLabel)")
            .accessibilityValue("\(Int(split * 100)) percent before")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: split = min(split + 0.1, 1)
                case .decrement: split = max(split - 0.1, 0)
                @unknown default: break
                }
            }
            Text("Drag to compare").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func fill(_ image: UIImage?) -> some View {
        Color(.secondarySystemFill)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFill() } else { ProgressView() }
            }
            .clipped()
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.65), in: Capsule())
    }
}
