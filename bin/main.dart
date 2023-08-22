import 'dart:math';

import 'package:parallelism/parallelism.dart';

void main(List<String> args) async {
  const chars = 'AaBbCcDdEe FfGgHhIiJj KkLlMmNnOo PpQqRrSsTt UuVvWwXxYy Zz12345678 90';
  Random randomEngine = Random();

  // ===============
  // === Process ===
  // ===============

  // generate random paragraph lengths
  var numSetProc = Process(
    processLoop: (int paragraphCount) async {
      var paragraphLengthSpec = <int>[];

      for (var i = 0; i < paragraphCount; i++) {
        paragraphLengthSpec.add(randomEngine.nextInt(20) * 50);
      }

      // This is why ProcessingLine's addStation methods need to be re-written
      return paragraphLengthSpec;
    },
  );

  // ====================
  // === ProcessGroup ===
  // ====================

  // generate paragraphs
  var paraGenProcGrp = ProcessGroup(
    processLoop: (List<int> paraSpec) async {
      var masterText = '';

      for (var length in paraSpec) {
        var paraString = String.fromCharCodes(
          Iterable.generate(
            length,
            (_) => chars.codeUnitAt(randomEngine.nextInt(chars.length)),
          ),
        );

        masterText += '$paraString\n\n';
      }

      return masterText;
    },
  );

  // ===================
  // === ProcessLine ===
  // ===================

  // Setup ProcessingLine
  var procLine = ProcessingLine<String, int>();
  procLine.addStation(numSetProc);
  procLine.addStation(paraGenProcGrp);

  var _ = await procLine.start();

  // ====================
  // === Main Program ===
  // ====================

  var __ = procLine.stream.listen((data) {
    print(data);
  });

  // Send data for processing
  for (var i = 0; i < 10; i++) {
    procLine.send(randomEngine.nextInt(10));
  }

  procLine.kill();
}
