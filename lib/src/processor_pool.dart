import 'dart:async';
import 'processor.dart';

/// setup multiple isolate process to run a given function with a common 2-way
/// communication interface shared by all the isolates
/// 
/// ### Notes
/// - Startup time (worst-case, 4 isolates): 800ms (200ms/isolate)
/// - Force-kill time (worst-case, 4 isolates): 40ms (10ms/isolate)
///
class ProcessorPool<R, I> {
  // [NOTE] Closing the Stream:
  //
  // - the outputStream is simply an amalgamation of the outputStreams of all the individual
  // sub-processors, and should only be close after all sub-processors close their outputStreams.
  // the simplest way to do this is to check if the number of inputs equals the number of outputs.
  // That is what we do here.

  // ==================
  // === Properties ===
  // ==================

  // collection of underlying `Processor`s
  //
  final _pool = <Processor<R, I>>[];

  // indicates which the index of the `Processor` to which the next input will be sent
  //
  var _currentProcessorIndex = 0;

  /// the function being run
  ///
  late final Function(I input) function;

  // a streamController, we use this to enable type checks/enforcement over isolate outputs
  // and also the pipe outputs from all processes into a common output point
  //
  final _streamController = StreamController<R>();

  // n(inputs) - n(outputs)
  //
  var _inOutDelta = 0;

  /// a [Stream] containing processed outputs
  ///
  Stream<R> get outputStream => _streamController.stream;

  /// number of processes on which the given function is being run
  ///
  int get processCount => _pool.length;

  // ==============================
  // === Constructors & Methods ===
  // ==============================

  /// setup a ProcessorPool that will run the provided (synchronous) function
  ///
  /// ### Args
  /// - `function`: a function that takes exactly one input
  /// - `processorCount`: number of processes across which the function provided should be run
  ///
  /// ### Returns
  /// - `ProcessorPool`
  ///
  /// ### Errors
  /// - None
  ///
  /// ### Notes
  /// - you must run [ProcessorPool.start] to actually get the underlying [Processor]'s up and
  /// running, this just sets up necessary pre-requisites
  ///
  ProcessorPool.setupSync(R Function(I input) this.function,
      [int processorCount = 4]) {
    for (var i = 0; i < processorCount; i++) {
      // create a Processors
      var processor = Processor.setupSync(function as R Function(I));
      _pool.add(processor);

      // redirect its output to the common outputStream
      processor.outputStream.listen((output) {
        _streamController.add(output);
        _inOutDelta -= 1;
      });
    }
  }

  /// setup a ProcessorPool that will run the provided (asynchronous) function
  ///
  /// ### Args
  /// - `function`: a function that takes exactly one input
  /// - `processorCount`: number of processes across which the function provided should be run
  ///
  /// ### Returns
  /// - `ProcessorPool`
  ///
  /// ### Errors
  /// - None
  ///
  /// ### Notes
  /// - you must run [ProcessorPool.start] to actually get the underlying [Processor]'s up and
  /// running, this just sets up necessary pre-requisites
  ///
  ProcessorPool.setupAsync(Future<R> Function(I input) this.function,
      [int processorCount = 4]) {
    for (var i = 0; i < processorCount; i++) {
      // create a Processors
      var processor = Processor.setupAsync(function as Future<R> Function(I));
      _pool.add(processor);

      // redirect its output to the common outputStream
      processor.outputStream.listen((output) {
        _streamController.add(output);
        _inOutDelta -= 1;
      });
    }
  }

  /// startup the ProcessorPool (creates the underlying [Processor]s)
  ///
  /// ### Args
  /// - None
  ///
  /// ### Returns
  /// - None
  ///
  /// ### Errors
  /// - None
  ///
  /// ### Notes
  /// - always `await` this method call, else you'll run into errors due to
  /// uninitialized variables
  ///
  Future<void> start() async {
    for (var processor in _pool) {
      await processor.start();
    }
  }

  /// send an input to be processed
  ///
  /// ### Args
  /// - `input`: an input to be sent to the function being run within the `ProcessorPool`
  ///
  /// ### Returns
  /// - None
  ///
  /// ### Errors
  /// - None
  ///
  void send(I input) {
    // send input to Processor at _currentProcessorIndex
    _pool[_currentProcessorIndex].send(input);

    // increment _currentProcessorIndex
    _currentProcessorIndex += 1;
    _currentProcessorIndex %= _pool.length;

    // update input-output delta
    _inOutDelta += 1;
  }

  // the shutdown call has to be asynchronous to work but if "awaited" will hang up the main
  // process. At the same time, the only class method without args (`ProcessorPool.start`) is async
  // and has to be awaited. This wrapper exits to avoid confusion, you can await `Processor.kill`
  // without hanging up the main process (just like `ProcessorPool.start`) - it calls the actual
  // underlying shutdown method without awaiting it
  //
  /// shutdown the `Processor` after currently supplied inputs are processed
  ///
  /// ### Args
  /// - `awaitCompletion`: weather to wait for all inputs to be processed or not
  ///
  /// ### Returns
  /// - None
  ///
  /// ### Errors
  /// - None
  ///

  Future<void> kill({bool awaitCompletion = true}) async {
    _shutdown(awaitCompletion);
  }

  /// shutdown the `Processor` after currently supplied inputs are processed
  ///
  /// ### Args
  /// - `awaitCompletion`: weather to wait for all inputs to be processed or not
  ///
  /// ### Returns
  /// - None
  ///
  /// ### Errors
  /// - None
  ///
  Future<void> _shutdown(bool awaitCompletion) async {
    for (var processor in _pool) {
      await processor.kill(awaitCompletion: awaitCompletion);
    }

    if (awaitCompletion) {
      while (_inOutDelta != 0) {
        await Future.delayed(Duration(milliseconds: 250));
      }
    }

    _streamController.close();
  }
}
