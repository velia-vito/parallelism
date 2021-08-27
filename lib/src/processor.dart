// Imports
import 'dart:async';
import 'dart:isolate';

/// setup an isolate process to run a given function with 2-way communication
/// 
/// ### Notes
/// - Startup time (worst-case): 200ms
/// - Force-kill time (worst-case): 10ms
/// 
class Processor<R, I> {
  // [NOTE] Complications while running async functions in a Processor:
  //
  //  - Async function run line-by-line up until the first `await` statement and then passes the
  //    control-flow to which ever other bit of code that wants to run, in essenes, the function
  //    pauses until the awaited data is received.
  //
  //  - In our case, the control-flow is passed onto the same function working on the next input,
  //    and the next, and the next until eventually, the "kill signal" is processed while waiting
  //    on an await - the Processor is shutdown but while some inputs have been completely
  //    processed and sent over to the "main process", a few are still "paused" on await while
  //    the isolate is shutdown from within the main process - i.e. they never complete processing
  //    this can show up an inexplicable behaviour like your main process just suddenly deciding to
  //    skip a whole chunk of code and exiting with no apparent rhyme or reason.
  //
  //  - To counteract this, we keep track of the difference between the number of inputs sent
  //    and the number of outputs received from the isolate - we do this on main process. Once
  //    the kill signal is mirrored, we periodically check if all inputs have been processed - i.e.
  //    n(inputs) = n(outputs) - then and only then do we shut down the isolate.

  // ==================
  // === Properties ===
  // ==================

  // port to receive "processed outputs" from the isolate
  //
  final _outputPort = ReceivePort();

  // port to send inputs for the isolate to process
  //
  late final SendPort _inputPort;

  // the isolate in question
  //
  late final Isolate _isolate;

  // a streamController, we use this to enable type checks/enforcement over isolate outputs
  //
  final _streamControl = StreamController<R>();

  // a reference to the function being run in the isolate
  // !this is kept for 2 reasons:
  // !    1. to keep a reference to the function in case its required
  // !    2. to enforce generic type R & I (returnType, InputType)
  //
  /// the function being run in the isolate
  ///
  late final Function(I input) function;

  /// weather the function being run internally is asynchronous
  ///
  late final bool isAsync;

  /// a [Stream] containing processed outputs
  ///
  Stream<R> get outputStream => _streamControl.stream;

  // n(inputs) - n(outputs), see NOTE on async functions at the top of the class
  //
  var _inOutDelta = 0;

  // ==============================
  // === Constructors & Methods ===
  // ==============================

  /// setup a `Processor` that will run the provided (synchronous) function
  ///
  /// ### Args
  /// - `function`: a (synchronous) function that takes exactly one input
  ///
  /// ### Returns
  /// - `Processor`
  ///
  /// ### Errors
  /// - None
  ///
  /// ### Notes
  /// - you must run [Processor.start] to actually get the underlying isolate up and running,
  /// this just sets up necessary pre-requisites
  ///
  Processor.setupSync(R Function(I input) this.function) {
    isAsync = false;
  }

  /// setup a `Processor` that will run the provided (asynchronous) function
  ///
  /// ### Args
  /// - `function`: a (asynchronous) function that takes exactly one input
  ///
  /// ### Returns
  /// - `Processor`
  ///
  /// ### Errors
  /// - None
  ///
  /// ### Notes
  /// - you must run [Processor.start] to actually get the underlying isolate up and running,
  /// this just sets up necessary pre-requisites
  ///
  Processor.setupAsync(Future<R> Function(I input) this.function) {
    isAsync = true;
  }

  /// startup the `Processor` (creates the underlying isolate)
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
    // !a throw-away port to obtain an inputPort
    var setupPort = ReceivePort();

    // startup the isolate
    var setupList = [
      function,
      _outputPort.sendPort,
      setupPort.sendPort,
    ];

    if (isAsync) {
      _isolate = await Isolate.spawn(_asyncFunctionRunner, setupList);
    } else {
      _isolate = await Isolate.spawn(_syncFunctionRunner, setupList);
    }

    // obtain a port to send inputs to the isolate
    // !this shuts down metaPort
    _inputPort = await setupPort.first;

    // redirect all outputs to the stream
    _outputPort.listen((output) {
      _streamControl.add(output as R);

      // note that the input-output count difference is now decreased by 1
      _inOutDelta -= 1;
    });
  }

  /// send an input to be processed
  ///
  /// ### Args
  /// - `input`: an input to be sent to the function being run within the `Processor`
  ///
  /// ### Returns
  /// - None
  ///
  /// ### Errors
  /// - None
  ///
  void send(I input) {
    _inputPort.send(input);

    // note that there is now 1 more input than output
    _inOutDelta += 1;
  }

  // the shutdown call has to be asynchronous to work but if "awaited" will hang up the main
  // process. At the same time, the only class method without args (`Processor.start`) is async
  // and has to be awaited. This wrapper exits to avoid confusion, you can await `Processor.kill`
  // without hanging up the main process (just like `Processor.start`) - it calls the actual
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
    if (awaitCompletion) {
      while (_inOutDelta != 0) {
        await Future.delayed(Duration(milliseconds: 250));
      }
    }

    _outputPort.close();
    _streamControl.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  // =====================================
  // === Essential Background Function ===
  // =====================================

  /// the function that is run within the isolate, handles the comms. setup
  ///
  /// `setupList` must contain exactly 3 elements in the following order:
  ///   - `Function` to be run
  ///   - `SendPort` (to send outputs to main)
  ///   - `SendPort` (throw-away port to share an inputPort)
  ///
  static void _syncFunctionRunner(List setupList) {
    // get the function to be run, comms. ports
    var function = setupList[0] as Function;
    var outputPort = setupList[1] as SendPort;
    var setupPort = setupList[2] as SendPort;

    // send a port to main so as to receive inputs
    var inputPort = ReceivePort();
    setupPort.send(inputPort.sendPort);

    // start a micro-task queue
    inputPort.listen((input) {
      var output = function(input);
      outputPort.send(output);
    });
  }

  /// the function that is run within the isolate, handles the comms. setup
  ///
  /// `setupList` must contain exactly 3 elements in the following order:
  ///   - `Function` to be run
  ///   - `SendPort` (to send outputs to main)
  ///   - `SendPort` (throw-away port to share an inputPort)
  ///
  /// Note:
  /// - The only difference from `_syncFunctionRunner` is that function output is awaited
  ///
  static void _asyncFunctionRunner(List setupList) {
    // get the function to be run, comms. ports
    var function = setupList[0] as Function;
    var outputPort = setupList[1] as SendPort;
    var setupPort = setupList[2] as SendPort;

    // send a port to main so as to receive inputs
    var inputPort = ReceivePort();
    setupPort.send(inputPort.sendPort);

    // start a micro-task queue
    inputPort.listen((input) async {
      var output = await function(input);
      outputPort.send(output);
    });
  }
}
