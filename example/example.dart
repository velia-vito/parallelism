import 'dart:async';
import 'dart:math';

import 'package:parallelize/parallelize.dart';

// =================================================
// ========== TEST OUTPUT (Ryzen 7 5800H) ==========
// =================================================
// proc(16) 1192487000 generated in 13s, 86524 cr/ms
// proc(08) 1193112000 generated in 19s, 61000 cr/ms
// proc(04) 1192426250 generated in 32s, 36870 cr/ms
// proc(02) 1192733250 generated in 53s, 22143 cr/ms
// proc(01) 1193177600 generated in 92s, 12847 cr/ms
void main() async {
  for (var i = 16; i > 0; i = i ~/ 2) {
    await testPrefGain(i);
  }
}

// ignore: prefer-static-class, as this will be called inside the isolate.
Future<void> testPrefGain(int procCount) async {
  // 1. Generate procCount number of processes.
  var procGrp = await ProcessGroup.boot(
    generateCommonResourceRecord,
    generateParagraph,
    cleanup,
    procCount,
  );

  // 2. Send random inputs, find related outputs.
  // Check time here, to exclude setup time.
  var initTime = DateTime.now();
  var charCount = 0;

  // 3. Send 50000 random inputs to the processes.
  for (var i = 0; i < 50000; i++) {
    var paragraphLock = procGrp.process(50);

    // Using `Future.then` as `Process.process` is tagged (bg-proc), see Library Documentation Notes.
    paragraphLock.then((paragraph) {
      charCount += paragraph.length;
    });
  }

  // 4. Shutdown all processes.
  var _ = await procGrp.shutdownOnCompletion();

  // 5. Display Time taken.
  var endTime = DateTime.now();
  print(
    'proc(${procCount.toString().padLeft(2, '0')}) $charCount generated in ${endTime.difference(initTime).inSeconds}s, ${charCount ~/ endTime.difference(initTime).inMilliseconds} cr/ms',
  );
}

// ignore: prefer-static-class, as this will be called inside the isolate.
Future<(String, Random)> generateCommonResourceRecord() async {
  return (
    'AaBbCcDdEe FfGgHhIiJj KkLlMmNnOo PpQqRrSsTt UuVvWwXxYy Zz12345678 90',
    Random(),
  );
}

// ignore: prefer-static-class, as this will be called inside the isolate.
Future<String> generateParagraph(int paragraphCount, (String, Random) commonResources) async {
  // 1. Destructure common resources.
  var (chars, randomEngine) = commonResources;

  // 2. Generate random paragraph lengths.
  var paraLengthSpec = Iterable.generate(paragraphCount, (_) => randomEngine.nextInt(20) * 50);

  // 3. Generate paragraphs.
  var masterText = '';

  for (var length in paraLengthSpec) {
    var paraString = String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(randomEngine.nextInt(chars.length)),
      ),
    );

    masterText += '$paraString\n\n';
  }

  return masterText;
}

// ignore: prefer-static-class, as this will be called inside the isolate.
Future<void> cleanup((String, Random) commonResources) async => null;
