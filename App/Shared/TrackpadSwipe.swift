#if os(macOS)
import SwiftUI
import AppKit

enum SwipeDirection {
    /// 指を右へ（前の日へ）
    case right
    /// 指を左へ（次の日へ）
    case left
}

extension View {
    /// トラックパッドを2本指で横にスワイプしたら action を呼ぶ（1回のスワイプにつき1回）。
    func onTrackpadSwipe(isEnabled: Bool = true, perform action: @escaping (SwipeDirection) -> Void) -> some View {
        modifier(TrackpadSwipeModifier(isEnabled: isEnabled, action: action))
    }
}

private struct TrackpadSwipeModifier: ViewModifier {
    var isEnabled: Bool
    var action: (SwipeDirection) -> Void
    @State private var monitor = SwipeMonitor()

    func body(content: Content) -> some View {
        content
            .onAppear { monitor.start() }
            .onDisappear { monitor.stop() }
            .onChange(of: isEnabled, initial: true) { _, enabled in monitor.isEnabled = enabled }
            .task { monitor.action = action }
    }
}

@MainActor
private final class SwipeMonitor {
    var isEnabled = true
    var action: ((SwipeDirection) -> Void)?
    private var token: Any?
    private var accumulated: CGFloat = 0
    private var fired = false

    /// これだけ横に動いたら1日送る
    private let threshold: CGFloat = 60

    func start() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    private func handle(_ event: NSEvent) {
        // トラックパッドの指の動きだけを見る（マウスホイールと慣性スクロールは無視）
        guard isEnabled, event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty else { return }

        if event.phase.contains(.began) {
            accumulated = 0
            fired = false
        }
        if event.phase.contains(.changed), !fired,
           abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            // 「ナチュラルなスクロール」の設定によらず、指の向きにそろえる
            let fingerDX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
            accumulated += fingerDX
            if abs(accumulated) >= threshold {
                fired = true
                action?(accumulated > 0 ? .right : .left)
            }
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            accumulated = 0
            fired = false
        }
    }
}
#endif
