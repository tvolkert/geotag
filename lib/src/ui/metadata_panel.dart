import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../extensions/date_time.dart';
import '../model/gps.dart';
import '../model/media.dart';
import 'date_time_editor.dart';

class MetadataPanel extends StatefulWidget {
  const MetadataPanel(this.items, {super.key});

  final MediaItemsView items;

  @override
  State<MetadataPanel> createState() => _MetadataPanelState();
}

class _MetadataPanelState extends State<MetadataPanel> {
  bool _isEditingLatlng = false;
  late TextEditingController latlngController;
  late FocusNode dateTimeFocusNode;
  late FocusNode latlngFocusNode;
  late final WebViewController webViewController;

  static final DateFormat mmmmdyyyy = DateFormat('MMM d, yyyy');
  static final DateFormat ehmma = DateFormat('E, h:mm a');
  static final DateFormat hmma = DateFormat('h:mm a');

  Future<void> _updateLatlngUiElements({bool firstRun = false}) async {
    if (widget.items.isEmpty) {
      latlngController.text = '';
    } else if (widget.items.isSingle) {
      final MediaItem item = widget.items.single;
      String? currentUrl = await webViewController.currentUrl();
      if (item.hasLatlng) {
        final GpsCoordinates coords = item.coords!;
        latlngController.text = '${coords.latitude}, ${coords.longitude}';
        if (firstRun || currentUrl == null) {
          webViewController.loadRequest(
            Uri.parse('https://tvolkert.dev/map.html?initial=${coords.latitude},${coords.longitude}'),
          );
        } else {
          webViewController.runJavaScript('window.rePin("${coords.latitude},${coords.longitude}")');
        }
      } else {
        latlngController.text = '';
        webViewController.loadRequest(Uri.parse('https://tvolkert.dev/map.html?initial=0,0'));
      }
    } else {
      latlngController.text = '';
    }
    setState(() {});
  }

  Future<void> _updateDateTime(MediaItem item, DateTime dateTime) async {
    item
        ..dateTimeOriginal = dateTime
        ..dateTimeDigitized = dateTime
        ..isModified = true
        ..lastModified = DateTime.now()
        ;
    await item.commit();
  }

  void _handleEditDateTime() async {
    if (widget.items.isEmpty) {
      return;
    }

    DateTime? initialDateTime = widget.items.isSingle ? widget.items.single.dateTime : null;
    DateTime? newDateTime = await DateTimeEditorDialog.show(context, initialDateTime);
    if (newDateTime != null) {
      if (widget.items.isSingle) {
        await _updateDateTime(widget.items.single, newDateTime);
      } else {
        final List<Future<void>> futures = <Future<void>>[];
        widget.items.forEach((MediaItem item) {
          futures.add(_updateDateTime(item, newDateTime));
        });
        await Future.wait<void>(futures);
      }
      setState(() {});
    }
  }

  void _handleLatlngSubmitted(String value) {
    assert(value == latlngController.text);
    setIsEditingLatlng(false);
  }

  void _handleFocusChanged() {
    setIsEditingLatlng(FocusManager.instance.primaryFocus == latlngFocusNode);
  }

  void setIsEditingLatlng(bool value) {
    if (value != _isEditingLatlng) {
      _isEditingLatlng = value;
      if (!value) {
        _saveLatlngEdits();
      }
    }
  }

  Future<void> _updateLatlng(MediaItem item, GpsCoordinates coords) async {
    item
        ..latlng = coords.latlng
        ..isModified = true
        ..lastModified = DateTime.now()
        ;
    await item.commit();
  }

  Future<void> _saveLatlngEdits() async {
    if (widget.items.isEmpty || latlngController.text.isEmpty) {
      return;
    }

    try {
      final GpsCoordinates coords = GpsCoordinates.fromString(latlngController.text);
      if (widget.items.isSingle) {
        final MediaItem item = widget.items.single;
        if (item.latlng != coords.latlng) {
          await _updateLatlng(item, coords);
          _updateLatlngUiElements();
        }
      } else {
        final List<Future<void>> futures = <Future<void>>[];
        widget.items.forEach((MediaItem item) {
          if (item.latlng != coords.latlng) {
            futures.add(_updateLatlng(item, coords));
          }
        });
        await Future.wait<void>(futures);
        _updateLatlngUiElements();
      }
    } on FormatException {
      print('invalid gps coordinates');
    }
  }

  Widget _buildSingleDateTimeDisplay(DateTime? value) {
    if (value == null) {
      return const Text('unset', style: TextStyle(fontStyle: FontStyle.italic));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mmmmdyyyy.format(value)),
        Text(ehmma.format(value)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    latlngController = TextEditingController();
    dateTimeFocusNode = FocusNode();
    latlngFocusNode = FocusNode();
    FocusManager.instance.addListener(_handleFocusChanged);
    _updateLatlngUiElements(firstRun: true);
    webViewController = WebViewController()
      ..clearCache()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            // TODO: update GPS coordinates
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ;
  }

  @override
  void didUpdateWidget(covariant MetadataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLatlngUiElements(firstRun: false);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    latlngFocusNode.dispose();
    dateTimeFocusNode.dispose();
    latlngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container();
    }

    final Widget dateTimeDisplay;
    if (widget.items.isSingle) {
      dateTimeDisplay = _buildSingleDateTimeDisplay(widget.items.single.dateTime);
    } else {
      DateTime? min, max;
      widget.items.forEach((MediaItem item) {
        final DateTime? dateTime = item.dateTime;
        if (dateTime != null) {
          min ??= dateTime;
          max ??= dateTime;
          min = min!.earlier(dateTime);
          max = max!.later(dateTime);
        }
      });
      if (min == max) {
        dateTimeDisplay = _buildSingleDateTimeDisplay(min);
      } else {
        assert(min != null);
        assert(max != null);
        final String minValue = mmmmdyyyy.format(min!);
        final String maxValue = mmmmdyyyy.format(max!);
        if (minValue == maxValue) {
          dateTimeDisplay = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(minValue),
              Text('${ehmma.format(min!)} - ${hmma.format(max!)}'),
            ],
          );
        } else {
          dateTimeDisplay = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minValue - $maxValue'),
              Text('${ehmma.format(min!)} - ${ehmma.format(max!)}'),
            ],
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Details',
            style: TextStyle(
              color: Color(0xff606367),
              fontFeatures: <FontFeature>[FontFeature.enable('smcp')],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.calendar_today_rounded),
              const SizedBox(width: 30),
              dateTimeDisplay,
              Expanded(child: Container()),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _handleEditDateTime,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.photo_outlined),
              const SizedBox(width: 30),
              widget.items.isSingle
                  ? SelectableText(widget.items.single.path.split('/').last)
                  : Text(
                    '${widget.items.length} items',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
            ],
          ),
        ),
        Center(
          child: TextField(
            controller: latlngController,
            focusNode: latlngFocusNode,
            onSubmitted: _handleLatlngSubmitted,
          ),
        ),
        Expanded(
          child: WebViewWidget(controller: webViewController),
        ),
      ],
    );
  }
}