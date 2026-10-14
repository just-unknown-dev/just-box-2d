/// just_box_2d's native API, for native platforms only (it imports
/// `dart:ffi`):
///
/// - [Box2D], to check the library is there before anything else;
/// - the generated bindings to the C layer (`b2w_*`, see
///   `src/b2w/box2d_wrapper.h`), and `addresses` of the finalizers and of
///   the functions [Box2D] checks.
///
/// Handles are int64. Every function accepts a dead one, or one of a world
/// that has gone, and does nothing with it. Use the library from one isolate
/// per process: its worlds belong to the whole process.
library;

export 'src/box2d_loader.dart';
export 'src/native/bindings.g.dart';
