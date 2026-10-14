import 'dart:ffi';

import 'native/bindings.g.dart';

/// Box2D in this process: whether its native library is in the build.
///
/// The bindings (`package:just_box_2d/ffi.dart`) are `@Native` functions that
/// resolve through the code asset the build hook bundles, by asset id, on
/// every platform. A function is looked up the first time it is called, so a
/// library that is missing, or older than the bindings, would otherwise
/// fail at the first call to a missing function — mid-game. The first
/// question asked here resolves a set of symbols up front instead, and
/// reports the answer.
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

  /// Whether the native library is in the build and matches the bindings.
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
      for (final symbol in _symbols) {
        symbol();
      }
    } on Object catch (error) {
      return 'the just_box_2d native library is not in this build (an app '
          'turns it off with `build: false` under `hooks: user_defines: '
          'just_box_2d:` in its pubspec.yaml) ($error)';
    }
    return null;
  }

  /// The original surface is covered by the finalizers; the rest are the
  /// functions added since, so a library older than the bindings is caught.
  static final List<Pointer<NativeType> Function()> _symbols = [
    () => addresses.b2w_finalizer_world,
    () => addresses.b2w_finalizer_body,
    () => addresses.b2w_version,
    () => addresses.b2w_createBody,
    () => addresses.b2w_setBodyTransform,
    () => addresses.b2w_setBodyType,
    () => addresses.b2w_getBodyType,
    () => addresses.b2w_setBodyOneWay,
    () => addresses.b2w_castRayClosest,
    () => addresses.b2w_castRayAll,
    () => addresses.b2w_queryAABB,
    () => addresses.b2w_setBodyFilter64,
    () => addresses.b2w_setBodyFriction,
    () => addresses.b2w_setBodyRestitution,
    () => addresses.b2w_setBodyLinearDamping,
    () => addresses.b2w_setBodyAngularDamping,
    () => addresses.b2w_setBodySleepEnabled,
    () => addresses.b2w_moverCollide,
    () => addresses.b2w_moverCast,
  ];
}
