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

part 'process/process.dart';
