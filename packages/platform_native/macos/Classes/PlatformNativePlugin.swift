import Cocoa
import FlutterMacOS

public class PlatformNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "platform_native", binaryMessenger: registrar.messenger)
    let instance = PlatformNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    let viewFactory = PlatformViewFactory(messenger: registrar.messenger)
    registrar.register(viewFactory, withId: "platformview-view-type")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
