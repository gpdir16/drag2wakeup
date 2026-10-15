import AppKit
import SwiftUI

// 드래그 마우스 때면
enum Choice {
    case cancel     // 무시
    case keepAwake  // 가운데: 화면 켠상태로
    case screenOff  // 오른쪽: 화면 끈상태ㄹ호
    case turnOff    // 왼쪽: 타이머 끔
}

let minuteSteps = [
    5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60,
    75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240,
    270, 300, 330, 360, 390, 420, 450, 480, 510, 540, 570, 600, 630, 660, 690, 720,
]

let overlayWidth: CGFloat = 440
let overlayHeight: CGFloat = 660
let cancelZone: CGFloat = 34       // 아이콘에서 이만큼은 끌어야 시작
let pixelsPerStep: CGFloat = 12    // 이만큼 끌 때마다 한 단계
let sideZone: CGFloat = 70         // 좌우로 이만큼 벗어나면 다른 모드
let dropRadius: CGFloat = 34

@MainActor
class OverlayState: ObservableObject {
    @Published var top = CGPoint.zero   // 아이콘 바로 아래
    @Published var drop = CGPoint.zero  // 방울 위치
    @Published var choice = Choice.cancel
    @Published var minutes: Int? = nil  // nil = 무제한
    @Published var canTurnOff = false
    @Published var showHints = false
}

// 투명 창
@MainActor
class Overlay {
    let state = OverlayState()
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView(state: state))
    }

    func show(iconBottom: CGPoint, screen: NSScreen?, canTurnOff: Bool) {
        var x = iconBottom.x - overlayWidth / 2
        if let screen {
            x = max(x, screen.frame.minX)
            x = min(x, screen.frame.maxX - overlayWidth)
        }
        panel.setFrame(
            NSRect(x: x, y: iconBottom.y - overlayHeight, width: overlayWidth, height: overlayHeight),
            display: false
        )

        state.top = CGPoint(x: iconBottom.x - x, y: 0)
        state.drop = state.top
        state.choice = .cancel
        state.minutes = nil
        state.canTurnOff = canTurnOff
        state.showHints = false

        panel.alphaValue = 1
        panel.orderFrontRegardless()
        withAnimation(.smooth(duration: 0.3)) {
            state.showHints = true
        }
    }

    func mouseMoved(to mouse: CGPoint) {
        // 화면 좌표(아래에서 위로)를 창 안 좌표(위에서 아래로)로 바꿈
        let x = mouse.x - panel.frame.minX
        let y = panel.frame.maxY - mouse.y
        let dx = x - state.top.x

        var choice = Choice.keepAwake
        if dx > sideZone {
            choice = .screenOff
        }
        if dx < -sideZone && state.canTurnOff {
            choice = .turnOff
        }
        if y < cancelZone {
            choice = .cancel
        }

        let step = max(0, Int((y - cancelZone) / pixelsPerStep))
        var minutes: Int? = nil
        if step < minuteSteps.count {
            minutes = minuteSteps[step]
        }

        // 트랙패드
        if choice != state.choice || minutes != state.minutes {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        state.choice = choice
        state.minutes = minutes

        // 방울
        let dropX = min(max(x, dropRadius + 4), overlayWidth - dropRadius - 4)
        let dropY = min(max(y + 40, 0), overlayHeight - dropRadius - 70)
        state.drop = CGPoint(x: dropX, y: dropY)
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                self.panel.orderOut(nil)
            }
        }
    }
}

let keepAwakeColors = [Color(red: 1.00, green: 0.78, blue: 0.25), Color(red: 1.00, green: 0.52, blue: 0.18)]
let screenOffColors = [Color(red: 0.45, green: 0.55, blue: 1.00), Color(red: 0.42, green: 0.28, blue: 0.90)]
let turnOffColors = [Color(red: 1.00, green: 0.42, blue: 0.40), Color(red: 0.86, green: 0.18, blue: 0.28)]
let cancelColors = [Color(white: 0.62), Color(white: 0.45)]

