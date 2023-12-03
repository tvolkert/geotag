import 'package:file/local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'src/model/app.dart';
import 'src/model/db.dart';
import 'src/model/gps.dart';
import 'src/model/image.dart';

void main() async {
  await GeotagAppBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geotagger',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,
      ),
      home: const MyHomePage(),
    );
  }
}

abstract class HomeController {
  set mainImage(String path);
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();

  static HomeController of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_HomeScope>()!.state;
  }
}

class _MyHomePageState extends State<MyHomePage> implements HomeController {
  late final ScrollController scrollController;
  DbResults? photos;
  String? currentPath;

  void _launchFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      allowMultiple: true,
      lockParentWindow: true,
    );
    if (result != null) {
      assert(photos != null);
      photos!.addFiles(result.files.map<String>((PlatformFile file) {
        return file.path!;
      })).then((_) {
        setState(() {});
      });
    }
  }

  @override
  set mainImage(String path) {
    setState(() {
      currentPath = path;
    });
  }

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      () async {
        photos = await DatabaseBinding.instance.getAllPhotos();
        setState(() {});
      }();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScope(
      state: this,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Add photos & videos to library',
            onPressed: _launchFilePicker,
          ),
        ),
        body: Column(
          children: <Widget>[
            Expanded(child: MainArea(currentPath)),
            const Divider(height: 1),
            SizedBox(
              height: 175,
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.builder(
                  itemExtent: 175,
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: photos?.length ?? 0,
                  itemBuilder: (BuildContext context, int index) {
                    return Thumbnail(
                      key: ValueKey<String>(photos![index].path),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeScope extends InheritedWidget {
  const _HomeScope({
    required super.child,
    required this.state,
  });

  final _MyHomePageState state;

  @override
  bool updateShouldNotify(covariant _HomeScope oldWidget) => false;
}

class Thumbnail extends StatefulWidget {
  /// The [key] argument is required for thumbnails and should be set to the
  /// file system path of the photo whose thumbnail is to be shown.
  const Thumbnail({required ValueKey<String> super.key});

  ValueKey<String> get valueKey => key as ValueKey<String>;

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  void _handleTap() {
    MyHomePage.of(context).mainImage = widget.valueKey.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Image.file(
        const LocalFileSystem().file(widget.valueKey.value),
        fit: BoxFit.cover,
        key: widget.key,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
          return Placeholder(
            color: Colors.red,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Text(widget.valueKey.value),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainArea extends StatelessWidget {
  const MainArea(this.path, {super.key});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(child: MainImage(path)),
        SizedBox(
          width: 500,
          child: GeoSetter(path),
        ),
      ],
    );
  }
}

class MainImage extends StatelessWidget {
  const MainImage(this.path, {super.key});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return Container();
    }

    return Image.file(
      const LocalFileSystem().file(path),
    );
  }
}

class GeoSetter extends StatefulWidget {
  const GeoSetter(this.path, {super.key});

  final String? path;

  @override
  State<GeoSetter> createState() => _GeoSetterState();
}

class _GeoSetterState extends State<GeoSetter> {
  DbRow? row;
  bool _isEditing = false;
  late TextEditingController controller;
  late FocusNode focusNode;
  late final WebViewController webViewController;

  Future<void> _updateRow() async {
    if (widget.path == null) {
      row = null;
      controller.text = '';
    } else {
      row = await DatabaseBinding.instance.getPhoto(widget.path!);
      final GpsCoordinates? coords = JpegFile(widget.path!).getGpsCoordinates();
      print('~!@ :: $coords');
      if (coords != null) {
        controller.text = '${coords.latitude}, ${coords.longitude}';
        webViewController.loadRequest(Uri.parse('https://tvolkert.dev/map.html?initial=${coords.latitude},${coords.longitude}'));
        // webViewController.loadRequest(Uri.parse('https://www.google.com/maps/embed/v1/place?key=AIzaSyBzhnRnULijOGJ34pv_rarOReZnGabGEM8&q=${coords.latitude}%2C${coords.longitude}&zoom=10'));
        // webViewController.loadRequest(Uri.parse('https://www.google.com/maps/@?api=1&map_action=map&center=${coords.latitude},${coords.longitude}&zoom=10&layer=none&query=${coords.latitude}%2C${coords.longitude}%2C10z'));
        // webViewController.loadRequest(Uri.parse('https://www.google.com/maps/search/?api=1&query=${coords.latitude}%2C${coords.longitude}'));
      } else {
        controller.text = '';
      }
    }
    setState(() {});
  }

  void _handleSubmitted(String value) {
    assert(value == controller.text);
    setIsEditing(false);
  }

  void _handleFocusChanged() {
    print('focus changed -- ${FocusManager.instance.primaryFocus == focusNode}');
    setIsEditing(FocusManager.instance.primaryFocus == focusNode);
  }

  void _saveEdits() {
    print('saving edits...');
    try {
      final GpsCoordinates coords = GpsCoordinates.fromString(controller.text);
      // DatabaseBinding.instance.db.update(
      //   'PHOTO',
      //   <String, Object?>{'LATLON': '${coords.latitude}/${coords.longitude}'},
      //   where: 'PATH = ?',
      //   whereArgs: <String>[widget.path!],
      // );
    } on FormatException {
      print('invalid gps coordinates');
    }
  }

  void setIsEditing(bool value) {
    if (value != _isEditing) {
      _isEditing = value;
      if (!value) {
        _saveEdits();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    focusNode = FocusNode();
    FocusManager.instance.addListener(_handleFocusChanged);
    _updateRow();
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      //..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          // onProgress: (int progress) {
          //   print('progress!');
          //   // Update loading bar.
          // },
          // onPageStarted: (String url) {
          //   print('started!');
          // },
          // onPageFinished: (String url) {
          //   print('finished!');
          // },
          // onWebResourceError: (WebResourceError error) {
          //   print('web resource error!');
          // },
          onUrlChange: (UrlChange change) {
            print('url change! :: ${change.url}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      // ..loadRequest(Uri.parse('https://flutter.dev'))
      ;
  }

  @override
  void didUpdateWidget(covariant GeoSetter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRow();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) {
      return Container();
    }

    if (row == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SelectableText(row!.path),
        Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: _handleSubmitted,
          ),
        ),
        const Divider(),
        const SizedBox(width: 1, height: 20),
        const Divider(),
        Expanded(
          child: WebViewWidget(controller: webViewController),
        ),
      ],
    );
  }
}
