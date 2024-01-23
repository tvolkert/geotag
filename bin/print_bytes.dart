// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

Future<void> main(List<String> args) async {
  Uint8List bytes = File(args.last).readAsBytesSync();
  StringBuffer buf = StringBuffer();
  int i = 1;

  void dumpBuffer() {
    buf.write(', //');
    print(buf.toString());
    buf.clear();
    i = 1;
  }

  for (int byte in bytes) {
    if (i > 1) buf.write(', ');
    buf.write('$byte');
    if (i % 15 == 0) {
      dumpBuffer();
    } else {
      i++;
    }
  }

  dumpBuffer();
}
