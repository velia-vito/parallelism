part of '../parallelize.dart';

class ProcessGroup<I, O, CR> implements ParallelizationInterface<I, O, CR> {
  @override
  final Future<CR> Function() setupProcess;

  @override
  final Future<O> Function(I input, CR commonResourceRecord) processInput;

  @override
  final Future<void> Function(CR commonResourceRecord) shutdownProcess;

  /// The index of the next worker to be used.
  var _workerIndex = 0;

  /// All of the underlying processes.
  final List<Process<I, O, CR>> _processGroup;

  /// Returns `null` when all processing is completed. (bg-proc).
  final Completer<void> _processingIsComplete = Completer<void>.sync();

  @override
  Future<void> get processingIsComplete => _processingIsComplete.future;

  /// Creates a new [ProcessGroup] instance. Use [ProcessGroup.boot] instead.
  ProcessGroup._(
    this.setupProcess,
    this.processInput,
    this.shutdownProcess,
    this._processGroup,
  );

  /// Boots up a new [ProcessGroup] instance.
  static Future<ProcessGroup<I, O, CR>> boot<I, O, CR>(
    Future<CR> Function() setupProcess,
    Future<O> Function(I input, CR commonResourceRecord) processInput,
    Future<void> Function(CR commonResourceRecord) shutdownProcess, [
    int? numberOfProcesses,
  ]) async {
    numberOfProcesses ??= Platform.numberOfProcessors;

    var processGroup = await Future.wait(
      List.generate(
        numberOfProcesses,
        (_) => Process.boot(setupProcess, processInput, shutdownProcess),
      ),
    );

    return ProcessGroup._(setupProcess, processInput, shutdownProcess, processGroup);
  }

  @override
  Future<O> process(I input) {
    return _processGroup[(_workerIndex++ % _processGroup.length)].process(input);
  }

  @override
  Future<void> shutdownNow() async {
    // Exit-lock.
    var _ = await Future.wait(_processGroup.map((process) => process.shutdownNow()));

    // Notification.
    _processingIsComplete.complete();

    return;
  }

  @override
  Future<void> shutdownOnCompletion() async {
    // Exit-lock.
    var _ = await Future.wait(_processGroup.map((process) => process.shutdownOnCompletion()));

    // Notification.
    _processingIsComplete.complete();

    return;
  }
}
