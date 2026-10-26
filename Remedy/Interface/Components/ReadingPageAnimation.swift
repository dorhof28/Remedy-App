//
//  ReadingPageAnimation.swift
//  Remedy
//
//  a little paper that gets scanned blacked out and read while the app works
//

import SwiftUI

struct ReadingPageAnimation: View {
    let isScanning: Bool
    let isBlackedOut: Bool
    let badge: String
    let isDone: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    // line widths on the paper the first two are the name and record number
    private let lines: [CGFloat] = [0.55, 0.4, 0.95, 0.75, 0.85, 0.6, 0.8]
    private let barWidths: [CGFloat] = [2, 1, 3, 1, 2, 1, 1, 3, 2, 1, 2, 1, 3, 1]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            paper
            badgeView
                .offset(x: 16, y: -16)
        }
        .frame(width: 132, height: 168)
        .padding(.top, 16)
        .padding(.trailing, 16)
        .accessibilityHidden(true)
    }

    // MARK: - Paper

    private var paper: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.cardBackground)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(lines.indices, id: \.self) { index in
                        line(index)
                    }
                    barcode
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .overlay { scanLine }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.quaternary))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    // one printed line the first two turn into black boxes
    private func line(_ index: Int) -> some View {
        let isPersonal = index < 2
        let hidden = isPersonal && isBlackedOut
        return RoundedRectangle(cornerRadius: hidden ? 2 : 4)
            .fill(hidden ? Color.primary : Color.secondary.opacity(0.3))
            .frame(width: 100 * lines[index], height: hidden ? 11 : 7)
            .animation(reduceMotion ? nil : .snappy.delay(Double(index) * 0.12), value: hidden)
    }

    // the patient sticker barcode
    private var barcode: some View {
        HStack(spacing: 2) {
            ForEach(barWidths.indices, id: \.self) { index in
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: barWidths[index], height: 16)
            }
        }
        .overlay {
            Rectangle()
                .fill(Color.primary)
                .opacity(isBlackedOut ? 1 : 0)
                .animation(reduceMotion ? nil : .snappy.delay(0.3), value: isBlackedOut)
        }
    }

    // the teal light that moves down the page while the phone reads it
    @ViewBuilder
    private var scanLine: some View {
        if isScanning && !reduceMotion {
            LinearGradient(colors: [Color.remedyTeal.opacity(0), Color.remedyTeal.opacity(0.45), Color.remedyTeal.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 30)
                .offset(y: sweep ? 84 : -84)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true }
                }
                .onDisappear { sweep = false }
                .transition(.opacity)
        }
    }

    // MARK: - Badge

    // the icon for the step that is running now
    private var badgeView: some View {
        Image(systemName: badge)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.pulse, isActive: !isDone && !reduceMotion)
            .frame(width: 46, height: 46)
            .background(Circle().fill(isDone ? Tone.good.color : Color.remedyTeal))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .animation(.snappy, value: badge)
    }
}
