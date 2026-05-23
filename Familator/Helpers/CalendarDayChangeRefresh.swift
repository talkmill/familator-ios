import SwiftUI
import UIKit

extension View {
    /// Calls `reload` when the user's calendar day changes (e.g. after midnight), when the scene becomes active after a possible day change, or after a significant time change.
    @ViewBuilder
    func reloadWhenCalendarDayChanges(if enabled: Bool = true, _ reload: @escaping () -> Void) -> some View {
        if enabled {
            modifier(CalendarDayChangeModifier(reload: reload))
        } else {
            self
        }
    }
}

private struct CalendarDayChangeModifier: ViewModifier {
    let reload: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var lastKnownDayStart: Date?

    private static let tick = Timer.publish(every: 30, tolerance: 5, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .onAppear(perform: checkDayChange)
            .onReceive(Self.tick) { _ in checkDayChange() }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    checkDayChange()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                checkDayChange()
            }
    }

    private func checkDayChange() {
        let todayStart = Calendar.current.startOfDay(for: Date())
        if let last = lastKnownDayStart {
            if last != todayStart {
                lastKnownDayStart = todayStart
                reload()
            }
        } else {
            lastKnownDayStart = todayStart
        }
    }
}
