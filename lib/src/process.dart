part of '../parallelism.dart';

/// A container within which to run a processLoop
class Process<O, I> {
  /// [Stream] with processed outputs
  late final Stream<O> stream;

  /// The [Isolate] running the `Process`
  late final Isolate _isolate;

  /// the function that is used to process data sent to the `Process`
  late final Future<O> Function(I) _processLoop;

  /// [SendPort] to send data to the `Process`
  late final SendPort _procSendPort;

  /// Create a `Process`. Use [start] to activate it
  ///
  /// ### Args:
  /// - `processLoop`: the function that is used to process data sent to the
  /// `Process`
  Process({
    required Future<O> Function(I) processLoop,
  }) : _processLoop = processLoop;

  /// Start up the `Process`. Call this before sending any data to the `Process`
  ///
  /// ### Args
  /// - `customMainRecvPort`: a custom [ReceivePort] for when you want finer
  /// control over received data, for e.g. when you'd like to pipe the outputs
  /// of multiple `Process`es to the same `ReceivePort`
  ///
  /// - `onExit`: function triggered when this `Process` terminates. This
  /// function __*must close*__ the `customMainRecvPort`, or, the application
  /// will not exit.
  Future<Stream<O>> start({
    ReceivePort? customMainRecvPort,
    void Function()? onExit,
  }) async {
    // Ports for Handshake/CleanUp
    final mainRecvPort = customMainRecvPort ?? ReceivePort();
    final usesCustomRecvPort = customMainRecvPort != null;

    if (usesCustomRecvPort && onExit == null) {
      throw Exception('`customMainRecvPort` must be accompanied with a custom '
          '`onExit` that closes the `ReceivePort`');
    }

    final exitRecvPort = ReceivePort();

    /// Clean up;
    var _ = exitRecvPort.listen((_) {
      if (!usesCustomRecvPort) {
        mainRecvPort.close();
      } else {
        onExit!();
      }

      exitRecvPort.close();
    });

    /// Create Isolate
    _isolate = await Isolate.spawn(
      _establishEventLoop,
      mainRecvPort.sendPort,
      onExit: exitRecvPort.sendPort,
    );

    /// stream setup
    var dynamicStream = mainRecvPort.getBroadcastStream();
    _procSendPort = await dynamicStream.first;

    // TODO: yield a custom stream instead of cast, that way you can send both
    // TODO: a data tag, along side the output (?)
    stream = dynamicStream.cast<O>();

    return stream;
  }

  /// Send data to the `Process`
  ///
  /// Note:
  /// - Sending `null` is the equivalent of calling [kill]
  void send(I data) {
    _procSendPort.send(data);
  }

  /// Kill the `Process` after all current inputs are processed
  void kill() {
    _procSendPort.send(null);
  }

  /// Kill the `Process` right NOW irrespective or unprocessed inputs
  void forceKill() {
    _isolate.kill();
  }

  /// Handshake; enable back-and-forth communication around a generic function
  Future<void> _establishEventLoop(SendPort mainSendPort) async {
    // enable sending to data to main
    final procRecvPort = ReceivePort();
    mainSendPort.send(procRecvPort.sendPort);

    // run the processing loop till null is sent
    await for (final data in procRecvPort) {
      if (data is Map<int, I>) {
        mainSendPort.send(await _processLoop(data.entries.first.value));
      } else if (data == null) {
        break;
      } else {
        throw Exception(
          'Isolate eventLoop not designed to handle inputs of type $I',
        );
      }
    }
  }
}
