import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/bindings/app.dart';
import 'src/ui/app.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      await GeotagAppBinding.ensureInitialized();
      runApp(const GeotagApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('Caught unhandled error by zone error handler.');
      debugPrint('$error\n$stack');
    },
  );
}
