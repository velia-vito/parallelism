import 'package:processors/src/processor_pool.dart';
import 'package:test/test.dart';

import 'dart:isolate';
import 'util_functions.dart';

void main() {
  test('ProcessorPool: SyncFunction [start/force-kill time]', () async {
    // NOTE: Throughout this test we assume a linear relationship between the number of
    // underlying `Processors` ans the startup/force-kill times. This has been tested
    // and holds true for small numbers (has been tested up to 32 underlying `Processors`)

    // start a processor & measure the time it takes
    var startupInitTime = DateTime.now();

    var pool = ProcessorPool.setupSync(syncFn);
    await pool.start();

    var startupEndTime = DateTime.now();

    // check if startup time is less than 0.8s (800 ms, 200ms worst-case time per `Processor`)
    var startupTime = startupEndTime.difference(startupInitTime).inMilliseconds;
    assert(startupTime < 800);

    // close the processor, measure the time it takes
    var killStartTime = DateTime.now();

    await pool.kill(awaitCompletion: false);

    var killEndTime = DateTime.now();

    // check if forced-kill time is less than 0.04s (40 ms, 10ms per underlying-processor)
    var killTime = killEndTime.difference(killStartTime).inMilliseconds;
    assert(killTime < 40);
  });

  test('ProcessorPool: SyncFunction [run & exit]', () async {
    // create and start processor
    var pool = ProcessorPool.setupSync(syncFn);
    await pool.start();

    // send args
    for (var i = 0; i < 400; i++) {
      pool.send(i);
    }

    // shutdown
    await pool.kill();

    // event loop
    var isolateSet = <int>{};

    await for (var output in pool.outputStream) {
      var processorIsolate = output.key;
      var powerVal = output.value;

      var gcd = powerVal.gcd(BigInt.from(2));
      assert(gcd.toInt() == 2 || powerVal.toInt() == 1);

      isolateSet.add(processorIsolate);
    }

    assert(!isolateSet.contains(Isolate.current.hashCode));
    assert(isolateSet.length == 4);
  });

  test('ProcessorPool: SyncFunction [forced exit]', () async {
    // create and start processor
    var pool = ProcessorPool.setupSync(syncFn);
    await pool.start();

    // send args
    for (var i = 0; i < 400; i++) {
      pool.send(i);
    }

    // shutdown
    // !this is the normal "kill signal" that will be processed only after all the inputs
    await pool.kill();

    // shutdown
    // !syncFn processes 4 inputs/sec -> total time = 25 sec
    await Future.delayed(Duration(seconds: 4));
    await pool.kill(awaitCompletion: false);

    var outputCount = await pool.outputStream.length;
    assert(outputCount < 400);
  });

  test('ProcessorPool: AsyncFunction [start/force-kill time]', () async {
    // NOTE: Throughout this test we assume a linear relationship between the number of
    // underlying `Processors` ans the startup/force-kill times. This has been tested
    // and holds true for small numbers (has been tested up to 32 underlying `Processors`)

    // start a processor & measure the time it takes
    var startupInitTime = DateTime.now();

    var pool = ProcessorPool.setupAsync(asyncFn);
    await pool.start();

    var startupEndTime = DateTime.now();

    // check if startup time is less than 0.8s (800 ms, 200ms worst-case time per `Processor`)
    var startupTime = startupEndTime.difference(startupInitTime).inMilliseconds;
    assert(startupTime < 800);

    // close the processor, measure the time it takes
    var killStartTime = DateTime.now();

    await pool.kill(awaitCompletion: false);

    var killEndTime = DateTime.now();

    // check if forced-kill time is less than 0.04s (40 ms, 10ms per underlying-processor)
    var killTime = killEndTime.difference(killStartTime).inMilliseconds;
    assert(killTime < 40);
  });

  test('ProcessorPool: AsyncFunction [run & exit]', () async {
    // create and start processor
    var pool = ProcessorPool.setupAsync(asyncFn);
    await pool.start();

    // send args
    for (var i = 0; i < 400; i++) {
      pool.send(i);
    }

    // shutdown
    await pool.kill();

    // event loop
    var isolateSet = <int>{};

    await for (var output in pool.outputStream) {
      var processorIsolate = output.key;
      var powerVal = output.value;

      var gcd = powerVal.gcd(BigInt.from(2));
      assert(gcd.toInt() == 2 || powerVal.toInt() == 1);

      isolateSet.add(processorIsolate);
    }

    assert(!isolateSet.contains(Isolate.current.hashCode));
    assert(isolateSet.length == 4);
  });

  test('ProcessorPool: AsyncFunction [forced exit]', () async {
    // create and start processor
    var pool = ProcessorPool.setupSync(asyncFn);
    await pool.start();

    // send args
    for (var i = 0; i < 400; i++) {
      pool.send(i);
    }

    // shutdown
    // !this is the normal "kill signal" that will be processed only after all the inputs
    await pool.kill();

    // shutdown
    // !syncFn processes 4 inputs/sec -> total time = 25 sec
    await Future.delayed(Duration(milliseconds: 5));
    await pool.kill(awaitCompletion: false);

    // !outputCount will probably be "0" because `asyncFn` doesn't really take time to complete,
    // !just a few micro seconds, the delay is created by awaiting a `Future.delayed`, so with
    // !the async function giving up control (which is then used to process the next input in
    // !the same function), you might as well assume that all 100 inputs are calculated in a
    // !single instant
    var outputCount = await pool.outputStream.length;
    assert(outputCount < 400);
  });
}
