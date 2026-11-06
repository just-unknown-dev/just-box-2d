## 0.2.0

Joints that start out satisfied and take what just_physics_engine 2.0.0 saves, and a way to switch a body off.

### Breaking

* `b2w_createDistanceJoint(world, bodyA, bodyB, anchorAX, anchorAY, anchorBX, anchorBY, minLen, maxLen, collideConnected)`: a world anchor on each body, where it was the two bodies' origins (was `(world, bodyA, bodyB, minLen, maxLen)`).
* Every `b2w_create*Joint` takes `int32_t collideConnected` last: non-zero lets the two bodies collide with each other; 0, Box2D's default and what 0.1.0 always did, keeps them apart.

### Added

* `b2w_setBodyEnabled(body, enabled)`, over `b2Body_Disable` / `b2Body_Enable`: a body switched off does not move, ends its contacts (with end events), leaves the broad phase (no query, mover or sensor finds it) and its joints hold nothing; it keeps its place, shapes and settings, and comes back at rest.

### Fixed

* Joint frames keep the angle between the bodies they are made at. 0.1.0 left both frames unturned, so a weld or slider made between bodies turned apart pulled them into line (swinging the second body round the anchor: a slider's car left its rail), and a hinge's limits counted from the bodies' absolute angles instead of from the angle it was made at.
* `b2w_setWheelSpring` clamps a negative frequency to 0 and wakes the joint's bodies, as `b2w_setDistanceSpring` does.

## 0.1.0

First release: Box2D for Dart, moved out of just_physics_engine 1.4.0 so other code can use it and the physics engine is plain Dart.

* Box2D v3.2 (our fork of erincatto/box2d, `a7a2e57`) compiled from source by a two-stage build hook: a static `box2d_core`, linked into the bundled library `package:just_box_2d/just_box_2d`. Builds by default on every native platform and every Android ABI; an app turns it off with `hooks: user_defines: just_box_2d: build: false`.
* `Box2D` (in `package:just_box_2d/just_box_2d.dart`, safe on the web): whether the library is in the build — one call up front, so a missing library is reported, not found mid-game — and its version (`b2w_version`). `package:just_box_2d/ffi.dart` adds the bindings.
* The `b2w_*` C layer: worlds on their own thread pool at 100 units to the metre with min-restitution mixing; int64 handles carrying their world's generation, checked on every call; finalizers that only queue a destroy, performed on the next call from Dart; batched transform reads; contact, sensor and body-move events, and an impact callback from Box2D's hit events; ray and AABB queries; character-mover collide and cast queries; one-way platforms; circles, boxes, polygons of any vertex count (cut into convex pieces past 8), rounded polygons, capsules, segments and chains; revolute, prismatic, distance (rope, rod or spring), weld and wheel joints. Every function's rules and units are documented in `box2d_wrapper.h` and carried into the bindings' doc comments.
* Only the `b2w_*` functions are exported: Box2D's own symbols, and the C++ runtime Android and Linux link in, stay hidden.
* Web, compiled to JavaScript or to WebAssembly: `package:just_box_2d/just_box_2d.dart` compiles, and `Box2D.isAvailable` is false.
* An example, `example/example.dart`: a ball dropped on a floor.
* `LICENSE` carries Box2D's MIT text beside ours, in the form Flutter's licence page reads.
