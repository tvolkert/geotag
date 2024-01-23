// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';

import 'src/model/app.dart';
import 'src/ui/home.dart';

void main() {
  runZonedGuarded<void>(
    () async {
      await GeotagAppBinding.ensureInitialized();
      runApp(const Geotagger());
    },
    (Object error, StackTrace stack) {
      debugPrint('Caught unhandled error by zone error handler.');
      debugPrint('$error\n$stack');
    },
  );
}

class Geotagger extends StatelessWidget {
  const Geotagger({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Geotagger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GeotagHome(),
    );
  }
}
