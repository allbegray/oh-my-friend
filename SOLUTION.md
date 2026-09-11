이 문서는 Oh My Friend 개발 과정에서 발생한 기술적 문제, 근본 원인 및 재발 방지 해결책을 기록합니다.

# 문제 해결 지식

## [CommandLineTools에 SwiftUIMacros 플러그인 부재로 전체 빌드 실패]

### 증상
`swift build` 실행 시 `SkinGalleryView.swift`의 `@State` 매크로에서 아래 오류로 전체 빌드 실패:
```text
error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found
```

### 원인
- SwiftUI의 `@State` 등은 매크로이며, 그 구현체(`libSwiftUIMacros.dylib`)는 풀 Xcode에만 들어 있고 CommandLineTools에는 없음.
- 증분 빌드 캐시(`.build`)가 살아 있는 동안은 갤러리 파일을 다시 파싱하지 않아 문제가 드러나지 않다가, `rm -rf .build` 후 전체 재빌드에서 폭발함.

### 해결
1. 풀 Xcode 설치 후 `scripts/run.sh`·`scripts/build_app.sh` 선두에 툴체인 가드 추가:
   ```bash
   if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
       export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
   fi
   ```
   (`sudo xcode-select` 없이 동작. CI는 기본 Xcode를 쓰므로 영향 없음)

### 재발 방지
- `.build`를 함부로 지우지 않는다. 지워야 하면 위 가드(또는 풀 Xcode) 상태에서 전체 빌드가 통과하는지 먼저 확인한다.
- SwiftUI 매크로를 쓰는 파일 추가 시 로컬 CLT 빌드 가능 여부를 확인한다.

---

## [CommandLineTools와 SPM 매니페스트 링커 불일치 오류]

### 증상
macOS Sonoma(14.x) 및 특정 Xcode CommandLineTools 환경에서 `./scripts/run.sh` 또는 `swift build` 실행 시 아래와 같은 링커 오류가 발생하며 빌드 실패:
```text
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(name: Swift.String, ...) -> PackageDescription.Package", referenced from: _main in Package-1.o
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1
```

### 원인
- `Package.swift` 최상단에 `// swift-tools-version: 5.9`가 명시되어 있을 때, 사용자의 머신에 설치된 Apple CommandLineTools의 `libPackageDescription.dylib` 내 심볼 버전과 매니페스트 컴파일러가 요구하는 `Package.init` 생성자 ABI 심볼 간의 불일치로 인해 발생하는 Apple의 고질적인 링커 버그입니다.

### 해결
1. **`Package.swift` 도구 버전 조정**:
   - `// swift-tools-version: 5.7`로 선언을 변경하여 macOS 13, 14, 15 전반의 CommandLineTools 라이브러리에서 검증된 안정적인 하위 호환 심볼로 매핑되도록 조치했습니다.
2. **빌드 스크립트 2중 안전장치(Fallback) 적용**:
   - `scripts/build_app.sh`에서 `swift build`를 1차로 시도하고, 만약 시스템 툴체인 문제로 매니페스트 링크 실패 시 즉시 순수 `swiftc` 직접 컴파일(`swiftc -O -target ... Sources/OhMyFriend/*.swift -framework AppKit -framework SceneKit -framework SwiftUI -framework CoreGraphics`)로 자동 전환하는 안전장치를 구현했습니다.

### 재발 방지
- 서드파티 패키지 의존성이 없는 순수 Apple 시스템 프레임워크 기반 프로젝트의 경우, `Package.swift`의 tools-version을 불필요하게 최신 버전으로 올리지 않고 검증된 5.7 버전을 유지합니다.
- 배포 스크립트에는 SPM 툴체인 손상 시에도 바이너리를 빌드할 수 있는 직접 컴파일 Fallback을 상시 유지합니다.

---

## [macOS SceneKit SCNVector3 좌표 컴포넌트 타입 불일치]

### 증상
각도 대입 또는 삼각함수 연산 시 `Float`과 `CGFloat` 간 타입 불일치 컴파일 오류 발생:
```text
cannot assign value of type 'Float' to type 'CGFloat'
binary operator '-' cannot be applied to operands of type 'Float' and 'CGFloat'
```

### 원인
- iOS 플랫폼의 SceneKit에서는 `SCNVector3`의 멤버(`x, y, z`)가 `Float` 타입이지만, macOS AppKit 환경에서는 64비트 `CGFloat`로 정의되어 있습니다.

### 해결
- `MinecraftCharacterNode`의 `targetHeadYaw`, `targetHeadPitch`, `animTime` 및 `CharacterBehaviorController`의 회전 각도 계산 변수를 모두 `CGFloat`로 통일하고, 삼각함수(`sin`, `cos`, `atan2`) 및 `CGFloat.pi` 상수를 사용하도록 일원화했습니다.

### 재발 방지
- macOS 전용 SceneKit 코드 작성 시 3D 벡터와 오일러 각도(`eulerAngles`) 연산에는 항상 `CGFloat`를 표준으로 채택합니다.

---

