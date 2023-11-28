import AppKit
import FlutterMacOS
import WebKit

class PlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private var controller: ViewController

    init(messenger: FlutterBinaryMessenger) {
        self.controller = ViewController()
        super.init()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 512, height: 512), configuration: webConfiguration)
        webView.uiDelegate = self.controller
        self.controller.webView = webView
        return webView
    }
}

class ViewController: NSViewController, WKUIDelegate {
    var webView: WKWebView!

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let myURL = URL(string:"https://www.apple.com")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
}
