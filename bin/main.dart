import 'package:parallelism/parallelism.dart';

// Over 48 cycles, more the cycles, more the time delta
// 02:18.854134s on 01 threads
// 01:36.916452s on 04 threads
// 05:48.823434s on 08 threads (ram bottleneck)

void main(List<String> args) async {
  var sTime = DateTime.now();

  var fibProcGroup = ProcessGroup<List<int>, int>(
    processLoop: (n) async {
      // compute fibonacci sequence up to 50000000
      var fibList = <int>[];

      var cur = 1;
      var lst = 0;
      var tmp = 0;

      for (var i = 0; i < 50000000; i++) {
        fibList.add(cur);

        tmp = cur;
        cur += lst;
        lst = tmp;
      }

      return fibList;
    },
    processCount: 4,
  );

  var stream = await fibProcGroup.start();
  var _ = stream.listen((fibList) {
    print('Current Delta: ${DateTime.now().difference(sTime)} upto ${fibList.length}');
  });

  // number of cycles
  for (var i = 0; i < 48; i++) {
    fibProcGroup.send(i);
  }

  fibProcGroup.kill();
}
