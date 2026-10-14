# Just Box 2D

[Box2D](https://github.com/erincatto/box2d) v3.2 for Dart, through a C layer of our own (`src/b2w/`) that gives Dart what Box2D's C API cannot: int64 handles checked on every call, worlds on a thread pool, events and transforms read in batches after a step, queries into caller buffers, character-mover queries, one-way platforms and safe teardown in any order. Everything is compiled from source by the package's build hook. Plain Dart: it works in Flutter apps and Dart programs alike, and depends on no engine.

```yaml
# The app's pubspec.yaml
dependencies:
  just_box_2d: ^0.1.0
```

```dart
import 'package:just_box_2d/ffi.dart';

void main() {
  Box2D.ensureAvailable(); // throws, saying why, when the library is not in the build
  final world = b2w_createWorld(0, 981, 1); // gravity (+Y down), one worker thread
  final ball = b2w_createDynamicBody(world, 0, -200, 0);
  b2w_addCircleShape(ball, 0, 0, 10, 1, 0.6, 0.3);
  for (var i = 0; i < 60; i++) {
    b2w_step(world, 1 / 60, 4);
  }
  // … b2w_bulkExtractTransforms, b2w_getContactBeginEvent, b2w_castRayClosest …
  b2w_destroyWorld(world);
}
```

- `package:just_box_2d/just_box_2d.dart` — `Box2D`: whether the library is in this build, and its version. Safe to import on the web, where it says Box2D cannot run.
- `package:just_box_2d/ffi.dart` — native platforms only: `Box2D` and the generated bindings (`b2w_*`, with `addresses` of the finalizers).

The whole program, a ball dropped on a floor, is in [`example/example.dart`](example/example.dart). For a game engine's 2D physics on top of it, with a pure-Dart engine for the web, see just_physics_engine's `Box2DPhysicsEngine`.

## Turning the build off

The library builds by default. An app that never uses native Box2D — a web-only game, or one that runs a pure-Dart engine everywhere — skips compiling and shipping it:

```yaml
hooks:
  user_defines:
    just_box_2d:
      build: false
```

Then `Box2D.isAvailable` is false, and `Box2D.unavailableReason` says why.

## Platforms

| Platform | Status |
|---|---|
| Windows x64 | Built and tested here (MSVC); about 0.5 MB. |
| Android arm64-v8a, armeabi-v7a, x86_64 | Built by the hook (NDK); run on an x86_64 emulator. The C++ runtime is linked in (no `libc++_shared.so` to ship). |
| Linux | The C layer and Box2D build with GCC 12 and pass a smoke test of the C layer; not run in a Flutter app. |
| macOS, iOS | Should build (clang); untested. |
| Web (JavaScript and WebAssembly) | `package:just_box_2d/just_box_2d.dart` compiles, and `Box2D.isAvailable` is false (no `dart:ffi`). Don't import `package:just_box_2d/ffi.dart` in web code. |

## How it builds

There is no CMake step. `hook/build.dart` compiles everything unless an app says `build: false`:

1. **`box2d_core`** (static, never bundled): Box2D's C sources in `src/box2d/src/`, C17, with `B2_ENABLE_MULTITHREADING`.
2. **`just_box_2d`** (the bundled library, asset id `package:just_box_2d/just_box_2d`): the C layer, `src/b2w/box2d_wrapper.cpp` and `thread_pool.cpp`, C++17, with `box2d_core` linked in.

Both stages build at `-O2`; Android and Linux link `libm`, and Android links `c++_static`. The bindings find the library by its asset id on every platform, never by a file name.

## Our C layer (`src/b2w/box2d_wrapper.h`)

- **Worlds** on a thread pool of their own (cores minus one, at most 4, when asked for 0), at 100 length units to the metre. Contacts bounce as much as the less bouncy of their two bodies.
- **Handles**: a world handle is Box2D's id (slot and generation); a body, chain or joint handle packs Box2D's id with its world's generation, so one from a world that has gone never names something in a newer world in the same slot. Every function checks its handles before Box2D sees them (Box2D checks nothing in a release build) and does nothing with a dead one.
- **Teardown in any order.** `b2w_finalizer_world` and `b2w_finalizer_body` are for `NativeFinalizer`. A finalizer can run on any thread, even mid-step, so it only queues the destroy; the next create, destroy or step from Dart performs it.
- **Batch reads**: every body's position, angle, velocity, spin and awake flag in one call (`b2w_bulkExtractTransforms`), and the bodies that moved.
- **Events** after a step: contact begin and end (with the normal), sensor begin and end, and an impact callback for fast collisions (a `NativeCallable.listener`, called with no lock held). An event whose shape has gone names no body (0).
- **Queries** into caller buffers: closest or all ray hits, AABB overlaps.
- **Character movers**: `b2w_moverCollide` (the surfaces a capsule or box touches, as planes) and `b2w_moverCast` (how far it can move), on Box2D's GJK and shape cast, passing over sensors, one ignored body, and one-way platforms it is not standing on or is partway through.
- **One-way platforms**: a pre-solve filter by side (`b2w_setBodyOneWay`), screen convention (+Y down: "from above" is the smaller-y side).
- **Shapes**: circles (off-centre too), boxes, convex polygons of any vertex count (more than 8 are cut into a fan of convex pieces), rounded polygons, capsules, segments and chains (at least 4 points; an open chain's first and last are ghosts).
- **Joints**: revolute, prismatic, distance, weld and wheel, with limits, motors and springs.

Use the library from one isolate per process: its worlds belong to the whole process. On a 32-bit platform a finalizer token keeps only a body handle's low 32 bits, so a body's finalizer does nothing there; the body goes with its world.

## Updating Box2D

Box2D comes from our fork of erincatto/box2d, at commit `a7a2e57` (v3.2.0).

1. Replace `src/box2d/src/`, `src/box2d/include/` and `src/box2d/LICENSE` with the fork's.
2. If `src/b2w/box2d_wrapper.h` changed, `dart run ffigen --config ffigen.yaml` regenerates `lib/src/native/bindings.g.dart`.
3. Run the tests (`dart test`).

## Licences

just_box_2d's own code is under the BSD 3-Clause licence. It builds and bundles **Box2D** v3.2 (© 2022 Erin Catto, MIT). Both texts are in `LICENSE`, in the form Flutter reads, so a Flutter app's licence page lists them without any code.
