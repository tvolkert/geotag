// ignore_for_file: avoid_print

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:geotag/src/extensions/iterable.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../bindings/clock.dart';
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
  bool _isEditingEvent = false;
  bool _isEditingLatlng = false;
  final Completer<void> _onMapLoaded = Completer<void>();
  late TextEditingController eventController;
  late TextEditingController latlngController;
  late FocusNode dateTimeFocusNode;
  late FocusNode eventFocusNode;
  late FocusNode latlngFocusNode;
  late final WebViewController webViewController;

  static final DateFormat mmmmdyyyy = DateFormat('MMM d, yyyy');
  static final DateFormat ehmma = DateFormat('E, h:mm a');
  static final DateFormat hmma = DateFormat('h:mm a');

  Future<void> _updateEventUiElement() async {
    if (widget.items.isEmpty) {
      eventController.text = '';
    } else if (widget.items.isSingle) {
      final MediaItem item = widget.items.single;
      eventController.text = item.event ?? '';
    } else {
      final String? sharedEvent = widget.items
          .map<String?>((MediaItem item) => item.event)
          .reduce((String? value, String? element) => value == element ? value : null);
      eventController.text = sharedEvent ?? '';
    }
    setState(() {});
  }

  Future<void> _updateLatlngUiElements({bool firstRun = false}) async {
    if (widget.items.isEmpty) {
      latlngController.text = '';
      await _loadMapCoordinates(<GpsCoordinates>[], firstRun);
    } else if (widget.items.isSingle) {
      final MediaItem item = widget.items.single;
      if (item.hasLatlng) {
        final GpsCoordinates coords = item.coords!;
        latlngController.text = coords.toString();
        await _loadMapCoordinates(<GpsCoordinates>[coords], firstRun);
      } else {
        latlngController.text = '';
        await _loadMapCoordinates(<GpsCoordinates>[], firstRun);
      }
    } else {
      final Iterable<GpsCoordinates> coords = widget.items
          .map<GpsCoordinates?>((MediaItem item) => item.coords)
          .whereNotNull()
          .removeDuplicates()
          .toList();
      latlngController.text = '';
      await _loadMapCoordinates(coords, firstRun);
    }
    setState(() {});
  }

  Future<void> _loadMapCoordinates(Iterable<GpsCoordinates> coords, bool firstRun) async {
    Uri url = Uri.https('tvolkert.dev', '/map.html');
    String? coordsParam;
    if (coords.isSingle) {
      coordsParam = coords.single.toString();
    } else if (coords.isNotEmpty) {
      coordsParam = coords.map<String>((GpsCoordinates c) => c.toShortString()).join(';');
    }
    if (firstRun) {
      if (coordsParam != null) {
        url = url.replace(queryParameters: <String, String>{'initial': coordsParam});
      }
      webViewController.loadRequest(url);
    } else {
      if (!_onMapLoaded.isCompleted) {
        await _onMapLoaded.future;
      }
      final String js = 'window.rePin(${coordsParam == null ? 'null' : '"$coordsParam"'})';
      webViewController.runJavaScript(js);
    }
  }

  Future<void> _updateDateTime(MediaItem item, DateTime dateTime) async {
    item
      ..dateTimeOriginal = dateTime
      ..dateTimeDigitized = dateTime
      ..isModified = true
      ..lastModified = ClockBinding.instance.now();
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

  void _handleEventSubmitted(String value) {
    assert(value == eventController.text);
    setIsEditingEvent(false);
  }

  void _handleLatlngSubmitted(String value) {
    assert(value == latlngController.text);
    setIsEditingLatlng(false);
  }

  void _handleFocusChanged() {
    setIsEditingEvent(FocusManager.instance.primaryFocus == eventFocusNode);
    setIsEditingLatlng(FocusManager.instance.primaryFocus == latlngFocusNode);
  }

  void _handlePostMessageReceived(JavaScriptMessage message) {
    final List<String> parts = message.message.split(':');
    switch (parts.first) {
      case 'loaded':
        assert(!_onMapLoaded.isCompleted);
        _onMapLoaded.complete();
      case 'latlng':
        print(parts.last);
        // TODO: Update coordinates of the selected items
      case 'print':
        print(parts.skip(1).join());
      default:
        print(message.message);
    }
  }

  void setIsEditingEvent(bool value) {
    if (value != _isEditingEvent) {
      _isEditingEvent = value;
      if (!value) {
        _saveEventEdits();
      }
    }
  }

  void setIsEditingLatlng(bool value) {
    if (value != _isEditingLatlng) {
      _isEditingLatlng = value;
      if (!value) {
        _saveLatlngEdits();
      }
    }
  }

  Future<void> _updateEvent(MediaItem item, String? event) async {
    item
      ..event = event
      ..isModified = true
      ..lastModified = ClockBinding.instance.now();
    await item.commit();
  }

  Future<void> _updateLatlng(MediaItem item, GpsCoordinates coords) async {
    item
      ..latlng = coords.latlng
      ..isModified = true
      ..lastModified = ClockBinding.instance.now();
    await item.commit();
  }

  Future<void> _saveEventEdits() async {
    if (widget.items.isEmpty) {
      return;
    }

    String? event = eventController.text.trim();
    if (event.isEmpty) {
      event = null;
    }
    if (widget.items.isSingle) {
      final MediaItem item = widget.items.single;
      if (item.event != event) {
        await _updateEvent(item, event);
        _updateEventUiElement();
      }
    } else {
      final List<Future<void>> futures = <Future<void>>[];
      widget.items.forEach((MediaItem item) {
        if (item.event != event) {
          futures.add(_updateEvent(item, event));
        }
      });
      await Future.wait<void>(futures);
      _updateEventUiElement();
    }
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
    eventController = TextEditingController();
    latlngController = TextEditingController();
    dateTimeFocusNode = FocusNode();
    eventFocusNode = FocusNode();
    latlngFocusNode = FocusNode();
    FocusManager.instance.addListener(_handleFocusChanged);
    webViewController = WebViewController()
      ..clearCache()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Geotag', onMessageReceived: _handlePostMessageReceived)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange change) {
            // TODO: update GPS coordinates
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    _updateEventUiElement();
    _updateLatlngUiElements(firstRun: true);
  }

  @override
  void didUpdateWidget(covariant MetadataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateEventUiElement();
    _updateLatlngUiElements();
  }

  @override
  void reassemble() {
    super.reassemble();
    webViewController.clearCache();
    webViewController.clearLocalStorage();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    latlngFocusNode.dispose();
    eventFocusNode.dispose();
    dateTimeFocusNode.dispose();
    latlngController.dispose();
    eventController.dispose();
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
        MetadataField(
          icon: Icons.calendar_today_rounded,
          onEdit: _handleEditDateTime,
          child: dateTimeDisplay,
        ),
        MetadataField(
          icon: Icons.photo_outlined,
          child: widget.items.isSingle
              ? SelectableText(widget.items.single.path.split('/').last)
              : Text(
                  '${widget.items.length} items',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
        ),
        MetadataField(
          icon: Icons.local_activity,
          child: Expanded(
            // TODO: figure out why space is getting handled by `Home`
            child: TextField(
              controller: eventController,
              focusNode: eventFocusNode,
              onSubmitted: _handleEventSubmitted,
            ),
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
          child: AspectRatio(
            aspectRatio: 1.65,
            child: WebViewWidget(controller: webViewController),
          ),
        ),
      ],
    );
  }
}

class MetadataField extends StatelessWidget {
  const MetadataField({
    super.key,
    required this.icon,
    this.onEdit,
    this.editIcon = Icons.edit,
    required this.child,
  });

  final IconData icon;
  final VoidCallback? onEdit;
  final IconData editIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: 30),
          child,
          if (onEdit != null) ...<Widget>[
            Expanded(child: Container()),
            IconButton(
              icon: Icon(editIcon),
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}
