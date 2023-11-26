import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_native_platform_interface.dart';

/// An implementation of [PlatformNativePlatform] that uses method channels.
class MethodChannelPlatformNative extends PlatformNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('platform_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
