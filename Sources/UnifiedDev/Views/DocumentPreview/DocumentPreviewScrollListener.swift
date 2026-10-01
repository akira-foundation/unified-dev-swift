import Foundation
import WebKit

@MainActor
final class DocumentPreviewScrollListener: NSObject, WKScriptMessageHandler {
    static let name = "unifiedDevPreviewScroll"

    var onScroll: ((CGPoint) -> Void)?

    static let source = """
    (() => {
      let pending = false;
      addEventListener("scroll", () => {
        if (pending) return;
        pending = true;
        setTimeout(() => {
          pending = false;
          webkit.messageHandlers.\(name).postMessage([scrollX, scrollY]);
        }, 150);
      }, { passive: true });
    })();
    """

    static let restore = """
    let moved = false;
    const stop = () => { moved = true; };
    addEventListener("wheel", stop, { once: true, passive: true });
    addEventListener("keydown", stop, { once: true });
    for (const delay of [0, 50, 150, 300, 600, 1000, 2000]) {
      await new Promise(resolve => setTimeout(resolve, delay));
      if (moved) return;
      scrollTo(x, y);
      if (Math.abs(scrollY - y) < 2 && Math.abs(scrollX - x) < 2) return;
    }
    """

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let pair = message.body as? [Double], pair.count == 2 else { return }
        onScroll?(CGPoint(x: pair[0], y: pair[1]))
    }
}
