import 'native/bindings.g.dart';

/// Box2D in this process: whether its native library is in the build.
///
/// The bindings (`package:just_box_2d/ffi.dart`) are `@Native` functions that
/// resolve through the code asset the build hook bundles, by asset id, on
/// every platform. A function is looked up the first time it is called, so
/// without the library the first call would throw — mid-game. The first
/// question asked here makes one call up front instead, and reports the
/// answer.
abstract final class Box2D {
  static bool _checked = false;
  static String? _reason;

  /// Why Box2D cannot be used here, or null when it can — most often that
  /// the app's pubspec turned the build off (`build: false`).
  static String? get unavailableReason {
    if (!_checked) {
      _checked = true;
      _reason = _probe();
    }
    return _reason;
  }

  /// Whether the native library is in the build.
  static bool get isAvailable => unavailableReason == null;

  /// Box2D's version, `major.minor.revision`; null when it is not available.
  static String? get version {
    if (!isAvailable) return null;
    final v = b2w_version();
    return '${v >> 16}.${(v >> 8) & 0xFF}.${v & 0xFF}';
  }

  /// Throws a [StateError] saying why when Box2D is not available.
  static void ensureAvailable() {
    final reason = unavailableReason;
    if (reason != null) throw StateError('Box2D is not available: $reason');
  }

  static String? _probe() {
    try {
      b2w_version();
    } on Object catch (error) {
      return 'the just_box_2d native library could not be loaded ($error). '
          'The build hook builds it for every native platform unless the '
          "app's pubspec.yaml turns it off with `build: false` under "
          '`hooks: user_defines: just_box_2d:`.';
    }
    return null;
  }
}
