import 'dart:math';

import 'package:parallelism/parallelism.dart';

void main(List<String> args) async {
  const chars = 'AaBbCcDdEe FfGgHhIiJj KkLlMmNnOo PpQqRrSsTt UuVvWwXxYy Zz12345678 90';
  Random rnd = Random();

  var pl = ProcessingLine<String, int>();

  // generate random text blocks: paragraph lengths
  await pl.addProcessStation<List<int>, int>(
    processLoop: (paragraphCount) async {
      var paragraphLengthSpec = <int>[];

      for (var i = 0; i < paragraphCount; i++) {
        paragraphLengthSpec.add(rnd.nextInt(20) * 50);
      }

      // This is why ProcessingLine's addStation methods need to be re-written
      return paragraphLengthSpec;
    },
  );

  // generate paragraphs
  await pl.addProcessGroupStation<String, List<int>>(
    processLoop: (paraSpec) async {
      var masterText = '';

      for (var length in paraSpec) {
        var paraString = String.fromCharCodes(
          Iterable.generate(
            length,
            (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
          ),
        );

        masterText += '$paraString\n\n';
      }

      return masterText;
    },
  );

  var _ = await pl.start();

  for (var i = 0; i < 10; i++) {
    pl.send(rnd.nextInt(10));
  }

  // Causes Error cuz ProcessGroup ActiveProcesses decrements well before the
  // send command is called and DivisionByZero Occurs
  //
  // var __ = pl.stream.listen((par) {
  //   print(par);
  //   print('\n\n----------------------------------------------------------\n\n');
  // });

  await for (var par in pl.stream) {
    print(par);
    print('\n\n----------------------------------------------------------\n\n');
  }

  pl.kill();

  // TODO: Find cause for non-exiting behaviour and fix it
}
