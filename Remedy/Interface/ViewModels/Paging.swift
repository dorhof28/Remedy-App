//
//  Paging.swift
//  Remedy
//
//  splits a list into pages so simple doesnt scroll
//

import Foundation

struct Paging {
    let count: Int
    let perPage: Int
    let page: Int               // 0 = first page (kept inside the real pages)

    init(count: Int, perPage: Int, page: Int) {
        self.count = count
        self.perPage = max(perPage, 1)
        let last = max((count - 1) / max(perPage, 1), 0)
        self.page = min(max(page, 0), last)
    }

    var pageCount: Int { max((count + perPage - 1) / perPage, 1) }
    var range: Range<Int> { (page * perPage)..<min((page + 1) * perPage, count) }
    var hasNext: Bool { page + 1 < pageCount }
    var hasPrevious: Bool { page > 0 }
    var showsButtons: Bool { pageCount > 1 }
    var pageText: String { "Page \(page + 1) of \(pageCount)" }
}
