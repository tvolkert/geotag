import 'package:flutter/material.dart';

class ConfirmDeleteFilesDialog extends StatelessWidget {
  const ConfirmDeleteFilesDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext context) => const ConfirmDeleteFilesDialog(),
    );
    return confirmed ?? false;
  }

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
            const Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  'Are you sure you wan to delete the selected files?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

