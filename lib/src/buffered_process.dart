part of '../parallelism.dart';

/// A process that allows for a single input processed as multiple parts
/// Basically a failure
class BufferedProcessPrototypeTest<O, OP, IP, I> {
  final _internalStream = StreamController<O>.broadcast();

  /// Which-eth input this is
  var _iCount = 0;

  var _pCountTemp = 0;

  /// Buffer for processed parts
  var _buffer = SplayTreeMap<int, List<MapEntry<int, OP>>>();

  var _pCount = <int, int>{};

  /// The [Isolate] running the `Process`
  late final Isolate _isolate;

  /// the function that is used to process data sent to the `Process`
  late final Future<OP> Function(IP) _processLoop;

  /// the function that is used to split the input into pieces
  late final Stream<IP> Function(I) _inputSplitter;

  late final O Function(List<MapEntry<int, OP>>) _rebuilder;

  /// [Stream] with processed outputs
  Stream<O> get stream => _internalStream.stream;

  /// [SendPort] to send data to the `Process`
  late final SendPort _procSendPort;

  /// Create a `Process`. Use [start] to activate it
  ///
  /// ### Args:
  /// - `processLoop`: the function that is used to process data sent to the
  /// `Process`
  BufferedProcessPrototypeTest({
    required Future<OP> Function(IP) processLoop,
    required Stream<IP> Function(I) inputSplitter,
    required O Function(List<MapEntry<int, OP>>) rebuilder,
  })  : _processLoop = processLoop,
        _inputSplitter = inputSplitter,
        _rebuilder = rebuilder;

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

    // TODO: Rebuild output from pieces here
    var __ = dynamicStream.listen((oPiece) {
      oPiece = oPiece as Map;

      var iCount = oPiece['iCount'] as int;
      var pCount = oPiece['pCount'] as int;
      var piece = oPiece['piece'] as OP;

      if (!_buffer.containsKey(iCount)) {
        _buffer[iCount] = [MapEntry(pCount, piece)];
      } else {
        _buffer[iCount]!.add(MapEntry(pCount, piece));

        if (_buffer[iCount]!.length == _pCount[iCount]) {
          _internalStream.add(_rebuilder(_buffer[iCount]!));

          var ___ = _buffer.remove(iCount);
          var ____ = _pCount.remove(iCount);
        }
      }
    });

    return stream;
  }

  /// Send data to the `Process`
  ///
  /// Note:
  /// - Sending `null` is the equivalent of calling [kill]
  Future<void> send(I data) async {
    _pCountTemp = 0;

    await for (var iPiece in await _inputSplitter(data)) {
      _procSendPort.send({
        'iCount': _iCount,
        'pCount': _pCountTemp++,
        'piece': iPiece,
      });

      // store number of parts generated for cross-verification before rebuilding
      _pCount[_iCount] = _pCountTemp;
    }
    ;

    // increment inputCount for the next call to send
    _iCount++;
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
      if (data is Map && data['piece'] is IP) {
        mainSendPort.send({
          'iCount': data['iCount'] as int,
          'pCOunt': data['pCount'] as int,
          'piece': await _processLoop(data['piece'] as IP),
        });
      } else if (data == null) {
        break;
      } else {
        throw Exception(
          'Isolate eventLoop not designed to handle inputs of type ${data.runtimeType}',
        );
      }
    }
  }
}
