/// Run Code in parallel without having to worry about low-level [Isolate] details.
///
/// ## Overview
///
/// The library is built around [ParallelizationInterface], the most fundamental implementation of
/// which is the [Process] class. Both the [ProcessGroup] and [ProcessWorkflow] classes are simply
/// utility wrappers around the `Process` class.
///
/// ### Conceptual Notes
///
/// 1. `Processing Loop`: A `Process` runs a single callback, [Process.processInput] every time it
/// is presented with a fresh input. This is the *Processing Loop* (called as such because the same
/// method is called back repeatedly for each input).
///
/// 2. `Setup`: Let's say you're running a process to download multiple files in
/// parallel to the main isolate. You have two options: (a) create a new HTTP client for each file
/// download (inefficient due to overhead), or (b) create a single HTTP client and reuse it for all
/// file downloads (much more efficient). The `Processing Loop` is not capable of variable
/// persistence, so, such persistent variables have to be created outside of the `Processing Loop`.
/// This is done before the `Processing Loop` starts by the [Process.setupProcess] callback.
///
/// 3. `Common Resource Record`: Let's say that your `Processing Loop` requires multiple common
/// resources. Unlike Python, Dart doesn't allow arbitrary length arguments. So, how do you pass
/// such a variable length list of common resources while maintaining type safety? We do so by
/// bundling all common resources into a single [Record](https://dart.dev/language/records). As you
/// are aware of the Record's structure, you can easily destructure it to access individual `Common
/// Resources` within the `Processing Loop` and the subsequent `Clean Up`.
///
/// 4. `Clean Up`: After the `Processing Loop` has completed, the `Common Resources` need to be
/// cleaned up to allow proper termination of the application and to prevent other unexpected
/// behaviors. This is done by the [Process.shutdownProcess] callback.
///
/// 5. The overall functioning of any implementation of `ParallelizationInterface` is as follows:
/// `Create Common Resources` -> `Process Input` (repeatedly) -> `Clean Up` -> `TerminateProcess`.
///
/// 6. `Future`: A [Future] is a *promise* of a value. It is important to understand that a `Future`
/// is not the value itself, but a *promise* to deliver the value at some point in the future.
///
/// 7. `Future Completion`: When a `Future` upholds its promise and delivers the value, we call this
/// *delivering of the value* as `Future Completion`. The important part is that a `Future` may
/// *complete* almost immediately as if it were a synchronous function, or it may take a significant
/// amount of time to *complete*.
///
/// 8. `Future.then` vs `await`: `await` is best used when the value of a future is absolutely
/// required for the next step in the program, or when you're using the completion of a future as
/// a *lock* to prevent further execution until some condition is met. `Future.then` is best used
/// when you want to perform some action after the completion of a `Future` that displays
/// significant delay before completion.
///
/// ### Misc Notes
///
/// - The words `Process` and `Isolate` are used interchangeably in this library.
///
/// - All async methods will be marked as follows:
///
///   - `(bg-proc)`: Background Process. Indicates that there is a significant delay between the
///   method returning a `Future` and the `Future` completing. These methods are best handles with
///   [Future.then].
///
///   - `(im-proc)`: Immediate Process. Indicates that the `Future` will complete almost immediately
///   after it is returned. These methods are best handled with `await`.
library;

// Dart imports:
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

part 'interface/parallelization_interface.dart';

part 'core/process.dart';

part 'utils/process_group.dart';
part 'utils/process_workflow.dart';
