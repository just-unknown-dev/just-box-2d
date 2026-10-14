// The C layer's behaviour, function by function, through the bindings.
//
// Units are the layer's: 100 to a metre, +Y down, 981 is Earth's gravity.
// Most tests stand things on a floor whose top is at y = 0.

@TestOn('vm')
library;

import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:just_box_2d/ffi.dart';
import 'package:test/test.dart';

const _dt = 1 / 60;

/// A world with Earth's gravity, destroyed after the test.
int _world() {
  final world = b2w_createWorld(0, 981, 1);
  addTearDown(() => b2w_destroyWorld(world));
  return world;
}

void _steps(int world, int n) {
  for (var i = 0; i < n; i++) {
    b2w_step(world, _dt, 4);
  }
}

/// A static floor 6 m wide, its top at y = 0.
int _floor(int world) {
  final floor = b2w_createStaticBody(world, 0, 20, 0);
  b2w_addBoxShape(floor, 300, 20, 1, 0.6, 0);
  return floor;
}

/// A dynamic ball of [radius] at (x, y).
int _ball(int world, double x, double y, {double radius = 5}) {
  final ball = b2w_createDynamicBody(world, x, y, 0);
  b2w_addCircleShape(ball, 0, 0, radius, 1, 0.6, 0);
  return ball;
}

typedef _Pose = ({
  double x,
  double y,
  double angle,
  double vx,
  double vy,
  bool awake,
  double spin,
});

_Pose _read(int body) => using((arena) {
  final handles = arena<Int64>()..value = body;
  final b = arena<Float>(7);
  b2w_bulkExtractTransforms(handles, b, 1);
  return (
    x: b[0],
    y: b[1],
    angle: b[2],
    vx: b[3],
    vy: b[4],
    awake: b[5] == 1,
    spin: b[6],
  );
});

double _distance(int a, int b) {
  final pa = _read(a), pb = _read(b);
  return math.sqrt(math.pow(pb.x - pa.x, 2) + math.pow(pb.y - pa.y, 2));
}

