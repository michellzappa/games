import GameShell
import SwiftUI

/// A guided, hands-on introduction to the game. Six steps: the goal, the four
/// traits, a worked set, a worked non-set, a practice board the learner must
/// solve, and the table rules.
///
/// Shown once on first launch (`RootView`) and replayable from the rules
/// sheet. Every worked example runs through `Card.audit`, so what the tutorial
/// teaches and what the game enforces cannot drift apart.
struct TutorialView: View {
    var onFinish: () -> Void

    @State private var step = 0
    @State private var validExample = Card.randomValidSet()
    @State private var nearMissExample = Card.nearMissTrio()

    @State private var practiceCards = Card.practiceBoard()
    @State private var practiceSelection: [Card] = []
    /// The last trio the learner completed, kept on screen so the audit
    /// explains the pick even after a wrong selection clears.
    @State private var practiceVerdict: [Card] = []
    @State private var practiceSolved = false
    @State private var practiceHint: Set<Int> = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let stepCount = 6
    /// Every card the tutorial draws is this size, on every step. A card that
    /// changes size between steps reads as a different kind of thing.
    private static let cardSide: CGFloat = 92
    private static let cardGap: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            footer
        }
        .background(Appearance.shared.gameBackground)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<Self.stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.primary : Color.primary.opacity(0.18))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.3), value: step)

            Spacer()

            Button("Skip", action: onFinish)
                .buttonStyle(.game(.quiet, size: .inline))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if step == 4, !practiceSolved {
                Text("Find the set to continue, or use a hint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    footerControls
                }
            } else {
                HStack(spacing: 12) {
                    footerControls
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var footerControls: some View {
        if step > 0 {
            Button("Back") {
                withAnimation(.spring(duration: 0.35)) { step -= 1 }
            }
            .buttonStyle(.game(.quiet, size: .large))
        }
        if step == 4 {
            Button {
                revealPracticeHint()
            } label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .buttonStyle(.game(.secondary, tint: .third, size: .large))
            .disabled(practiceSolved)
        }
        Button(step == Self.stepCount - 1 ? "Play" : "Next") {
            if step == Self.stepCount - 1 {
                onFinish()
            } else {
                withAnimation(.spring(duration: 0.35)) { step += 1 }
            }
        }
        .buttonStyle(.game(.primary, tint: .second, size: .large))
        .disabled(step == 4 && !practiceSolved)
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: goalStep
        case 1: traitsStep
        case 2: validStep
        case 3: nearMissStep
        case 4: practiceStep
        default: tableStep
        }
    }

    private var goalStep: some View {
        VStack(spacing: 18) {
            VaryingTitleView(fontSize: 56)
                .padding(.top, 12)

            Text("Three cards. One rule.")
                .font(.title3.weight(.semibold))

            cardRow(validExample)

            Text("These three make a set")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            paragraph("Every card carries four traits. Three cards form a set when each trait is the same on all three cards or different on all three. There is no middle case.")
            paragraph("That is the rule. The next few steps unpack it.")
        }
    }

    private var traitsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Four traits", "Each card has a count, a color, a shape, and a fill. Each trait has exactly three values.")

            traitRow(
                "Count",
                "one, two, or three symbols",
                (1...3).map { Card(count: $0, tint: .red, symbol: .circle, fill: .solid) }
            )
            traitRow(
                "Color",
                "red, blue, yellow",
                Card.Tint.allCases.map { Card(count: 2, tint: $0, symbol: .circle, fill: .solid) }
            )
            traitRow(
                "Shape",
                "circle, square, triangle",
                Card.Symbol.allCases.map { Card(count: 2, tint: .blue, symbol: $0, fill: .solid) }
            )
            traitRow(
                "Fill",
                "solid, \(Card.Fill.translucent.name), outline",
                [Card.Fill.solid, .translucent, .outline].map {
                    Card(count: 2, tint: .yellow, symbol: .circle, fill: $0)
                }
            )

            paragraph("Each row above is already a valid set: one trait runs through all three values, and the other three traits hold still.")
        }
    }

    private var validStep: some View {
        VStack(spacing: 18) {
            heading("A set passes all four checks", "Check the traits one at a time. Each one must be all the same or all different.")
                .frame(maxWidth: .infinity, alignment: .leading)

            cardRow(validExample)

            TraitAuditView(cards: validExample)
                .padding(16)
                .glassPanel(cornerRadius: 18)

            paragraph("All four pass, so these cards make a set. In a game, tap them to collect them.")

            rerollButton("Another example") {
                validExample = Card.randomValidSet()
            }
        }
    }

    private var nearMissStep: some View {
        VStack(spacing: 18) {
            heading("One failed trait is enough", "These cards look close, but one trait fails. Check them the same way as before.")
                .frame(maxWidth: .infinity, alignment: .leading)

            cardRow(nearMissExample)

            TraitAuditView(cards: nearMissExample)
                .padding(16)
                .glassPanel(cornerRadius: 18)

            paragraph("A trait can only fail one way: two cards agree and the third does not. Two and one is never a set.")
            paragraph("The game shows this message whenever a pick fails, so you can see why.")

            rerollButton("Another example") {
                nearMissExample = Card.nearMissTrio()
            }
        }
    }

    private var practiceStep: some View {
        VStack(spacing: 16) {
            heading("Your turn", "Exactly one set hides in these six cards. Tap three cards to pick them.")
                .frame(maxWidth: .infinity, alignment: .leading)

            // Fixed cells rather than flexible ones: the board sits inside a
            // ScrollView, where a square that sizes itself off the proposed
            // width has no reliable height to grow into.
            VStack(spacing: Self.cardGap) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: Self.cardGap) {
                        ForEach(0..<3, id: \.self) { column in
                            let index = row * 3 + column
                            if index < practiceCards.count {
                                practiceCell(practiceCards[index])
                            } else {
                                Color.clear
                                    .frame(width: Self.cardSide, height: Self.cardSide)
                            }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.25), value: practiceSelection)

            if practiceSolved {
                Text("That is a set")
                    .font(.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(Appearance.shared.successColor)
            }

            if practiceVerdict.count == 3 {
                TraitAuditView(cards: practiceVerdict)
                    .padding(16)
                    .glassPanel(cornerRadius: 18)
                    .transition(.opacity)
            } else {
                paragraph("Pick a pair first. Any two cards have exactly one card that completes them, so you are always hunting for one specific card.")
            }
        }
        .animation(.spring(duration: 0.3), value: practiceSolved)
    }

    private var tableStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("At the table", "These are the board rules.")

            ruleRow("square.grid.3x3", "Start with 12 cards", "Tap three that make a set. Replacements take their place.")
            ruleRow("plus.rectangle.on.rectangle", "No set on the table?", "The game deals three more cards until a set appears.")
            ruleRow("timer", "Solo 81", "Clear the deck against the clock. Hints keep the run off the leaderboard.")
            ruleRow("bolt.fill", "Quick 27", "Play the 27 solid cards. The fill never changes, so you check three traits.")
            ruleRow("person.2.fill", "Duel", "On one phone or two, buzz first and then tap the three cards within \(Int(ClaimRace<Int>.Configuration.standard.claimWindow)) seconds. Miss and you lose a point and sit out briefly.")

            paragraph("At the end, the remaining cards are simply the ones nobody claimed.")
        }
    }

    // MARK: - Practice logic

    private func practiceCell(_ card: Card) -> some View {
        let isSelected = practiceSelection.contains(card)
        let position = (practiceCards.firstIndex(of: card) ?? 0) + 1

        return Button {
            tapPractice(card)
        } label: {
            CardView(card: card, isSelected: isSelected)
                .frame(width: Self.cardSide, height: Self.cardSide)
                .overlay {
                    if practiceHint.contains(card.id) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.orange,
                                style: StrokeStyle(lineWidth: 3, dash: [7, 5])
                            )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.accessibilityDescription), practice card \(position)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(
            isSelected
                ? "Double-tap to deselect this card"
                : "Double-tap to select this card"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .disabled(practiceSolved)
    }

    private func tapPractice(_ card: Card) {
        guard !practiceSolved else { return }
        if let index = practiceSelection.firstIndex(of: card) {
            practiceSelection.remove(at: index)
            return
        }
        practiceSelection.append(card)
        guard practiceSelection.count == 3 else { return }

        let trio = practiceSelection
        withAnimation(.spring(duration: 0.3)) {
            practiceVerdict = trio
            if Card.isValidSet(trio[0], trio[1], trio[2]) {
                practiceSolved = true
            } else {
                practiceSelection = []
            }
        }
    }

    /// First press outlines one card of the answer. Second press reveals the
    /// whole set, which also unblocks the Next button.
    private func revealPracticeHint() {
        guard let set = Card.findSet(in: practiceCards) else { return }
        withAnimation(.spring(duration: 0.3)) {
            if practiceHint.isEmpty {
                practiceHint = [set[0].id]
            } else {
                practiceHint = Set(set.map(\.id))
                practiceSelection = set
                practiceVerdict = set
                practiceSolved = true
            }
        }
    }

    // MARK: - Pieces

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardRow(_ cards: [Card]) -> some View {
        HStack(spacing: Self.cardGap) {
            ForEach(cards) { card in
                CardView(card: card)
                    .frame(width: Self.cardSide, height: Self.cardSide)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .id(card.id)
            }
        }
    }

    private func traitRow(_ label: String, _ detail: String, _ cards: [Card]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Self.cardGap) {
                ForEach(cards) { card in
                    CardView(card: card)
                        .frame(width: Self.cardSide, height: Self.cardSide)
                }
            }
        }
    }

    private func ruleRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rerollButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.4)) { action() }
        } label: {
            Label(title, systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(.game(.quiet, size: .inline))
    }
}

/// The teaching device: one row per trait, showing the three values the trait
/// takes across the cards and whether it passes. Reads `Card.audit`, so it
/// never restates the set rule on its own.
struct TraitAuditView: View {
    let cards: [Card]

    var body: some View {
        if cards.count == 3 {
            VStack(spacing: 8) {
                ForEach(Card.audit(cards[0], cards[1], cards[2])) { verdict in
                    HStack(spacing: 10) {
                        Image(systemName: verdict.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(verdict.isValid ? Appearance.shared.successColor : Appearance.shared.errorColor)
                        Text(verdict.label)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 46, alignment: .leading)
                        Text(verdict.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 6)
                        Text(verdict.outcomeName)
                            .font(.caption)
                            .foregroundStyle(verdict.isValid ? Color.secondary : Appearance.shared.errorColor)
                    }
                }
            }
        }
    }
}

#Preview {
    TutorialView(onFinish: {})
}
