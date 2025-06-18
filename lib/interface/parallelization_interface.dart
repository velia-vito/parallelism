part of '../parallelize.dart';

// ignore: format-comment, as markdown table.
/// General interface for all parallelization implementations.
///
/// ### Args
///
/// | Generic | Description             |
/// | :-----: | :---------------------- |
/// |   `I`   | Input Type              |
/// |   `O`   | Output Type             |
/// |  `CR`   | Common Resource Record  |
///
/// ### Note
/// - Things like creating a HttpClient takes quiet a bit of time, so closing/reopening it each
/// input is a bad idea. So, instead you create a common resource record in the [setupProcess]
/// to bundle such high-cost setup operations. The output will be passed to all calls of
/// [processInput].
///
///   ```dart
///   // Generate high-cost resources like HttpClient.
/// 
///   // Creating a "record" with field names.
///   var commonResources = (id: 10, name: 'Example', client: httpClient);
///   ```
///
/// - You destructure the record in [processInput] to access the high-cost resources while
/// processing inputs.
///
///   ```dart
///   // Full unpacking of a record.
///   var (id, name, client) = commonResourceRecord;
/// 
///   // field access of a record.
///   var client = commonResourceRecord.client;
/// 
///   // Do Processing
///   ```
/// 
/// - The [shutdownProcess] is used to clean up resources after processing is done.
abstract interface class ParallelizationInterface<I, O, CR> {
  /// Generate common resources required to process individual inputs. The outputs are passed to all
  /// calls of [processInput].
  Future<CR> Function() get setupProcess;

  /// Callback used for processing individual inputs sent to the spawned process.
  Future<O> Function(I input, CR commonResourceRecord) get processInput;

  /// Callback used for cleaning up any resources generated in [setupProcess] after processing
  /// is done.
  Future<void> Function(CR commonResourceRecord) get shutdownProcess;

  /// Returns `null` when all processing is completed.
  Future<void> get processingIsComplete;

  /// Process the given input in a the spawned process.
  Future<O> process(I input);

  /// Kill the spawned process after processing current items in queue.
  Future<void> shutdownOnCompletion();

  /// Kill the spawned process immediately irrespective of weather the current inputs are processed
  /// or not.
  Future<void> shutdownNow();
}
