import AVFoundation
import UIKit

@MainActor
final class ProceduralAudio {
    static let shared = ProceduralAudio()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var ready = false
    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        do { try engine.start(); player.play(); ready = true } catch { ready = false }
    }
    func play(_ kind: SoundKind, enabled: Bool = true) {
        guard enabled, ready else { return }
        let spec = kind.spec
        let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
        let frames = AVAudioFrameCount(22050 * spec.duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / 22050
            let envelope = min(1, t * 70) * max(0, 1 - t / spec.duration)
            channel[i] = Float(sin(2 * Double.pi * spec.frequency * t) * envelope * 0.18)
        }
        player.scheduleBuffer(buffer)
    }
    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle, enabled: Bool = true) {
        guard enabled else { return }
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