part of '../parallelism.dart';

/// Create a bunch of [Process]es that run the same `processLoop`.
class ProcessGroup<O, I> {
  /// [Stream] with processed outputs
  late final Stream<O> stream;

  final _procGroup = <Process>[];

  var _activeProcCount = 0;

  var _selectedProc = 0;

  /// Create a `ProcessGroup`
  ///
  /// ### Args
  /// - `processLoop`: the function that is used to process data sent to the
  /// `ProcessGroup`
  ///
  /// ### Notes
  /// - This is primarily for when you have high volume work, note that all
  /// outputs are streamed together.
  ///
  /// - `processCount` defaults to the number of processors your device has.
  ProcessGroup({
    required Future<O> Function(I) processLoop,
    int? processCount,
  }) {
    _activeProcCount = processCount ?? Platform.numberOfProcessors;

    for (var i = 0; i < _activeProcCount; i++) {
      _procGroup.add(Process<O, I>(processLoop: processLoop));
    }
  }

  /// Start up the `ProcessGroup`. Call this before sending any data to the
  /// `ProcessGroup`
  Future<Stream<O>> start() async {
    // custom receive port to be shared across all processes
    var customRecvPort = ReceivePort();

    for (var proc in _procGroup) {
      var _ = await proc.start(
        customMainRecvPort: customRecvPort,
        onExit: () {
          // keep track of active processes and close the receive port when all
          // processes are dead
          _activeProcCount--;

          if (_activeProcCount <= 0) {
            customRecvPort.close();
          }
        },
      );
    }

    stream = customRecvPort.getBroadcastStream().cast<O>();

    return stream;
  }

  ///Send data to the Process
  ///
  /// ### Note
  ///
  /// - Sending `null` is the equivalent of calling [kill] for one on the
  /// [Process]es in the group
  void send(I data) {
    _procGroup[_selectedProc].send(data);

    _selectedProc = (_selectedProc + 1) % _activeProcCount;
  }

  /// Kill the `ProcessGroup` after all current inputs are processed
  void kill() {
    for (var proc in _procGroup) {
      proc.kill();
    }
  }

  /// Kill the `ProcessGroup` right NOW irrespective or unprocessed inputs
  void forceKill() {
    for (var proc in _procGroup) {
      proc.forceKill();
    }
  }
}
