part of '../parallelism.dart';

/// Order [Process]es and [ProcessGroup]s sequentially to complete a complex,
/// multi-step workload akin to how factory lines work.
class ProcessingLine<O, I> implements ParallelizationInterface<O, I> {
  @override
  late final iType;

  @override
  late final oType;

  @override
  late final Stream<O> stream;

  /// n(inputs) - n(outputs)
  ///
  /// ### Note:
  /// - calling [kill] will shut down all individual stations of this
  /// `ProcessLine` at the same time, so instead of A -> B, Station A gives an
  /// output but Station B is already closed. This causes unexpected behaviors,
  /// by ensuring that n(inputs) == n(outputs), we can kill the stations only
  /// when all the data is processed.
  var _dataDelta = 0;

  final _stations = <ParallelizationInterface>[];

  /// Create a `ProcessingLine`
  ProcessingLine()
      : iType = I,
        oType = O;

  /// Add a new station to the `ProcessingLine`
  void addStation<o, i>(ParallelizationInterface<o, i> station) {
    if (_stations.isNotEmpty && station.iType != _stations.last.oType) {
      throw Exception('Type mismatch: Previous Station gives output of type '
          '${_stations.last.oType}, but the given station accepts inputs of '
          'type ${station.iType}');
    }

    _stations.add(station);
  }

  @override
  void forceKill() {
    for (var station in _stations) {
      station.forceKill();
    }
  }

  @override
  void kill() {
    var _ = stream.listen((data) {
      if (_dataDelta == 0) {
        for (var station in _stations) {
          station.kill();
        }
      }
    });
  }

  @override
  void send(I data) {
    _stations.first.send(data);
    _dataDelta += 1;
  }

  @override
  Future<Stream<O>> start() async {
    if (_stations.first.iType != I || _stations.last.oType != O) {
      throw Exception('ProcessingLine was defined as <$O, $I> but created '
          'as <${_stations.first.iType}, ${_stations.last.oType}>, check '
          'initial and final Process/ProcessGroup');
    }

    for (var i = 0; i < _stations.length - 1; i++) {
      var cStation = _stations[i];
      var nStation = _stations[i + 1];

      var _ = await cStation.start();
      var __ = cStation.stream.listen((data) {
        nStation.send(data);
      });
    }

    var _ = await _stations.last.start();
    stream = _stations.last.stream as Stream<O>;

    var __ = stream.listen((data) {
      _dataDelta -= 1;
    });

    return stream;
  }
}
