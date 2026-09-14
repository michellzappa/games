import GameShell
import SwiftUI

/// One card in the 81-card deck. Four attributes, three values each: 3^4 = 81.
struct Card: Identifiable, Hashable {
    enum Symbol: Int, CaseIterable {
        case circle, square, triangle

        var name: String {
            switch self {
            case .circle: "circle"
            case .square: "square"
            case .triangle: "triangle"
            }
        }
    }

    enum Tint: Int, CaseIterable {
        case red, blue, yellow

        /// Themed via Appearance through the tint's palette position, so a
        /// theme change restyles everything that draws with tint colors.
        var color: Color { gameAccent.color }

        /// Lighter sibling used as the top of the solid-fill gradient.
        var highlight: Color { gameAccent.highlight }

        var gradient: LinearGradient { gameAccent.gradient }

        var name: String {
            switch self {
            case .red: "red"
            case .blue: "blue"
            case .yellow: "yellow"
            }
        }

        var accessibilityMarker: String {
            switch self {
            case .red: "R"
            case .blue: "B"
            case .yellow: "Y"
            }
        }
    }

    enum Fill: Int, CaseIterable {
        // Raw values are load-bearing (card id math); only names may change.
        case solid, outline, translucent

        var name: String {
            switch self {
            case .solid: "solid"
            case .outline: "outline"
            case .translucent: CardAppearance.shared.fillStyle == .pinstriped ? "striped" : "shaded"
            }
        }
    }

    /// 1, 2, or 3 symbols on the card.
    let count: Int
    let tint: Tint
    let symbol: Symbol
    let fill: Fill

    var id: Int {
        (count - 1) * 27 + tint.rawValue * 9 + symbol.rawValue * 3 + fill.rawValue
    }

    /// A complete spoken description of the card. This is deliberately based
    /// on the four game traits rather than on its numeric ID, so it works as
    /// both a VoiceOver label and a Voice Control command.
    var accessibilityDescription: String {
        let countName = switch count {
        case 1: "one"
        case 2: "two"
        default: "three"
        }
        let shapeName = count == 1 ? symbol.name : "\(symbol.name)s"
        return "\(countName) \(tint.name) \(fill.name) \(shapeName)"
    }

    init(count: Int, tint: Tint, symbol: Symbol, fill: Fill) {
        self.count = count
        self.tint = tint
        self.symbol = symbol
        self.fill = fill
    }

    /// Inverse of `id`, used to decode cards off the wire (0...80).
    init(id: Int) {
        self.count = id / 27 + 1
        self.tint = Tint(rawValue: (id % 27) / 9)!
        self.symbol = Symbol(rawValue: (id % 9) / 3)!
        self.fill = Fill(rawValue: id % 3)!
    }

    /// Attribute values as trits (0...2), used by the set math.
    var trits: [Int] {
        [count - 1, tint.rawValue, symbol.rawValue, fill.rawValue]
    }

    static var fullDeck: [Card] {
        var deck: [Card] = []
        for count in 1...3 {
            for tint in Tint.allCases {
                for symbol in Symbol.allCases {
                    for fill in Fill.allCases {
                        deck.append(Card(count: count, tint: tint, symbol: symbol, fill: fill))
                    }
                }
            }
        }
        return deck
    }

    /// Three cards form a valid set when, for every attribute, the values are
    /// all equal or all different. Equivalent: each trit sum is 0 mod 3.
    static func isValidSet(_ a: Card, _ b: Card, _ c: Card) -> Bool {
        for i in 0..<4 where (a.trits[i] + b.trits[i] + c.trits[i]) % 3 != 0 {
            return false
        }
        return true
    }

    /// The unique third card that completes a set with `a` and `b`.
    /// For each trit: c = (2 * (a + b)) mod 3 gives "same if same, the
    /// remaining value if different".
    static func completing(_ a: Card, _ b: Card) -> Card {
        let t = (0..<4).map { (2 * (a.trits[$0] + b.trits[$0])) % 3 }
        return Card(
            count: t[0] + 1,
            tint: Tint(rawValue: t[1])!,
            symbol: Symbol(rawValue: t[2])!,
            fill: Fill(rawValue: t[3])!
        )
    }

    /// A random valid set, shuffled. Two random distinct cards plus their
    /// unique completion always form one.
    static func randomValidSet() -> [Card] {
        let deck = fullDeck
        let a = deck.randomElement()!
        var b = deck.randomElement()!
        while b == a {
            b = deck.randomElement()!
        }
        return [a, b, completing(a, b)].shuffled()
    }

    /// How one trait behaves across three cards: the three values it takes,
    /// and whether they satisfy the rule. A trait passes when it is all same
    /// or all different, and breaks only as a two-and-one split.
    struct TraitVerdict: Identifiable {
        enum Outcome {
            case allSame, allDifferent, twoAndOne
        }

