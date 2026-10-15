import AppKit
import ServiceManagement

// 메뉴바 아이콘
@MainActor
class MenuBar: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let overlay = Overlay()

    var mouseTimer: Timer?
    var mouseStart = CGPoint.zero
    var isDragging = false

    override init() {
        super.init()

        let button = statusItem.button!
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        // 버튼 위에 투명한 뷰를 덮어서 마우스 누름을 직접 받음
        let catcher = ClickCatcher(frame: button.bounds)
        catcher.autoresizingMask = [.width, .height]
        catcher.onPress = { [weak self] in
            self?.mousePressed()
        }
        button.addSubview(catcher)

        SleepBlocker.shared.onChange = { [weak self] in
            self?.updateIcon()
        }
        updateIcon()
    }

    // 켜져 있으면 채워진 컵 + 남은 시간
    func updateIcon() {
        let blocker = SleepBlocker.shared
        let button = statusItem.button!

        let symbol = blocker.isOn ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "drag2wakeup")
        image?.isTemplate = true
        button.image = image

        var title = ""
        if blocker.isOn {
            if let endTime = blocker.endTime {
                let minutesLeft = Int(ceil(endTime.timeIntervalSinceNow / 60))
                title = " " + durationText(max(minutesLeft, 1))
            } else {
                title = " ∞"
            }
        }
        if button.title != title {
            button.title = title
        }
    }

    // 버튼 누르는 동안 마우스 위치 확인
    func mousePressed() {
        if mouseTimer != nil { return }

        mouseStart = NSEvent.mouseLocation
        isDragging = false
        statusItem.button?.highlight(true)

        mouseTimer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkMouse()
            }
        }
        RunLoop.main.add(mouseTimer!, forMode: .common)
    }

    func checkMouse() {
        let mouse = NSEvent.mouseLocation
        let buttonIsDown = NSEvent.pressedMouseButtons & 1 == 1

        if !buttonIsDown {
            mouseReleased()
            return
        }

        // 3pt 넘게 움직이면 드래그로 봄
        let moved = hypot(mouse.x - mouseStart.x, mouse.y - mouseStart.y)
        if !isDragging && moved > 3 {
            isDragging = true
            let button = statusItem.button!
            let iconRect = button.window!.convertToScreen(button.convert(button.bounds, to: nil))
            overlay.show(
                iconBottom: CGPoint(x: iconRect.midX, y: iconRect.minY),
                screen: button.window!.screen,
                canTurnOff: SleepBlocker.shared.isOn
            )
        }

        if isDragging {
            overlay.mouseMoved(to: mouse)
        }
    }

    func mouseReleased() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        statusItem.button?.highlight(false)

        if !isDragging {
            showMenu()
            return
        }

        let minutes = overlay.state.minutes
        switch overlay.state.choice {
        case .keepAwake: SleepBlocker.shared.start(screenOff: false, minutes: minutes)
        case .screenOff: SleepBlocker.shared.start(screenOff: true, minutes: minutes)
        case .turnOff: SleepBlocker.shared.stop()
        case .cancel: break
        }
        overlay.hide()
    }

    func showMenu() {
        let menu = NSMenu()

        if SleepBlocker.shared.isOn {
            let turnOff = menu.addItem(withTitle: "Turn Off", action: #selector(turnOff), keyEquivalent: "")
            turnOff.target = self
            menu.addItem(.separator())
        }

        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func turnOff() {
        SleepBlocker.shared.stop()
    }

    @objc func toggleLogin() {
        let app = SMAppService.mainApp
        do {
            if app.status == .enabled {
                try app.unregister()
            } else {
                try app.register()
            }
        } catch {
            NSSound.beep()
        }
    }
}

class ClickCatcher: NSView {
    var onPress: () -> Void = {}

    override func mouseDown(with event: NSEvent) { onPress() }
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
