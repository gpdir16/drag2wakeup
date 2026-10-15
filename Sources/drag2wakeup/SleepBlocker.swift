import Foundation
import IOKit.pwr_mgt

@MainActor
class SleepBlocker {
    static let shared = SleepBlocker()

    var isOn = false
    var endTime: Date?  // nil = 무제한
    var onChange: () -> Void = {}

    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    // if (screenOff == true)면 화면 끄고 잠자기만 방지
    func start(screenOff: Bool, minutes: Int?) {
        stop()

        var type = kIOPMAssertionTypePreventUserIdleDisplaySleep
        if screenOff {
            type = kIOPMAssertionTypePreventUserIdleSystemSleep
        }
        IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "drag2wakeup" as CFString,
            &assertionID
        )

        isOn = true
        if let minutes {
            endTime = Date().addingTimeInterval(Double(minutes * 60))
        }

        // 10초마다 시간 확인
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated {
                SleepBlocker.shared.checkTime()
            }
        }

        onChange()
    }

    func stop() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        timer?.invalidate()
        timer = nil
        isOn = false
        endTime = nil

        onChange()
    }

    private func checkTime() {
        if let endTime, Date() >= endTime {
            stop()
        } else {
            onChange()  // 메뉴바의 남은 시간 갱신
        }
    }
}

// 5 -> "5m", 90 -> "1h 30m", 120 -> "2h", nil -> "∞"
func durationText(_ minutes: Int?) -> String {
    guard let minutes else { return "∞" }

    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
}

// 지금부터 minutes 뒤의 시각
func untilText(_ minutes: Int?) -> String {
    guard let minutes else { return "until stopped" }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "h:mm a"
    return "until " + formatter.string(from: Date().addingTimeInterval(Double(minutes * 60)))
}
