import SwiftUI

/// The chrome around a guided tour: step dots and Skip on top, the step's
/// content in a scroll view, Back / optional action / Next on the bottom.
/// A game supplies the steps; the frame owns navigation, so every tutorial
/// in the library moves the same way.
public struct TutorialFrame<Content: View, Extra: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let stepCount: Int
    @Binding private var step: Int
    private let canAdvance: Bool
    private let blockedHint: String?
    private let onFinish: () -> Void
    private let content: Content
    private let extra: Extra

    /// `canAdvance` gates Next on a practice step; `blockedHint` is the
    /// line shown under the buttons while it is false. `extra` is an
    /// optional button placed before Next (a hint, a reroll).
    public init(
        stepCount: Int,
        step: Binding<Int>,
        canAdvance: Bool = true,
        blockedHint: String? = nil,
        onFinish: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder extra: () -> Extra
    ) {
        self.stepCount = stepCount
        _step = step
        self.canAdvance = canAdvance
        self.blockedHint = blockedHint
        self.onFinish = onFinish
        self.content = content()
        self.extra = extra()
    }

    public var body: some View {
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

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
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
            if !canAdvance, let blockedHint {
                Text(blockedHint)
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
        extra
        Button(step == stepCount - 1 ? "Play" : "Next") {
            if step == stepCount - 1 {
                onFinish()
            } else {
                withAnimation(.spring(duration: 0.35)) { step += 1 }
            }
        }
        .buttonStyle(.game(.primary, tint: .second, size: .large))
        .disabled(!canAdvance)
    }
}

public extension TutorialFrame where Extra == EmptyView {
    init(
        stepCount: Int,
        step: Binding<Int>,
        canAdvance: Bool = true,
        blockedHint: String? = nil,
        onFinish: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            stepCount: stepCount, step: step, canAdvance: canAdvance,
            blockedHint: blockedHint, onFinish: onFinish, content: content
        ) { EmptyView() }
    }
}

/// Text pieces every tutorial and explainer shares.
public enum TutorialText {
    public static func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    public static func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    public static func ruleRow(_ icon: String, _ title: String, _ text: String) -> some View {
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
}