        let label: String
        let values: [String]
        let outcome: Outcome

        var id: String { label }
        var isValid: Bool { outcome != .twoAndOne }

        /// The values as a phrase: "all red", "red, blue, yellow", or
        /// "red, red vs blue" for the split that breaks a set.
        var summary: String {
            switch outcome {
            case .allSame:
                return "all \(values[0])"
            case .allDifferent:
                return values.joined(separator: ", ")
            case .twoAndOne:
                let pair = values.first { v in values.filter { $0 == v }.count == 2 }!
                let odd = values.first { $0 != pair }!
                return "\(pair), \(pair) vs \(odd)"
            }
        }

        var outcomeName: String {
            switch outcome {
            case .allSame: "all same"
            case .allDifferent: "all different"
            case .twoAndOne: "two and one"
            }
        }
    }

    /// Per-trait verdicts for three cards, always in the order count, color,
    /// shape, fill. `isValidSet` is exactly "no verdict is two-and-one"; the
    /// mismatch toast and the tutorial both read this.
    static func audit(_ a: Card, _ b: Card, _ c: Card) -> [TraitVerdict] {
        let trio = [a, b, c]
        func verdict(_ label: String, _ values: [String]) -> TraitVerdict {
            let distinct = Set(values).count
            let outcome: TraitVerdict.Outcome = switch distinct {
            case 1: .allSame
            case 3: .allDifferent
            default: .twoAndOne
            }
            return TraitVerdict(label: label, values: values, outcome: outcome)
        }
        return [
            verdict("count", trio.map { String($0.count) }),
            verdict("color", trio.map(\.tint.name)),
            verdict("shape", trio.map(\.symbol.name)),
            verdict("fill", trio.map(\.fill.name))
        ]
    }

    /// Why three cards fail, one line per broken trait.
    static func violationDescriptions(_ a: Card, _ b: Card, _ c: Card) -> [String] {
        audit(a, b, c)
            .filter { !$0.isValid }
            .map { "\($0.label): \($0.summary)" }
    }

    /// A trio that breaks on exactly one trait: the clearest counter-example
    /// to show a learner. Takes a valid set and nudges one card's value on a
    /// trait the set holds constant. That trait becomes a two-and-one split,
    /// the other three stay intact, and the three cards stay distinct.
    /// A set with no constant trait varies all four, so nudging any trait is
    /// safe there too.
    static func nearMissTrio() -> [Card] {
        let set = randomValidSet()
        let a = set[0], b = set[1], c = set[2]
        let index = (0..<4).first { a.trits[$0] == b.trits[$0] } ?? 1
        var trits = c.trits
        trits[index] = (trits[index] + 1) % 3
        let broken = Card(
            count: trits[0] + 1,
            tint: Tint(rawValue: trits[1])!,
            symbol: Symbol(rawValue: trits[2])!,
            fill: Fill(rawValue: trits[3])!
        )
        return [a, b, broken].shuffled()
    }

    /// A small teaching board: exactly one set hides among `size` cards.
    /// Grows a known set with cards that add no second set.
    static func practiceBoard(size: Int = 6) -> [Card] {
        for _ in 0..<40 {
            var cards = randomValidSet()
            for card in fullDeck.shuffled() where cards.count < size {
                guard !cards.contains(card) else { continue }
                let candidate = cards + [card]
                if countSets(in: candidate) == 1 {
                    cards = candidate
                }
            }
            if cards.count == size {
                return cards.shuffled()
            }
        }
        return randomValidSet()
    }

    /// How many valid sets `cards` contain. Each set is met once per pair,
    /// so divide by 3.
    static func countSets(in cards: [Card]) -> Int {
        let present = Set(cards)
        var found = 0
        for i in cards.indices {
            for j in cards.indices where j > i {
                let third = completing(cards[i], cards[j])
                if third != cards[i], third != cards[j], present.contains(third) {
                    found += 1
                }
            }
        }
        return found / 3
    }

    /// First set found among `cards`, or nil. O(n^2) via the completion trick.
    static func findSet(in cards: [Card]) -> [Card]? {
        let present = Set(cards)
        for i in cards.indices {
            for j in cards.indices where j > i {
                let third = completing(cards[i], cards[j])
                if third != cards[i], third != cards[j], present.contains(third) {
                    return [cards[i], cards[j], third]
                }
            }
        }
        return nil
    }
}

extension Card.Tint {
    /// EST cards retain their named identity colours while shared chrome uses
    /// palette positions. Future games can map their own identity system onto
    /// the same three positions.
    var gameAccent: GameAccent {
        switch self {
        case .red: .first
        case .blue: .second
        case .yellow: .third
        }
    }
}
