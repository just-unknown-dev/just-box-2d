/// Box2D where there is no `dart:ffi` (the web): never available.
abstract final class Box2D {
  /// Why Box2D cannot be used here.
  static String? get unavailableReason =>
      'Box2D needs dart:ffi, which the web does not have.';

  /// Always false here.
  static bool get isAvailable => false;

  /// Always null here.
  static String? get version => null;

  /// Always throws a [StateError] here.
  static void ensureAvailable() =>
      throw StateError('Box2D is not available: $unavailableReason');
}
