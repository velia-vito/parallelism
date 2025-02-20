import 'dart:async';
import 'dart:math';

import 'package:parallelism/parallelism.dart';

void main(List<String> args) async {
  final procCount = 1;

  var procGrp = <Process<int, String, (String, Random)>>[];

  for (var i = 0; i < procCount; i++) {
    procGrp.add(await Process.boot(generateCommonResourceRecord, generateParagraph, cleanup));
  }

  // Send random inputs & process outputs.
  var randomEngine = Random();

  var initTime = DateTime.now();
  var charCount = 0;

  for (var i = 0; i < 10000; i++) {
    var paragraphLock = await procGrp.elementAt(i % procCount).process(randomEngine.nextInt(25));

    var paragraph = await paragraphLock.future;
    charCount += paragraph.length;
  }

  var endTime = DateTime.now();

  print('$charCount generated in ${endTime.difference(initTime).inMilliseconds}ms');

  for (var proc in procGrp) {
    await proc.shutdownOnCompletion();
  }

  print('should exit');
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
