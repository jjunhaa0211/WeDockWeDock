import AppKit
import ApplicationServices

enum AppFocuser {
    /// 앱을 앞으로 가져오기 추가적으로 스페이스로 이동
    static func focus(_ app: NSRunningApplication) {
        _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        // AX 권한이 있을 때만 Raise 시도 (권한 필수)
        guard isAXTrusted else { return }

        // 약간의 딜레이 후 창 Raise 시도 <- 컴바인으로 바꾸자
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            _ = raiseFirstWindow(of: app.processIdentifier)
        }
    }

    /// AX(손쉬운 사용) 권한 체크
    private static var isAXTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Accessibility로 해당 PID의 창을 하나 골라 Raise(앞으로) + 최소화 해제 시도
    private static func raiseFirstWindow(of pid: pid_t) -> Bool {
        let appAX = AXUIElementCreateApplication(pid)

        // windows 가져오기 (CFArray로 받기!)
        guard let windows = copyAXWindows(appAX), !windows.isEmpty else {
            return false
        }

        // main window 가져오기(있으면 우선)
        let targetWindow: AXUIElement = {
            if let main = copyAXMainWindow(appAX) {
                return main
            }
            return windows[0]
        }()

        // 최소화 해제 시도
        if let minimized = copyBoolAttribute(targetWindow, kAXMinimizedAttribute as CFString), minimized == true {
            _ = AXUIElementSetAttributeValue(targetWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // 앞으로 올리기
        let raiseErr = AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
        if raiseErr == .success {
            _ = AXUIElementSetAttributeValue(appAX, kAXFocusedWindowAttribute as CFString, targetWindow)
            return true
        }

        return false
    }

    // MARK: - AX Helpers

    private static func copyAXWindows(_ appAX: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appAX, kAXWindowsAttribute as CFString, &value)
        guard err == .success, let cfArray = value else { return nil }

        // CFArray로 다루기 (가장 안전)
        let arr = unsafeBitCast(cfArray, to: CFArray.self)
        let count = CFArrayGetCount(arr)

        var result: [AXUIElement] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let raw = CFArrayGetValueAtIndex(arr, i) // UnsafeRawPointer?
            // 여기서 unsafeBitCast는 "포인터 -> AXUIElement"라 크기 문제 없음
            let ax = unsafeBitCast(raw, to: AXUIElement.self)
            result.append(ax)
        }
        return result
    }

    private static func copyAXMainWindow(_ appAX: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appAX, kAXMainWindowAttribute as CFString, &value)
        guard err == .success, let v = value else { return nil }
        return unsafeBitCast(v, to: AXUIElement.self) // CFTypeRef 포인터 -> AXUIElement
    }

    private static func copyBoolAttribute(_ element: AXUIElement, _ key: CFString) -> Bool? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, key, &value)
        guard err == .success, let v = value else { return nil }
        return (v as? Bool)
    }
}
