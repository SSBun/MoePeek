// 本地人工预览的定向键盘工具；只向参数指定的预览进程投递输入，不修改应用源码。
import AppKit
import ApplicationServices

let arguments = CommandLine.arguments
let pid = pid_t(arguments[1])!
let action = arguments[2]
func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = flags
        event.postToPid(pid)
        usleep(60_000)
    }
}
switch action {
case "type":
    key(0, flags: .maskCommand)
    let text = Array(arguments[3].utf16)
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
        event.keyboardSetUnicodeString(stringLength: text.count, unicodeString: text)
        event.postToPid(pid)
        usleep(60_000)
    }
case "open":
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 101, keyDown: down)!
        event.flags = [.maskControl, .maskAlternate, .maskShift]
        event.post(tap: .cghidEventTap)
        usleep(60_000)
    }
case "enter": key(36)
case "newline": key(36, flags: .maskShift)
case "copy": key(36, flags: .maskCommand)
case "escape": key(53)
case "scroll":
    let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -500, wheel2: 0, wheel3: 0)!
    let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    if let window = windows.first(where: { $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowName as String] as? String == "Smart Translation" }),
       let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
        let point = CGPoint(x: bounds["X"]! + bounds["Width"]! / 2, y: bounds["Y"]! + bounds["Height"]! / 2)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(100_000)
        event.location = point
        event.post(tap: .cghidEventTap)
    }
case "window-id":
    for window in CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [] {
        if window[kCGWindowOwnerPID as String] as? pid_t == pid,
           window[kCGWindowName as String] as? String == "Smart Translation" {
            print(window[kCGWindowNumber as String]!)
        }
    }
default: fatalError("Unknown preview action")
}
