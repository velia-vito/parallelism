import 'dart:isolate';

/// returns MapEntry(`Isolate.current.hashCode`, `2 ^ x` as `BigInt`)
/// after a 250ms (synchronous) delay
///
MapEntry<int, BigInt> syncFn(int x) {
  var startTime = DateTime.now();

  while (DateTime.now().difference(startTime).inMilliseconds < 250) {
    // wait, do nothing
  }

  return MapEntry(Isolate.current.hashCode, BigInt.two.pow(x));
}

/// returns MapEntry(`Isolate.current.hashCode`, `2 ^ x` as `BigInt`)
/// after a 250ms (asynchronous) delay
///
Future<MapEntry<int, BigInt>> asyncFn(int x) async {
  await Future.delayed(Duration(milliseconds: 250));

  return MapEntry(Isolate.current.hashCode, BigInt.two.pow(x));
}
