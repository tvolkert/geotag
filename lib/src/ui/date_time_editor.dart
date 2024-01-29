import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bindings/clock.dart';

/// A widget that allows the user to edit the DateTime associated with a photo
/// or video.
///
/// This widget is meant to be shown via the [show] method.
// TODO: handle left/right keys to navigate
// TODO: Add seconds
// TODO: handle enter key to submit
// TODO: zero-pad time values
// TODO: render noon and midnight as "12", not "0" hours
// TODO: handle input of "12" PM as noon, not midnight (by adding 12)
class DateTimeEditorDialog extends StatefulWidget {
  const DateTimeEditorDialog({
    super.key,
    required this.initialDateTime,
  });

  final DateTime? initialDateTime;

  /// Shows a [DateTimeEditorDialog] and returns a future that contains the
  /// results of the user's edits.
  ///
  /// If the user cancels the edits or clicks outside the dialog to dismiss it,
  /// the returned future will produce a null value.
  static Future<DateTime?> show(BuildContext context, [DateTime? initialDateTime]) {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) => DateTimeEditorDialog(initialDateTime: initialDateTime),
    );
  }

  @override
  State<DateTimeEditorDialog> createState() => _DateTimeEditorDialogState();
}

enum _AmPm {
  am,
  pm,
}

class _DateTimeEditorDialogState extends State<DateTimeEditorDialog> {
  late int year, defaultYear;
  late int month, defaultMonth;
  late int day, defaultDay;
  late int hour, defaultHour;
  late int minute, defaultMinute;
  late _AmPm ampm, defaultAmPm;

  void _handleYearChanged(int value) {
    setState(() {
      year = value;
    });
  }

  void _handleMonthChanged(int value) {
    setState(() {
      month = value;
    });
  }

  void _handleDayChanged(int value) {
    setState(() {
      day = value;
    });
  }

  void _handleHourChanged(int value) {
    setState(() {
      hour = value;
    });
  }

  void _handleMinuteChanged(int value) {
    setState(() {
      minute = value;
    });
  }

  void _handleAmPmChanged(_AmPm value) {
    setState(() {
      ampm = value;
    });
  }

  void _handleCancel() {
    Navigator.pop<DateTime>(context);
  }

  void _handleSave() {
    Navigator.pop<DateTime>(context, currentDateTime);
  }

  DateTime get currentDateTime {
    final int hour24 = hour + (ampm == _AmPm.pm ? 12 : 0);
    return DateTime(year, month, day, hour24, minute);
  }

  String _formatCurrentDateTime() {
    final DateFormat format = DateFormat('EEEE, MMMM d, yyyy, h:mm a');
    return format.format(currentDateTime);
  }

