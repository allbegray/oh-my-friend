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
