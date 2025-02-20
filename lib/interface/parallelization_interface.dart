part of '../parallelism.dart';

// ignore: format-comment, as markdown table.
/// Parallelization interface where:
///
/// | Generic | Description             |
/// | :-----: | :---------------------- |
/// |   `I`   | Input Type              |
/// |   `O`   | Output Type             |
/// |  `CR`   | Common Resource Record  |
///
/// ### Note
/// - Let's say you're downloading files in parallel. You can either create and close a fresh
/// HTTP client for each download (inefficient) or create a single HTTP client and reuse it for
/// all downloads (efficient). The common resource record is where you'd store the HTTP client.
///
/// - It's called a record because if you require multiple *common resources*, you can store them
/// as [Dart Record](https://dart.dev/language/records). All you would need to do is destructure
/// the record in your [processInput] and [shutdownProcess] methods.
abstract interface class ParallelizationInterface<I, O, CR> {
  /// Generate common resources required to process individual inputs.
  ///
  /// ### Note
  /// - See Note on [ParallelizationInterface].
  Future<CR> Function() get setupProcess;

  /// Callback used for processing the input.
  ///
  /// ### Note
  /// - See Note on [ParallelizationInterface].
  Future<O> Function(I input, CR commonResourceRecord) get processInput;

  /// Callback used for shutting down the processing.
  ///
  /// ### Note
  /// - See Note on [ParallelizationInterface].
  Future<void> Function(CR commonResourceRecord) get shutdownProcess;

  /// Process the given input in a separate process.
  Future<Completer<O>> process(I input);

  /// Kill the spawned process after processing current items in queue.
  Future<void> shutdownOnCompletion();

  /// Kill the spawned process immediately.
  Future<void> shutdownNow();
}
