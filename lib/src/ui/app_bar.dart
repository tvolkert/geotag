// ignore_for_file: avoid_print

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../bindings/media.dart';
import '../bindings/tasks.dart';
import '../extensions/stream.dart';
import '../model/image.dart';
import '../model/media.dart';
import '../model/video.dart';
import 'home.dart';

class GeotagAppBar extends StatefulWidget implements PreferredSizeWidget {
  const GeotagAppBar({super.key});

  @override
  State<GeotagAppBar> createState() => _GeotagAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _GeotagAppBarState extends State<GeotagAppBar> {
  double? _taskProgress;

  void _handleTasksChanged() {
    setState(() {
      _taskProgress = TaskBinding.instance.progress;
    });
  }

  Future<void> _launchFilePicker() async {
    // TODO: disable this button while a file picker is pending
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>[
        ...JpegFile.allowedExtensions,
        ...Mp4.allowedExtensions,
      ],
      allowMultiple: true,
      lockParentWindow: true,
    );
    if (result != null) {
      TaskBinding.instance.addTasks(result.files.length);
      final Iterable<String> paths = result.files.map<String>((PlatformFile file) => file.path!);
      await MediaBinding.instance.items.addFiles(paths).listenAndWait((void _) {
        TaskBinding.instance.onTaskCompleted();
        if (mounted) {
          // TODO: Have _containsModified and _isEmpty state variables
          setState(() {});
        }
      }, onError: (Object error, StackTrace stack) {
        print('$error\n$stack');
        TaskBinding.instance.onTaskCompleted();
      });
    }
  }

  Future<void> _writeEditsToDisk() async {
    final MediaItems modified = MediaBinding.instance.items.whereModified;
    assert(modified.isNotEmpty);
    TaskBinding.instance.addTasks(modified.length);
    await modified.writeFilesToDisk().listenAndWait((void _) {
      // TODO: cancel operation upon `dispose`
      TaskBinding.instance.onTaskCompleted();
    }, onError: (Object error, StackTrace stack) {
      print('$error\n$stack');
      TaskBinding.instance.onTaskCompleted();
    });
  }

  Future<void> _exportToFolder() async {
    // TODO: confirm if the user only wants to export 1 item if only 1 is selected
    final MediaItems items = GeotagHome.of(context).featuredItems;
    String? path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Export to folder',
      lockParentWindow: true,
    );
    if (path != null) {
      TaskBinding.instance.addTasks(items.length);
      await items.exportToFolder(path).listenAndWait((void _) {
        TaskBinding.instance.onTaskCompleted();
      }, onError: (Object error, StackTrace stack) {
        print('$error\n$stack');
        TaskBinding.instance.onTaskCompleted();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    TaskBinding.instance.addTaskListener(_handleTasksChanged);
  }

  @override
  void dispose() {
    TaskBinding.instance.removeTaskListener(_handleTasksChanged);
    super.dispose();
  }

  Widget? _getLeading() {
    if (_taskProgress == null) {
      return null;
    }
    return Row(
      children: <Widget>[
        const CircularProgressIndicator(
          color: Color.fromARGB(255, 73, 69, 79),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: _taskProgress,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Receive notifications of items changed and rebuild.
    // e.g. metadata edits don't force a rebuild of `items.containsModified`
    final RootMediaItems items = MediaBinding.instance.items;
    return AppBar(
      backgroundColor: Colors.black,
      leading: _getLeading(),
      actions: <Widget>[
        IconButton(
          icon: const Icon(
            Icons.add_a_photo_outlined,
            color: Colors.white,
          ),
          tooltip: 'Add photos & videos to library',
          onPressed: _launchFilePicker,
        ),
        IconButton(
          icon: Icon(
            Icons.save,
            color: _taskProgress == null && items.containsModified
                ? Colors.white
                : null,
          ),
          tooltip: 'Save all edits',
          onPressed: _taskProgress == null && items.containsModified
              ? _writeEditsToDisk
              : null,
        ),
        IconButton(
          icon: Icon(
            Icons.drive_folder_upload,
            color: _taskProgress == null && items.isNotEmpty ? Colors.white : null,
          ),
          tooltip: 'Export to folder',
          onPressed: _taskProgress == null && items.isNotEmpty ? _exportToFolder : null,
        ),
      ],
    );
  }
}
