import UIKit

/// 对应 Android 翻译期间前台保活：禁用自动锁屏并申请系统后台任务，便于长批次翻译在切出应用时尽量跑完。
@MainActor
final class BackgroundTranslationActivity: ObservableObject {
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    func begin(reason: String = "batch_translate") {
        UIApplication.shared.isIdleTimerDisabled = true
        endBackgroundTask()
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: reason) { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func end() {
        UIApplication.shared.isIdleTimerDisabled = false
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}