  _initialize() {
    final DateTime instant = widget.initialDateTime ?? ClockBinding.instance.now();
    year = defaultYear = instant.year;
    month = defaultMonth = instant.month;
    day = defaultDay = instant.day;
    hour = defaultHour = instant.hour % 12;
    minute = defaultMinute = instant.minute;
    ampm = defaultAmPm = instant.hour < 12 ? _AmPm.am : _AmPm.pm;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant DateTimeEditorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDateTime != oldWidget.initialDateTime) {
      _initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      // TODO: Use a Dialog widget once the webview handles input correctly.
      child: Material(
        // backgroundColor: Colors.white,
        // surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Edit date & time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_formatCurrentDateTime()),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _IntEntry(
                    defaultValue: defaultYear,
                    label: 'Year',
                    maxLength: 4,
                    onValueChanged: _handleYearChanged,
                    autofocus: true,
                  ),
                  const SizedBox(width: 8),
                  _IntEntry(
                    defaultValue: defaultMonth,
                    label: 'Month',
                    onValueChanged: _handleMonthChanged,
                  ),
                  const SizedBox(width: 8),
                  _IntEntry(
                    defaultValue: defaultDay,
                    label: 'Day',
                    onValueChanged: _handleDayChanged,
                  ),
                  const SizedBox(width: 12),
                  _IntEntry(
                    defaultValue: defaultHour,
                    label: 'Time',
                    onValueChanged: _handleHourChanged,
                  ),
                  const SizedBox(width: 8, child: Center(child: Text(':'))),
                  _IntEntry(
                    defaultValue: defaultMinute,
                    onValueChanged: _handleMinuteChanged,
                  ),
                  const SizedBox(width: 8),
                  _AmPmEntry(
                    defaultValue: defaultAmPm,
                    onValueChanged: _handleAmPmChanged,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  const SizedBox(width: 500),
                  _ActionButton(label: 'Cancel', onPressed: _handleCancel),
                  const SizedBox(width: 10),
                  _ActionButton(label: 'Save', onPressed: _handleSave),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidatingTextEditingController<T> extends TextEditingController {
  _ValidatingTextEditingController(this.onValueChanged);

  final ValueChanged<T> onValueChanged;
  bool _doingSetup = false;

  @protected
  bool get doingSetup => _doingSetup;

  void invokeSetupCallback(VoidCallback callback) {
    _doingSetup = true;
    try {
      callback();
    } finally {
      _doingSetup = false;
    }
  }
}

class _IntValidatingTextEditingController extends _ValidatingTextEditingController<int> {
  _IntValidatingTextEditingController(super.onValueChanged);

  @override
  set value(TextEditingValue newValue) {
    final String newText = newValue.text;
    final bool textChanged = newText != value.text;
    final int? intValue = int.tryParse(newValue.text);
    if (newText.isEmpty || (intValue != null && intValue >= 0)) {
      super.value = newValue;
      if (!doingSetup && textChanged && intValue != null) {
        onValueChanged(intValue);
      }
    }
  }
}

// TODO: handle configuration for minutes ("07" instead of "7")
class _IntEntry extends StatefulWidget {
  const _IntEntry({
    required this.defaultValue,
    this.label = '',
    this.maxLength = 2,
    required this.onValueChanged,
    this.autofocus = false,
  });

  final int defaultValue;
  final String label;
  final int maxLength;
  final ValueChanged<int> onValueChanged;
  final bool autofocus;

  @override
  State<_IntEntry> createState() => _IntEntryState();
}

class _IntEntryState extends State<_IntEntry> {
  late final FocusNode _focusNode;
  late final _IntValidatingTextEditingController _controller;
  bool _hasFocus = false;

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      if (_hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      } else if (_controller.text.isEmpty) {
        _controller.text = '${widget.defaultValue}';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller = _IntValidatingTextEditingController(widget.onValueChanged);
    _controller.invokeSetupCallback(() {
      _controller.text = '${widget.defaultValue}';
    });
  }

  @override
  void didUpdateWidget(covariant _IntEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.onValueChanged == oldWidget.onValueChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RawEntry(
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      controller: _controller,
      onTap: null,
      maxLength: widget.maxLength,
      labelText: widget.label,
      hasFocus: _hasFocus,
    );
  }
}

class _AmPmValidatingTextEditingController extends _ValidatingTextEditingController<_AmPm> {
  _AmPmValidatingTextEditingController(super.onValueChanged);

  static const TextSelection selectAll = TextSelection(baseOffset: 0, extentOffset: 2);

  @override
  set value(TextEditingValue newValue) {
    switch (newValue.text.toLowerCase()) {
      case 'a':
      case 'am':
        super.value = const TextEditingValue(text: 'AM', selection: selectAll);
        if (!doingSetup) {
          onValueChanged(_AmPm.am);
        }
      case 'p':
      case 'pm':
        super.value = const TextEditingValue(text: 'PM', selection: selectAll);
        if (!doingSetup) {
          onValueChanged(_AmPm.pm);
        }
    }
  }
}

class _AmPmEntry extends StatefulWidget {
  const _AmPmEntry({
    required this.defaultValue,
    required this.onValueChanged,
  });

  final _AmPm defaultValue;
  final ValueChanged<_AmPm> onValueChanged;

  @override
  State<_AmPmEntry> createState() => _AmPmEntryState();
}

class _AmPmEntryState extends State<_AmPmEntry> {
  late final FocusNode _focusNode;
  late final _AmPmValidatingTextEditingController _controller;
  bool _hasFocus = false;

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
      if (_hasFocus) {
        _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      }
    }
  }

  void _handleTap() {
    switch (_controller.text) {
      case 'AM':
        _controller.text = 'PM';
      case 'PM':
        _controller.text = 'AM';
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _controller = _AmPmValidatingTextEditingController(widget.onValueChanged);
    _controller.invokeSetupCallback(() {
      _controller.text = widget.defaultValue == _AmPm.am ? 'AM' : 'PM';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RawEntry(
      autofocus: false,
      focusNode: _focusNode,
      controller: _controller,
      onTap: _handleTap,
      maxLength: 2,
      labelText: '',
      hasFocus: _hasFocus,
    );
  }
}

class _RawEntry extends StatelessWidget {
  const _RawEntry({
    required this.autofocus,
    required this.focusNode,
    required this.controller,
    required this.onTap,
    required this.maxLength,
    required this.labelText,
    required this.hasFocus,
  });

  final bool autofocus;
  final FocusNode focusNode;
  final TextEditingController controller;
  final GestureTapCallback? onTap;
  final int maxLength;
  final String labelText;
  final bool hasFocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: TextField(
        autofocus: autofocus,
        focusNode: focusNode,
        controller: controller,
        maxLength: maxLength,
        onTap: onTap,
        maxLines: 1,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(fontSize: 15),
          counterText: '',
          filled: true,
          fillColor: hasFocus ? const Color(0xffe7e9ea) : const Color(0xfff1f3f4),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: ColoredBox(
        color: const Color.fromARGB(255, 56, 113, 224),
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            textStyle: const TextStyle(fontSize: 14),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
