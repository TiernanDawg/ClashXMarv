import AVFoundation
import UIKit
import CoreHaptics

enum MusicMode: String { case menu, battle }

@MainActor
final class ProceduralAudio {
    static let shared = ProceduralAudio()
    private let engine = AVAudioEngine()
    private let sfxPlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private var ready = false
    private var hapticEngine: CHHapticEngine?
    private var musicKey = ""

    private init() {
        engine.attach(sfxPlayer)
        engine.attach(musicPlayer)
        engine.connect(sfxPlayer, to: engine.mainMixerNode, format: nil)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
            sfxPlayer.play()
            ready = true
            if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                hapticEngine = try? CHHapticEngine()
                try? hapticEngine?.start()
            }
        } catch {
            ready = false
        }
    }

    func play(_ kind: SoundKind, enabled: Bool = true) {
        guard enabled, ready else { return }
        let spec = kind.spec
        guard let format = sfxPlayer.outputFormat(forBus: 0).sampleRate > 0
            ? AVAudioFormat(standardFormatWithSampleRate: sfxPlayer.outputFormat(forBus: 0).sampleRate,
                            channels: sfxPlayer.outputFormat(forBus: 0).channelCount)
            : nil else { return }
        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let frames = AVAudioFrameCount(sampleRate * spec.duration)
        guard channels > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channelData = buffer.floatChannelData else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let envelope = min(1, t * 70) * max(0, 1 - t / spec.duration)
            let sample = Float(sin(2 * Double.pi * spec.frequency * t) * envelope * 0.18)
            for channel in 0..<channels { channelData[channel][i] = sample }
        }
        sfxPlayer.scheduleBuffer(buffer)
    }

    func setMusic(mode: MusicMode, phase: Int = 1, enabled: Bool) {
        guard ready else { return }
        guard enabled else {
            if musicPlayer.isPlaying { musicPlayer.stop() }
            musicKey = ""
            return
        }
        let normalizedPhase = max(1, min(3, phase))
        let key = "\(mode.rawValue)-\(normalizedPhase)"
        guard key != musicKey else { return }
        musicPlayer.stop()
        musicKey = key
        let outputFormat = musicPlayer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channels = Int(outputFormat.channelCount)
        let seconds = 8.0
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard sampleRate > 0, channels > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channels)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channelData = buffer.floatChannelData else { return }
        buffer.frameLength = frames
        let menuNotes = [261.63, 329.63, 392.00, 329.63, 293.66, 349.23, 440.00, 349.23]
        let battleNotes = [196.00, 246.94, 293.66, 246.94, 220.00, 261.63, 329.63, 261.63]
        let notes = mode == .menu ? menuNotes : battleNotes
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let beat = Int(t / (mode == .menu ? 0.5 : 0.25))
            let base = notes[beat % notes.count]
            let layer = normalizedPhase >= 2 ? sin(2 * Double.pi * base * 2 * t) * 0.18 : 0
            let topLayer = normalizedPhase >= 3 ? sin(2 * Double.pi * base * 3 * t) * 0.10 : 0
            let fade = min(1, t * 4) * min(1, (seconds - t) * 4)
            let pulse = 0.62 + 0.38 * sin(2 * Double.pi * (mode == .menu ? 0.5 : 1.0) * t)
            let sample = (sin(2 * Double.pi * base * t) * 0.42 + sin(2 * Double.pi * base * 0.5 * t) * 0.20 + layer + topLayer) * pulse * fade * 0.10
            let value = Float(sample)
            for channel in 0..<channels { channelData[channel][i] = value }
        }
        musicPlayer.volume = 0.7
        musicPlayer.scheduleBuffer(buffer, at: nil, options: [.loops])
        musicPlayer.play()
    }

    func playAttack(card: CardDefinition, enabled: Bool = true) {
        guard enabled, ready else { return }
        let signature = card.name.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 480 }
        let frequency = 160.0 + Double(signature)
        let outputFormat = sfxPlayer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        let channels = Int(outputFormat.channelCount)
        let duration = 0.055
        let frames = AVAudioFrameCount(sampleRate * duration)
        guard sampleRate > 0, channels > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channels)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channelData = buffer.floatChannelData else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let sample = Float(sin(2 * Double.pi * frequency * t) * min(1, t * 80) * max(0, 1 - t / duration) * 0.10)
            for channel in 0..<channels { channelData[channel][i] = sample }
        }
        sfxPlayer.scheduleBuffer(buffer)
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle, enabled: Bool = true) {
        guard enabled else { return }
        if let hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            let intensity: Float = style == .heavy ? 0.95 : (style == .medium ? 0.65 : 0.35)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.62)
            ], relativeTime: 0)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let player = try? hapticEngine.makePlayer(with: pattern),
               (try? player.start(atTime: 0)) != nil { return }
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

enum SoundKind {
    case deploy, hit, spell, crown, emote
    var spec: (frequency: Double, duration: Double) {
        switch self {
        case .deploy: return (520, 0.09)
        case .hit: return (145, 0.07)
        case .spell: return (780, 0.18)
        case .crown: return (940, 0.32)
        case .emote: return (620, 0.12)
        }
    }
}
