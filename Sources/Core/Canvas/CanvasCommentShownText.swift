import Foundation

enum CanvasCommentShownText {
    private static let zeroWidthNonJoiner: UInt32 = 0x200C
    private static let zeroWidthJoiner: UInt32 = 0x200D
    private static let mongolianVowelSeparator: UInt32 = 0x180E
    private static let emojiPresentation: UInt32 = 0xFE0F
    private static let keycap: UInt32 = 0x20E3
    private static let keycapBases: Set<UInt32> = [0x23, 0x2A, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
    private static let directionMarks: Set<UInt32> = [0x200E, 0x200F, 0x061C]
    private static let annotationAnchors: ClosedRange<UInt32> = 0xFFF9...0xFFFB
    private static let pictographicBlocks: ClosedRange<UInt32> = 0x1F000...0x1FAFF
    private static let mongolian: ClosedRange<UInt32> = 0x1800...0x18AF
    private static let blackFlag: UInt32 = 0x1F3F4

    private static let flagTags: [[UInt32]] = ["gbeng", "gbsct", "gbwls"].map { region in
        region.unicodeScalars.map { $0.value + 0xE0000 } + [0xE007F]
    }

    private static let scriptsThatJoin: [ClosedRange<UInt32>] = [
        0x0600...0x08FF, 0x0900...0x0DFF, 0x0F00...0x109F, 0x1780...0x18AF, 0x1900...0x194F,
        0x1A20...0x1AAF, 0x1B00...0x1C4F, 0xA800...0xA8FF, 0xA900...0xA9DF, 0xAA00...0xAAFF,
        0xABC0...0xABFF, 0xFB50...0xFDFF, 0xFE70...0xFEFC, 0x10A00...0x10A5F, 0x10AC0...0x10AFF,
        0x10D00...0x10D3F, 0x10F30...0x10F6F, 0x11000...0x11FFF, 0x1E900...0x1E95F,
    ]

    private static let rightToLeftScripts: [ClosedRange<UInt32>] = [
        0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFC, 0x10800...0x10FFF, 0x1E800...0x1EFFF,
    ]

    private static let basesOfStandardVariants: [ClosedRange<UInt32>] = [
        0x1000...0x109F, 0xA840...0xA87F, 0xA9E0...0xA9FF, 0xAA60...0xAA7F, 0x10AC0...0x10AFF, 0x13000...0x1345F,
    ]

    static func filtered(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var kept = String.UnicodeScalarView()
        var last: Unicode.Scalar?
        var lastNotSpace: Unicode.Scalar?
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            let next = index + 1 < scalars.count ? scalars[index + 1] : nil
            if let tags = validFlagTags(after: index, in: scalars) {
                kept.append(scalar)
                kept.append(contentsOf: tags)
                last = tags.last
                lastNotSpace = tags.last
                index += tags.count + 1
                continue
            }
            if scalar == "\r" {
                if next != "\n" {
                    kept.append("\n")
                    last = "\n"
                }
                index += 1
                continue
            }
            let keptHere = directionMarks.contains(scalar.value)
                ? directionMarkApplies(after: last, lastNotSpace, at: index, in: scalars)
                : keeps(scalar, after: last, before: next)
            if keptHere {
                kept.append(scalar)
                last = scalar
                if !scalar.properties.isWhitespace { lastNotSpace = scalar }
            }
            index += 1
        }
        return String(kept)
    }

    private static func validFlagTags(after index: Int, in scalars: [Unicode.Scalar]) -> ArraySlice<Unicode.Scalar>? {
        guard scalars[index].value == blackFlag else { return nil }
        let following = scalars[(index + 1)...]
        guard let tags = flagTags.first(where: { tags in following.prefix(tags.count).map(\.value) == tags }) else { return nil }
        return following.prefix(tags.count)
    }

    private static func keeps(_ scalar: Unicode.Scalar, after last: Unicode.Scalar?, before next: Unicode.Scalar?) -> Bool {
        if scalar == "\n" || scalar == "\t" { return true }
        if scalar.value == zeroWidthJoiner || scalar.value == zeroWidthNonJoiner || scalar.value == mongolianVowelSeparator {
            return joinerApplies(scalar, after: last, before: next)
        }
        if scalar.properties.isVariationSelector { return selectorApplies(scalar, after: last, before: next) }
        let category = scalar.properties.generalCategory
        if category == .control || category == .privateUse || annotationAnchors.contains(scalar.value) { return false }
        return !scalar.properties.isDefaultIgnorableCodePoint
    }

    private static func joinerApplies(_ joiner: Unicode.Scalar, after last: Unicode.Scalar?, before next: Unicode.Scalar?) -> Bool {
        guard let last else { return false }
        if joiner.value == mongolianVowelSeparator {
            return next.map { isMongolianLetterOrMark(last) && isMongolianLetterOrMark($0) } ?? false
        }
        if last.properties.canonicalCombiningClass == .virama { return true }
        guard let next else { return false }
        if joiner.value == zeroWidthJoiner, isEmojiBefore(last, joining: next) { return true }
        return usesJoiners(last) && usesJoiners(next)
    }

    private static func isEmojiBefore(_ last: Unicode.Scalar, joining next: Unicode.Scalar) -> Bool {
        (last.value == emojiPresentation || isPictographic(last)) && isPictographic(next)
    }

    private static func isPictographic(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value > 0x7F && (scalar.properties.isEmoji || pictographicBlocks.contains(scalar.value))
    }

    private static func usesJoiners(_ scalar: Unicode.Scalar) -> Bool {
        guard !scalar.properties.isVariationSelector,
              scriptsThatJoin.contains(where: { $0.contains(scalar.value) }) else { return false }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark:
            return true
        default:
            return false
        }
    }

    private static func isMongolianLetterOrMark(_ scalar: Unicode.Scalar) -> Bool {
        mongolian.contains(scalar.value) && usesJoiners(scalar)
    }

    private static func directionMarkApplies(
        after last: Unicode.Scalar?, _ lastNotSpace: Unicode.Scalar?, at index: Int, in scalars: [Unicode.Scalar]
    ) -> Bool {
        if let last, directionMarks.contains(last.value) { return false }
        if let lastNotSpace, isRightToLeft(lastNotSpace) { return true }
        let following = scalars[(index + 1)...].first { !$0.properties.isWhitespace }
        return following.map(isRightToLeft) ?? false
    }

    private static func isRightToLeft(_ scalar: Unicode.Scalar) -> Bool {
        guard rightToLeftScripts.contains(where: { $0.contains(scalar.value) }) else { return false }
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber:
            return true
        default:
            return false
        }
    }

    private static func selectorApplies(_ selector: Unicode.Scalar, after last: Unicode.Scalar?, before next: Unicode.Scalar?) -> Bool {
        guard let last, !last.properties.isVariationSelector else { return false }
        switch selector.value {
        case 0xFE0E, 0xFE0F:
            if keycapBases.contains(last.value) { return selector.value == emojiPresentation && next?.value == keycap }
            return last.value > 0x7F && (last.properties.isEmoji || pictographicBlocks.contains(last.value))
        case 0xFE00...0xFE0D:
            return last.properties.isIdeographic || (last.value > 0x7F && last.properties.generalCategory == .mathSymbol)
                || basesOfStandardVariants.contains { $0.contains(last.value) }
        case 0xE0100...0xE01EF:
            return false
        default:
            return isMongolianLetterOrMark(last)
        }
    }
}
