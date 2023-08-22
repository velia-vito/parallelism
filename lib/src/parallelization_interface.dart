part of '../parallelism.dart';

/// The interface that is used to simplify parallelization
abstract interface class ParallelizationInterface<O, I> {
  /// A [Stream] with processed outputs
  Stream<O> get stream;

  /// Input Type for this process
  Type get iType;

  /// Output Type for this process
  Type get oType;

  /// Start the required [Isolate]s and perform a "hand-shake"
  Future<Stream<O>> start();

  /// Send data for processing;
  void send(I data);

  /// Kill the relevant [Isolate]s after processing all current inputs
  void kill();

  /// Kill the relevant [Isolate]s IMMEDIATELY irrespective of pending inputs
  void forceKill();
}
