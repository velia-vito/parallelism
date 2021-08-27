import 'package:processors/src/processor.dart';
import 'package:test/test.dart';

import 'dart:isolate';
import 'util_functions.dart';

void main() {
  test('Processor: SyncFunction [start/force-kill time]', () async {
    // start a processor & measure the time it takes
    var startupInitTime = DateTime.now();

    var processor = Processor.setupSync(syncFn);
    await processor.start();

    var startupEndTime = DateTime.now();

    // check if startup time is less than 0.2s (200ms, worst-case time)
    var startupTime = startupEndTime.difference(startupInitTime).inMilliseconds;
    assert(startupTime < 200);

    // close the processor, measure the time it takes
    var killStartTime = DateTime.now();

    await processor.kill(awaitCompletion: false);

    var killEndTime = DateTime.now();

    // check if forced-kill time is less than 0.01s (10 ms)
    var killTime = killEndTime.difference(killStartTime).inMilliseconds;
    assert(killTime < 10);
  });

  test('Processor: SyncFunction [run & exit]', () async {
    // create and start processor
    var processor = Processor.setupSync(syncFn);
    await processor.start();

    // send args
    for (var i = 0; i < 100; i++) {
      processor.send(i);
    }

    // shutdown
    processor.kill();

    // main process code (for identification purpose)
    var thisIsolate = Isolate.current.hashCode;

    // event loop
    var exponent = 0;

    await for (var output in processor.outputStream) {
      var processorIsolate = output.key;
      var powerVal = output.value;

      assert(processorIsolate != thisIsolate);
      assert(powerVal == BigInt.two.pow(exponent++));
    }
  });

  test('Processor: SyncFunction [forced exit]', () async {
    // create and start processor
    var processor = Processor.setupSync(syncFn);
    await processor.start();

    // send args
    for (var i = 0; i < 100; i++) {
      processor.send(i);
    }

    // shutdown
    // !this is the normal "kill signal" that will be processed only after all the inputs
    await processor.kill();

    // shutdown
    // !syncFn processes 4 inputs/sec -> total time = 25 sec
    await Future.delayed(Duration(seconds: 5));
    await processor.kill(awaitCompletion: false);

    var outputCount = await processor.outputStream.length;
    assert(outputCount < 100);
  });

  test('Processor: AsyncFunction [start/force-kill time]', () async {
    // start a processor & measure the time it takes
    var startupInitTime = DateTime.now();

    var processor = Processor.setupAsync(asyncFn);
    await processor.start();

    var startupEndTime = DateTime.now();

    // check if startup time is less than 0.2s (200ms, worst-case time)
    var startupTime = startupEndTime.difference(startupInitTime).inMilliseconds;
    assert(startupTime < 200);

    // close the processor, measure the time it takes
    var killStartTime = DateTime.now();

    await processor.kill(awaitCompletion: false);

    var killEndTime = DateTime.now();

    // check if forced-kill time is less than 0.01s (10 ms)
    var killTime = killEndTime.difference(killStartTime).inMilliseconds;
    assert(killTime < 10);
  });

  test('Processor: AsyncFunction [run & exit]', () async {
    // create and start processor
    var processor = Processor.setupAsync(asyncFn);
    await processor.start();

    // send args
    for (var i = 0; i < 100; i++) {
      processor.send(i);
    }

    // shutdown
    processor.kill();

    // main process code (for identification purpose)
    var thisIsolate = Isolate.current.hashCode;

    // event loop
    var exponent = 0;

    await for (var output in processor.outputStream) {
      var processorIsolate = output.key;
      var powerVal = output.value;

      assert(processorIsolate != thisIsolate);
      assert(powerVal == BigInt.two.pow(exponent++));
    }
  });

  test('Processor: AsyncFunction [forced exit]', () async {
    // create and start processor
    var processor = Processor.setupSync(asyncFn);
    await processor.start();

    // send args
    for (var i = 0; i < 100; i++) {
      processor.send(i);
    }

    // shutdown
    // !this is the normal "kill signal" that will be processed only after all the inputs
    processor.kill();

    // shutdown
    // !syncFn processes 4 inputs/sec -> total time = 25 sec
    await Future.delayed(Duration(milliseconds: 5));
    processor.kill(awaitCompletion: false);

    // !outputCount will probably be "0" because `asyncFn` doesn't really take time to complete,
    // !just a few micro seconds, the delay is created by awaiting a `Future.delayed`, so with
    // !the async function giving up control (which is then used to process the next input in
    // !the same function), you might as well assume that all 100 inputs are calculated in a
    // !single instant
    var outputCount = await processor.outputStream.length;
    assert(outputCount < 100);
  });
}
