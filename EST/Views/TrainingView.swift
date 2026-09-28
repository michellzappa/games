import GameShell
import SwiftUI

/// "Is this a set?" drill. Three cards, two answers, then the four traits
/// explain the verdict. No clock: this is for learning the rule.
struct TrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("trainingBestStreak") private var bestStreak = 0
    @State private var trio = Card.trainingTrio()
    @State private var answer: Bool?
    @State private var streak = 0
    @State private var round = 0

    /// Fixed cells, as in the tutorial: a card inside a ScrollView has no
    /// reliable height to grow into.
    private static let cardSide: CGFloat = 96
    private static let cardGap: CGFloat = 12

    private var isCorrect: Bool? {
        answer.map { $0 == trio.isSet }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakRow

                    HStack(spacing: Self.cardGap) {
                        ForEach(trio.cards) { card in
                            CardView(card: card)
                                .frame(width: Self.cardSide, height: Self.cardSide)
                        }
                    }
                    .id(round)
                    .transition(.opacity)

                    if let isCorrect {
                        verdict(isCorrect)
                    } else {
                        Text("Is this a set?")
                            .font(.title3.weight(.bold))
                        answerButtons
                    }
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(20)
                .animation(.spring(duration: 0.3), value: answer)
                .animation(.spring(duration: 0.3), value: round)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Is this a set?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var streakRow: some View {
        HStack {
            Label("Streak \(streak)", systemImage: "flame.fill")
            Spacer()
            Label("Best \(bestStreak)", systemImage: "trophy")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
    }

    /// Both answers share one style, so neither looks like the expected one.
    private var answerButtons: some View {
        HStack(spacing: 12) {
            Button {
                submit(true)
            } label: {
                Label("Set", systemImage: "checkmark")
            }
            .buttonStyle(.game(.secondary, tint: .second, size: .large))

            Button {
                submit(false)
            } label: {
                Label("Not a set", systemImage: "xmark")
            }
            .buttonStyle(.game(.secondary, tint: .first, size: .large))
        }
    }

    private func verdict(_ isCorrect: Bool) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(isCorrect ? "Right" : "Not quite")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isCorrect ? Appearance.shared.successColor : Appearance.shared.errorColor)
                Text(trio.isSet ? "These three make a set." : "These three are not a set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TraitAuditView(cards: trio.cards)
                .padding(16)
                .glassPanel(cornerRadius: 18)

            Button {
                next()
            } label: {
                Label("Next", systemImage: "arrow.right")
            }
            .buttonStyle(.game(.primary, tint: .first, size: .large))
        }
        .transition(.opacity)
    }

    private func submit(_ saysSet: Bool) {
        guard answer == nil else { return }
        answer = saysSet
        if saysSet == trio.isSet {
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
    }

    private func next() {
        answer = nil
        trio = Card.trainingTrio()
        round += 1
    }
}

#Preview {
    TrainingView()
}
