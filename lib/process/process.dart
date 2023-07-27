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
  Future<Stream<O>> start({ReceivePort? customMainRecvPort}) async {
    // Ports for Handshake/CleanUp
    final usesCustomRecvPort = customMainRecvPort != null;
    final mainRecvPort = customMainRecvPort ?? ReceivePort();
    final exitRecvPort = ReceivePort();

    /// Clean up;
    var _ = exitRecvPort.listen((_) {
      exitRecvPort.close();
      if (!usesCustomRecvPort) mainRecvPort.close();
    });

    /// Create Isolate
    _isolate = await Isolate.spawn(
      _establishEventLoop,
      mainRecvPort.sendPort,
      onExit: exitRecvPort.sendPort,
    );

    /// stream setup
    var dynamicStream = mainRecvPort.asBroadcastStream();
    _procSendPort = await dynamicStream.first;

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
      if (data is I) {
        mainSendPort.send(await _processLoop(data));
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
