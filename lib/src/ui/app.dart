import 'package:flutter/material.dart';

import 'home.dart';

class GeotagApp extends StatefulWidget {
  const GeotagApp({super.key});

  @override
  State<GeotagApp> createState() => _GeotagAppState();

  static GeotagAppController of(BuildContext context) {
    final _AppScope? scope = context.getInheritedWidgetOfExactType<_AppScope>();
    return scope!.state;
  }
}

abstract interface class GeotagAppController {
  ShortcutRegistration registerShortcuts(Map<ShortcutActivator, Intent> shortcuts);
}

class ShortcutRegistration {
  ShortcutRegistration._(this._shortcuts, this._state);

  final Map<ShortcutActivator, Intent> _shortcuts;
  _GeotagAppState? _state;

  void dispose() {
    if (_state == null) {
      throw StateError('registration has already been disposed');
    }
    _state!._removeRegistration(this);
    _state = null;
  }
}

class _GeotagAppState extends State<GeotagApp> implements GeotagAppController {
  final List<ShortcutRegistration> _shortcutRegistrations = <ShortcutRegistration>[];
  _AppScope? _scope;

  void _removeRegistration(ShortcutRegistration registration) {
    setState(() {
      _shortcutRegistrations.remove(registration);
    });
  }

  @override
  ShortcutRegistration registerShortcuts(Map<ShortcutActivator, Intent> shortcuts) {
    final ShortcutRegistration registration = ShortcutRegistration._(Map<ShortcutActivator, Intent>.from(shortcuts), this);
    setState(() {
      _shortcutRegistrations.add(registration);
    });
    return registration;
  }

  @override
  void dispose() {
    for (final ShortcutRegistration registration in _shortcutRegistrations) {
      registration.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Shortcut registrations won't cause our scope to get rebuilt.
    _scope ??= _AppScope(
      state: this,
      child: const GeotagHome(),
    );

    return MaterialApp(
      home: _scope,
      debugShowCheckedModeBanner: false,
      title: 'Geotagger',
      theme: ThemeData(primarySwatch: Colors.blue),
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        for (final ShortcutRegistration registration in _shortcutRegistrations)
          ...registration._shortcuts,
      },
    );
  }
}

class _AppScope extends InheritedWidget {
  const _AppScope({
    required super.child,
    required this.state,
  });

  final _GeotagAppState state;

  @override
  bool updateShouldNotify(covariant _AppScope oldWidget) => false;
}
