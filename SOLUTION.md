이 문서는 Oh My Friend 개발 과정에서 발생한 기술적 문제, 근본 원인 및 재발 방지 해결책을 기록합니다.

# 문제 해결 지식

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
