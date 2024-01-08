// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart';

import '../extensions/date_time.dart';
import 'gps.dart';
import 'metadata.dart';

class Mp4 {
  Mp4(this.path) : assert(allowedExtensions.contains(path.toLowerCase().split('.').last));

  final String path;

  static Set<String> allowedExtensions = <String>{'m4v', 'mp4', 'mov'};

  Metadata extractMetadata() {
    final Uint8List thumbnailBytes = _getFrameBytes();
    final io.ProcessResult ffprobe = io.Process.runSync(
      '/opt/homebrew/bin/ffprobe',
      <String>[path],
    );
    DateTime? dateTime;
    GpsCoordinates? coordinates;
    if (ffprobe.exitCode == 0) {
      final RegExp extractCreationTime = RegExp(r'^ +creation_time +: (.+)$');
      final RegExpMatch? matchCreationTime = LineSplitter.split(ffprobe.stderr)
          .where(extractCreationTime.hasMatch)
          .map<RegExpMatch?>(extractCreationTime.firstMatch)
          .firstOrNull;
      if (matchCreationTime != null) {
        dateTime = DateTime.parse(matchCreationTime.group(1)!);
      }

      final RegExp extractLatlng = RegExp(r'^ +location +: ([-+][0-9.]+)([-+][0-9.]+)/$');
      final RegExpMatch? matchLatlng = LineSplitter.split(ffprobe.stderr)
          .where(extractLatlng.hasMatch)
          .map<RegExpMatch?>(extractLatlng.firstMatch)
          .firstOrNull;
      if (matchLatlng != null) {
        final double latitude = double.parse(matchLatlng.group(1)!);
        final double longitude = double.parse(matchLatlng.group(2)!);
        coordinates = GpsCoordinates(latitude, longitude);
      }
    }
    return Metadata(
      thumbnail: thumbnailBytes,
      dateTime: dateTime,
      coordinates: coordinates,
    );
  }

  void extractFrame(FileSystem fs, String extractedPath) {
    final Uint8List bytes = _getFrameBytes(size: 1024, quality: 3);
    fs.file(extractedPath).writeAsBytesSync(bytes);
  }

  /// [size] represents the square bounding box inside which the extracted
  /// frame must fit.
  ///
  /// [quality] values range from 1 to 31, with 1 being the highest quality and
  /// 31 being the lowest quality. The higher the quality, the larger the file
  /// size.
  Uint8List _getFrameBytes({
    int size = 320,
    int quality = 6,
  }) {
    final io.Directory tmpDir = io.Directory.systemTemp.createTempSync('geotag_');
    try {
      final io.File tmpFile = io.File('${tmpDir.path}/thumbnail.jpg');
      final io.ProcessResult createThumbnail = io.Process.runSync(
        '/opt/homebrew/bin/ffmpeg',
        <String>[
          '-ss', '00:00:01.00', //
          '-i', path, //
          '-qscale:v', '$quality', //
          '-vf', 'scale=$size:$size:force_original_aspect_ratio=decrease', //
          '-vframes', '1', //
          tmpFile.path,
        ],
      );
      if (createThumbnail.exitCode == 0) {
        return tmpFile.readAsBytesSync();
      } else {
        // TODO: use hard-coded placeholder thumbnail bytes
        return Uint8List.fromList(<int>[]);
      }
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  }

  Future<bool> writeMetadata({DateTime? dateTime, GpsCoordinates? coordinates}) async {
    assert(dateTime != null || coordinates != null);
    final io.Directory tmpDir = io.Directory.systemTemp.createTempSync('geotag_');
    try {
      final io.File metaFile = io.File('${tmpDir.path}/metadata.meta');
      final io.IOSink sink = metaFile.openWrite();
      try {
        sink.writeln(';FFMETADATA1');
        if (coordinates != null) {
          final String coordinatesString = coordinates.toVideoString();
          sink.writeln('location-eng=$coordinatesString');
          sink.writeln('location=$coordinatesString');
        }
        if (dateTime != null) {
          sink.writeln('creation_time=${dateTime.toVideoString()}');
        }
      } finally {
        await sink.close();
      }

      // First, try to add the metadata without having to re-encode the file.
      final io.File outputFile = io.File('${tmpDir.path}/output.mp4');
      io.ProcessResult addMetadata = io.Process.runSync(
        '/opt/homebrew/bin/ffmpeg',
        <String>[
          '-i', path, //
          '-i', metaFile.path, //
          '-map_metadata', '1', //
          '-c', 'copy', //
          outputFile.path,
        ],
      );
      if (addMetadata.exitCode == 0) {
        outputFile.copySync(path);
      } else if (addMetadata.stderr.contains('incorrect codec parameters')) {
        // The video probably needs to be re-encoded
        outputFile.deleteSync();
        addMetadata = io.Process.runSync(
          '/opt/homebrew/bin/ffmpeg',
          <String>[
            '-i', path, //
            '-i', metaFile.path, //
            '-map_metadata', '1', //
            '-c:v', 'libx264', //
            '-preset', 'slow', //
            '-crf', '18', //
            '-strict', '-2', //
            '-pix_fmt', 'yuv420p', //
            outputFile.path,
          ],
        );
        if (addMetadata.exitCode == 0) {
          outputFile.copySync(path);
        } else {
          print('Error ${addMetadata.exitCode}:');
          print('${addMetadata.stderr}');
          return false;
        }
      } else {
        print('Error ${addMetadata.exitCode}:');
        print('${addMetadata.stderr}');
        return false;
      }
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
    return true;
  }
}
