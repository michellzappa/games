import AVFAudio
import Foundation

/// A tiny, original sound palette for EST. Sounds are synthesized in memory so
/// the project has no third-party audio dependency or asset-license baggage.
@MainActor
public final class GameAudio {
    public static let shared = GameAudio()

    public enum Effect {
        case cardSelected(step: Int)
        case cardDeselected
        case deal
        case validSet
        case mismatch
        case hint
        case buzz
        case penalty
        case completion
    }

    private enum EffectKey: Hashable {
        case cardSelected(Int)
        case cardDeselected
        case deal
        case validSet
        case mismatch
        case hint
        case buzz
        case penalty
        case completion
    }

    private enum Waveform {
        case sine
        case triangle
        case noise
    }

    private struct Voice {
        public let frequency: Double
        public let start: Double
        public let duration: Double
        public let amplitude: Double
        public var waveform: Waveform = .sine
        public var attack: Double = 0.008
        public var release: Double = 0.06
        public var vibratoDepth: Double = 0
        public var vibratoRate: Double = 5
    }

    private let sampleRate = 44_100.0
    private let channelCount: AVAudioChannelCount = 2
    private var audioEngine: AVAudioEngine?
    private var playerNodes: [AVAudioPlayerNode] = []
    private var buffers: [EffectKey: AVAudioPCMBuffer] = [:]
    private var nextPlayerIndex = 0

    private init() {}

