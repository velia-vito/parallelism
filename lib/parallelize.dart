/// Run Code in parallel without having to worry about low-level [Isolate] details.
///
/// ## Background
///
/// ### Multi-threading vs. Multi-processing
///
/// Imagine your code as one long string, this string has knots on it that you have to untangle,
/// you have to paint the untangled sections red. The string is your logic-flow, and the knots are
/// things you have to wait for (e.g a network request or reading a file from your OS or waiting for
/// a specified amount of time,) and the painting the untangled string is further processing after
/// the waiting for data.
///
/// In single-threaded processing, you move down the thread till the first knot, stop till your
/// friend untangles it, you paint it, then you move till the next knot, wait for your friend to
/// untangle it, then you paint it and so on. You spend a significant amount of time waiting.
///
/// In multi-threading, you move down to the first knot, hand it off to your friend and instead of
/// waiting, you move on down to the next knot, pass it to your friend (irrespective of weather he
/// has untangled the first one or not) and continue moving down the string and handing off new
/// knots. When  your friend untangles the first knot,  you pause your hunt for the next knot, and
/// go paint the freshly returned untangled section while he untangles the next knot you sent him.
/// You go back to finding the next knot till he's done with the second knot. Here a good chunk of
/// the waiting time from your earlier single-threaded system is actually utilized doing searching
/// for the next knot instead of simply idling. More work is getting done in lesser time. The more
/// waiting time your single-threaded process takes, the more time multi-threading will save.
///
/// In parallel process, it's not just you working on a single string while waiting for your friend
/// to untangle knots. You either have 16 people and their friends working on 16 different strings
/// or you have 16 people and their friends working on 16 different sections of the same string
/// *_all at same time_* i.e you're doing 16x the work in the same time, or the same work in 1/16th
/// of the time. THe key part is that there are 16 people and their friends here.
///
/// If multi-threading is about reducing wait times. Multi-processing is about increasing the number
/// of workers. It's not optimizing, it's brute-forcing.
///
/// ### Isolates 101
///
/// Most low level languages and quiet a few high level languages have multi-processing
/// capabilities, but how it works in Dart and other languages have one major difference.
///
/// In other languages, each separate process (each worker) has a shared context i.e resources are
/// shared like different artisans in a workshop with only one CNC Machine or 3D Printer. If an
/// artisan need to use the 3D printer but but someone else has already started printing a part. He
/// will either have to wait, cancel the other printing task, or his attempts to print his part
/// before the other person's printing task is done and will mess up both peoples work. To prevent
/// the last situation (which usually means memory overruns, corrupted data, and [data race
/// conditions](https://en.wikipedia.org/wiki/Race_condition),) you need to implement a *global
/// lock* that ensure that only one process can access those shared resources at any given time.
/// This is both finicky and and a pain in the ass.
///
/// In dart, there are no shared resources. If you create an object that takes up a lot of memory
/// and you need all your processes to have access to it, you either create a dozen copies of it an
/// fill up the OS memory, or you create some other alternative way to access just the relevant
/// parts of the data without loading the whole thing into memory. Same goes for computationally
/// heavy to create objects, like say, a hash map.
///
/// But, on the flip side, you don't have to worry about a *global lock*, race conditions that
/// permanently brick your program, or unexplained crashes. This also means that individual
/// processes do not have to wait on resources. It's a much more robust and efficient system if more
/// resource heavy. So, keep that in mind when you write code for prallelization.
///
/// ### Futures are not deferred data
///
/// When you get  get a [Future] object, you're not getting a container that will be filled with
/// data later. You're getting a *promise* that the data will be available at some point in the
/// future. A future "completes" when the promise is upheld and the data is either sent for further
/// processing (when you use [Future.then]) or when you `await`.
///
/// This means that you really need to know what promise any returned future represents. For
/// example, if you write a `Future<void> sendTenRequests()` function that sends 10 network requests
/// (with no custom [Completer]), the default returned future from the function will complete when
/// the 10 requests are sent, and because the requests are part of the local scope, you now have not
/// way to wait till the sever responds to the requests outside of the function. The person calling
/// this function may not be aware of the difference and assume that awaiting `sendTenRequests` will
/// ensure that the server has responded to all 10 requests, which is not the case.
///
/// ### Microtasks vs. Events
///
/// Your program is split into *Events* (or tasks, which ever you want to call them) — chunks of
/// code to be executed on particular triggers. Even a "purely sequential" program can be split up
/// into tasks that require waiting in between. Consider the simple task of writing data to console,
///  this requires waiting for your OS to provide you  access to the output sink, and hence the
/// logic before would be split into one event and the logic after into a separate event triggered
/// by obtaining access to the standard output sink.
///
/// The very first task on the "Event Queue" is to start the execution of the `main` function. This
/// event queue is sequential, but some tasks are extremely important and have to be handled on a
/// high priority basis. Dart uses a separate first-in-first-out event queue called the "Microtask
/// Queue".
///
/// Events on the microtask queue are given greater priority than events in the event queue i.e the
/// event queue processing is always put on hold until the microtask queue is empty.
///
/// When you run an async function with [Future.then] to handle the returned value, the callback in
/// internally registered within the Future, and whenever the future completes, the callback is
/// added to the microtask queue. What this means is that there is a gap between triggering the
/// future and the callback being added to the microtask queue. A gap during which the program may
/// exit. On using `await`, much the same happens, but the rest of the logic after the `await` is
/// registered as the callback and added to the microtask queue.
///
/// Why is this important? One, avoid using `await` as much as possible. The point of
/// multi-threading is to reduce waiting time, and `await` adding all the subsequent logic to the
/// microtask queue means that the program will simply stop and wait for a response before doing the
/// rest of the logic. It will still save you time if you're doing separate tasks (e.g downloading a
/// file and writing a completely different file to disk,) but otherwise it might as well be purely
/// sequential. Using `Future.then` is better as it only adds the callback to the microtask queue
/// and continues program execution. While there is much to gain from using `then` it requires you
/// to be aware of what exactly is being tracked by the returned future i.e as long as you ensure
/// that the future *completes*, you can be assured that the post-processing will be done.
///
/// Example pf the differences in `await` vs. `then` can be seen at
/// [avtfuture.dart](https://github.com/velia-vito/utils/blob/main/bin/avtfuture.dart)) with some
/// minimal explanation.
///
/// ## Design Overview
///
/// Isolates are basically separate programs that run in parallel to the main program due to the
/// lack of a shared context. This, coupled with the process for creation of a new isolate means
/// that you can essentially think of it as one big function that run on a different processor.
///
/// This means that something like creating a persistent HTTP client for downloading multiple files
/// whose links will be provided at different points in time is not possible. You'd simply create
/// a new HTTP client for each "call" to the isolate, which is inefficient.
///
/// This is handled internally by the library. A custom loop is created for the main function:
/// `setupProcess` -> `processInput` (repeatedly) -> `shutdownProcess`. The logic is in the users
/// control, and they are the ones who code all three callbacks, but the actual code run in the
/// isolate is pre-defined in the library.
///
/// ### [Process.setupProcess] & `CR`
/// Used to create any persistent objects/resources that will be reused across all processing done
/// within the isolate. Since Dart doesn't support arbitrary length arguments, all generated
/// resources need to be bundled into a single [Record](https://dart.dev/language/records). This
/// record is generically typed as `CR` for *Common Resources*.
///
/// ```dart
/// // Creating a "record" with field names.
/// var commonResources = (id: 10, name: 'Example', client: httpClient);
/// ```
///
/// ### [Process.processInput]
///
/// Take an input & the common resources, process the input and return a result. The library
/// automatically handles the passing of the output back to the main isolate. This usually requires
/// unpacking of the `CR` record.
///
/// ```dart
/// // Full unpacking of a record.
/// var (id, name, client) = commonResources;
///
/// // field access of a record.
/// var client = commonResources.client;
/// ```
///
/// ### [Process.shutdownProcess]
///
/// Takes the Common Resources and cleans them up if necessary.
///
/// ### [Process.processingIsComplete]
///
/// Both are internal [Completer] that only completes when all the sent inputs have been processed.
/// This is done by assigning a `inputID` to each input, and then logging the input under
/// "unprocessed inputs". When the isolate finishes processing the input, it send back the output
/// with the related `inputID`. We need to do this as there is no shared context for the isolate to
/// update the main isolate about the progress of anything.
///
/// When a call is made to [Process.shutdownOnCompletion], the isolate is marked as "close for new
/// inputs" (or inactive)., the `processingIsComplete` future completes only when all inputs in the
/// "unprocessed inputs" list have been processed and the isolate is closed for further inputs. It
/// essentially tracks overall completion of all futures, so that the user does't have to.
///
/// ### Misc Notes
///
/// - The words `Process` and `Isolate` are used interchangeably in this library.
library;

// Dart imports:
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

part 'interface/parallelization_interface.dart';

part 'core/process.dart';

part 'utils/process_group.dart';
part 'utils/process_workflow.dart';