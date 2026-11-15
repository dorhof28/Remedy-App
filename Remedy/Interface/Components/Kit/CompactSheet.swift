//
//  CompactSheet.swift
//  Remedy
//
//  a sheet only as tall as its content, see material and a drag indicator
//
//  usage: .sheet(isPresented: $on) { MyShortContent().compactSheet() }
//  the content must be a plain stack (not a ScrollView) so it has its own height
//

import SwiftUI

// height of the content, read by the background
private struct CompactSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// sizes a sheet to its content
private struct CompactSheetModifier: ViewModifier {
    // let people tap the screen behind while the sheet is up
    let allowsBackground: Bool
    // UI only the measured height, 0 = not measured yet
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.top, 20)
            .padding(.bottom, 12)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    // add the home bar gap so the sheet reaches the bottom edge
                    Color.clear.preference(key: CompactSheetHeightKey.self,
                                           value: proxy.size.height + proxy.safeAreaInsets.bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onPreferenceChange(CompactSheetHeightKey.self) { height = $0 }
            .presentationDetents(detents)
            .presentationBackground { RemedyBackground() }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.large)
            .presentationBackgroundInteraction(allowsBackground ? .enabled : .disabled)
    }

    private var detents: Set<PresentationDetent> {
        height > 0 ? [.height(height)] : [.medium]
    }
}

extension View {
    // sheet as tall as its content with a material background
    func compactSheet(allowsBackgroundInteraction: Bool = false) -> some View {
        modifier(CompactSheetModifier(allowsBackground: allowsBackgroundInteraction))
    }
}
