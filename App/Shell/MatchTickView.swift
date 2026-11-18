import SwiftUI

/// Drives `LocalMatchSession` at display refresh with a fixed 60 Hz accumulator.
struct MatchTickView: View {
    let isActive: Bool
    let onTick: (Date) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            TickEmitter(date: timeline.date, onTick: onTick)
        }
    }
}

private struct TickEmitter: View {
    let date: Date
    let onTick: (Date) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: date) { _, newDate in
                onTick(newDate)
            }
            .onAppear {
                onTick(date)
            }
    }
}