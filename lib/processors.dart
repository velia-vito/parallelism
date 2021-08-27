/// This library is a wrapper over `dart:isolate` primarily focusing on setting up 2-way
/// communication between the main dart-process and any `Isolates` spawned and doing this
/// with minimal-overhead, as fast as possible.
///
library processors;

export './src/processor.dart';
export './src/processor_pool.dart';