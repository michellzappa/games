import GameShell
import GridKit
import SwiftUI

/// The table: 3 columns, rows grow as the engine deals (12, 15, ...).
/// Sizes cards to fit both width and height, no scrolling.
/// Takes plain values so it renders local engines and remote snapshots alike.
///
/// When the hosting screen provides pile frames (measured in a "game"
/// coordinate space via `PileFramesKey`), matched cards fly to the collector's
/// card box and replacements flip into their existing table slots.
struct BoardGridView: View {
    let table: [Card]
    let selectedIDs: Set<Int>
    let mismatchIDs: Set<Int>
    let mismatchToken: Int
    let dealToken: Int
    var celebrationIDs: Set<Int> = []
    var hintedIDs: Set<Int> = []
    var collectedCount = 0
    var collectionTargetID: String?
    var pileFrames = PileFrames()
    var isInteractive = true
    var claimColor: Color?
    var claimDeadline: Date?
    /// Largest a card may become. A caller that frames the board itself passes
    /// `.infinity`: it has already fitted the grid, and clamping here would
    /// shrink the board inside a frame sized for something larger.
    var maximumCardSide: CGFloat = BoardGridView.compactMaximumCardSide
    var onTap: (Card) -> Void

    init(
        engine: GameEngine,
        selectedIDsOverride: Set<Int>? = nil,
        hintedIDs: Set<Int> = [],
        collectionTargetID: String? = nil,
        pileFrames: PileFrames = PileFrames(),
        isInteractive: Bool = true,
        claimColor: Color? = nil,
        claimDeadline: Date? = nil,
        maximumCardSide: CGFloat = BoardGridView.compactMaximumCardSide,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = engine.table
        self.selectedIDs = selectedIDsOverride ?? Set(engine.selection.map(\.id))
        self.mismatchIDs = engine.lastMismatch
        self.mismatchToken = engine.mismatchToken
        self.dealToken = engine.dealToken
        self.celebrationIDs = engine.celebrationIDs
        self.hintedIDs = hintedIDs
        self.collectedCount = engine.done.count
        self.collectionTargetID = collectionTargetID
        self.pileFrames = pileFrames
        self.isInteractive = isInteractive
        self.claimColor = claimColor
        self.claimDeadline = claimDeadline
        self.maximumCardSide = maximumCardSide
        self.onTap = onTap
    }

    init(
        table: [Card],
        selectedIDs: Set<Int>,
        mismatchIDs: Set<Int>,
        mismatchToken: Int,
        dealToken: Int = 0,
        celebrationIDs: Set<Int> = [],
        collectedCount: Int = 0,
        collectionTargetID: String? = nil,
        pileFrames: PileFrames = PileFrames(),
        isInteractive: Bool = true,
        claimColor: Color? = nil,
        claimDeadline: Date? = nil,
        maximumCardSide: CGFloat = BoardGridView.compactMaximumCardSide,
        onTap: @escaping (Card) -> Void
    ) {
        self.table = table
        self.selectedIDs = selectedIDs
        self.mismatchIDs = mismatchIDs
        self.mismatchToken = mismatchToken
        self.dealToken = dealToken
        self.celebrationIDs = celebrationIDs
        self.collectedCount = collectedCount
        self.collectionTargetID = collectionTargetID
        self.pileFrames = pileFrames
        self.isInteractive = isInteractive
        self.claimColor = claimColor
        self.claimDeadline = claimDeadline
        self.maximumCardSide = maximumCardSide
        self.onTap = onTap
    }

    private let gap: CGFloat = 10

    /// Ceiling for a compact-width screen. A phone's width limit always wins
    /// before this binds, so it effectively never applies there.
    static let compactMaximumCardSide: CGFloat = 150

    /// Ceiling for a regular-width screen. This matches the card size the
    /// four-seat table computes on a 13-inch iPad, so solo and party read as
    /// one game rather than two.
    static let regularMaximumCardSide: CGFloat = 240

