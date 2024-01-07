import 'dart:async';
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart' as vp;

import '../extensions/duration.dart';
import '../model/media.dart';

class VideoPlaySymbol extends StatelessWidget {
  const VideoPlaySymbol({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double size = (constraints.biggest / 5).shortestSide;
          return SizedBox(
            width: size,
            height: size,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xaa000000),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: CustomPaint(
                painter: _PlayPauseButtonPainter(value: _PlayPauseButtonPainter.playSymbol),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class VideoPlayerPlayPauseController {
  VoidCallback? _onPlayPause;

  void playPause() {
    _onPlayPause?.call();
  }
}

class VideoPlayer extends StatefulWidget {
  VideoPlayer({
    super.key,
    required this.item,
    required this.playPauseController,
    this.fs = const LocalFileSystem(),
  }) : assert(item.type == MediaType.video);

  final MediaItem item;
  final VideoPlayerPlayPauseController playPauseController;
  final FileSystem fs;

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  late vp.VideoPlayerController _controller;
  bool _isControllerInitialized = false;

  void _handlePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _initializeVideoController() {
    _isControllerInitialized = false;
    _controller = vp.VideoPlayerController.file(widget.fs.file(widget.item.path));
    _controller.setLooping(true);
    _controller.initialize().then((void _) {
      setState(() {
        _isControllerInitialized = true;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
    widget.playPauseController._onPlayPause = _handlePlayPause;
  }

  @override
  void didUpdateWidget(covariant VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.path != oldWidget.item.path) {
      // TODO: Can we just update it instead of disposing and re-creating?
      _controller.pause();
      _controller.dispose();
      _initializeVideoController();
    }
    if (widget.playPauseController != oldWidget.playPauseController) {
      oldWidget.playPauseController._onPlayPause = null;
      widget.playPauseController._onPlayPause = _handlePlayPause;
    }
  }

  @override
  void dispose() {
    widget.playPauseController._onPlayPause = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Image.file(widget.fs.file(widget.item.photoPath));
    if (_isControllerInitialized) {
      result = Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: GestureDetector(
            onTap: _handlePlayPause,
            child: Stack(
              fit: StackFit.expand,
              children: [
                vp.VideoPlayer(_controller),
                _VideoProgressMonitor(
                  controller: _controller,
                  forceIsVisible: !_controller.value.isPlaying,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: result,
    );
  }
}

class _VideoProgressMonitor extends StatefulWidget {
  const _VideoProgressMonitor({
    required this.controller,
    required this.forceIsVisible,
  });

  final vp.VideoPlayerController controller;
  final bool forceIsVisible;

  @override
  State<_VideoProgressMonitor> createState() => _VideoProgressMonitorState();
}

class _VideoProgressMonitorState extends State<_VideoProgressMonitor> {
  double _progress = 0;
  String _positionText = '';
  String _durationText = '';
  bool _isPlaying = false;
  bool _pointerDown = false;
  bool _isVisible = false;
  Timer? _hoverTimer;

  static const Duration _fadeDuration = Duration(milliseconds: 100);
  static const Duration _visibleDuration = Duration(seconds: 3);

  static const BoxDecoration _gradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[Color(0x99000000), Colors.transparent],
      begin: Alignment.bottomCenter,
      end: Alignment.center,
    ),
  );

  void _handleProgressUpdate() {
    setState(() {
      final vp.VideoPlayerValue value = widget.controller.value;
      _progress = value.position.inMilliseconds / value.duration.inMilliseconds;
      _positionText = value.position.toSecondsPrecision();
      _durationText = value.duration.toSecondsPrecision();
      _isPlaying = value.isPlaying;
    });
  }

  void _handlePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _consumeTap() {
    // Consume taps over the seeker so it doesn't play/pause the video
  }

  void _handlePointerDown(PointerDownEvent event) {
    _seekToPosition(event);
    setState(() {
      _pointerDown = true;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    setState(() {
      _pointerDown = false;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    assert(_pointerDown);
    _seekToPosition(event);
  }

  void _handlePointerHover(PointerHoverEvent event) {
    setState(() {
      _isVisible = true;
    });
    _resetHoverTimer();
  }

  void _seekToPosition(PointerEvent event) {
    final Duration total = widget.controller.value.duration;
    final double percentage = event.localPosition.dx / context.size!.width;
    final Duration seekTo = total * percentage;
    widget.controller.seekTo(seekTo);
  }

  void _resetHoverTimer() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(_visibleDuration, () {
      assert(mounted);
      setState(() {
        _isVisible = false;
        _hoverTimer = null;
      });
    });
  }

  bool get isVisible => widget.forceIsVisible || _isVisible;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleProgressUpdate);
    _handleProgressUpdate();
  }

  @override
  void didUpdateWidget(covariant _VideoProgressMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleProgressUpdate);
      widget.controller.addListener(_handleProgressUpdate);
      _handleProgressUpdate();
    }
    if (widget.forceIsVisible != oldWidget.forceIsVisible) {
      _isVisible = true;
      _resetHoverTimer();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    widget.controller.removeListener(_handleProgressUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: _handlePointerHover,
      child: AnimatedOpacity(
        opacity: isVisible ? 1 : 0,
        duration: _fadeDuration,
        child: DecoratedBox(
          decoration: _gradientDecoration,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 21,
                  child: GestureDetector(
                    onTap: _consumeTap,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handlePointerDown,
                        onPointerUp: _handlePointerUp,
                        onPointerMove: _pointerDown ? _handlePointerMove : null,
                        child: AbsorbPointer(
                          child: Align(
                            alignment: const Alignment(-1, 0),
                            child: SizedBox(
                              height: 5,
                              child: LinearProgressIndicator(
                                value: _progress,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 3),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        _PlayPauseButton(isPlaying: _isPlaying, onPlayPause: _handlePlayPause),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 45),
                          child: Text(_positionText),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 10),
                          child: const Text('/'),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 45),
                          child: Text(_durationText),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends ImplicitlyAnimatedWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPlayPause,
  }) : super(duration: const Duration(milliseconds: 200));

  final bool isPlaying;
  final VoidCallback onPlayPause;

  @override
  AnimatedWidgetBaseState<_PlayPauseButton> createState() => _PlayPauseButtonState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isPlaying', isPlaying));
  }
}

class _PlayPauseButtonState extends AnimatedWidgetBaseState<_PlayPauseButton> {
  Tween<double>? _value;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _value = visitor(
      _value,
      widget.isPlaying ? _PlayPauseButtonPainter.pauseSymbol : _PlayPauseButtonPainter.playSymbol,
      (dynamic value) => Tween<double>(begin: value as double)
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPlayPause,
        child: SizedBox(
          width: 40,
          height: 50,
          child: CustomPaint(
            painter: _PlayPauseButtonPainter(value: _value!.evaluate(animation)),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<Tween<double>>('value', _value, defaultValue: null));
  }
}

class _PlayPauseButtonPainter extends CustomPainter {
  const _PlayPauseButtonPainter({
    required this.value,
  });

  final double value;

  static const double playSymbol = 0;
  static const double pauseSymbol = 1;

  @override
  void paint(Canvas canvas, Size size) {
    ui.Paint paint = ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = Colors.white
        ;
    List<Offset> pauseOffsets = <Offset>[
      Offset(size.width / 3, size.height / 3),
      Offset(size.width * 4 / 9, size.height / 3),
      Offset(size.width * 4 / 9, size.height * 2 / 3),
      Offset(size.width / 3, size.height * 2 / 3),
      Offset(size.width * 5 / 9, size.height / 3),
      Offset(size.width * 2 / 3, size.height / 3),
      Offset(size.width * 2 / 3, size.height * 2 / 3),
      Offset(size.width * 5 / 9, size.height * 2 / 3),
    ];
    List<Offset> playOffsets = <Offset>[
      Offset(size.width / 3, size.height / 3),
      Offset(size.width / 2, size.height * 5 / 12),
      Offset(size.width / 2, size.height * 7 / 12),
      Offset(size.width / 3, size.height * 2 / 3),
      Offset(size.width / 2, size.height * 5 / 12),
      Offset(size.width * 2 / 3, size.height / 2),
      Offset(size.width * 2 / 3, size.height / 2),
      Offset(size.width / 2, size.height * 7 / 12),
    ];

    List<Offset> offsets;
    if (value == playSymbol) {
      offsets = playOffsets;
    } else if (value == pauseSymbol) {
      offsets = pauseOffsets;
    } else {
      offsets = List<Offset>.generate(playOffsets.length, (int index) {
        return Offset.lerp(playOffsets[index], pauseOffsets[index], value)!;
      });
    }

    ui.Path path = ui.Path()
        ..moveTo(offsets[0].dx, offsets[0].dy)
        ..lineTo(offsets[1].dx, offsets[1].dy)
        ..lineTo(offsets[2].dx, offsets[2].dy)
        ..lineTo(offsets[3].dx, offsets[3].dy)
        ..close()
        ..moveTo(offsets[4].dx, offsets[4].dy)
        ..lineTo(offsets[5].dx, offsets[5].dy)
        ..lineTo(offsets[6].dx, offsets[6].dy)
        ..lineTo(offsets[7].dx, offsets[7].dy)
        ..close()
        ;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayPauseButtonPainter oldDelegate) {
    return value != oldDelegate.value;
  }
}
