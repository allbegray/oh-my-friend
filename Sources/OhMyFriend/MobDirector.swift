import Foundation

// MARK: - MobDirector (앰비언트 몹 자동 스폰 전담)
// gameLoopTick에 흩어져 있던 순수 자동 스폰 타이머 블록만 모아둔 클래스.
// 조건·주기·확률·상대 순서는 AppController에 있던 원본 그대로 유지한다.
// 스폰 실행은 AppController의 기존 스폰 메서드(spawnCreeper/spawnSkeleton/spawnEnderman/
// spawnSlime/spawnFox/flyDragon)를 그대로 호출하며, 전투·보상·delegate·대화형
// 스폰/해제(didSelectSpawn*/despawn*) 로직은 절대 포함하지 않는다.
// 전투가 섞인 updatePhantom/updateSiege/updateSpider/updateGhast 등은
// AppController에 그대로 남긴다.
final class MobDirector {
    unowned let app: AppController

    // AppController에서 이동해온 타이머 ivar (초기값 동일)
    var creeperSpawnTimer: TimeInterval = 0
    var skeletonSpawnTimer: TimeInterval = 0
    var endermanSpawnTimer: TimeInterval = 0
    var slimeSpawnTimer: TimeInterval = 0
    var foxSpawnTimer: TimeInterval = 0
    var dragonTimer: TimeInterval = 0

    init(app: AppController) {
        self.app = app
    }

    func update(dt: TimeInterval) {
        // Autonomous Creeper Spawning (야간에는 H4 가중치로 더 자주 출현)
        if app.isCreeperSpawnEnabled && app.creeperWindow == nil {
            creeperSpawnTimer += dt
            if creeperSpawnTimer >= app.creeperSpawnInterval / DayNightCycleManager.shared.nightSpawnMultiplier {
                creeperSpawnTimer = 0
                app.spawnCreeper()
            }
        }

        // Autonomous Skeleton Spawning (야간 가중치 + 디펜스전 웨이브 가속 적용)
        if app.isSkeletonSpawnEnabled && app.skeletonWindow == nil {
            skeletonSpawnTimer += dt
            var effectiveInterval = app.skeletonSpawnInterval / DayNightCycleManager.shared.nightSpawnMultiplier
            if app.isDefenseMode && DayNightCycleManager.shared.isNight {
                effectiveInterval = max(12.0, 30.0 - Double(app.defenseWave) * 3.0)
            }
            if skeletonSpawnTimer >= effectiveInterval {
                skeletonSpawnTimer = 0
                app.spawnSkeleton()
            }
        }

        // Autonomous Enderman Spawning (야간 가중치 적용)
        if app.isEndermanSpawnEnabled && app.endermanWindow == nil {
            endermanSpawnTimer += dt
            if endermanSpawnTimer >= app.endermanSpawnInterval / DayNightCycleManager.shared.nightSpawnMultiplier {
                endermanSpawnTimer = 0
                app.spawnEnderman()
            }
        }

        // M3. Slime occasional spawn (근접 자동 공격 루프는 AppController에 남김)
        slimeSpawnTimer += dt
        if slimeSpawnTimer >= app.slimeSpawnInterval && app.slimeWindows.isEmpty {
            slimeSpawnTimer = 0
            app.spawnSlime(size: .big, at: nil)
        }

        // Dragon flyby (300초, 50% 확률) — 원본 updateDragon 본문 그대로
        if app.dragonWindow == nil {
            dragonTimer += dt
            if dragonTimer >= 300.0 {
                dragonTimer = 0
                if Bool.random() {
                    app.flyDragon()
                }
            }
        }

        // Fox: 밤에만 가끔 출현
        if DayNightCycleManager.shared.isNight && app.foxWindow == nil {
            foxSpawnTimer += dt
            if foxSpawnTimer >= app.foxSpawnInterval {
                foxSpawnTimer = 0
                app.spawnFox()
            }
        } else if !DayNightCycleManager.shared.isNight {
            foxSpawnTimer = 0
        }
    }
}
