// The web, compiled to JavaScript or to WebAssembly: there is no dart:ffi, so
// package:just_box_2d/just_box_2d.dart exports the stub, and Box2D says it
// cannot run instead of throwing. Run with `dart test -p chrome
// test/web_test.dart` (add `--compiler dart2wasm` for WebAssembly).

@TestOn('browser')
library;

import 'package:just_box_2d/just_box_2d.dart';
import 'package:test/test.dart';

void main() {
  test('Box2D says why it cannot run', () {
    expect(Box2D.unavailableReason, contains('dart:ffi'));
    expect(Box2D.isAvailable, isFalse);
    expect(Box2D.version, isNull);
    expect(Box2D.ensureAvailable, throwsStateError);
  });
}
