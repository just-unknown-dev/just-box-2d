## 0.1.0

First release: Box2D for Dart, moved out of just_physics_engine 1.4.0 so other code can use it and the physics engine is plain Dart.

* Box2D v3.2 (our fork of erincatto/box2d, `a7a2e57`) compiled from source by a two-stage build hook: a static `box2d_core`, linked into the bundled library `package:just_box_2d/just_box_2d`. Builds by default on every native platform and every Android ABI; an app turns it off with `hooks: user_defines: just_box_2d: build: false`.
* `Box2D` (in `package:just_box_2d/just_box_2d.dart`, safe on the web): whether the library is in the build — resolving a set of its functions up front, so a missing or older library is reported, not found mid-game — and its version (`b2w_version`). `package:just_box_2d/ffi.dart` adds the bindings.
* The `b2w_*` C layer: worlds on their own thread pool at 100 units to the metre with min-restitution mixing; int64 handles carrying their world's generation, checked on every call; finalizers that only queue a destroy, performed on the next call from Dart; batched transform reads; contact, sensor and body-move events, and an impact callback called with no lock held; ray and AABB queries; character-mover collide and cast queries; one-way platforms; circles, boxes, polygons of any vertex count (cut into convex pieces past 8), rounded polygons, capsules, segments and chains; revolute, prismatic, distance, weld and wheel joints.
* Web, compiled to JavaScript or to WebAssembly: `package:just_box_2d/just_box_2d.dart` compiles, and `Box2D.isAvailable` is false.
* An example, `example/example.dart`: a ball dropped on a floor.
* `LICENSE` carries Box2D's MIT text beside ours, in the form Flutter's licence page reads.
