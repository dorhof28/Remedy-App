//
//  PhotoTrackViewModel.swift
//  Remedy
//
//  photo timeline logic shared by both looks
//  Remedy never comments on the photos
//

import SwiftUI
import SwiftData
import UIKit
import ImageIO

// one photo series: adding, picking, comparing and sharing photos
@Observable
final class PhotoTrackViewModel {

    let track: PhotoTrack

    // the photos picked to compare or share
    var selectedIDs: Set<UUID> = []

    init(track: PhotoTrack) {
        self.track = track
    }

    // MARK: - Words

    static let listTitle = "Photo log"
    static let namePrompt = "What do you want to watch?"
    static let noComment = "Remedy does not look at or comment on your photos. Show them to your care team."

    var title: String { track.name }

    // MARK: - Check-in link

    // "Check-in: pain 3 of 10 · note"
    static func checkInText(_ checkIn: CheckIn) -> String {
        let note = checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["Check-in: pain \(checkIn.pain) of 10", note].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    static func latest(_ entries: [PhotoEntry], limit: Int = 6) -> [PhotoEntry] {
        Array(entries.sorted { $0.takenAt > $1.takenAt }.prefix(limit))
    }

    // small picture so a strip of them stays light, cached and never full size
    static func thumbnail(_ entry: PhotoEntry, side: CGFloat = 160) -> UIImage? {
        let key = PhotoImageCache.key(entry.id, side)
        if let hit = PhotoImageCache.cache.object(forKey: key) { return hit }
        guard let data = entry.imageData, let image = PhotoImageCache.downsample(data, maxPixel: side) else { return nil }
        PhotoImageCache.store(image, for: key)
        return image
    }

    // same picture made off the main thread
    static func loadImage(_ entry: PhotoEntry, maxPixel: CGFloat) async -> UIImage? {
        let key = PhotoImageCache.key(entry.id, maxPixel)
        if let hit = PhotoImageCache.cache.object(forKey: key) { return hit }
        guard let data = entry.imageData else { return nil }
        let image = await Task.detached(priority: .userInitiated) {
            PhotoImageCache.downsample(data, maxPixel: maxPixel)
        }.value
        if let image { PhotoImageCache.store(image, for: key) }
        return image
    }

    // MARK: - Entries

    // oldest first so progress reads left to right
    var entries: [PhotoEntry] { track.entries.sorted { $0.takenAt < $1.takenAt } }

    var selectedEntries: [PhotoEntry] { entries.filter { selectedIDs.contains($0.id) } }

    func isSelected(_ entry: PhotoEntry) -> Bool { selectedIDs.contains(entry.id) }

    func toggle(_ entry: PhotoEntry) {
        if selectedIDs.contains(entry.id) { selectedIDs.remove(entry.id) } else { selectedIDs.insert(entry.id) }
    }

    // compare needs exactly two
    var comparePair: (PhotoEntry, PhotoEntry)? {
        let picked = selectedEntries
        return picked.count == 2 ? (picked[0], picked[1]) : nil
    }

    func dateText(_ entry: PhotoEntry) -> String { Self.dateText(entry) }

    static func dateText(_ entry: PhotoEntry) -> String {
        entry.takenAt.formatted(date: .abbreviated, time: .shortened)
    }

    // days between two photos in words
    func gapText(_ first: PhotoEntry, _ second: PhotoEntry) -> String {
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: first.takenAt),
            to: Calendar.current.startOfDay(for: second.takenAt)).day ?? 0
        switch abs(days) {
        case 0: return "Same day"
        case 1: return "1 day apart"
        default: return "\(abs(days)) days apart"
        }
    }

    // sized for the screen not the camera
    func image(_ entry: PhotoEntry) -> UIImage? {
        PhotoTrackViewModel.thumbnail(entry, side: 1400)
    }

    // MARK: - Changes

    // a clean name or nil if empty
    static func cleanName(_ text: String) -> String? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    // a new series, nil when the name is empty
    @discardableResult
    static func addTrack(named text: String, in context: ModelContext) -> PhotoTrack? {
        guard let name = cleanName(text) else { return nil }
        let track = PhotoTrack(name: name)
        context.insert(track)
        context.saveNow()
        return track
    }

    // shrinks big photos so the app stays light
    static func jpegData(from image: UIImage, longestSide: CGFloat = 1600) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > longestSide else { return image.jpegData(compressionQuality: 0.8) }
        let scale = longestSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return small.jpegData(compressionQuality: 0.8)
    }

    @discardableResult
    func addPhoto(data: Data, note: String = "", takenAt: Date = Date(), in context: ModelContext) -> PhotoEntry {
        let entry = PhotoEntry(imageData: data, takenAt: takenAt,
                               note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(entry)
        entry.track = track
        context.saveNow()
        return entry
    }

    func delete(_ entry: PhotoEntry, in context: ModelContext) {
        selectedIDs.remove(entry.id)
        context.delete(entry)
        context.saveNow()
    }

    // MARK: - Share

    // one PDF page per photo, oldest first, with date and note
    func makePDF() -> URL? {
        Self.pdf(entries: selectedEntries, title: track.name)
    }

    // the picked photos as a pdf to share
    static func pdf(entries chosen: [PhotoEntry], title name: String) -> URL? {
        guard !chosen.isEmpty else { return nil }
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { pdf in
            for entry in chosen {
                pdf.beginPage()
                let head: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22)]
                let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15)]
                (name as NSString).draw(at: CGPoint(x: 40, y: 36), withAttributes: head)
                (Self.dateText(entry) as NSString).draw(at: CGPoint(x: 40, y: 68), withAttributes: body)
                var top: CGFloat = 96
                if !entry.note.isEmpty {
                    let rect = CGRect(x: 40, y: 92, width: 532, height: 40)
                    (entry.note as NSString).draw(in: rect, withAttributes: body)
                    top = 138
                }
                if let image = entry.imageData.flatMap({ UIImage(data: $0) }) {
                    let box = CGRect(x: 40, y: top, width: 532, height: 792 - top - 40)
                    let fit = min(box.width / image.size.width, box.height / image.size.height)
                    let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
                    image.draw(in: CGRect(origin: box.origin, size: size))
                }
            }
        }
        let safe = name.filter { $0.isLetter || $0.isNumber }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Photos-\(safe.isEmpty ? "track" : safe).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Remedy: photo pdf failed: \(error)")
            return nil
        }
    }
}

