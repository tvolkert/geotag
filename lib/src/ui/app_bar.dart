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
import 'dialogs.dart';
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
  late bool _modifiedItemsExist;
  late bool _itemsIsNotEmpty;

  void _handleTasksChanged() {
    setState(() {
      _taskProgress = TaskBinding.instance.progress;
    });
  }

  void _handleItemMetadataChanged() {
    setState(() {
      _modifiedItemsExist = MediaBinding.instance.items.containsModified;
    });
  }

  void _handleItemsChanged() {
    setState(() {
      _itemsIsNotEmpty = MediaBinding.instance.items.isNotEmpty;
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
      final List<String> failures = <String>[];
      await MediaBinding.instance.items.addFiles(paths).listenAndWait((void _) {
        TaskBinding.instance.onTaskCompleted();
      }, onError: (Object error, StackTrace stack) {
        if (error is AddFileError) {
          failures.add(error.path);
        }
        print('$error\n$stack');
        TaskBinding.instance.onTaskCompleted();
      });
      if (failures.isNotEmpty && mounted) {
        StringBuffer buf = StringBuffer();
        buf.writeln('The following files were unable to be added:');
        buf.write(failures.map<String>((String path) => path.split('/').last).join('\n'));
        InformationalDialog.showErrorMessage(context, buf.toString());
      }
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
    final MediaItems items = GeotagHome.of(context).featuredItems;
    if (items.containsModified && !await ConfirmationDialog.confirmExportUnsavedItems(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (items.length == 1 && !await ConfirmationDialog.confirmExportOneItem(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
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
    MediaBinding.instance.items.addMetadataListener(_handleItemMetadataChanged);
    MediaBinding.instance.items.addStructureListener(_handleItemsChanged);
    _modifiedItemsExist = MediaBinding.instance.items.containsModified;
    _itemsIsNotEmpty = MediaBinding.instance.items.isNotEmpty;
  }

  @override
  void dispose() {
    MediaBinding.instance.items.removeStructureListener(_handleItemsChanged);
    MediaBinding.instance.items.removeMetadataListener(_handleItemMetadataChanged);
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
            color: _taskProgress == null && _modifiedItemsExist
                ? Colors.white
                : null,
          ),
          tooltip: 'Save all edits',
          onPressed: _taskProgress == null && _modifiedItemsExist
              ? _writeEditsToDisk
              : null,
        ),
        IconButton(
          icon: Icon(
            Icons.drive_folder_upload,
            color: _taskProgress == null && _itemsIsNotEmpty ? Colors.white : null,
          ),
          tooltip: 'Export to folder',
          onPressed: _taskProgress == null && _itemsIsNotEmpty ? _exportToFolder : null,
        ),
      ],
    );
  }
}
