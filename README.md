# Parallelism: Concurrency made simple

> ⚠️ All relevant documentation is built into the source code, generate docs with dartdoc for
> ? comprehensive documentation. Or, view documentation on
> [Github](https://velia-vito.github.io/parallelism/parallelize/) or
> [Pub.dev](https://pub.dev/documentation/parallelize/latest/parallelize/)

```ps
dart doc --output docs
```

## Misc Coding Conventions

### Documentation

1. All documentation goes in the dart documentation comments.

1. Library level documentation must provide an overview explanation of how it's constituent
classes/methods work. __*All of them.*__ This is primarily aimed at future developers, not package
users.

   Also note the following in Library level documentation:

   - Necessary background knowledge (explanation or links.)

   - Design Rationale behind major design choices.

   - Naming Conventions, so consistency is maintained over all modifications.

   - Comparative outlines of similar classes with different purposes/performance considerations.

   - Other Misc Technical details of note.

1. Class documentation should include a usage example. Keep the example under 10 lines.

1. Documentation for all public interfaces. Use this format:

   ```markdown
   One line description of what the method/class/thing does
   
   <!-- Add only if the arguments aren't self-descriptive -->
   <!-- Add for all generics -->
   | Args / Generics | Description  |
   | --------------- | ------------ |
   | `argumentName`  | What it does |
 
   ### Exceptions <!-- Add this section if there are uncaught Exceptions/Errors -->
   - `ExceptionName`: Cause(s) for this exception.
 
   ### Note <!-- Add this section where you want to highlight something specific -->
   - Bullet point everything except the one line description.
 
   - You can highlight anything from the a quirk of the internal logic of this function to a random
   fact related to this function
   ```

### Variable Naming

1. Don't ignore return values even if you are not using them, use dummy variables (`_`, `__`,
  basically any number of underscores) to handle them

### Library Structuring

1. Keep file sizes small. Break up large 'design chunks' (eg. color) into smaller
  [mini-libraries](https://dart.dev/guides/libraries/create-packages#organizing-a-package:~:text=Packages%20are%20easiest%20to%20maintain%2C%20extend%2C%20and%20test%20when%20you%20create%20small%2C%20individual%20libraries%2C%20referred%20to%20as%20mini%20libraries)
  (eg. color utils, color palette generation, color theme generation).

1. Mini-libraries are to be collected into a single library (eg. color.dart) using the
  [`export/show` directives](https://dart.dev/guides/libraries/create-packages#organizing-a-package:~:text=export%20%27src/cascade.dart%27%20show%20Cascade%3B%0Aexport%20%27src/handler.dart%27%20show%20Handler%3B%0Aexport%20%27src/hijack_exception.dart%27%20show%20HijackException%3B%0Aexport%20%27src/middleware.dart%27%20show%20Middleware%2C%20createMiddleware%3B).

### Related Reading

- The library-level api documentation:
  [Github](https://velia-vito.github.io/parallelism/parallelize/) |
  [Pub.dev](https://pub.dev/documentation/parallelize/latest/parallelize/)

- [How Isolates Work, Dart Developer Documentation](https://dart.dev/language/concurrency#how-isolates-work)

- [Is Dart multi-threaded?, Martin Fink](https://martin-robert-fink.medium.com/dart-is-indeed-multi-threaded-94e75f66aa1e)

- [Dart Isolates: What, Why, and How!, Hardik Mehta](https://medium.com/mobilepeople/dart-isolates-what-why-and-how-d390717b64b4)

- [MultiThreading is Flutter, Mohit Joshi](https://medium.flutterdevs.com/multithreading-in-flutter-aa07e2ae2971)
