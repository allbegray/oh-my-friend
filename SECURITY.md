이 문서는 Oh My Friend 프로젝트의 보안 정책, 네트워크 통신, 비밀 관리 및 코드 작성 보안 규칙을 안내합니다.

# 보안 정책

## 인증/인가
Oh My Friend는 순수 클라이언트 기반의 macOS 데스크톱 애플리케이션으로, 자체 사용자 계정 데이터베이스나 인가 서버를 두지 않습니다.

1. **외부 공개 API 통신**:
   - Mojang 공개 프로필 API, Minotar 및 Crafatar 스킨 CDN을 활용하며, 별도의 사용자 비밀번호나 유료 인증키를 요구하지 않는 공개 조회 방식으로 동작합니다.
   - 공개 API 호출 예시:
     ```bash
     # Mojang UUID 조회
     curl -s "https://api.mojang.com/users/profiles/minecraft/<USERNAME>"

     # Minotar 64x64 PNG 스킨 직접 다운로드
     curl -s -o skin.png "https://minotar.net/skin/<USERNAME>"

     # Crafatar 스킨 다운로드
     curl -s -o skin.png "https://crafatar.com/skins/<UUID>"
     ```

2. **인증이 필요한 외부 연동 확장 시 규칙**:
   - 향후 인증이 필요한 커스텀 스킨 서버 연동 시 아래 표준 헤더 형식을 준수해야 하며, 소스 코드 내에 실제 키 값을 하드코딩하는 것을 엄격히 금지합니다:
     ```bash
     # JWT / Bearer 토큰 형식
     curl -H "Authorization: Bearer <API_TOKEN>" "https://api.example.com/v1/skins"

     # API Key 헤더 형식
     curl -H "X-API-Key: <API_KEY>" "https://api.example.com/v1/skins"
     ```

## 비밀 관리
- 저장소 내에 어떠한 인증 토큰, 비밀번호, 개인 식별 정보(PII)도 포함되어서는 안 됩니다.
- 설정값이나 민감한 정보가 필요한 경우 환경 변수(`ProcessInfo.processInfo.environment`) 또는 macOS 시스템 키체인(`Keychain`)을 활용합니다.
- `.gitignore`를 통해 빌드 산출물, 개인 IDE 설정, 캐시 파일의 커밋을 철저히 차단합니다.

## 배포 바이너리 서명 및 공증
배포물은 항상 **번들 전체가 코드 서명된 상태**로 만들어집니다. Mach-O 링커가 붙이는 ad-hoc 서명만으로는 `_CodeSignature/CodeResources` 가 없어 번들이 성립하지 않고(`code has no resources but signature indicates they must be present`), 그대로 배포하면 Gatekeeper 가 앱을 **손상됨**으로 판정해 "손상되었기 때문에 열 수 없습니다" 경고가 뜹니다. `scripts/build_app.sh` 는 항상 번들 전체를 서명해 이 상태를 방지합니다.

서명 수준은 환경에 따라 자동으로 결정됩니다.

| 환경 | 서명 | 공증 | 사용자 최초 실행 |
| :--- | :--- | :--- | :--- |
| Developer ID 인증서 + 공증 자격증명 | Developer ID Application + Hardened Runtime | O | 경고 없음 |
| Developer ID 인증서만 | Developer ID Application + Hardened Runtime | X | "확인되지 않은 개발자" → 우클릭 → 열기 |
| 인증서 없음(로컬 빌드) | ad-hoc + Hardened Runtime | X | "확인되지 않은 개발자" → 우클릭 → 열기 |

- **Hardened Runtime 은 두 경로 모두에 적용**합니다. 인증서 없는 로컬 빌드가 배포본과 같은 제약을 드러내야 권한 누락을 미리 잡을 수 있기 때문입니다.
- Hardened Runtime 아래에서 필요한 권한은 `scripts/OhMyFriend.entitlements` 에만 선언합니다. 현재 필요한 것은 `com.apple.security.automation.apple-events` 하나뿐입니다 — `WindowMinimizer` 의 AppleScript 폴백이 System Events 에 창 최소화를 요청하기 때문이며, 이 entitlement 와 Info.plist 의 `NSAppleEventsUsageDescription` 이 모두 없으면 공증 후 그 경로만 조용히 실패합니다.
- 접근성(AX) 권한과 화면상 창 좌표 조회는 비샌드박스 앱이므로 entitlement 대상이 아니며, 사용자 동의로만 부여됩니다.
- CI 자격증명은 GitHub Secrets 로만 주입하며(`MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_PASSWORD`), 값이 없으면 서명·공증 단계를 건너뛰고 ad-hoc 배포본을 만듭니다. 저장소에는 어떤 인증서·비밀번호도 커밋되지 않습니다.

## 취약점 보고
- 보안 취약점이나 잠재적 위험이 발견된 경우, 공개 이슈(Public Issue) 대신 GitHub 저장소의 **Private Vulnerability Reporting**을 이용해 비공개로 제보해 주시기 바랍니다.
- 제보 접수 후 48시간 이내에 분석 및 패치 일정을 안내합니다.

## 코드 작성 시 보안 규칙
- **HTTPS 의무화**: 외부 네트워크 요청은 반드시 암호화된 HTTPS 프로토콜만 사용합니다.
- **네트워크 타임아웃 적용**: 무한정 대기로 인한 리소스 고갈을 막기 위해 요청 타임아웃(10초) 및 리소스 타임아웃(20초)을 강제합니다.
- **입력 데이터 및 이미지 유효성 검증**:
  - 외부에서 수신한 스킨 데이터는 단순 확장이 아닌 `NSImage` 및 `CGImage` 디코딩을 거치며, 마인크래프트 스킨 규격(64×64, 64×32, 128×128 등)에 부합하는지 엄격히 검증합니다.
- **경로 조작(Path Traversal) 방지**:
  - 스킨을 로컬에 저장할 때 파일명에서 슬래시(`/`), 역슬래시(`\`), `..` 등의 경로 제어 문자를 철저히 필터링/치환합니다.
- **개인정보 및 화면 보안**:
  - 본 앱은 화면 캡처(Screen Recording)를 수행하지 않으며, 열려 있는 윈도우의 프레임 좌표(`kCGWindowBounds`)만을 질의하여 개인 화면 내용이 유출되지 않도록 설계되었습니다.
- **자동 업데이트 보안**:
  - GitHub 공식 Releases API(`api.github.com`)를 통해 암호화된 HTTPS로만 릴리스 바이너리를 다운로드하며, 교체 프로세스는 공식 번들 구조 내에서만 한정하여 동작합니다.
