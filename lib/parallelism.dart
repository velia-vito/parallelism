/// ### Usage
///
/// The [Process] class is meant for repeated tasks that could slow down the
/// main program. Note that the example doesn't reflect that.
///
/// ```dart
/// import 'dart:io';
/// import 'package:parallelism/parallelism.dart';
///
/// void main(List<String> args) async {
///   // top directory for test
///   final topDir = Directory(r'A:\\Code');
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
///   final lastSubDir = (await topDir.list().toList()).whereType<Directory>().lastWhere((element) {
///     try {
///       return element.listSync().whereType<File>().length > 10;
///     } catch (e) {
///       return false;
///     }
///   });
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
///   // send a directory to the process
///   process.send(firstSubDir);
///
///   // NOTE: `kill` will end the process after all current inputs are processed,
///   // a.k.a no new inputs are accepted. use `forceKill` to end it instantly
///   process.kill();
///
///   // Do the same path listing here, so you can clearly differentiate which is
///   // done in the process and what is done in the main program
///   for (var filePath
///       in (await lastSubDir.list().toList()).whereType<File>().map((e) => e.path).toList()) {
///     print('main: $filePath');
///   }
/// }
///
/// ```
///
/// ### Design Considerations:
///
/// Setting up long-running [Isolate]s with all of four Send/Receive Ports is a
/// pain. We get that 'Handshake' done for you. Similarly, the data returned by
/// the Isolate being typed as dynamic  is also annoying, we go ahead and deal
/// with that too. We also make a few assumptions regarding the workloads you
/// offload on these [Process]es (name chosen because its the best analog I
/// could come up with):
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
import 'dart:isolate';
import 'dart:io';

part 'process/receive_port_mod.dart';
part 'process/process.dart';
part 'process/process_group.dart';
