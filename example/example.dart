// A ball dropped on a floor, through just_box_2d's C layer.
//
// From this package's folder: `dart run example/example.dart`.
//
// Units are the layer's: 100 to a metre, +Y down (981 is Earth's gravity).

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:just_box_2d/ffi.dart';

void main() {
  final reason = Box2D.unavailableReason;
  if (reason != null) {
    print('Box2D cannot run: $reason');
    return;
  }
  print('Box2D ${Box2D.version}');

  // A world on one worker thread.
  final world = b2w_createWorld(0, 981, 1);

  // A floor 6 m wide, its top at y = 0.
  final floor = b2w_createStaticBody(world, 0, 20, 0);
  b2w_addBoxShape(floor, 300, 20, 1, 0.6, 0);

  // A ball 2 m up.
  final ball = b2w_createDynamicBody(world, 0, -200, 0);
  b2w_addCircleShape(ball, 0, 0, 10, 1, 0.6, 0.3);

  // Read it back after each second: x, y, angle, vx, vy, awake, spin.
  using((Arena arena) {
    final handles = arena<Int64>()..value = ball;
    final pose = arena<Float>(7);
    for (var second = 1; second <= 3; second++) {
      for (var i = 0; i < 60; i++) {
        b2w_step(world, 1 / 60, 4);
      }
      b2w_bulkExtractTransforms(handles, pose, 1);
      print(
        'after ${second}s: y = ${pose[1].toStringAsFixed(1)}, '
        'vy = ${pose[4].toStringAsFixed(1)}, awake = ${pose[5] == 1}',
      );
    }
  });

  // Destroying the world destroys its bodies.
  b2w_destroyWorld(world);
}