    @State private var flights: [DepartureFlight] = []
    @State private var departureOrigins: [DepartureOrigin] = []
    @State private var playedOpeningDeal = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private struct DepartureOrigin: Equatable {
        let card: Card
        let rect: CGRect
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = 3
            let rows = GridLayout.rows(for: table.count, columns: columns)
            let layout = GridLayout.fitting(
                columns: columns, rows: rows, gap: gap, in: proxy.size, maximumSide: maximumCardSide
            )
            let side = layout.side
            let gridWidth = layout.width
            let gridHeight = layout.height
            let origin = layout.origin(centeredIn: proxy.size)
            let boardFrame = proxy.frame(in: .named("game"))
            let slotCenter: (Int) -> CGPoint = { index in
                layout.center(index: index, origin: origin)
            }
            let toLocal: (CGRect) -> CGPoint = { rect in
                CGPoint(x: rect.midX - boardFrame.minX, y: rect.midY - boardFrame.minY)
            }
            let doneLocal = pileFrames.done.map(toLocal)
            let collectionLocal = collectionTargetID
                .flatMap { pileFrames.cardBoxes[$0] }
                .map(toLocal)
                ?? doneLocal

            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < table.count {
                                    let card = table[index]
                                    let isSelected = selectedIDs.contains(card.id)
                                    Button {
                                        guard isInteractive else { return }
                                        if isSelected {
                                            GameAudio.shared.play(.cardDeselected)
                                        } else {
                                            GameAudio.shared.play(.cardSelected(step: selectedIDs.count + 1))
                                        }
                                        onTap(card)
                                    }
                                    label: {
                                        CardCell(
                                            card: card,
                                            index: index,
                                            isSelected: isSelected,
                                            isHinted: hintedIDs.contains(card.id),
                                            isCelebrating: celebrationIDs.contains(card.id),
                                            isMismatched: mismatchIDs.contains(card.id),
                                            mismatchToken: mismatchToken
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: side, height: side)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(
                                        "\(card.accessibilityDescription), row \(row + 1), column \(column + 1)"
                                    )
                                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                                    .accessibilityHint(
                                        isSelected
                                            ? "Double-tap to deselect this card"
                                            : "Double-tap to select this card"
                                    )
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                    .disabled(!isInteractive)
                                    .transition(.identity)
                                    .id(card.id)
                                } else {
                                    Color.clear.frame(width: side, height: side)
                                }
                            }
                        }
                    }
                }
                .frame(width: gridWidth, height: gridHeight)
                .overlay {
                    if let claimColor {
                        PartyClaimOutline(color: claimColor, deadline: claimDeadline)
                    }
                }
                .animation(.spring(duration: 0.4), value: table)
                .animation(.spring(duration: 0.25), value: selectedIDs)

                ForEach(flights) { flight in
                    FlightCardView(flight: flight)
                }
            }
            // Fill the reader so the ZStack can center the grid. Without this
            // the ZStack sizes to the grid and GeometryReader pins it
            // top-leading. It shows whenever the grid is narrower than the
            // space it was given, which is any screen where the ceiling or the
            // height limit binds before the width does. slotCenter already
            // computes flight coordinates from the centered origin, so the
            // match animation needs this too.
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onChange(of: celebrationIDs) { _, ids in
                guard !ids.isEmpty else { return }
                GameAudio.shared.play(.validSet)
                // Remember where the matched cards sit; by the time they move
                // to the done pile they are no longer on the table.
                departureOrigins = table.indices.compactMap { index in
                    guard ids.contains(table[index].id) else { return nil }
                    let center = slotCenter(index)
                    return DepartureOrigin(
                        card: table[index],
                        rect: CGRect(
                            x: center.x - side / 2,
                            y: center.y - side / 2,
                            width: side,
                            height: side
                        )
                    )
                }
            }
            .onChange(of: mismatchToken) { _, newToken in
                guard newToken > 0 else { return }
                GameAudio.shared.play(.mismatch)
            }
            .onChange(of: dealToken) { oldToken, newToken in
                guard newToken > oldToken else { return }
                GameAudio.shared.play(.deal)
            }
            .onChange(of: collectedCount) { oldCount, newCount in
                guard newCount > oldCount else { return }
                guard !departureOrigins.isEmpty, let collectionLocal else { return }
                let newFlights = departureOrigins.enumerated().map { offset, departure in
                    DepartureFlight(
                        card: departure.card,
                        from: departure.rect,
                        to: collectionLocal,
                        delay: Double(offset) * 0.06
                    )
                }
                departureOrigins = []
                flights.append(contentsOf: newFlights)
                let flightIDs = Set(newFlights.map(\.id))
                Task {
                    try? await Task.sleep(for: .seconds(1.1))
                    flights.removeAll { flightIDs.contains($0.id) }
                }
            }
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: table, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .impact(flexibility: .soft, intensity: 0.6)
        }
        .onAppear {
            if !table.isEmpty, !playedOpeningDeal {
                playedOpeningDeal = true
                GameAudio.shared.play(.deal)
            }
        }
    }
}

