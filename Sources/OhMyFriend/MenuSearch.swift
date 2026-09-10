import AppKit

// 대형 서브메뉴 인라인 검색 필터: 메뉴를 열고 타이핑하면 해당 서브메뉴 항목이 실시간 필터링된다.
// 검색은 필터일 뿐이며 기존 항목·순서·동작을 변경하지 않는다.

// MARK: - 검색 필드 내장 메뉴 아이템

/// 서브메뉴 첫 줄에 들어가는 검색 필드 아이템.
/// 클릭 시 포커스를 확보하고, 입력마다 + Enter(확정)마다 onQuery를 호출한다.
final class MenuSearchField: NSSearchField {
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        // 메뉴 트래킹 중 클릭이 씹히지 않도록 먼저 포커스를 확보한다.
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }
}

final class SearchFieldItem: NSMenuItem {
    let searchField = MenuSearchField()
    var onQuery: ((String) -> Void)?

    init(onQuery: @escaping (String) -> Void) {
        self.onQuery = onQuery
        super.init(title: "", action: nil, keyEquivalent: "")
        // view를 가진 아이템은 highlight 대상이 아니므로 메뉴가 닫히지 않는다.
        isEnabled = true
        let field = searchField
        field.placeholderString = "🔍 검색..."
        field.frame = NSRect(x: 8, y: 2, width: 250, height: 22)
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = true
        field.target = self
        field.action = #selector(fieldCommitted(_:))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fieldChanged(_:)),
            name: NSControl.textDidChangeNotification,
            object: field
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 266, height: 26))
        container.addSubview(field)
        view = container
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func fieldChanged(_ note: Notification) {
        onQuery?(searchField.stringValue)
    }

    @objc private func fieldCommitted(_ sender: NSSearchField) {
        // Enter 확정 시에도 동일 필터를 적용한다.
        onQuery?(sender.stringValue)
    }
}

// MARK: - 검색 가능 서브메뉴 팩토리

private func menuSearchNormalize(_ s: String) -> String {
    // 대소문자 무시·공백 무시 비교용 정규화.
    s.lowercased().filter { !$0.isWhitespace }
}

/// 검색 필터가 달린 서브메뉴 아이템을 만든다.
///
/// - 쿼리 비었을 때: groups가 1개면 항목 그대로 평탄 나열,
///   2개 이상이면 그룹별 서브메뉴(기존 구조 유지).
/// - 쿼리 있을 때: 전 그룹 평탄화 후 타이틀 contains(정규화 비교) 필터,
///   결과 타이틀은 "그룹 › 항목", 0건이면 "(결과 없음)" 비활성 항목.
/// - 결과 클릭은 ClosureMenuItem(동일 run/key/isEnabled) 그대로.
/// - 쿼리 변경 시 서브메뉴 아이템들을 그 자리에서 교체한다(검색 필드 줄 유지).
func makeSearchableMenu(title: String, groups: [(String, [ExtraMenuEntry])]) -> NSMenuItem {
    let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    let sub = NSMenu()
    sub.autoenablesItems = false
    root.submenu = sub

    func rebuild(query: String, in menu: NSMenu) {
        // 검색 필드(0번) 유지, 그 아래만 그 자리에서 교체.
        while menu.items.count > 1 {
            menu.removeItem(at: 1)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if groups.count == 1 {
                for e in groups[0].1 {
                    menu.addItem(ClosureMenuItem(e))
                }
            } else {
                for (gTitle, entries) in groups {
                    let child = NSMenu()
                    child.autoenablesItems = false
                    for e in entries {
                        child.addItem(ClosureMenuItem(e))
                    }
                    let gItem = NSMenuItem(title: gTitle, action: nil, keyEquivalent: "")
                    gItem.submenu = child
                    menu.addItem(gItem)
                }
            }
            return
        }
        let nq = menuSearchNormalize(trimmed)
        var matched: [(String, ExtraMenuEntry)] = []
        for (gTitle, entries) in groups {
            for e in entries where menuSearchNormalize(e.title()).contains(nq) {
                matched.append((gTitle, e))
            }
        }
        if matched.isEmpty {
            let empty = NSMenuItem(title: "(결과 없음)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for (gTitle, e) in matched {
            // 동일 동작을 유지하면서 필터 결과임을 드러내는 타이틀.
            let item = ClosureMenuItem(
                title: "\(gTitle) › \(e.title())",
                run: e.run,
                keyEquivalent: e.keyEquivalent,
                isEnabled: e.isEnabled()
            )
            menu.addItem(item)
        }
    }

    // 검색 클로저가 서브메뉴를 캡처하되 순환 참조로 메뉴가 새지 않도록 weak로 잡는다.
    weak var weakSub: NSMenu? = sub
    let searchItem = SearchFieldItem { query in
        guard let menu = weakSub else { return }
        // 메뉴 트래킹 중 UI 갱신은 메인 스레드에서 그 자리 교체.
        if Thread.isMainThread {
            rebuild(query: query, in: menu)
        } else {
            DispatchQueue.main.async {
                rebuild(query: query, in: menu)
            }
        }
    }
    sub.addItem(searchItem)
    rebuild(query: "", in: sub)
    return root
}