// the quick add sheet opened from the check-in, both looks
@Observable
final class PhotoQuickAddViewModel {

    static let title = "Add a photo"
    static let trackTitle = "What is it a photo of?"
    static let newTrackPrompt = "Something new, like incision"
    static let noteTitle = "Note (optional)"
    static let takeTitle = "Take a photo"
    static let chooseTitle = "Choose from library"

    // the track picked by the patient
    var selectedID: UUID?
    var newName = ""
    var note: String

    init(note: String = "") {
        self.note = note
    }

    // a typed new name wins, then the pick, then the track used last
    func track(in tracks: [PhotoTrack]) -> PhotoTrack? {
        if PhotoTrackViewModel.cleanName(newName) != nil { return nil }
        if let selectedID, let found = tracks.first(where: { $0.id == selectedID }) { return found }
        return tracks.max { lastUsed($0) < lastUsed($1) }
    }

    private func lastUsed(_ track: PhotoTrack) -> Date {
        track.entries.map(\.takenAt).max() ?? track.createdAt
    }

    // a photo needs a track to go in
    func canAdd(tracks: [PhotoTrack]) -> Bool {
        PhotoTrackViewModel.cleanName(newName) != nil || track(in: tracks) != nil
    }

    func isPicked(_ track: PhotoTrack, in tracks: [PhotoTrack]) -> Bool {
        self.track(in: tracks)?.id == track.id
    }

    // saves the photo and returns whether it went in
    @discardableResult
    func add(data: Data, tracks: [PhotoTrack], in context: ModelContext) -> Bool {
        let target = track(in: tracks) ?? PhotoTrackViewModel.addTrack(named: newName, in: context)
        guard let target else { return false }
        selectedID = target.id
        newName = ""
        PhotoTrackViewModel(track: target).addPhoto(data: data, note: note, in: context)
        return true
    }
}

// MARK: - Image cache

// small pictures made with ImageIO so the grid never decodes full size photos
enum PhotoImageCache {
    nonisolated(unsafe) static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    // the cache key for one photo at one size
    nonisolated static func key(_ id: UUID, _ side: CGFloat) -> NSString {
        "\(id.uuidString)-\(Int(side))" as NSString
    }

    // cached by pixel cost so the cache's memory limit works
    nonisolated static func store(_ image: UIImage, for key: NSString) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
    }

    // decodes a small copy straight from the file data so big photos never load whole
    nonisolated static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixel, 1)
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Photo log rules

