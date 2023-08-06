part of '../parallelism.dart';

class ProcessingLine<O, I> implements ParallelizationInterface<O, I> {
  late final Stream<O> stream;

  final _stations = <ParallelizationInterface>[];

  var _lastOType = I;

  bool _isFinalized = false;

  Future<void> addProcessStation<o, i>({
    required Future<o> Function(i) processLoop,
  }) async {
    if (_isFinalized) {
      throw Exception('ProcessingLine already finalized');
    }

    if (_lastOType != i) {
      throw Exception(
        'Previous Station return $_lastOType, this Station accepts $i: '
        'Type-Mismatch Error',
      );
    }

    var proc = Process<o, i>(processLoop: processLoop);
    var _ = await proc.start();

    if (_stations.isNotEmpty) {
      var __ = _stations.last.stream.listen((intermediateData) {
        proc.send(intermediateData);
      });
    }

    _stations.add(proc);
    _lastOType = o;
  }

  Future<void> addProcessGroupStation<o, i>({
    required Future<o> Function(i) processLoop,
    int? procCount,
  }) async {
    if (_isFinalized) {
      throw Exception('ProcessingLine already finalized');
    }

    if (_lastOType != i) {
      throw Exception(
        'Previous Station return $_lastOType, this Station accepts $i: '
        'Type-Mismatch Error',
      );
    }

    var proc = ProcessGroup<o, i>(
      processLoop: processLoop,
      processCount: procCount,
    );
    var _ = await proc.start();

    if (_stations.isNotEmpty) {
      var __ = _stations.last.stream.listen((intermediateData) {
        proc.send(intermediateData);
      });
    }

    _stations.add(proc);
    _lastOType = o;
  }

  @override
  void forceKill() {
    for (var station in _stations) {
      station.forceKill();
    }
  }

  @override
  void kill() {
    for (var station in _stations) {
      station.kill();
    }
  }

  @override
  void send(I data) {
    _stations.first.send(data);
  }

  @override
  Future<Stream<O>> start() async {
    if (_lastOType != O) {
      throw Exception(
        'Last Station on this ProcessingLine returns $_lastOType data, it is '
        'expected to return data of type $O',
      );
    }

    stream = _stations.last.stream as Stream<O>;

    return stream;
  }
}