    public var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
    }

    public func setEnabled(_ enabled: Bool) {
        guard !enabled else { return }
        playerNodes.forEach { $0.stop() }
    }

    public func play(_ effect: Effect) {
        guard isEnabled else { return }
        prepareEngineIfNeeded()
        guard !playerNodes.isEmpty else { return }

        let key = key(for: effect)
        guard let buffer = buffer(for: key) else { return }
        let player = playerNodes[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % playerNodes.count
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func prepareEngineIfNeeded() {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ) else { return }

        let players = (0..<6).map { _ in AVAudioPlayerNode() }
        players.forEach {
            engine.attach($0)
            engine.connect($0, to: engine.mainMixerNode, format: format)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Ambient respects the phone's silent switch and mixes politely
            // with other audio, which suits a quiet tabletop game.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
        } catch {
            return
        }

        audioEngine = engine
        playerNodes = players
    }

    private func key(for effect: Effect) -> EffectKey {
        switch effect {
        case .cardSelected(let step):
            return .cardSelected(min(max(step, 1), 3))
        case .cardDeselected: return .cardDeselected
        case .deal: return .deal
        case .validSet: return .validSet
        case .mismatch: return .mismatch
        case .hint: return .hint
        case .buzz: return .buzz
        case .penalty: return .penalty
        case .completion: return .completion
        }
    }

    private func buffer(for key: EffectKey) -> AVAudioPCMBuffer? {
        if let buffer = buffers[key] { return buffer }
        let buffer: AVAudioPCMBuffer?
        switch key {
        case .cardSelected(let step):
            let frequencies = [440.0, 554.37, 659.25]
            let frequency = frequencies[step - 1]
            buffer = makeBuffer(duration: 0.11, voices: [
                Voice(frequency: frequency, start: 0, duration: 0.10, amplitude: 0.13),
                Voice(frequency: frequency * 2, start: 0, duration: 0.06, amplitude: 0.025)
            ])
        case .cardDeselected:
            buffer = makeBuffer(duration: 0.10, voices: [
                Voice(frequency: 330, start: 0, duration: 0.09, amplitude: 0.10),
                Voice(frequency: 220, start: 0.025, duration: 0.06, amplitude: 0.025)
            ])
        case .deal:
            buffer = makeBuffer(duration: 0.14, voices: [
                Voice(frequency: 170, start: 0, duration: 0.10, amplitude: 0.045),
                Voice(
                    frequency: 0,
                    start: 0,
                    duration: 0.035,
                    amplitude: 0.075,
                    waveform: .noise,
                    attack: 0.001,
                    release: 0.028
                )
            ])
        case .validSet:
            buffer = makeBuffer(duration: 0.72, voices: [
                Voice(frequency: 392.00, start: 0.00, duration: 0.20, amplitude: 0.13),
                Voice(frequency: 493.88, start: 0.08, duration: 0.25, amplitude: 0.12),
                Voice(frequency: 587.33, start: 0.16, duration: 0.38, amplitude: 0.14),
                Voice(frequency: 1174.66, start: 0.20, duration: 0.25, amplitude: 0.025)
            ])
        case .mismatch:
            buffer = makeBuffer(duration: 0.28, voices: [
                Voice(
                    frequency: 230,
                    start: 0,
                    duration: 0.18,
                    amplitude: 0.13,
                    waveform: .triangle,
                    vibratoDepth: 12,
                    vibratoRate: 7
                ),
                Voice(
                    frequency: 175,
                    start: 0.07,
                    duration: 0.18,
                    amplitude: 0.10,
                    waveform: .triangle,
                    vibratoDepth: 10,
                    vibratoRate: 6
                )
            ])
        case .hint:
            buffer = makeBuffer(duration: 0.48, voices: [
                Voice(frequency: 659.25, start: 0.00, duration: 0.16, amplitude: 0.10),
                Voice(frequency: 880.00, start: 0.10, duration: 0.30, amplitude: 0.12),
                Voice(frequency: 1320.00, start: 0.16, duration: 0.20, amplitude: 0.018)
            ])
        case .buzz:
            buffer = makeBuffer(duration: 0.22, voices: [
                Voice(frequency: 130.81, start: 0, duration: 0.18, amplitude: 0.16, waveform: .triangle),
                Voice(frequency: 261.63, start: 0, duration: 0.08, amplitude: 0.045),
                Voice(
                    frequency: 0,
                    start: 0,
                    duration: 0.025,
                    amplitude: 0.07,
                    waveform: .noise,
                    attack: 0.001,
                    release: 0.020
                )
            ])
        case .penalty:
            buffer = makeBuffer(duration: 0.38, voices: [
                Voice(frequency: 220, start: 0.00, duration: 0.20, amplitude: 0.12, waveform: .triangle),
                Voice(frequency: 155.56, start: 0.10, duration: 0.25, amplitude: 0.12, waveform: .triangle)
            ])
        case .completion:
            buffer = makeBuffer(duration: 0.92, voices: [
                Voice(frequency: 392.00, start: 0.00, duration: 0.18, amplitude: 0.12),
                Voice(frequency: 493.88, start: 0.08, duration: 0.22, amplitude: 0.12),
                Voice(frequency: 587.33, start: 0.17, duration: 0.28, amplitude: 0.13),
                Voice(frequency: 783.99, start: 0.29, duration: 0.52, amplitude: 0.14),
                Voice(frequency: 987.77, start: 0.37, duration: 0.38, amplitude: 0.035)
            ])
        }
        if let buffer { buffers[key] = buffer }
        return buffer
    }

    private func makeBuffer(duration: Double, voices: [Voice]) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
        let channels = buffer.floatChannelData else { return nil }

        buffer.frameLength = frameCount
        var noiseState: UInt64 = 0x4D595DF4D0F33173

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            var sample = 0.0

            for voice in voices {
                guard time >= voice.start, time < voice.start + voice.duration else { continue }
                let localTime = time - voice.start
                let attack = min(voice.attack, voice.duration * 0.35)
                let release = min(voice.release, voice.duration * 0.45)
                let attackEnvelope = attack > 0 ? min(1, localTime / attack) : 1
                let releaseEnvelope = release > 0
                    ? min(1, (voice.duration - localTime) / release)
                    : 1
                let envelope = max(0, min(attackEnvelope, releaseEnvelope))
                let frequency = voice.frequency + voice.vibratoDepth * sin(2 * .pi * voice.vibratoRate * localTime)
                let phase = 2 * .pi * frequency * localTime

                let wave: Double
                switch voice.waveform {
                case .sine:
                    wave = sin(phase)
                case .triangle:
                    wave = 2 * abs(2 * (phase / (2 * .pi) - floor(phase / (2 * .pi) + 0.5))) - 1
                case .noise:
                    noiseState = noiseState &* 2862933555777941757 &+ 3037000493
                    wave = (Double(noiseState >> 40) / Double(1 << 24)) * 2 - 1
                }

                sample += wave * voice.amplitude * envelope
            }

            let clipped = max(-0.95, min(0.95, sample))
            channels[0][frame] = Float(clipped)
            channels[1][frame] = Float(clipped * 0.98)
        }

        return buffer
    }
}

/// Equatable trigger that lets SwiftUI sensory feedback respect the app's
/// haptics preference without firing when the preference itself changes.
public struct FeedbackTrigger<Value: Equatable>: Equatable {
    public let value: Value
    public let enabled: Bool

    public init(value: Value, enabled: Bool) {
        self.value = value
        self.enabled = enabled
    }
}