// photos taken on one day
struct PhotoDayGroup: Identifiable, Equatable {
    let day: Date
    let title: String
    let entries: [PhotoEntry]
    var id: Date { day }

    static func == (a: PhotoDayGroup, b: PhotoDayGroup) -> Bool {
        a.day == b.day && a.entries.map(\.id) == b.entries.map(\.id)
    }
}

// pure words and grouping for the log, tested
enum PhotoLogLogic {

    static let addTitle = "Add photo"
    static let emptyLine = "No photos yet. Add your first one."
    static let compareInstruction = "Pick a before and an after photo."

    // Today, Yesterday, or Nov 7 (with the year when it is not this year)
    static func dayLabel(_ day: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: now)
        let style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day()
        return sameYear ? day.formatted(style) : day.formatted(style.year())
    }

    // newest day first, newest photo first inside a day
    static func groups(_ entries: [PhotoEntry], now: Date, calendar: Calendar = .current) -> [PhotoDayGroup] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.takenAt) }
        return byDay.keys.sorted(by: >).map { day in
            PhotoDayGroup(day: day, title: dayLabel(day, now: now, calendar: calendar),
                          entries: (byDay[day] ?? []).sorted { $0.takenAt > $1.takenAt })
        }
    }

    static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // "Nov 7"
    static func shortDate(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        dayLabel(calendar.startOfDay(for: date), now: now, calendar: calendar)
    }

    // "Pain 3" or nothing
    static func painChip(_ checkIn: CheckIn?) -> String? {
        guard let checkIn else { return nil }
        return "Pain \(checkIn.pain)"
    }

    // "Photo from Nov 7, pain 3, note text"
    static func accessibilityText(_ entry: PhotoEntry, checkIn: CheckIn?, now: Date, calendar: Calendar = .current) -> String {
        var parts = ["Photo from " + shortDate(entry.takenAt, now: now, calendar: calendar)]
        if let checkIn { parts.append("pain \(checkIn.pain)") }
        let note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { parts.append(note) }
        return parts.joined(separator: ", ")
    }

    // days between two photos in words
    static func gapText(_ first: Date, _ second: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first),
                                           to: calendar.startOfDay(for: second)).day ?? 0
        switch abs(days) {
        case 0: return "Same day"
        case 1: return "1 day apart"
        default: return "\(abs(days)) days apart"
        }
    }

    static func countText(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(count) photos"
    }

    // earlier photo first so before and after read in order
    static func beforeAfter(_ a: PhotoEntry, _ b: PhotoEntry) -> (before: PhotoEntry, after: PhotoEntry) {
        a.takenAt <= b.takenAt ? (a, b) : (b, a)
    }

    // check-in lookup once per day not once per photo
    static func checkInsByDay(_ checkIns: [CheckIn], calendar: Calendar = .current) -> [Date: CheckIn] {
        var result: [Date: CheckIn] = [:]
        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.createdAt)
            if let existing = result[day], existing.createdAt >= checkIn.createdAt { continue }
            result[day] = checkIn
        }
        return result
    }
}

// the log screen state shared by both looks
@Observable
final class PhotoLogViewModel {

    // UI state kept here so both looks behave the same
    var isPicking = false
    var selectedIDs: Set<UUID> = []

    func toggle(_ entry: PhotoEntry) {
        if selectedIDs.contains(entry.id) { selectedIDs.remove(entry.id) } else { selectedIDs.insert(entry.id) }
    }

    func isSelected(_ entry: PhotoEntry) -> Bool { selectedIDs.contains(entry.id) }

    func endPicking() {
        isPicking = false
        selectedIDs = []
    }

    func picked(from entries: [PhotoEntry]) -> [PhotoEntry] {
        entries.filter { selectedIDs.contains($0.id) }.sorted { $0.takenAt < $1.takenAt }
    }

    // the first and last picked photo, for side by side
    func comparePair(from entries: [PhotoEntry]) -> (before: PhotoEntry, after: PhotoEntry)? {
        let list = picked(from: entries)
        return list.count == 2 ? (list[0], list[1]) : nil
    }

    func delete(_ entry: PhotoEntry, in context: ModelContext) {
        selectedIDs.remove(entry.id)
        context.delete(entry)
        context.saveNow()
    }

    func pdf(from entries: [PhotoEntry]) -> URL? {
        PhotoTrackViewModel.pdf(entries: picked(from: entries), title: "Photo log")
    }
}
