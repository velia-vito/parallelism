part of '../parallelism.dart';

/// Small utility modification to [ReceivePort]
extension ReceivePortMod on ReceivePort {
  /// used to keep track of all broadcast streams of all ReceivePorts; Store
  /// and serve up when required
  static final Map<int, Stream> _broadcastStreamMap = {};

  /// wrapper around [asBroadcastStream] that prevents `StateError (Bad state:
  /// Stream has already been listened to.)` that occurs when
  /// [asBroadcastStream] is called more than once.
  Stream<dynamic> getBroadcastStream() {
    if (!_broadcastStreamMap.containsKey(hashCode)) {
      _broadcastStreamMap[hashCode] = asBroadcastStream();
    }

    return _broadcastStreamMap[hashCode]!;
  }
}
