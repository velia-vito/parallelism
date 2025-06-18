part of '../parallelize.dart';

// ignore: format-comment, as markdown table.
/// Creates a new *process* and runs your code in parallel.
/// 
/// ### Args
///
/// | Generic | Description                                                   |
/// |:-------:|:------------------------------------------------------------- |
/// |   `I`   | Input Type                                                    |
/// |   `O`   | Output Type                                                   |
/// |  `CR`   | Common Resource (see [ParallelizationInterface] Note)         |
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
class Process<I, O, CR> implements ParallelizationInterface<I, O, CR> {
  /// Shutdown code for the spawned Isolate.
  final String shutdownCode;

  @override
  final Future<CR> Function() setupProcess;

  @override
  final Future<O> Function(I input, CR setupRecord) processInput;

  @override
  final Future<void> Function(CR commonResourceRecord) shutdownProcess;

  /// Underlying completer for [processingIsComplete].
  final Completer<void> _processingComplete = Completer<void>.sync();

  /// All completer and their relevant ids. This is used to link input/output to the
  /// relevant completer.
  final Map<int, Completer<O>> _unprocessedInputs = {};

  /// Id for the next completer entry into _unprocessedInputs. Always increment just after use.
  int _sequentialId = 0;

  /// Underlying [Isolate] instance.
  late final Isolate _isolate;

  /// Port to send data to [_isolate].
  late final SendPort _toProcessPort;

  /// Port to receive data from [_isolate].
  late final ReceivePort _fromProcessPort;

  /// Weather the process is still accepting inputs.
  bool _isActive = true;

  /// Weather the process is still accepting inputs.
  bool get isActive => _isActive;

  @override
  Future<void> get processingIsComplete => _processingComplete.future;

  /// Create a new [Process] instance. Use [Process.boot] instead.
  Process._(
    this.setupProcess,
    this.processInput,
    this.shutdownProcess,
    this.shutdownCode,
    this._isolate,
    this._toProcessPort,
    this._fromProcessPort,
  ) {
    // Handle processed outputs from the spawned Isolate.
    var _ = _fromProcessPort.listen((message) {
      var (completerId, output) = message as (int, O);

      // Complete the relevant completer.
      _unprocessedInputs[completerId]!.complete(output);
      var _ = _unprocessedInputs.remove(completerId);

      if (!isActive && _unprocessedInputs.isEmpty) {
        _fromProcessPort.close();
        _processingComplete.complete();
      }
    });
  }

  @override
  Future<O> process(I input) async {
    // If the process is not active, throw an error.
    if (!isActive) {
      throw StateError(
        '`shutdownOnCompletion` or `shutdownNow` has been called, cannot process new inputs.',
      );
    }

    // This completer is used to notify a user when the input has been processed.
    final processingStatusLock = Completer<O>.sync();
    final id = ++_sequentialId;

    // Related to the completer system, see Note on `Process`.
    _unprocessedInputs[id] = processingStatusLock;
    _toProcessPort.send((id, input));

    return processingStatusLock.future;
  }

  @override
  Future<void> shutdownNow() async {
    _isActive = false;

    // Mass murder.
    _isolate.kill(priority: Isolate.immediate);
    _processingComplete.complete();

    // Clean up connections to allow Main Isolate to exit.
    _fromProcessPort.close();
  }

  @override
  Future<void> shutdownOnCompletion() async {
    _isActive = false;

    // Start winding down.
    _toProcessPort.send(shutdownCode);

    // To ensure that the Future completes only when the _isolate has been shutdown.
    return processingIsComplete;
  }

  /// Create a new Operating System process. Runs on main Process.
  static Future<Process<I, O, CR>> boot<I, O, CR>(
    Future<CR> Function() setupProcess,
    Future<O> Function(I input, CR setupRecord) processInput,
    Future<void> Function(CR commonResourceRecord) shutdownProcess, [
    String shutdownCode = '5hu†d0wn',
  ]) async {
    // Used to block boot completion until 2-way communication is established.
    // Note: Completer returns a record — a structured bundle of ReceivePort and SendPort.
    final connectionLock = Completer<(ReceivePort, SendPort)>.sync();

    // Create a `RawReceivePort` (as we can set a different handler when we convert it to a
    // `ReceivePort` later).
    final protoFromProcessPort = RawReceivePort();

    // Add in the connectionLock logic. The callback is only executed when `Isolate.spawn` is
    // called later in this method.
    protoFromProcessPort.handler = (toProcessPort) {
      connectionLock.complete(
        // Note: Record, (ReceivePort, SendPort).
        (
          ReceivePort.fromRawReceivePort(protoFromProcessPort),
          toProcessPort as SendPort,
        ),
      );
    };

    // Spawn worker Isolate.
    late final Isolate isolate;

    try {
      isolate = await Isolate.spawn(
        _setupIsolate<I, O, CR>,
        (protoFromProcessPort.sendPort, shutdownCode, setupProcess, processInput, shutdownProcess),
      );
    } catch (err) {
      // Close Port and rethrow error on literally any error.
      protoFromProcessPort.close();
      rethrow;
    }

    // Hold execution until the connectionLock is released. Update Ports.
    final (fromProcessPort, toProcessPort) = await connectionLock.future;

    return Process._(
      setupProcess,
      processInput,
      shutdownProcess,
      shutdownCode,
      isolate,
      toProcessPort,
      fromProcessPort,
    );
  }

  /// Isolate Setup, Common Resource Generation, and Event Processing loop.
  ///
  /// ### Note
  /// - The method signature is just plain fucked, but it's the only things that I could come up
  /// with that also works.
  static void _setupIsolate<I, O, CR>(
    (
      SendPort,
      String,
      Future<CR> Function(),
      Future<O> Function(I input, CR commonResources),
      Future<void> Function(CR commonResources)
    ) instructionRecord,
  ) {
    // Destructuring the instruction record.
    var (toMainPort, shutdownCode, setupProcess, processInput, shutdownProcess) = instructionRecord;

    // Note that  toMainPort is protoFromProcessPort.sendPort, this lambda is written from the
    // PoV of the spawned Isolate. So, toMainPort is the SendPort to the main Isolate, and
    // fromMainPort is the ReceivePort whose SendPort is sent to the main Isolate.

    // Exchange Send/Receive Ports with the main Isolate.
    final fromMainPort = ReceivePort();
    toMainPort.send(fromMainPort.sendPort);

    // Process input and/or Shutdown Isolate.
    //
    // Note: As there is no other good way to allow the flexibility of performing
    // async setup steps within the sync requirements of an Isolate's entryPoint.
    //
    // ignore: prefer-async-await, async flexibility, sync required.
    setupProcess().then((commonResources) {
      var _ = fromMainPort.listen((message) {
        if (message != shutdownCode) {
          // Related to _unprocessedInputs. See Note on `Process`.
          var (completerId, input) = message as (int, I);

          // ignore: prefer-async-await, async flexibility, sync required.
          processInput(input, commonResources).then((output) {
            toMainPort.send((completerId, output));
          });
        } else {
          toMainPort.send(shutdownCode);
          fromMainPort.close();

          // ignore: prefer-async-await, async flexibility, sync required.
          shutdownProcess(commonResources).then((_) {
            // Note, killing the Isolate will break `shutdownOnComplete` as the isolate can no
            // longer process inputs on kill and hence _unprocessedInputs will never be empty.
            return;
          });
        }
      });
    });
  }
}
