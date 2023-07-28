import 'package:parallelism/parallelism.dart';

// 01:05.544569s on 16 threads
// 00:54.202234 on 01 threads

void main(List<String> args) async {
  var sTime = DateTime.now();

  var fibProcGroup = ProcessGroup<List<int>, int>(
    processLoop: (n) async {
      var fibList = <int>[];

      var cur = 1;
      var lst = 0;
      var tmp = 0;
//10000000
      for (var i = 0; i < 100; i++) {
        fibList.add(cur);

        tmp = cur;
        cur += lst;
        lst = tmp;
      }

      return fibList;
    },
  );

  var stream = await fibProcGroup.start();
  var _ = stream.listen((fibList) {
    print('Current Delta: ${DateTime.now().difference(sTime)} upto ${fibList.length}');
  });

  for (var i = 0; i < 100; i++) {
    fibProcGroup.send(i);
  }

  fibProcGroup.kill();
}
