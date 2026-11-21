import EventKit
import Foundation

/// 写入系统日历（P2）。对应 Android 版 Cal.java 的语义：
/// 标题带站点短名、描述带站点名与比赛链接、北京时间、提前 15 分钟提醒。
@MainActor
final class CalendarService {
    static let shared = CalendarService()

    let store = EKEventStore()

    enum Access {
        case granted
        case denied
    }

    func ensureAccess() async -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .writeOnly, .fullAccess:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                store.requestWriteOnlyAccessToEvents { ok, _ in
                    continuation.resume(returning: ok)
                }
            }
            return granted ? .granted : .denied
        @unknown default:
            return .denied
        }
    }

    /// 预填一场比赛的事件（由系统编辑页让用户确认保存）。
    func makeEvent(for contest: Contest) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = "[\(contest.oj.short)] \(contest.title)"
        var notes = "\(contest.oj.name) 比赛"
        if let url = contest.url {
            notes += "\n\(url.absoluteString)"
        }
        event.notes = notes
        event.startDate = contest.start
        event.endDate = contest.end
        event.isAllDay = false
        event.timeZone = Contest.calendar.timeZone
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
        event.calendar = store.defaultCalendarForNewEvents
        return event
    }
}