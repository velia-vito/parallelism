import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:parallelize/parallelize.dart';

void main() async {
  var maxCount = Platform.numberOfProcessors;

  while (maxCount != 1) {
    await testPrefGain(maxCount);

    maxCount = maxCount ~/ 2;
  }
}

// ignore: prefer-static-class, as this will be called inside the isolate.
Future<void> testPrefGain(int procCount) async {
  // 1. Generate procCount number of processes.
  var procGrp = <Process<int, String, (String, Random)>>[];

  for (var i = 0; i < procCount; i++) {
    procGrp.add(await Process.boot(generateCommonResourceRecord, generateParagraph, cleanup));
  }

  // 2. Send random inputs, find related outputs.
  // Check time here, to exclude setup time.
  var initTime = DateTime.now();

  var charCount = 0;

  // 3. Send 100000 random inputs to the processes.
  for (var i = 0; i < 50000; i++) {
    var paragraphLock = procGrp.elementAt(i % procCount).process(50);

    // Using `Future.then` as `Process.process` is tagged (bg-proc), see Library Documentation Notes.
    paragraphLock.then((paragraph) {
      charCount += paragraph.length;
    });
  }

  var cmplCount = 0;

  // 4. Shutdown all processes.
  for (var proc in procGrp) {
    await proc.shutdownOnCompletion();

    // Easy way to check if all inputs have been processed have completed.
    proc.processingIsComplete.then((_) {
      cmplCount++;

      // Additional step to check if all processes in the Group have completed.
      if (cmplCount == procCount) {
        var endTime = DateTime.now();

        print(
          'proc(${procCount.toString().padLeft(2, '0')}) $charCount generated in ${endTime.difference(initTime).inSeconds}s, ${charCount ~/ endTime.difference(initTime).inMilliseconds} cr/ms',
        );
      }
    });
  }
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
  // Destructure common resources
  var (chars, randomEngine) = commonResources;

  // generate random paragraph lengths
  var paraLengthSpec = Iterable.generate(paragraphCount, (_) => randomEngine.nextInt(20) * 50);

  // generate paragraphs.
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
