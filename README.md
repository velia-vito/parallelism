# Parallelism: Concurrency made simple

(⚠️ Most of the relevant documentation is built into the source code, generate docs with dartdoc for
comprehensive documentation.)

While concurrency is comparatively less hairy in dart/flutter, writing code to leverage concurrency
is still not as simple as it could be. This package aims to change that.

## Primary Features

1. Setting up long-running `Isolate`s with all of four Send/Receive Ports is a pain. We get that
   'Handshake' done for you.

2. Similarly, the data returned by the Isolate being typed as dynamic is also annoying, we go ahead
   and deal with that too. So, now you don't have to deal with finicky type-casting inputs across
   your background tasks.

## Code Conventions

- Library level design & developers documentation—an explanation of why things ended up the way they
  are. Code conventions and comparative outlines of feature sets and other technical details are
  added here too. Design considerations first and developer considerations next.

- Documentation for all public interfaces. Use this format:

  ```markdown
  One line description of what the method/class/thing does

  ### Args <!-- Add this sections if any of the argument names are open to interpretation -->
  - `argName`: Description of what this argument is.

  ### Exceptions <!-- Add this section if there are uncaught Exceptions/Errors -->
  - `ExceptionName`: Cause(s) for this exception.

  ### Note <!-- Add this section where you want to highlight something specific -->
  - Bullet point everything except the one line description.

  - You can highlight anything from the a quirk of the internal logic of this function to a random
  fact related to this function
  ```

- Use descriptive variable names.

- Don't ignore return values even if you are not using them, use dummy variables (`_`, `__`,
  basically any number of underscores) to handle them

- Keep file sizes small. Break up large 'design chunks' (eg. color) into smaller
  [mini-libraries](https://dart.dev/guides/libraries/create-packages#organizing-a-package:~:text=Packages%20are%20easiest%20to%20maintain%2C%20extend%2C%20and%20test%20when%20you%20create%20small%2C%20individual%20libraries%2C%20referred%20to%20as%20mini%20libraries)
  (eg. color utils, color palette generation, color theme generation). Mark the mini-libraries
  `/// {@nodoc}` (case sensitive).

- Mini-libraries are to be collected into a single library (eg. color.dart) using the
  [`export/show` directives](https://dart.dev/guides/libraries/create-packages#organizing-a-package:~:text=export%20%27src/cascade.dart%27%20show%20Cascade%3B%0Aexport%20%27src/handler.dart%27%20show%20Handler%3B%0Aexport%20%27src/hijack_exception.dart%27%20show%20HijackException%3B%0Aexport%20%27src/middleware.dart%27%20show%20Middleware%2C%20createMiddleware%3B).

## External Resources

- [Is Dart multi-threaded?, Martin Fink](https://martin-robert-fink.medium.com/dart-is-indeed-multi-threaded-94e75f66aa1e)

- [How Isolates Work, Dart Developer Documentation](https://dart.dev/language/concurrency#how-isolates-work)

- [Dart Isolates: What, Why, and How!, Hardik Mehta](https://medium.com/mobilepeople/dart-isolates-what-why-and-how-d390717b64b4)

- [MultiThreading is Flutter, Mohit Joshi](https://medium.flutterdevs.com/multithreading-in-flutter-aa07e2ae2971)
