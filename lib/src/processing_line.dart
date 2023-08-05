part of '../parallelism.dart';

// TODO: Rewrite ProcessingLine's addStation methods to be type safe

class ProcessingLine<O, I> implements ParallelizationInterface<O, I> {
  late final Stream<O> stream;

  var _isFinalized = false;

  late final ParallelizationInterface _firstStation;

  late ParallelizationInterface _lastStation;

  final _stationCollection = <ParallelizationInterface>[];

  void addFirstProcess(Future Function(I) processLoop) {
    _firstStation = Process<dynamic, I>(processLoop: processLoop);
    _lastStation = _firstStation;

    _stationCollection.add(_lastStation);
  }

  void addFirstProcessGroup(
    Future Function(I) processLoop,
    int? processCount,
  ) {
    _firstStation = ProcessGroup<dynamic, I>(
      processLoop: processLoop,
      processCount: processCount,
    );
    _lastStation = _firstStation;

    _stationCollection.add(_lastStation);
  }

  void addIntermediateProcess<T>(Future Function(T) processLoop) {
    if (_isFinalized) {
      throw Exception(
        'ProcessingLine is already finalized, cannot add intermediate Processes',
      );
    }

    var intermediateStation = Process<dynamic, T>(processLoop: processLoop);

    var __ = _lastStation.stream.listen((intermediateProcessedData) {
      intermediateStation.send(intermediateProcessedData as T);
    });

    _lastStation = intermediateStation;
    _stationCollection.add(intermediateStation);
  }

  void addIntermediateProcessGroup<T>(
    Future Function(T) processLoop,
    int? processCount,
  ) {
    if (_isFinalized) {
      throw Exception(
        'ProcessingLine is already finalized, cannot add intermediate ProcessGroups',
      );
    }

    var intermediateStation = ProcessGroup<dynamic, T>(
      processLoop: processLoop,
      processCount: processCount,
    );

    var __ = _lastStation.stream.listen((intermediateProcessedData) {
      intermediateStation.send(intermediateProcessedData as T);
    });

    _lastStation = intermediateStation;
    _stationCollection.add(intermediateStation);
  }

  void addFinalProcess<T>(Future<O> Function(T) processLoop) {
    var finalStation = Process<O, T>(processLoop: processLoop);
    stream = finalStation.stream;

    var __ = _lastStation.stream.listen((intermediateProcessedData) {
      finalStation.send(intermediateProcessedData as T);
    });

    _isFinalized = true;
    _lastStation = finalStation;
    _stationCollection.add(_lastStation);
  }

  void addFinalProcessGroup<T>(
    Future<O> Function(T) processLoop,
    int? processCount,
  ) {
    var finalStation = ProcessGroup<O, T>(
      processLoop: processLoop,
      processCount: processCount,
    );
    stream = finalStation.stream;

    var __ = _lastStation.stream.listen((intermediateProcessedData) {
      finalStation.send(intermediateProcessedData as T);
    });

    _isFinalized = true;
    _lastStation = finalStation;
    _stationCollection.add(_lastStation);
  }

  Future<Stream<O>> start() async {
    for (var processOrGroup in _stationCollection) {
      var _ = await processOrGroup.start();
    }

    return stream;
  }

  void send(I data) {
    _firstStation.send(data);
  }

  void kill() {
    for (var processOrGroup in _stationCollection) {
      processOrGroup.kill();
    }
  }

  void forceKill() {
    for (var processOrGroup in _stationCollection) {
      processOrGroup.forceKill();
    }
  }
}