struct OverlayView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawZoneLines(context)
                drawDrop(context)
            }

            if state.canTurnOff {
                hintChip(icon: "power", title: "Turn Off", colors: turnOffColors, arrow: "arrow.down.left")
                    .scaleEffect(state.choice == .turnOff ? 1.08 : 1)
                    .position(x: state.top.x - 150, y: 64)
            }
            hintChip(icon: "moon.fill", title: "Screen Off", colors: screenOffColors, arrow: "arrow.down.right")
                .scaleEffect(state.choice == .screenOff ? 1.08 : 1)
                .position(x: state.top.x + 150, y: 64)

            // 방울 안의 글자
            Text(dropText)
                .font(.system(size: dropText.count > 4 ? 14 : 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.1), value: dropText)
                .position(state.drop)

            // 방울 아래 설명
            caption
                .position(
                    x: min(max(state.drop.x, 120), overlayWidth - 120),
                    y: state.drop.y + dropRadius + 24
                )
        }
        .frame(width: overlayWidth, height: overlayHeight)
        .opacity(state.showHints ? 1 : 0)
        .animation(.snappy(duration: 0.2), value: state.choice)
    }

    var dropText: String {
        switch state.choice {
        case .cancel: return "×"
        case .turnOff: return "Off"
        case .keepAwake, .screenOff: return durationText(state.minutes)
        }
    }

    var colors: [Color] {
        switch state.choice {
        case .cancel: return cancelColors
        case .keepAwake: return keepAwakeColors
        case .screenOff: return screenOffColors
        case .turnOff: return turnOffColors
        }
    }

    var caption: some View {
        var icon = ""
        var title = ""
        var subtitle = ""
        switch state.choice {
        case .cancel:
            icon = "xmark"
            title = "Cancel"
            subtitle = "Pull down to set time"
        case .keepAwake:
            icon = "sun.max.fill"
            title = "Keep Awake"
            subtitle = "Display stays on · " + untilText(state.minutes)
        case .screenOff:
            icon = "moon.fill"
            title = "Screen Off"
            subtitle = "System stays awake · " + untilText(state.minutes)
        case .turnOff:
            icon = "power"
            title = "Turn Off"
            subtitle = "Allow sleep again"
        }

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .fixedSize()
        .glassBackground()
    }

    func hintChip(icon: String, title: String, colors: [Color], arrow: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: arrow)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Image(systemName: icon)
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .fixedSize()
        .glassBackground()
    }

    // 좌우 경계 점선
    func drawZoneLines(_ context: GraphicsContext) {
        var lines = [state.top.x + sideZone]
        if state.canTurnOff {
            lines.append(state.top.x - sideZone)
        }

        for x in lines {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 40))
            path.addLine(to: CGPoint(x: x, y: overlayHeight - 40))
            context.stroke(path, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }
    }

    // 아이콘에서 방울까지 늘어나는 물방울 모양
    func drawDrop(_ context: GraphicsContext) {
        let top = state.top
        let drop = state.drop
        let neck: CGFloat = 11

        // 점점 커지게
        let radius = dropRadius * min(1, 0.4 + drop.y / 80)

        // 루트에서 방울로 향하는 방향
        let dx = drop.x - top.x
        let dy = drop.y - top.y
        let length = max(hypot(dx, dy), 0.001)
        let dirX = dx / length
        let dirY = dy / length
        let angle = atan2(dirY, dirX)

        // 방울 둘레 위의 점
        func pointOnDrop(_ a: CGFloat) -> CGPoint {
            CGPoint(x: drop.x + radius * cos(a), y: drop.y + radius * sin(a))
        }

        let neckLeft = CGPoint(x: top.x - neck, y: top.y - 2)
        let neckRight = CGPoint(x: top.x + neck, y: top.y - 2)
        let dropLeft = pointOnDrop(angle + .pi / 2)
        let dropRight = pointOnDrop(angle - .pi / 2)
        let bend = length * 0.45

        var path = Path()
        // 목 왼쪽 -> 방울 왼쪽 (곡선)
        path.move(to: neckLeft)
        path.addCurve(
            to: dropLeft,
            control1: CGPoint(x: neckLeft.x, y: neckLeft.y + bend),
            control2: CGPoint(x: dropLeft.x - dirX * bend * 0.6, y: dropLeft.y - dirY * bend * 0.6)
        )
        // 방울 아래쪽 반원
        for i in 1...48 {
            path.addLine(to: pointOnDrop(angle + .pi / 2 - .pi * CGFloat(i) / 48))
        }
        // 방울 오른쪽 -> 목 오른쪽 (곡선)
        path.addCurve(
            to: neckRight,
            control1: CGPoint(x: dropRight.x - dirX * bend * 0.6, y: dropRight.y - dirY * bend * 0.6),
            control2: CGPoint(x: neckRight.x, y: neckRight.y + bend)
        )
        path.closeSubpath()

        var shadowContext = context
        shadowContext.addFilter(.shadow(color: .black.opacity(0.28), radius: 10, y: 4))
        shadowContext.fill(path, with: .linearGradient(Gradient(colors: colors), startPoint: top, endPoint: drop))
        context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 0.75)
    }
}

extension View {
    // Liquid Ass
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }
}
