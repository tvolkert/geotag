import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'platform_native_method_channel.dart';

abstract class PlatformNativePlatform extends PlatformInterface {
  /// Constructs a PlatformNativePlatform.
  PlatformNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static PlatformNativePlatform _instance = MethodChannelPlatformNative();

  /// The default instance of [PlatformNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelPlatformNative].
  static PlatformNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PlatformNativePlatform] when
  /// they register themselves.
  static set instance(PlatformNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