struct DepartureFlight: Identifiable {
    let id = UUID()
    let card: Card
    let from: CGRect
    let to: CGPoint
    let delay: Double
}

/// A matched card mid-air on its way to the collector's cards box.
private struct FlightCardView: View {
    let flight: DepartureFlight

    @State private var arrived = false

    var body: some View {
        CardView(card: flight.card)
            .frame(width: flight.from.width, height: flight.from.height)
            .scaleEffect(arrived ? PileStack.cardSide / flight.from.width : 1)
            .opacity(arrived ? 0.6 : 1)
            .position(arrived ? flight.to : CGPoint(x: flight.from.midX, y: flight.from.midY))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).delay(flight.delay)) {
                    arrived = true
                }
            }
            .allowsHitTesting(false)
            .zIndex(2)
    }
}

/// Brief toast explaining why the last trio failed, one line per broken
/// trait. Shows on every mismatch token bump, hides itself after a beat.
struct MismatchExplainer: View {
    let reasons: [String]
    let token: Int

    @State private var visibleToken = 0

    var body: some View {
        Group {
            if visibleToken == token, token > 0, !reasons.isEmpty {
                VStack(spacing: 3) {
                    Text("Not a set")
                        .font(.caption.bold())
                        .textCase(.uppercase)
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassPanel(cornerRadius: 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: visibleToken)
        .onChange(of: token) { _, newToken in
            visibleToken = newToken
            Task {
                try? await Task.sleep(for: .seconds(5))
                if visibleToken == newToken {
                    visibleToken = -1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// One slot on the board. New cards flip into their existing slots with a
/// small deterministic offset; mismatched picks shake; matched picks glow
/// while their celebration runs.
private struct CardCell: View {
    let card: Card
    let index: Int
    let isSelected: Bool
    var isHinted = false
    var isCelebrating = false
    let isMismatched: Bool
    let mismatchToken: Int

    @State private var dealt = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    /// Local shake progress. Bumped by exactly 1 per mismatch this card is
    /// part of, so cards from earlier mismatches stay still.
    @State private var shakes: CGFloat = 0

    private var entryOffset: CGSize {
        CGSize(
            width: CGFloat((card.id * 17) % 9 - 4),
            height: CGFloat((card.id * 31) % 11 - 5)
        )
    }

    private var entryRoll: Double {
        Double((card.id * 29) % 13 - 6)
    }

    var body: some View {
        CardView(card: card, isSelected: isSelected)
            .overlay {
                if isHinted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            Color.orange,
                            style: StrokeStyle(lineWidth: 3, dash: [7, 5])
                        )
                }
            }
            .scaleEffect(isCelebrating ? 1.10 : 1)
            .shadow(
                color: isCelebrating ? card.tint.color.opacity(0.7) : .clear,
                radius: isCelebrating ? 14 : 0
            )
            .zIndex(isCelebrating ? 1 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.55), value: isCelebrating)
            .modifier(ShakeEffect(animatableData: shakes))
            .onChange(of: mismatchToken) { _, _ in
                guard isMismatched else { return }
                withAnimation(.linear(duration: 0.4)) {
                    shakes += 1
                }
            }
            // The card lands face up. Only the title screen turns a card on
            // its edge; an edge-on card on the table reads as a sliver.
            .rotationEffect(.degrees(dealt ? 0 : entryRoll))
            .scaleEffect(dealt ? 1 : 0.88)
            .offset(dealt ? .zero : entryOffset)
            .opacity(dealt ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.62, bounce: 0.16).delay(Double(index) * 0.06)) {
                    dealt = true
                }
            }
            .sensoryFeedback(
                trigger: FeedbackTrigger(value: isSelected, enabled: hapticsEnabled)
            ) { oldValue, newValue in
                guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
                return .selection
            }
    }
}