## [Laby.net 스킨 페이지 URL 다운로드 시 Cloudflare 403 Forbidden 오류]

### 증상
`https://laby.net/skins/<hash>` 웹페이지 주소를 입력하여 스킨 다운로드 시도 시 `HTTP 403: Forbidden` 또는 올바르지 않은 스킨 이미지 오류 발생.

### 원인
1. Laby.net의 웹페이지(`laby.net/skins/...`)는 Cloudflare Bot Management(`cf-mitigated: challenge`)로 보호되고 있어 일반 HTTP 요청 시 403 Forbidden 차단이 발생함.
2. 또한 요청 헤더에 크롬 User-Agent(`Mozilla/5.0 ... Chrome/120.0`)를 설정할 경우, Apple URLSession의 TLS 핸드셰이크 지문(JA3/JA4)과 크롬 UA 간의 불일치로 인해 Cloudflare의 봇 스푸핑 방지 필터가 작동하여 공개 CDN 이미지 요청까지 403으로 차단됨.

### 해결
1. Laby.net의 원본 64×64 PNG 스킨 텍스처는 공개 CDN 엔드포인트(`https://laby.net/texture/<hash>.png`)에서 직접 호스팅되고 있음을 확인하고, URL에서 32자리 해시를 추출하여 CDN 주소로 다이렉트 변환.
2. User-Agent를 위조 크롬 대신 네이티브 식별자인 `OhMyFriend/1.0 (Macintosh; Mac OS X)`로 변경하여 Cloudflare의 TLS 지문 불일치 검사를 통과(200 OK)하도록 수정.
3. `scripts/run.sh`에 기존에 실행 중이던 이전 버전 앱 프로세스를 자동으로 종료(`killall OhMyFriend`)하고 새 버전으로 재실행하도록 갱신.
### 재발 방지
- 외부 스킨 사이트의 웹페이지 스크래핑 시 Cloudflare 차단 위험이 있는 사이트는 HTML 파싱 대신 정적 텍스처 CDN 엔드포인트 규칙을 분석하여 다이렉트 변환을 우선 적용합니다.

---

## [화면 가장자리 도달 시 무한 걷기(제자리걸음) 오류]

### 증상
캐릭터가 화면 좌우 가장자리에 도달했을 때 물리 엔진에 의해 이동이 멈추었음에도 불구하고 계속 한 방향으로 걷는 모션(moonwalk/제자리걸음)을 무한히 반복함.

### 원인
1. `PhysicsEngine`이 화면 경계에서 `position.x`를 `screenFrame.minX + 20`과 `screenFrame.maxX - 20`으로 클램핑하고 있었으나, `CharacterBehaviorController`의 엣지 도달 조건은 `platform.xMin + 15`로 마진이 더 좁게 설정되어 있어 `x <= xMin + 15` 조건이 영원히 `true`가 되지 못함.
2. 목표 지점(`targetX`)이 화면 바깥이나 경계 너머로 잡혀 있는 경우, 물리적으로 도달할 수 없어 도착 판정(`reachedTarget`)이 영구히 미달됨.
3. 걷기 상태(`.walk`)에 정체(Stuck) 감지 및 타임아웃 안전장치가 부재했음.

### 해결
1. **경계 감지 마진 정규화**: 화면 좌우 및 플랫폼 엣지 감지 여유폭을 30~35pt로 확대하여 물리 엔진의 클램프 이전에 확실하게 엣지 도달 이벤트가 발생하도록 수정.
2. **엣지 도착 시 다채로운 행동 전이**: 화면 끝 도달 시 걷기를 즉시 멈추고 45% 확률로 털썩 주저앉아 다리를 흔들며 쉬기(`.sit`), 40% 확률로 즉시 몸을 반대로 돌려 화면 안쪽으로 걸어가기, 15% 확률로 멈춰 서서 둘러보기로 상태를 전환.
3. **Anti-Stuck 안전장치**: 걷기 지속 시간이 6초를 초과하거나 실제 X 좌표 이동량이 0.6초 이상 멈춰 있는 경우 즉시 다음 행동으로 자동 전환하는 가드 추가.

### 재발 방지
- 물리적 좌표 제약(Clamping)이 존재하는 컴포넌트와 FSM 판단 로직 간에는 마진 값을 최소 10~15pt 이상 여유 있게 일치시키고, 모든 이동 FSM 상태에는 정체 감지(Anti-stuck guard)를 필수로 포함합니다.

---

## [사망 진행 중인 몹(스켈레톤) 지속 타격 및 넉백 무한 루프]

### 증상
스켈레톤의 HP가 0이 되어 쓰러지는 사망 애니메이션 진행 중에도 캐릭터의 Aggro 모드가 꺼지지 않아 계속 칼질을 가하고, 몹의 피격 플래시와 넉백 타이머가 리셋되어 완전히 사라지지 않는 현상 발생.

### 원인
1. `SkeletonWindow.takeHit()`에 체력 고갈 시 즉시 공격을 차단하는 생존 플래그(`isAlive`) 가드가 누락되어 있었음.
2. 플레이어의 스켈레톤 추격 Aggro 타이머(`skeletonAggroTimer`) 및 돌격 상태가 몹의 사망 시점에 즉시 리셋되지 않아 타격 모션이 잔류함.