void main() {
  setUpAll(Box2D.ensureAvailable);

  group('distance joint', () {
    test('a rope is free inside its range and stops at its end', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 0, 50);
      expect(b2w_createDistanceJoint(world, anchor, ball, 20, 100), isNot(0));
      _steps(world, 120);
      expect(_distance(anchor, ball), closeTo(100, 1.5));
    });

    test('equal lengths make a rigid rod', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 50, 0); // a pendulum, level with its pivot
      b2w_createDistanceJoint(world, anchor, ball, 50, 50);
      for (var i = 0; i < 120; i++) {
        _steps(world, 1);
        expect(_distance(anchor, ball), closeTo(50, 1), reason: 'step $i');
      }
      expect(_read(ball).y, greaterThan(20), reason: 'it swung down');
    });

    test('a spring stretches, and 0 Hz makes it a rod again', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 0, 50);
      final joint = b2w_createDistanceJoint(world, anchor, ball, 50, 50);
      // 2 Hz: gravity stretches it by about g / (2π·2)² ≈ 6 units at rest.
      b2w_setDistanceSpring(joint, 2, 0.1);
      var longest = 0.0;
      for (var i = 0; i < 120; i++) {
        _steps(world, 1);
        longest = math.max(longest, _distance(anchor, ball));
      }
      expect(longest, greaterThan(54));

      b2w_setDistanceSpring(joint, 0, 0);
      _steps(world, 120);
      expect(_distance(anchor, ball), closeTo(50, 1));
    });

    test('a new range takes effect on a rod', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 0, 50);
      final joint = b2w_createDistanceJoint(world, anchor, ball, 50, 50);
      _steps(world, 60);
      expect(_distance(anchor, ball), closeTo(50, 1));
      b2w_setDistanceLimits(joint, 20, 100);
      _steps(world, 120);
      expect(_distance(anchor, ball), closeTo(100, 1.5));
    });

    test('the reaction force of a hanging rod carries the weight', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 0, 50);
      final joint = b2w_createDistanceJoint(world, anchor, ball, 50, 50);
      _steps(world, 120);
      final weight = math.pi * 5 * 5 * 981; // density 1, radius 5
      using((arena) {
        final fx = arena<Float>(), fy = arena<Float>();
        b2w_getJointReactionForce(joint, fx, fy);
        expect(
          math.sqrt(fx.value * fx.value + fy.value * fy.value),
          closeTo(weight, weight * 0.05),
        );
      });
    });
  });

  group('other joints', () {
    test('a revolute motor turns its body at its speed', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final wheel = _ball(world, 0, 0, radius: 10);
      final joint = b2w_createRevoluteJoint(world, anchor, wheel, 0, 0);
      b2w_setRevoluteMotor(joint, 3, 1e9, 1);
      _steps(world, 30);
      expect(_read(wheel).spin, closeTo(3, 0.01));
      expect(_read(wheel).y, closeTo(0, 0.5), reason: 'pinned');
    });

    test('a prismatic limit stops the slider', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final slider = _ball(world, 0, 0);
      final joint = b2w_createPrismaticJoint(world, anchor, slider, 0, 0, 1, 0);
      b2w_setPrismaticLimits(joint, -10, 10, 1);
      b2w_setLinearVelocity(slider, 500, 0);
      _steps(world, 60);
      final pose = _read(slider);
      expect(pose.x, closeTo(10, 0.5));
      expect(pose.y, closeTo(0, 0.5), reason: 'held on its axis');
    });

    test('a weld holds a body where it was', () {
      final world = _world();
      final anchor = b2w_createStaticBody(world, 0, 0, 0);
      final ball = _ball(world, 30, 0);
      expect(b2w_createWeldJoint(world, anchor, ball, 0, 0), isNot(0));
      _steps(world, 60);
      expect(_read(ball).y, closeTo(0, 1));
    });

    test('a joint is not made between a body and itself', () {
      final world = _world();
      final ball = _ball(world, 0, 0);
      expect(b2w_createDistanceJoint(world, ball, ball, 1, 1), 0);
    });
  });

  group('events', () {
    test('contacts begin and end with their bodies and the normal', () {
      final world = _world();
      final floor = _floor(world);
      final box = b2w_createDynamicBody(world, 0, -50, 0);
      b2w_addBoxShape(box, 10, 10, 1, 0.6, 0);
      var began = false;
      using((arena) {
        final a = arena<Int64>(), b = arena<Int64>();
        final nx = arena<Float>(), ny = arena<Float>();
        for (var s = 0; s < 120 && !began; s++) {
          _steps(world, 1);
          for (var i = 0; i < b2w_getContactBeginCount(world); i++) {
            b2w_getContactBeginEvent(world, i, a, b, nx, ny);
            if ({a.value, b.value}.containsAll([floor, box])) {
              began = true;
              expect(ny.value.abs(), closeTo(1, 1e-3));
            }
          }
        }
        expect(began, isTrue);

        // Lift it off: the contact ends.
        b2w_setBodyTransform(box, 0, -200, 0, 1);
        var ended = false;
        for (var s = 0; s < 5 && !ended; s++) {
          _steps(world, 1);
          for (var i = 0; i < b2w_getContactEndCount(world); i++) {
            b2w_getContactEndEvent(world, i, a, b);
            ended |= {a.value, b.value}.containsAll([floor, box]);
          }
        }
        expect(ended, isTrue);

        // Out of range reads as zeros.
        b2w_getContactBeginEvent(world, 999, a, b, nx, ny);
        expect([a.value, b.value, nx.value, ny.value], [0, 0, 0, 0]);
      });
    });

    test('a sensor reports a ball passing through it', () {
      final world = _world();
      _floor(world);
      final sensor = b2w_createStaticBody(world, 0, -100, 0);
      b2w_setBodySensor(sensor, 1); // before its shapes
      b2w_addBoxShape(sensor, 50, 10, 1, 0.6, 0);
      final ball = _ball(world, 0, -200);
      var entered = false, left = false;
      using((arena) {
        final s = arena<Int64>(), v = arena<Int64>();
        for (var i = 0; i < 120; i++) {
          _steps(world, 1);
          for (var k = 0; k < b2w_getSensorBeginCount(world); k++) {
            b2w_getSensorBeginEvent(world, k, s, v);
            entered |= s.value == sensor && v.value == ball;
          }
          for (var k = 0; k < b2w_getSensorEndCount(world); k++) {
            b2w_getSensorEndEvent(world, k, s, v);
            left |= s.value == sensor && v.value == ball;
          }
        }
      });
      expect(entered, isTrue);
      expect(left, isTrue);
      expect(_read(ball).y, closeTo(-5, 0.6), reason: 'on the floor below');
    });

    test('a sensor flag set after the shapes leaves them solid', () {
      final world = _world();
      final ledge = b2w_createStaticBody(world, 0, -100, 0);
      b2w_addBoxShape(ledge, 50, 10, 1, 0.6, 0);
      b2w_setBodySensor(ledge, 1);
      final ball = _ball(world, 0, -200);
      _steps(world, 120);
      expect(_read(ball).y, closeTo(-115, 0.6), reason: 'on the ledge');
    });

    test('body move events name the bodies that moved', () {
      final world = _world();
      final ball = _ball(world, 0, 0);
      _steps(world, 1);
      final moved = <int>{};
      using((arena) {
        final body = arena<Int64>(), asleep = arena<Int32>();
        for (var i = 0; i < b2w_getBodyMoveEventCount(world); i++) {
          b2w_getBodyMoveEvent(world, i, body, asleep);
          moved.add(body.value);
        }
      });
      expect(moved, contains(ball));
    });

    test(
      'the impact callback hears a hard landing, and stops when removed',
      () async {
        final world = _world();
        final floor = _floor(world);
        final ball = _ball(world, 0, -300, radius: 10);
        final impacts = <(int, int, double)>[];
        final callable = NativeCallable<ImpactCallbackFnFunction>.listener(
          (int a, int b, double speed) => impacts.add((a, b, speed)),
        );
        addTearDown(callable.close);
        b2w_setImpactCallback(world, callable.nativeFunction, 300);

        _steps(world, 90); // lands at about 750 units/s, then rests
        await _settle();
        expect(impacts, isNotEmpty);
        final (a, b, speed) = impacts.first;
        expect({a, b}, {floor, ball});
        expect(speed, greaterThan(600));
        final heard = impacts.length;

        b2w_setImpactCallback(world, nullptr, 0);
        b2w_setBodyTransform(ball, 0, -300, 0, 1);
        _steps(world, 90);
        await _settle();
        expect(impacts, hasLength(heard));
      },
    );

    test('a soft landing is under the threshold', () async {
      final world = _world();
      _floor(world);
      _ball(world, 0, -20, radius: 10); // falls 10 units: about 140 units/s
      final impacts = <double>[];
      final callable = NativeCallable<ImpactCallbackFnFunction>.listener(
        (int a, int b, double speed) => impacts.add(speed),
      );
      addTearDown(callable.close);
      b2w_setImpactCallback(world, callable.nativeFunction, 300);
      _steps(world, 60);
      b2w_setImpactCallback(world, nullptr, 0);
      await _settle();
      expect(impacts, isEmpty);
    });
  });

  group('queries', () {
    test('the closest ray hit, and one that starts inside a shape', () {
      final world = _world();
      final floor = _floor(world);
      using((arena) {
        final body = arena<Int64>();
        final px = arena<Float>(), py = arena<Float>();
        final nx = arena<Float>(), ny = arena<Float>();
        final f = arena<Float>();
        final all = ~0;
        expect(
          b2w_castRayClosest(
            world,
            0,
            -100,
            0,
            200,
            all,
            all,
            body,
            px,
            py,
            nx,
            ny,
            f,
          ),
          1,
        );
        expect(body.value, floor);
        expect(py.value, closeTo(0, 1e-3));
        expect([nx.value, ny.value], [0, -1]);
        expect(f.value, closeTo(0.5, 1e-4));

        // From inside the floor, the closest cast passes it…
        expect(
          b2w_castRayClosest(
            world,
            0,
            10,
            0,
            100,
            all,
            all,
            body,
            px,
            py,
            nx,
            ny,
            f,
          ),
          0,
        );
        // …and casting for all hits reports it at fraction 0.
        final bodies = arena<Int64>(4);
        final hits = arena<Float>(4 * 5);
        expect(
          b2w_castRayAll(world, 0, 10, 0, 100, all, all, bodies, hits, 4),
          1,
        );
        expect(bodies[0], floor);
        expect(hits[4], 0);
      });
    });

    test('a ray filtered out misses', () {
      final world = _world();
      final floor = _floor(world);
      b2w_setBodyFilter64(floor, 0x2, ~0, 0);
      using((arena) {
        final body = arena<Int64>();
        final p = arena<Float>(5);
        expect(
          b2w_castRayClosest(
            world,
            0,
            -100,
            0,
            200,
            ~0,
            0x1,
            body,
            p,
            p + 1,
            p + 2,
            p + 3,
            p + 4,
          ),
          0,
        );
      });
    });

    test('an AABB query reports a body of two shapes once', () {
      final world = _world();
      final body = b2w_createStaticBody(world, 0, 0, 0);
      b2w_addCircleShape(body, -10, 0, 5, 1, 0.6, 0);
      b2w_addCircleShape(body, 10, 0, 5, 1, 0.6, 0);
      using((arena) {
        final out = arena<Int64>(4);
        expect(b2w_queryAABB(world, -50, -50, 50, 50, ~0, ~0, out, 4), 1);
        expect(out[0], body);
        expect(b2w_queryAABB(world, 100, 100, 200, 200, ~0, ~0, out, 4), 0);
      });
    });

    test('a polygon of 16 points keeps its whole outline', () {
      final world = _world();
      final body = b2w_createStaticBody(world, 0, 0, 0);
      const n = 16;
      using((arena) {
        final verts = arena<Float>(n * 2);
        for (var i = 0; i < n; i++) {
          verts[i * 2] = 50 * math.cos(2 * math.pi * i / n);
          verts[i * 2 + 1] = 50 * math.sin(2 * math.pi * i / n);
        }
        b2w_addPolygonShape(body, verts, n, 1, 0.6, 0);

        // A ray at every corner, from 200 out toward the centre.
        final hit = arena<Int64>();
        final p = arena<Float>(5);
        for (var i = 0; i < n; i++) {
          final c = math.cos(2 * math.pi * i / n);
          final s = math.sin(2 * math.pi * i / n);
          expect(
            b2w_castRayClosest(
              world,
              200 * c,
              200 * s,
              -200 * c,
              -200 * s,
              ~0,
              ~0,
              hit,
              p,
              p + 1,
              p + 2,
              p + 3,
              p + 4,
            ),
            1,
            reason: 'corner $i',
          );
          expect(p[4], closeTo(0.75, 0.01), reason: 'corner $i');
        }
      });
    });
  });

  group('movers', () {
    // A capsule 30 tall: points 10 above and below the origin, radius 5.
    Pointer<Float> capsule(Arena arena) => arena<Float>(4)
      ..[0] = 0
      ..[1] = -10
      ..[2] = 0
      ..[3] = 10;

    test('collide reports the floor it stands in', () {
      final world = _world();
      final floor = _floor(world);
      using((arena) {
        final planes = arena<Float>(4 * 5);
        final bodies = arena<Int64>(4);
        // Its bottom 0.2 into the floor.
        final n = b2w_moverCollide(
          world,
          0,
          -14.8,
          capsule(arena),
          2,
          5,
          ~0,
          ~0,
          0,
          planes,
          bodies,
          4,
        );
        expect(n, 1);
        expect(bodies[0], floor);
        expect(planes[0], closeTo(0, 1e-4));
        expect(planes[1], closeTo(-1, 1e-4), reason: 'toward the mover');
        expect(planes[2], closeTo(0.2, 1e-3));

        expect(
          b2w_moverCollide(
            world,
            0,
            -14.8,
            capsule(arena),
            2,
            5,
            ~0,
            ~0,
            floor,
            planes,
            bodies,
            4,
          ),
          0,
          reason: 'its body ignored',
        );
      });
    });

    test('cast stops at the floor', () {
      final world = _world();
      _floor(world);
      using((arena) {
        // The bottom starts 35 above the floor and moves 100 down.
        final fraction = b2w_moverCast(
          world,
          0,
          -50,
          capsule(arena),
          2,
          5,
          0,
          100,
          ~0,
          ~0,
          0,
        );
        expect(fraction, closeTo(0.35, 0.02));
        expect(
          b2w_moverCast(
            world,
            0,
            -50,
            capsule(arena),
            2,
            5,
            0,
            -100,
            ~0,
            ~0,
            0,
          ),
          1,
          reason: 'nothing above',
        );
      });
    });
  });

  group('bodies', () {
    test('a one-way platform lets a body up through and holds it on top', () {
      final world = _world();
      final platform = b2w_createStaticBody(world, 0, -100, 0);
      b2w_addBoxShape(platform, 50, 5, 1, 0.6, 0);
      b2w_setBodyOneWay(platform, 1, B2W_ONEWAY_FROM_ABOVE);
      final ball = _ball(world, 0, -50);
      b2w_setLinearVelocity(ball, 0, -600); // up, through it
      _steps(world, 180);
      expect(_read(ball).y, closeTo(-110, 0.6), reason: 'on top');
    });

    test('an impulse at the centre of mass does not spin the body', () {
      final world = b2w_createWorld(0, 0, 1);
      addTearDown(() => b2w_destroyWorld(world));
      final body = b2w_createDynamicBody(world, 0, 0, 0);
      b2w_addCircleShape(body, 20, 0, 10, 1, 0.6, 0); // off its origin
      b2w_setBodyMass(body, 2);
      b2w_applyLinearImpulse(body, 0, 4);
      final pose = _read(body);
      expect(pose.vy, closeTo(2, 1e-4), reason: 'mass 2');
      expect(pose.spin, closeTo(0, 1e-6));
    });

    test('gravity scale, fixed rotation and sleep', () {
      final world = _world();
      final floating = _ball(world, 0, 0);
      b2w_setBodyGravityScale(floating, 0);
      final fixed = _ball(world, 100, 0);
      b2w_setBodyFixedRotation(fixed, 1);
      b2w_applyTorque(fixed, 1e9);
      final sleeper = _ball(world, 200, 0);
      b2w_setBodyAwake(sleeper, 0);
      _steps(world, 30);
      expect(_read(floating).y, 0);
      expect(_read(fixed).angle, 0);
      expect(_read(sleeper).y, 0, reason: 'asleep, so not falling');

      b2w_setBodyTransform(sleeper, 200, -50, 0, 1);
      final woken = _read(sleeper);
      expect(woken.y, -50);
      expect(woken.awake, isTrue);
    });

    test('body types, and a kinematic body moved to a target', () {
      final world = _world();
      final mover = b2w_createBody(world, B2W_BODY_KINEMATIC, 0, 0, 0);
      expect(b2w_getBodyType(mover), B2W_BODY_KINEMATIC);
      b2w_setBodyTargetTransform(mover, 100, 0, 0, _dt, 1);
      _steps(world, 1);
      expect(_read(mover).x, closeTo(100, 1e-3));

      b2w_setBodyType(mover, B2W_BODY_DYNAMIC);
      expect(b2w_getBodyType(mover), B2W_BODY_DYNAMIC);
      expect(b2w_getBodyType(0), B2W_BODY_STATIC, reason: 'no body');
    });

    test('a filter that rejects the floor lets a ball fall through', () {
      final world = _world();
      final floor = _floor(world);
      b2w_setBodyFilter64(floor, 0x1, 0x1, 0);
      final ball = _ball(world, 0, -20);
      b2w_setBodyFilter64(ball, 0x2, 0x2, 0);
      _steps(world, 60);
      expect(_read(ball).y, greaterThan(100));
    });

    test('a chain holds a ball on its front, and goes when destroyed', () {
      final world = _world();
      final ground = b2w_createStaticBody(world, 0, 0, 0);
      using((arena) {
        // Left to right: its front faces up (smaller y).
        final points = arena<Float>(8);
        const xs = [-400.0, -300.0, 300.0, 400.0];
        for (var i = 0; i < 4; i++) {
          points[i * 2] = xs[i];
          points[i * 2 + 1] = 0;
        }
        final chain = b2w_addChainShape(ground, points, 4, 0, 0.6, 0);
        expect(chain, isNot(0));
        final ball = _ball(world, 0, -100);
        _steps(world, 120);
        expect(_read(ball).y, closeTo(-5, 0.6));

        b2w_destroyChain(chain);
        b2w_setBodyAwake(ball, 1);
        _steps(world, 60);
        expect(_read(ball).y, greaterThan(100));

        expect(
          b2w_addChainShape(ground, points, 3, 0, 0.6, 0),
          0,
          reason: 'too few points',
        );
      });
    });
  });
}

/// Lets the listeners' queued calls run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
