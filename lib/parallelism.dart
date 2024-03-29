/// Parallelism simplified.
///
/// ### Usage
///
/// The [Process] class is for long drawn (compute or waiting-bound), __*low
/// repetition*__, CPU-bound tasks. Note that the example doesn't reflect that.
/// The fact that no-isolate dart also, seems to put load across multiple
/// processors, means that using a [Process]es or [ProcessGroup]s in anything
/// other than waiting-bound situations is extremely finicky and should be
/// decided based of time-based tests.
///
/// ```dart
/// import 'dart:io';
/// import 'package:parallelism/parallelism.dart';
///
/// void main(List<String> args) async {
///   // top directory for test
///   final topDir = Directory(r'A:\\Code');
///
///   // ===============
///   // === Process ===
///   // ===============
///
///   // setup up a process to list and return all file paths in the given directory
///   var process = Process<List<String>, Directory>(
///     processLoop: (dir) async {
///       return (await dir.list().toList()).whereType<File>().map((e) => e.path).toList();
///     },
///   );
///
///   // Start the process and setup a listener to process the file paths that
///   // returned
///   var filePathListStream = await process.start();
///   var _ = filePathListStream.listen((filePaths) {
///     for (var path in filePaths) {
///       print('proc: $path');
///     }
///   });
///
///   // find sub-directories that contain files and can be accessed without a Permission errors
///   final firstSubDir = (await topDir.list().toList()).whereType<Directory>().firstWhere((element) {
///     try {
///       return element.listSync().whereType<File>().length > 10;
///     } catch (e) {
///       return false;
///     }
///   });
///
///   // send the directory to the process
///   process.send(firstSubDir);
///
///   // NOTE: `kill` will end the process after all current inputs are processed,
///   // a.k.a no new inputs are accepted. use `forceKill` to end it instantly
///   process.kill();
///
///   // ====================
///   // === Main Program ===
///   // ====================
///
///   // Do the same path listing here, but for a different directory, so you
///   // can clearly differentiate which is done in the process and what is done
///   // in the main program
///   final lastSubDir = (await topDir.list().toList()).whereType<Directory>().lastWhere((element) {
///     try {
///       return element.listSync().whereType<File>().length > 10;
///     } catch (e) {
///       return false;
///     }
///   });
///
///   for (var filePath
///       in (await lastSubDir.list().toList()).whereType<File>().map((e) => e.path).toList()) {
///     print('main: $filePath');
///   }
/// }
///
/// ```
///
/// The [ProcessGroup] class is for long drawn (compute or waiting-bound),
/// __*high repetition*__, CPU-bound tasks. Please note that, the moment you
/// hit a RAM bottleneck, performance drops faster than yak off a cliff. There
/// is also time loss during setup.
///
/// ```dart
/// import 'package:parallelism/parallelism.dart';
///
/// // Test Results over 48 cycles, more the cycles, more the time delta
/// // - 02:18.854134s on 01 threads
/// // - 01:36.916452s on 04 threads
/// // - 05:48.823434s on 08 threads (ram bottleneck)
///
/// void main(List<String> args) async {
///   // start time
///   var sTime = DateTime.now();
///
///   // ====================
///   // === ProcessGroup ===
///   // ====================
///   // compute fibonacci sequence up to n = 50000000
///   var fibProcGroup = ProcessGroup<List<int>, int>(
///     processLoop: (n) async {
///       var fibList = <int>[];
///
///       var cur = 1;
///       var lst = 0;
///       var tmp = 0;
///
///       for (var i = 0; i < 50000000; i++) {
///         fibList.add(cur);
///
///         tmp = cur;
///         cur += lst;
///         lst = tmp;
///       }
///
///       return fibList;
///     },
///     processCount: 4,
///   );
///
///   // ====================
///   // === Main Program ===
///   // ====================
///
///   // start the `ProcessGroup`, print time-delta from program start time for
///   // each return from the `ProcessGroup`
///   var stream = await fibProcGroup.start();
///   var _ = stream.listen((fibList) {
///     print('Current Delta: ${DateTime.now().difference(sTime)} up to ${fibList.length}');
///   });
///
///   // run the same memory-heavy fibonacci computation 48 times
///   for (var i = 0; i < 48; i++) {
///     fibProcGroup.send(i);
///   }
///
///   fibProcGroup.kill();
/// }
/// ```
///
/// The [ProcessingLine] class for for when you have a multi-step workload where
/// it does not make sense to expend equal compute resources on each step. Eg.
/// You're trying to download a comic, you could have just 2 [Process]es for
/// requesting the links to the page images and then have a 6-process
/// [ProcessGroup] to download those pages.
///
/// ```dart
/// import 'dart:math';
///
/// import 'package:parallelism/parallelism.dart';
///
/// void main(List<String> args) async {
///   const chars = 'AaBbCcDdEe FfGgHhIiJj KkLlMmNnOo PpQqRrSsTt UuVvWwXxYy Zz12345678 90';
///   Random randomEngine = Random();
///
///   // ===============
///   // === Process ===
///   // ===============
///
///   // generate random paragraph lengths
///   var numSetProc = Process(
///     processLoop: (int paragraphCount) async {
///       var paragraphLengthSpec = <int>[];
///
///       for (var i = 0; i < paragraphCount; i++) {
///         paragraphLengthSpec.add(randomEngine.nextInt(20) * 50);
///       }
///
///       // This is why ProcessingLine's addStation methods need to be re-written
///       return paragraphLengthSpec;
///     },
///   );
///
///   // ====================
///   // === ProcessGroup ===
///   // ====================
///
///   // generate paragraphs
///   var paraGenProcGrp = ProcessGroup(
///     processLoop: (List<int> paraSpec) async {
///       var masterText = '';
///
///       for (var length in paraSpec) {
///         var paraString = String.fromCharCodes(
///           Iterable.generate(
///             length,
///             (_) => chars.codeUnitAt(randomEngine.nextInt(chars.length)),
///           ),
///         );
///
///         masterText += '$paraString\n\n';
///       }
///
///       return masterText;
///     },
///   );
///
///   // ===================
///   // === ProcessLine ===
///   // ===================
///
///   // Setup ProcessingLine
///   var procLine = ProcessingLine<String, int>();
///   procLine.addStation(numSetProc);
///   procLine.addStation(paraGenProcGrp);
///
///   var _ = await procLine.start();
///
///   // ====================
///   // === Main Program ===
///   // ====================
///
///   var __ = procLine.stream.listen((data) {
///     print(data);
///   });
///
///   // Send data for processing
///   for (var i = 0; i < 10; i++) {
///     procLine.send(randomEngine.nextInt(10));
///   }
///
///   procLine.kill();
/// }
/// ```
///
/// ### Design Considerations:
///
/// 1. They all compute something, or at the very least, send back signals to
/// the main process, A.K.A they're not `void Function(args)`. This is because
/// void-functions usually aren't heavy enough to justify offloading onto a
/// different process.
///
/// 2. They all have a single distinct output type. If a process has to return
/// different data-types, it's more of a sub-program than a compute-heavy
/// function/sub-routine.
///
/// 3. The function being run as a separate process is asynchronous. It takes
/// async code to create [Isolate]s, so it kinda feels like 'bells and whistles'
/// to support sync code in addition to async code, especially when it's not
/// that hard to wrap up a sync function inside another to make it an async
/// function.
///
/// What effects do these assumptions result in? Not much, except for `null`
/// being used as a kill-signal on grounds of (1).
///
/// ### Dev Considerations
///
/// - `Main` refers to the 'main/parent' program. and `Proc` refers to the any
/// of the spawned isolates. This indicates 'ownership.' So, `mainRecvPort`
/// would mean the port via which the main isolate obtains information, and
/// `procSendPort` would be the port via which to send information to the
/// process.
///
/// - The *generics* `O` and `I` refer to Output and Input types respectively.
///
/// - There is also the matter of class interfaces with a mix of sync and async
/// methods. Instead of maintaining uniformity, we defer to
/// [effective dart guidelines on the `async` keyword](https://dart.dev/effective-dart/usage#dont-use-async-when-it-has-no-useful-effect).
///
/// ### External Resources
///
/// - [`await for` vs `Stream.listen`, StackOverflow](https://stackoverflow.com/a/42613676),
/// helps understand what to use, when to use, and why it is used.
///
/// - [Generics, Dart.dev > Docs > language > types](https://dart.dev/language/generics)
library;

// Dart imports:
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

// Support/Meta/Internal Parts:
part 'src/parallelization_interface.dart';
part 'src/receive_port_mod.dart';

// Exposed Parts:
part 'src/process.dart';
part 'src/process_group.dart';
part 'src/processing_line.dart';