### 해결
1. 스켈레톤 및 적대적 몹에 `isAlive` 프로퍼티 도입, `hp <= 0` 또는 `.dying` 진입 시 `guard isAlive`로 추가 피격을 완전 차단.
2. 몹 사망 진입 즉시 캐릭터 컨트롤러의 `skeletonAggroTimer = 0`, 무기 공격 모션 해제, 돌격 중단(`behavior.stopCharging()`)을 연동.

### 재발 방지
- 모든 전투 대상 엔티티는 피격 처리 선두에 `isAlive` 유효성 가드를 배치하고, 사망 트리거 시 상대방의 Aggro 및 타격 FSM 상태를 상호 동기화하여 즉각 해제합니다.

---

## [배포한 .app 의 코드 서명이 무효해 Gatekeeper 검증 실패]

### 증상
릴리스에서 내려받은 `OhMyFriend.app` 의 코드 서명이 무효 상태여서, 사용자가 앱을 그대로 열 수 없었다. 터미널에서 확인하면:

```bash
$ codesign --verify --strict OhMyFriend.app
OhMyFriend.app: code has no resources but signature indicates they must be present

$ codesign -dv --verbose=2 OhMyFriend.app
Identifier=OhMyFriend          # 번들 ID(com.hong.ohmyfriend)가 아니라 실행 파일 이름
Info.plist=not bound           # Info.plist 가 서명에 묶이지 않음

$ spctl --assess --type execute --verbose=4 OhMyFriend.app
OhMyFriend.app: code has no resources but signature indicates they must be present
```

(`spctl` 은 서명을 "신뢰할 수 없음"이 아니라 **구조가 깨졌음**으로 보고한다. 서명이 무효한 앱은 macOS 가 *"손상되었기 때문에 열 수 없습니다"* 로 처리하며, 이 경고에는 열기 버튼이 없고 휴지통 이동만 제안된다 — Apple 문서 기준 동작이며, 이 저장소에서는 `codesign`/`spctl` 출력으로 서명 무효까지를 직접 확인했다. 실제 사용자 화면의 경고 문구는 격리된 다운로드 환경이 필요해 재현하지 못했다.)

이 때문에 README 는 사용자에게 `xattr -cr` 을 직접 실행하도록 안내해야 했다.

### 원인
`scripts/build_app.sh` 가 실행 파일만 복사하고 **번들 전체를 `codesign` 하지 않았다**. Swift/Clang 링커가 Mach-O 에 붙이는 ad-hoc 서명(`flags=0x20002(adhoc,linker-signed)`)만 존재하는 상태라, 번들에 `_CodeSignature/CodeResources` 가 없고 Info.plist 도 서명에 묶이지 않는다. macOS 는 이 서명을 "리소스가 실려 있어야 하는데 없다"고 해석해 번들 검증에 실패하고, 결과를 손상으로 분류한다.

서명 무효는 "확인되지 않은 개발자"와 질적으로 다르다. 후자는 서명이 유효하되 신뢰할 수 없는 경우라 우클릭 → 열기로 사용자가 승인할 수 있지만, 전자는 검증 자체가 실패한 상태라 그 우회가 통하지 않는다.

### 해결
`build_app.sh` 에서 번들 전체를 항상 서명한다. Developer ID 인증서가 있으면 그 인증서 + Hardened Runtime 으로, 없으면 ad-hoc 으로 서명한다(둘 다 `--options runtime` 적용).

```bash
codesign --force --options runtime \
    --entitlements scripts/OhMyFriend.entitlements \
    --sign - OhMyFriend.app
codesign --verify --deep --strict OhMyFriend.app
```

서명 후 `Identifier=com.hong.ohmyfriend`, `Info.plist entries=12`, `Sealed Resources version=2` 가 되고 `valid on disk` 를 만족한다. `restrict`/`--deep` 은 서명 시 쓰지 않는다(중첩 번들이 없으므로 불필요하고, Apple 이 `--deep` 서명을 권장하지 않는다).

### 재발 방지
- 빌드 스크립트는 **서명 검증(`codesign --verify --strict`)을 통과하지 못하면 실패**해야 한다. `make_dmg.sh` 는 서명되지 않은 번들을 감싸는 것을 거부한다.
- Hardened Runtime 은 인증서 유무와 무관하게 항상 켠다. 로컬 ad-hoc 빌드가 배포본과 같은 제약을 드러내야 entitlement 누락(예: Apple Events)을 배포 전에 잡을 수 있다.
- 새 시스템 API 를 도입하면 `scripts/OhMyFriend.entitlements` 갱신이 필요한지 확인한다. 특히 런타임 Metal 셰이더 컴파일(SceneKit shader modifier), JIT, 다른 앱 제어(Apple Events)는 Hardened Runtime 의 영향을 받는다. 검증은 번들을 하드닝 서명한 뒤 실제 앱에서 해당 기능을 켜서 확인한다.
