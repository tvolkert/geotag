import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void installFakeWebPlatform() {
  WebViewPlatform.instance = _FakeWebViewPlatform();
}

class _FakeCookieManager extends MockPlatformInterfaceMixin implements PlatformWebViewCookieManager {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }
}

class _FakeNavigationDelegate extends MockPlatformInterfaceMixin implements PlatformNavigationDelegate {
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }
}

class _FakeWebViewController extends MockPlatformInterfaceMixin implements PlatformWebViewController {
  @override
  Future<void> clearCache() async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }
}

class _FakeWebViewWidget extends MockPlatformInterfaceMixin implements PlatformWebViewWidget {
  @override
  Widget build(BuildContext context) => Container();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    super.noSuchMethod(invocation);
  }
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params) {
    return _FakeCookieManager();
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params) {
    return _FakeNavigationDelegate();
  }

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params) {
    return _FakeWebViewController();
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params) {
    return _FakeWebViewWidget();
  }
}
