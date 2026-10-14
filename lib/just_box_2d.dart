/// Box2D (v3.2) for Dart.
///
/// [Box2D] says whether the native library is in the build. The bindings
/// themselves — just_box_2d's C layer (`b2w_*`: worlds on a thread pool,
/// checked handles, batched reads, events, queries, character-mover queries,
/// one-way platforms, joints) — are in `package:just_box_2d/ffi.dart`, for
/// native platforms.
///
/// The library is compiled from source by the package's build hook, on every
/// native platform, unless the app turns it off in its own pubspec:
///
/// ```yaml
/// hooks:
///   user_defines:
///     just_box_2d:
///       build: false
/// ```
///
/// On the web [Box2D.isAvailable] is false.
library;

export 'src/box2d_loader.dart'
    if (dart.library.js_interop) 'src/box2d_loader_stub.dart';
