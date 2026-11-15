//
//  SimpleFit.swift
//  Remedy
//
//  simple screens never scroll: the screen as it is, then a step smaller text at a time, then shrunk to fit
//  long lists already turn pages and details open on their own screen
//

import SwiftUI

// shrinks text a little before a simple page has to scroll
struct SimpleFit<Content: View>: View {
    let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(SimpleFitSteps.sizes(from: typeSize), id: \.self) { size in
                content
                    .dynamicTypeSize(size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            // nothing fit even at the smallest text, so the whole screen is drawn a little smaller
            ShrunkToFit { content.dynamicTypeSize(SimpleFitSteps.smallest) }
        }
    }
}

// the text sizes tried, the patient's own first
enum SimpleFitSteps {
    static let smallest: DynamicTypeSize = .large

    // never below the default size, a patient who picked big text still gets big text when it fits
    static func sizes(from start: DynamicTypeSize) -> [DynamicTypeSize] {
        let all = DynamicTypeSize.allCases
        guard let at = all.firstIndex(of: start), let floor = all.firstIndex(of: smallest), at > floor else { return [start] }
        return Array(all[floor...at].reversed())
    }
}

// draws the content at its full height then scales it down to the space
private struct ShrunkToFit<Content: View>: View {
    @ViewBuilder let content: Content
    // UI only the height the content wants
    @State private var wanted: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.height / max(wanted, 1))
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: proxy.size.width / scale, alignment: .top)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { wanted = $0 }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}
