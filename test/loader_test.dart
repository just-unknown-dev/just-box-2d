// Box2D: the native library is in this package's own build (the hook builds
// it unless an app turns it off), found by its asset id, and reports its
// version.

@TestOn('vm')
library;

import 'dart:io';

import 'package:just_box_2d/ffi.dart';
import 'package:test/test.dart';

void main() {
  test('is available, and says so again', () {
    expect(Box2D.unavailableReason, isNull);
    expect(Box2D.isAvailable, isTrue);
    expect(Box2D.isAvailable, isTrue);
    Box2D.ensureAvailable();
  });

  test('is Box2D 3.2.0', () {
    expect(Box2D.version, '3.2.0');
  });

  test('the bindings resolve through the asset, never a file name', () {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      expect(
        file.readAsStringSync().contains('DynamicLibrary.open'),
        isFalse,
        reason: '${file.path} opens a library by name',
      );
    }
    expect(
      File('lib/src/native/bindings.g.dart').readAsStringSync(),
      contains("@ffi.DefaultAsset('package:just_box_2d/just_box_2d')"),
    );
  });

  test('a world steps and a body falls', () {
    final world = b2w_createWorld(0, 981, 1);
    expect(world, isNot(0));
    final body = b2w_createDynamicBody(world, 0, 0, 0);
    expect(body, isNot(0));
    b2w_addBoxShape(body, 8, 8, 1, 0.5, 0);
    for (var i = 0; i < 30; i++) {
      b2w_step(world, 1 / 60, 4);
    }
    expect(b2w_getBodyType(body), 2, reason: 'a live dynamic body');
    b2w_destroyWorld(world);
  });
}
