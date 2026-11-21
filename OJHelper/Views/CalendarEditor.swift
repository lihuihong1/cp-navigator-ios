import EventKit
import EventKitUI
import SwiftUI

/// 系统日历编辑页（等价于 Android 的 ACTION_INSERT：预填后由用户确认保存）。
struct CalendarEditor: UIViewControllerRepresentable {
    let contest: Contest
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let service = CalendarService.shared
        let controller = EKEventEditViewController()
        controller.eventStore = service.store
        controller.event = service.makeEvent(for: contest)
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFinish()
        }
    }
}

/// 以 sheet 形式弹出日历编辑页。
struct CalendarSheet: View {
    let contest: Contest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CalendarEditor(contest: contest) {
            dismiss()
        }
        .ignoresSafeArea()
    }
}