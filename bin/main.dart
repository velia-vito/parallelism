import 'dart:math';

import 'package:parallelism/parallelism.dart';

void main(List<String> args) {
  var pl = ProcessingLine<String, int>()
    ..addFirstProcess((paragraphCount) {
      var randGenerator = Random();
      var paragraphLengthSpec = <int>[];

      for (var i = 0; i < paragraphCount; i++) {
        paragraphLengthSpec.add(randGenerator.nextInt(100));
      }

      // This is why ProcessingLine's addStation methods need to be re-written
      return paragraphLengthSpec as dynamic;
    });
}
