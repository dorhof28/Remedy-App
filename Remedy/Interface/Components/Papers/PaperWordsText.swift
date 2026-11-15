//
//  PaperWordsText.swift
//  Remedy
//
//  the words of a page laid out with headings, bullets, indented medicine lines and paragraphs
//  a tap on a hidden part shows it and a tap on a word hides it, as before
//

import SwiftUI

// a hidden page's words, tap a word to hide or show it
struct PaperWordsText: View {
    let pieces: [RedactedPiece]
    var isSimple = false
    let onTap: (Int) -> Void

    var body: some View {
        let lines = PaperLayout.lines(from: pieces)
        VStack(alignment: .leading, spacing: isSimple ? 8 : 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                row(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            if let index = Int(url.lastPathComponent) { onTap(index) }
            return .handled
        })
    }

    @ViewBuilder
    private func row(_ line: PaperLayout.Line) -> some View {
        switch line.kind {
        case .spacer:
            Color.clear.frame(height: isSimple ? 8 : 4)
        case .heading:
            // classic keeps the page font, so a typed page stays typed
            Group {
                if isSimple { text(line).font(.title3.weight(.bold)) } else { text(line).bold() }
            }
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}").foregroundStyle(Color.accentInk)
                text(line)
            }
            .padding(.leading, 8)
        case .numbered:
            text(line)
                .padding(.leading, 8)
        case .medicine:
            // a small pill marks a line with a dose
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "pills.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentInk)
                    .accessibilityHidden(true)
                text(line)
                    .fontWeight(.medium)
            }
            .padding(.leading, 20)
        case .paragraph:
            text(line)
        }
    }

    // each tag and word is a link to its piece number
    private func text(_ line: PaperLayout.Line) -> Text {
        var result = AttributedString()
        for segment in line.segments {
            guard let index = segment.piece, pieces.indices.contains(index) else {
                result += AttributedString(segment.text)
                continue
            }
            let piece = pieces[index]
            var part = piece.isHidden ? PaperKit.hiddenTag : AttributedString(segment.text)
            if piece.isHidden || piece.isWord { part.link = URL(string: "remedy://piece/\(index)") }
            result += part
        }
        return Text(result)
    }
}
