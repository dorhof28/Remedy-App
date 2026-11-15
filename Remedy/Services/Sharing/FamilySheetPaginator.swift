//
//  FamilySheetPaginator.swift
//  Remedy
//
//  splits a long printed sheet over pages so nothing is cut off
//

import Foundation

// splits a sheet into pages so no block is cut in half
enum FamilySheetPaginator {

    // room for the blocks in one column under the header and above the footer
    static let pageBody: CGFloat = 728 - 150
    static let coverLineHeight: CGFloat = 20
    static let blockGap: CGFloat = 14
    static let blockHeader: CGFloat = 21

    // every page of the document with "Page 1 of 3" on each
    static func pages(for sheet: FamilySheet) -> [FamilySheet] {
        let all = ([sheet] + sheet.more).flatMap { split($0) }
        guard all.count > 1 else { return all }
        return all.enumerated().map { index, page in
            var page = page
            page.pageText = "Page \(index + 1) of \(all.count)"
            return page
        }
    }

    // one sheet becomes one or more pages with the same top
    static func split(_ sheet: FamilySheet) -> [FamilySheet] {
        let cover = sheet.cover.isEmpty ? 0 : CGFloat(sheet.cover.count) * coverLineHeight + 24
        let room = pageBody - cover
        let left = fill(sheet.left, room: room)
        let right = fill(sheet.right, room: room)
        let count = max(1, left.count, right.count)
        return (0..<count).map { index in
            var page = sheet
            page.left = index < left.count ? left[index] : []
            page.right = index < right.count ? right[index] : []
            page.more = []
            if index > 0 { page.title = sheet.title + " (continued)" }
            return page
        }
    }

    // fills pages top down, a long block carries on at the top of the next page
    static func fill(_ blocks: [FamilyBlock], room: CGFloat) -> [[FamilyBlock]] {
        var pages: [[FamilyBlock]] = [[]]
        var remaining = room
        for block in blocks {
            var lines = block.lines
            var isContinued = false
            while true {
                let title = isContinued ? block.title + " (continued)" : block.title
                let more = block.moreText
                let whole = height(lines, hasMore: !more.isEmpty)
                if whole <= remaining {
                    pages[pages.count - 1].append(make(block, title, lines, more))
                    remaining -= whole + blockGap
                    break
                }
                // how many lines fit under the heading
                var fit = 0
                var used = blockHeader
                for line in lines {
                    let next = used + lineHeight(line)
                    if next > remaining { break }
                    used = next
                    fit += 1
                }
                let isTopOfPage = pages[pages.count - 1].isEmpty
                if fit >= 2 || (fit >= 1 && isTopOfPage) || (isTopOfPage && fit == 0) {
                    let take = max(1, fit)
                    pages[pages.count - 1].append(make(block, title, Array(lines.prefix(take)), ""))
                    lines = Array(lines.dropFirst(take))
                    isContinued = true
                    if lines.isEmpty { remaining -= used + blockGap; break }
                }
                // the rest starts a fresh page
                pages.append([])
                remaining = room
            }
        }
        return pages.count > 1 && pages.last?.isEmpty == true ? Array(pages.dropLast()) : pages
    }

    private static func make(_ block: FamilyBlock, _ title: String, _ lines: [FamilyLine], _ more: String) -> FamilyBlock {
        FamilyBlock(title: title, symbol: block.symbol, tone: block.tone, lines: lines, moreText: more)
    }

    // how tall a block's lines are on paper
    static func height(_ lines: [FamilyLine], hasMore: Bool) -> CGFloat {
        blockHeader + lines.reduce(0) { $0 + lineHeight($1) } + (hasMore ? 17 : 0)
    }

    // worst case wrapping in a half page column
    static func lineHeight(_ line: FamilyLine) -> CGFloat {
        let titleChars = line.hasCheckbox ? 30 : 34
        let detailChars = line.hasCheckbox ? 38 : 42
        let titleRows = min(4, max(1, Int((Double(line.title.count) / Double(titleChars)).rounded(.up))))
        let detailRows = line.detail.isEmpty ? 0 : min(4, Int((Double(line.detail.count) / Double(detailChars)).rounded(.up)))
        return CGFloat(titleRows) * 18 + (detailRows > 0 ? CGFloat(detailRows) * 15 + 1 : 0) + 6
    }
}
