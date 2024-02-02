import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.message,
  });

  final String message;

  static Future<bool> confirmDeleteFiles(BuildContext context) {
    return _show(context, 'Are you sure you want to delete the selected files?');
  }

  static Future<bool> confirmExportOneItem(BuildContext context) {
    return _show(
      context,
      'You only have one item selected. Are you sure you want to export just that one item?',
    );
  }

  static Future<bool> confirmExportUnsavedItems(BuildContext context) {
    return _show(
      context,
      'One or more of the selected items has unsaved changes. Are you sure you '
      'want to export these items without saving changes first?',
    );
  }

  static Future<bool> _show(BuildContext context, String message) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(message: message);
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return _DialogBody(
      message: message,
      options: <Widget>[
        Expanded(
          flex: 4,
          child: ElevatedButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop<bool>(context, false),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(),
        ),
        Expanded(
          flex: 4,
          child: ElevatedButton(
            autofocus: true,
            child: const Text('Yes'),
            onPressed: () => Navigator.pop<bool>(context, true),
          ),
        ),
      ],
    );
  }
}

class InformationalDialog extends StatelessWidget {
  const InformationalDialog({
    super.key,
    required this.message,
  });

  final String message;

  static Future<void> showErrorMessage(BuildContext context, String message) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => InformationalDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogBody(
      message: message,
      options: <Widget>[
        Expanded(
          flex: 3,
          child: Container(),
        ),
        Expanded(
          flex: 4,
          child: ElevatedButton(
            autofocus: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop<void>(context),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(),
        ),
      ],
    );
  }
}

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.message,
  });

  final String message;

  static Future<String?> show(BuildContext context, String message) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => TextPromptDialog(message: message),
    );
  }

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller;

  void _handleSubmit() {
    final String text = _controller.text.trim();
    Navigator.pop<String>(context, text.isEmpty ? null : text);
  }

  void _handleTextfieldSubmitted(String value) {
    _handleSubmit();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DialogBody(
      message: widget.message,
      input: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 100),
        child: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: _handleTextfieldSubmitted,
          maxLines: 1,
        ),
      ),
      options: <Widget>[
        Expanded(
          flex: 3,
          child: Container(),
        ),
        Expanded(
          flex: 4,
          child: ElevatedButton(
            onPressed: _handleSubmit,
            child: const Text('OK'),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(),
        ),
      ],
    );
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.message,
    required this.options,
    this.input,
  });

  final String message;
  final List<Widget> options;
  final Widget? input;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 151, 200, 223),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      child: SizedBox(
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Center(
                  child: SelectableText(
                    message,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (input != null) input!,
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: options,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
