# Processors

<!-- mdformat-toc start --slug=github --maxlevel=6 --minlevel=2 -->

- [Quick Intro](#quick-intro)
  - [Class: `ProcessorPool`](#class-processorpool)
  - [Class: `Processor`](#class-processor)

<!-- mdformat-toc end -->

## Quick Intro<a name="quick-intro"></a>

This library is a wrapper over `dart:isolate` primarily focusing on setting up 2-way
communication between the main dart-process and any `Isolates` spawned and doing this with
minimal-overhead, as fast as possible.

### Class: `ProcessorPool`<a name="class-processorpool"></a>

Sets up multiple isolate process to run a given function with a common 2-way communication
interface shared by all the isolates

You would use this when you need to speed up execution of a CPU-intensive task whose
output you need immediately. This is what you'll use often.

```dart
import 'dart:io';
import 'package:processors/processors.dart';

List<int> compressFile(String filePath) {
  // read file and compress the data. NOTE: compression interchanges data size
  // for processing (i.e is CPU-intensive)

  return compressedData;
}

void main(List<String> args) async {
  // === app setup ===
  // ...

  // setup a Processor, use "Processor.setupAsync" to setup an asynchronous func
  var compressorPool = ProcessorPool.setupSync(compressFile);
  await compressorPool.start();

  // send the required details to the compressorPool
  for (var file in fileList) {
    compressorPool.send(file);
  }

  // this closes all underlying isolates "after all inputs are processed"
  await compressorPool.kill();

  // do stuff with the output
  compressorPool.outputStream.listen(
    // do something (like saved the compressed data to a file)
  )

  // === more app stuff here ===
  //...
}

```

Note that saving the compressed output to a file will backfire, the `ProcessorPool`
doesn't return outputs in the same order an inputs, it returns outputs on a
first-processed first-returned basis. the output order might be different from the input
order.

### Class: `Processor`<a name="class-processor"></a>

Sets up a *single* isolate to run a given function with 2-way communication.

You would use this when you have a CPU-intensive task whose output is not required any
time soon or a CPU-intensive background-task that you need to keep alive for the duration
your app is working without your application lagging inexplicably You probably won't be
using this much.

```dart
import 'dart:io';
import 'package:processors/processors.dart';

int getHashCode(String filePath) {
  // calculate SHA512 hash of a file (CPU-heavy and Disk read/write heavy)
  // especially for big files

  return hashValue;
}

void main(List<String> fileList) async {
  // === app setup ===
  // ...

  // setup a Processor, use "Processor.setupAsync" to setup an asynchronous func
  var hasher = Processor.setupSync(getHashCode);
  await hasher.start();

  // send over inputs
  for (var path in filePaths) {
    hasher.send(path);
  }

  // this closes the underlying isolates "after all inputs are processed"
  await hasher.kill()

  hasher.outputStream.listen((hash) {
    // do something with the has (like verify that said file hasn't been modified)
  });

  // === more app stuff here ===
  //...
}
```

As the CPU-intensive "hashing" part of your app run on a separate `Processor`, the
user-facing "main-process" will never lag.
