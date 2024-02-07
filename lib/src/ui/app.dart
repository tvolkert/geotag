import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../intents/delete.dart';
import '../intents/move_selection.dart';
import '../intents/select_all.dart';
import '../intents/sort.dart';
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
  ShortcutsRegistration registerShortcuts(Map<ShortcutActivator, Intent> shortcuts);
  ActionsRegistration registerActions(Map<Type, Action<Intent>> actions);
}

class ShortcutsRegistration {
  ShortcutsRegistration._(this._shortcuts, this._state);

  final Map<ShortcutActivator, Intent> _shortcuts;
  _GeotagAppState? _state;

  void dispose() {
    if (_state == null) {
      throw StateError('registration has already been disposed');
    }
    _state!._removeShortcutsRegistration(this);
    _state = null;
  }
}

class ActionsRegistration {
  ActionsRegistration._(this._actions, this._state);

  final Map<Type, Action<Intent>> _actions;
  _GeotagAppState? _state;

  void dispose() {
    if (_state == null) {
      throw StateError('registration has already been disposed');
    }
    _state!._removeActionsRegistration(this);
    _state = null;
  }
}

class _GeotagAppState extends State<GeotagApp> implements GeotagAppController {
  final List<ShortcutsRegistration> _shortcutsRegistrations = <ShortcutsRegistration>[];
  final List<ActionsRegistration> _actionsRegistrations = <ActionsRegistration>[];
  _AppScope? _scope;

  void _removeShortcutsRegistration(ShortcutsRegistration registration) {
    // Avoid calling setState during a build phase or during tree finalization
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      if (mounted) {
        setState(() {
          _shortcutsRegistrations.remove(registration);
        });
      }
    });
  }

  void _removeActionsRegistration(ActionsRegistration registration) {
    // Avoid calling setState during a build phase or during tree finalization
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      if (mounted) {
        setState(() {
          _actionsRegistrations.remove(registration);
        });
      }
    });
  }

  @override
  ShortcutsRegistration registerShortcuts(Map<ShortcutActivator, Intent> shortcuts) {
    final ShortcutsRegistration registration = ShortcutsRegistration._(Map<ShortcutActivator, Intent>.from(shortcuts), this);
    // Avoid calling setState during a build phase
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      setState(() {
        _shortcutsRegistrations.add(registration);
      });
    });
    return registration;
  }

  @override
  ActionsRegistration registerActions(Map<Type, Action<Intent>> actions) {
    final ActionsRegistration registration = ActionsRegistration._(Map<Type, Action<Intent>>.from(actions), this);
    // Avoid calling setState during a build phase
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      setState(() {
        _actionsRegistrations.add(registration);
      });
    });
    return registration;
  }
  
  @override
  void dispose() {
    for (final ShortcutsRegistration registration in _shortcutsRegistrations) {
      registration.dispose();
    }
    for (final ActionsRegistration registration in _actionsRegistrations) {
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

        // Override activation intents to not include repeats
        const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false): const ActivateIntent(),

        // Selection
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const MoveSelectionIntent.backward(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const MoveSelectionIntent.forward(),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true, includeRepeats: false): const SelectAllIntent(),

        // Sorting
        const SingleActivator(LogicalKeyboardKey.keyD, includeRepeats: false): const SortIntent(SortKey.date),
        const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false): const SortIntent(SortKey.filename),
        const SingleActivator(LogicalKeyboardKey.keyI, includeRepeats: false): const SortIntent(SortKey.itemId),

        // Delete
        const SingleActivator(LogicalKeyboardKey.backspace, includeRepeats: false): const DeleteIntent(),
        const SingleActivator(LogicalKeyboardKey.delete, includeRepeats: false): const DeleteIntent(),

        for (final ShortcutsRegistration registration in _shortcutsRegistrations)
          ...registration._shortcuts,
      },
      actions: <Type, Action<Intent>>{
        ...WidgetsApp.defaultActions,
        for (final ActionsRegistration registration in _actionsRegistrations)
          ...registration._actions,
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
