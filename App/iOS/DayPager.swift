import SwiftUI
import UIKit

/// 日付を左右にめくるページ送り（iPhone）。
///
/// UIPageViewController は表示中と前後のページしか持たないので、何日分さかのぼれても軽い。
/// SwiftUI の TabView(.page) は全ページを準備して重く、ScrollView + LazyHStack は縦の配置がずれたため、
/// UIKit の標準部品を使う。
struct DayPager<Page: View>: UIViewControllerRepresentable {
    /// 表示中のページ（0 = 今日、-1 = 昨日）
    @Binding var offset: Int
    let range: ClosedRange<Int>
    @ViewBuilder let page: (Int) -> Page

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.setViewControllers([context.coordinator.host(for: offset)], direction: .forward, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let current = controller.viewControllers?.first as? PageHost else { return }
        if current.offset == offset {
            // 表示中のページの中身を最新にする
            current.rootView = AnyView(page(offset))
        } else {
            // スワイプ以外で offset が変わったとき
            controller.setViewControllers(
                [coordinator.host(for: offset)],
                direction: offset < current.offset ? .reverse : .forward,
                animated: false)
        }
    }

    final class PageHost: UIHostingController<AnyView> {
        var offset = 0
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: DayPager

        init(_ parent: DayPager) {
            self.parent = parent
        }

        func host(for offset: Int) -> PageHost {
            let host = PageHost(rootView: AnyView(parent.page(offset)))
            host.offset = offset
            // ナビゲーションバーなどの余白は外側の SwiftUI が持つので、ページ側では付けない
            host.safeAreaRegions = []
            host.view.backgroundColor = .clear
            return host
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? PageHost, host.offset - 1 >= parent.range.lowerBound else { return nil }
            return self.host(for: host.offset - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? PageHost, host.offset + 1 <= parent.range.upperBound else { return nil }
            return self.host(for: host.offset + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController], transitionCompleted completed: Bool
        ) {
            guard completed, let host = pageViewController.viewControllers?.first as? PageHost else { return }
            parent.offset = host.offset
        }
    }
}
