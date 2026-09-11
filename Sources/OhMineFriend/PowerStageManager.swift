import Foundation

/// CPU-driven Super-Saiyan-style staged aura for the main character.
/// Polling is NOT done here — a sibling owns wiring; call `update(characterNode:)` from the game loop.
public final class PowerStageManager {
    public static let shared = PowerStageManager()

    /// Stage thresholds: stage 0 below thresholds[0], stages 1/2/3 above each entry.
    public var stageThresholds = [50.0, 75.0, 90.0]

    /// Last stage delivered to the character node. Guards against emission/emoji spam.
    private var lastStage: Int = 0

    private init() {}

    /// Maps a CPU percent to a power stage (0...stageThresholds.count).
    public func stage(for cpu: Double) -> Int {
        var s = 0
        for t in stageThresholds where cpu >= t {
            s += 1
        }
        return min(max(s, 0), 3)
    }

    /// Reads cpuPercent, computes stage, forwards to the node only when changed.
    public func update(characterNode: MinecraftCharacterNode) {
        let cpu = CPULoadMonitor.shared.cpuPercent()
        let s = stage(for: cpu)
        guard s != lastStage else { return }
        lastStage = s
        characterNode.applyPowerStage(s)
    }
}
