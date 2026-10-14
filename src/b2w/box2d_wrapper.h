// box2d_wrapper.h — the C layer over Box2D v3.2 that just_box_2d builds and
// binds. ffigen generates lib/src/native/bindings.g.dart from this file
// (ffigen.yaml); regenerate it after any change here.
//
// Rules that hold for every function below:
//
// Handles. Box2D's id structs travel as int64_t, so Dart never passes a
// struct by value:
//   world → index1[15:0] | generation[31:16]
//   body, chain, joint →
//     index1[23:0] | world0[31:24] | generation[47:32] | world generation[63:48]
// 0 is no handle. The world's generation tells a handle of a world that has
// gone from one of a newer world in the same slot. Every function checks its
// handles and does nothing with a dead one (Box2D itself checks nothing in a
// release build): a setter returns, a create returns 0, a query reports
// nothing.
//
// Units. The first b2w_createWorld sets Box2D's length units to 100 per metre
// for the whole process (b2SetLengthUnitsPerMeter), so one unit is a
// centimetre: lengths are in units, speeds in units per second, gravity in
// units per second squared (981 is Earth's), and Box2D's tolerances, speed
// cap and thresholds are scaled to match. Angles are radians, counter-
// clockwise in a y-up view. Masses are in whatever unit the caller picks.
//
// Directions. Box2D has no up. This layer's one-way platforms (and the
// movers, which honour them) read screen space, +y down:
// B2W_ONEWAY_FROM_ABOVE holds a body at a smaller y.
//
// Threads. Call every function from one thread at a time, and use the
// library from one isolate per process. b2w_step runs Box2D's work on the
// world's own thread pool and returns when all of it is done, so nothing of
// Box2D runs between calls. The two finalizers are the exception: any thread
// may call them at any time (see the end of this file).
//
// Pointers. Arrays and out-parameters must be valid for the sizes given.
// Getters zero their out-parameters first, so a dead handle or an index out
// of range reads as zeros (b2w_castRayClosest writes them only on a hit).
//
// Restitution. Two shapes bounce with the smaller restitution of the two
// (Box2D's own default is the larger).

#pragma once

#include <stdbool.h>
#include <stdint.h>

// Windows DLLs export nothing by default, and the build hides every other
// platform's symbols (-fvisibility=hidden): only what is marked here leaves
// the library. Without it, DynamicLibrary lookups fail with "procedure not
// found" although the library itself loads.
#if defined(_WIN32)
  #define B2W_EXPORT __declspec(dllexport)
#else
  #define B2W_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ── Library ──────────────────────────────────────────────────────────────────

/// Box2D's version, major << 16 | minor << 8 | revision (3.2.0 is 0x030200).
B2W_EXPORT int32_t b2w_version(void);

// ── World ────────────────────────────────────────────────────────────────────

/// Create a world with gravity (gravityX, gravityY) and a thread pool of its
/// own for Box2D's work. numThreads <= 0 → cores - 1, at most 4.
/// Returns its handle; 0 when every world slot is taken (Box2D has 128).
B2W_EXPORT int64_t b2w_createWorld(float gravityX, float gravityY, int32_t numThreads);

/// Destroy a world with everything in it, then its thread pool.
B2W_EXPORT void b2w_destroyWorld(int64_t worldHandle);

/// Advance the world by timeStep seconds in subSteps sub-steps (Box2D
/// recommends 4). The events read below are this step's until the next one.
B2W_EXPORT void b2w_step(int64_t worldHandle, float timeStep, int32_t subSteps);

/// Change the world's gravity.
B2W_EXPORT void b2w_setGravity(int64_t worldHandle, float gx, float gy);

// ── Bodies ───────────────────────────────────────────────────────────────────

/// Create a dynamic body at (posX, posY), turned by angle. Returns its
/// handle; 0 when the world has gone. Same as b2w_createBody with
/// B2W_BODY_DYNAMIC.
B2W_EXPORT int64_t b2w_createDynamicBody(int64_t worldHandle,
                               float posX, float posY, float angle);

/// Create a static body. Same as b2w_createBody with B2W_BODY_STATIC.
B2W_EXPORT int64_t b2w_createStaticBody(int64_t worldHandle,
                              float posX, float posY, float angle);

/// Destroy a body with its shapes, chains and joints.
B2W_EXPORT void b2w_destroyBody(int64_t bodyHandle);

// ── Shapes ───────────────────────────────────────────────────────────────────
//
// Positions are in body space. density is mass per square unit; Box2D sums a
// body's mass from its shapes (b2w_setBodyMass overrides it). friction and
// restitution are 0 and up (1 = no energy lost). Every shape reports contact
// begin/end, sensor and hit events, and is a sensor if b2w_setBodySensor
// said so before it was added.

/// Attach a circle centred at (cx, cy).
B2W_EXPORT void b2w_addCircleShape(int64_t bodyHandle, float cx, float cy,
                         float radius, float density, float friction,
                         float restitution);

/// Attach a box centred on the body's origin. halfW/halfH are half-extents.
B2W_EXPORT void b2w_addBoxShape(int64_t bodyHandle, float halfW, float halfH,
                      float density, float friction, float restitution);

/// Attach a convex polygon. verts: count points as x0, y0, x1, y1, …; Box2D
/// takes their convex hull. More than 8 points (Box2D's limit) are cut into
/// a fan of pieces that share the first point, so the body keeps the whole
/// shape. Fewer than 3 attach nothing.
B2W_EXPORT void b2w_addPolygonShape(int64_t bodyHandle,
                          const float* verts, int32_t count,
                          float density, float friction, float restitution);

/// Attach a convex polygon grown by cornerRadius, which rounds its corners.
/// verts as for b2w_addPolygonShape, cut the same way past 8 points (the
/// pieces then overlap along their seams by the rounding).
B2W_EXPORT void b2w_addRoundedPolygonShape(int64_t bodyHandle,
                                 const float* verts, int32_t count,
                                 float cornerRadius,
                                 float density, float friction, float restitution);

/// Attach a capsule: the segment from (cx1, cy1) to (cx2, cy2) grown by
/// radius.
B2W_EXPORT void b2w_addCapsuleShape(int64_t bodyHandle,
                          float cx1, float cy1, float cx2, float cy2,
                          float radius,
                          float density, float friction, float restitution);

/// Attach a line segment from (x1, y1) to (x2, y2). It has no area, so it
/// adds no mass; use it on static bodies.
B2W_EXPORT void b2w_addSegmentShape(int64_t bodyHandle,
                          float x1, float y1, float x2, float y2,
                          float density, float friction, float restitution);

/// Attach a chain of segments. points: count points as x0, y0, x1, y1, …;
/// loop != 0 joins the last back to the first. At least 4 points; an open
/// chain's first and last are ghosts that only shape its ends. A chain is
/// one-sided: it collides on the right of its direction (counter-clockwise
/// points face out) and sensors never see it.
/// Returns its handle, for b2w_destroyChain; 0 for too few points or a dead
/// body.
B2W_EXPORT int64_t b2w_addChainShape(int64_t bodyHandle,
                           const float* points, int32_t count, int32_t loop,
                           float friction, float restitution);

/// Destroy a chain made by b2w_addChainShape.
B2W_EXPORT void b2w_destroyChain(int64_t chainHandle);

// ── Forces & impulses ────────────────────────────────────────────────────────
//
// Each wakes the body (b2w_setLinearVelocity unless the velocity is zero).

/// Apply a force at the body's centre of mass, for the next step.
B2W_EXPORT void b2w_applyForce(int64_t bodyHandle, float fx, float fy);

/// Apply an impulse at the body's centre of mass: its velocity changes now.
B2W_EXPORT void b2w_applyLinearImpulse(int64_t bodyHandle, float ix, float iy);

/// Apply a torque, for the next step.
B2W_EXPORT void b2w_applyTorque(int64_t bodyHandle, float torque);

/// Set the body's velocity.
B2W_EXPORT void b2w_setLinearVelocity(int64_t bodyHandle, float vx, float vy);

// ── Reading bodies back ──────────────────────────────────────────────────────

/// Read count bodies at once, after a step. handles: count body handles.
/// buffer: count * 7 floats, written per body as
///   [posX, posY, angle, velX, velY, isAwake (1 or 0), angularVelocity]
/// A dead handle's seven are zeros.
B2W_EXPORT void b2w_bulkExtractTransforms(const int64_t* handles,
                                float* buffer,
                                int32_t count);

// ── Contact events (read after a step) ───────────────────────────────────────
//
// Between shapes that touch, one of them on a dynamic or kinematic body.
// The body handles are 0 for a shape destroyed since the step.

/// How many contacts began in the last step.
B2W_EXPORT int32_t b2w_getContactBeginCount(int64_t worldHandle);

/// Read the index-th contact that began: the two bodies, and the contact
/// normal, pointing from A to B (zeros if the contact has gone since).
B2W_EXPORT void b2w_getContactBeginEvent(int64_t worldHandle, int32_t index,
                               int64_t* outBodyA, int64_t* outBodyB,
                               float* outNormalX, float* outNormalY);

/// How many contacts ended in the last step.
B2W_EXPORT int32_t b2w_getContactEndCount(int64_t worldHandle);

/// Read the index-th contact that ended.
B2W_EXPORT void b2w_getContactEndEvent(int64_t worldHandle, int32_t index,
                             int64_t* outBodyA, int64_t* outBodyB);

// ── Sensor events (read after a step) ────────────────────────────────────────
//
// A sensor shape reports the shapes that start and stop overlapping it,
// checked at the end of each step, whatever bodies they are on. It never
// sees chains or shapes of its own body, nor shapes its filter rejects.

/// How many overlaps began in the last step.
B2W_EXPORT int32_t b2w_getSensorBeginCount(int64_t worldHandle);

/// Read the index-th overlap that began: the sensor's body and the body
/// that entered it.
B2W_EXPORT void b2w_getSensorBeginEvent(int64_t worldHandle, int32_t index,
                              int64_t* outSensorBody, int64_t* outVisitorBody);

/// How many overlaps ended in the last step.
B2W_EXPORT int32_t b2w_getSensorEndCount(int64_t worldHandle);

/// Read the index-th overlap that ended.
B2W_EXPORT void b2w_getSensorEndEvent(int64_t worldHandle, int32_t index,
                            int64_t* outSensorBody, int64_t* outVisitorBody);

// ── Body settings ────────────────────────────────────────────────────────────

/// Make the shapes added to the body from now on sensors (isSensor != 0) or
/// solid (0). Call it before adding them: shapes already on the body keep
/// what they are, as Box2D cannot change a shape between the two.
B2W_EXPORT void b2w_setBodySensor(int64_t bodyHandle, int32_t isSensor);

/// Set the collision filter of every shape on the body (chains included),
/// with 32-bit category and mask bits. Two shapes collide when each one's
/// mask has a bit of the other's category, unless they share a groupIndex:
/// then a positive group always collides and a negative one never does.
/// b2w_setBodyFilter64 takes all 64 bits.
B2W_EXPORT void b2w_setBodyFilter(int64_t bodyHandle,
                        uint32_t categoryBits, uint32_t maskBits,
                        int32_t groupIndex);

/// Turn continuous collision against other moving bodies on (isBullet != 0)
/// or off, for a small fast body that would pass through them. Box2D already
/// keeps every dynamic body from passing through static ones.
B2W_EXPORT void b2w_setBodyBullet(int64_t bodyHandle, int32_t isBullet);

/// Scale the world's gravity for this body: 1 is normal, 0 none.
B2W_EXPORT void b2w_setBodyGravityScale(int64_t bodyHandle, float gravityScale);

/// Wake the body (awake != 0) or put it to sleep. A body sleeps by itself
/// once it rests, and contacts, forces and impulses wake it.
B2W_EXPORT void b2w_setBodyAwake(int64_t bodyHandle, int32_t awake);

/// Allow the body to sleep (enabled != 0, the default) or keep it awake for
/// as long as it exists.
B2W_EXPORT void b2w_setBodySleepEnabled(int64_t bodyHandle, int32_t enabled);

/// Lock the body's rotation (fixed != 0): nothing turns it, not torques nor
/// contacts. Its movement stays free.
B2W_EXPORT void b2w_setBodyFixedRotation(int64_t bodyHandle, int32_t fixed);

/// Give the body this mass instead of the one its shapes' density adds up
/// to. The centre of mass stays where the shapes put it, and the rotational
/// inertia scales with the mass, so the body turns as before. Call it after
/// adding the shapes (adding one sums the mass again), and again after
/// b2w_setBodyType.
B2W_EXPORT void b2w_setBodyMass(int64_t bodyHandle, float mass);

// ── Impact callback ──────────────────────────────────────────────────────────

/// What b2w_setImpactCallback calls: the two bodies, and the speed (units
/// per second) their shapes closed at.
typedef void (*ImpactCallbackFn)(int64_t bodyA, int64_t bodyB, float speed);

/// Have b2w_step call callback for every contact whose shapes closed faster
/// than speedThreshold (units per second) in that step, with the two bodies
/// and that speed: Box2D's hit events. It is called on the thread that called
/// b2w_step, after the step and before b2w_step returns; it must not call
/// back into this library (a Dart NativeCallable.listener, which only queues
/// the call, is the way to receive it). NULL removes the callback, and with
/// no callback Box2D gathers no hit events.
B2W_EXPORT void b2w_setImpactCallback(int64_t worldHandle,
                            ImpactCallbackFn callback,
                            float speedThreshold);

// ── Body move events (read after a step) ─────────────────────────────────────

/// How many bodies moved in the last step, including those that fell asleep
/// at the end of it.
B2W_EXPORT int32_t b2w_getBodyMoveEventCount(int64_t worldHandle);

/// Read the index-th body that moved, and whether it fell asleep (1) or not
/// (0).
B2W_EXPORT void b2w_getBodyMoveEvent(int64_t worldHandle, int32_t index,
                           int64_t* outBodyHandle, int32_t* outFellAsleep);

// ── Joints ───────────────────────────────────────────────────────────────────
//
// A joint holds two different bodies of the world. Anchors and axes are in
// world space at the moment of creation. Each create returns the joint's
// handle; 0 if a handle is dead or both are the same body. A joint goes with
// either of its bodies; the two bodies do not collide with each other.

/// A hinge: the bodies turn freely about the anchor they share.
B2W_EXPORT int64_t b2w_createRevoluteJoint(int64_t worldHandle,
                                 int64_t bodyA, int64_t bodyB,
                                 float anchorX, float anchorY);

/// A slider: bodyB moves along the axis through the anchor, and the two do
/// not turn against each other.
B2W_EXPORT int64_t b2w_createPrismaticJoint(int64_t worldHandle,
                                  int64_t bodyA, int64_t bodyB,
                                  float anchorX, float anchorY,
                                  float axisX,   float axisY);

/// A rope or rod between the two bodies' origins: their distance stays
/// within [minLen, maxLen], free in between and rigid at the ends; equal
/// lengths make a rigid rod. b2w_setDistanceSpring makes it springy.
B2W_EXPORT int64_t b2w_createDistanceJoint(int64_t worldHandle,
                                 int64_t bodyA, int64_t bodyB,
                                 float minLen, float maxLen);

/// Weld the bodies together at the anchor, as they are now.
B2W_EXPORT int64_t b2w_createWeldJoint(int64_t worldHandle,
                              int64_t bodyA, int64_t bodyB,
                              float anchorX, float anchorY);

/// A wheel: bodyB turns freely about the anchor and moves on a spring along
/// the axis (suspension; 4 Hz, damping ratio 0.7 until b2w_setWheelSpring).
B2W_EXPORT int64_t b2w_createWheelJoint(int64_t worldHandle,
                               int64_t bodyA, int64_t bodyB,
                               float anchorX, float anchorY,
                               float axisX,   float axisY);

/// Destroy a joint.
B2W_EXPORT void b2w_destroyJoint(int64_t jointHandle);

// ── Joint settings ───────────────────────────────────────────────────────────
//
// A motor setter that turns its motor on wakes the bodies, as do the
// distance joint's.

/// Limit a revolute joint's angle to [lower, upper] radians (enable != 0)
/// or free it.
B2W_EXPORT void b2w_setRevoluteLimits(int64_t jointHandle,
                            float lower, float upper, int32_t enable);

/// Drive a revolute joint at speed (radians per second) with up to maxTorque
/// (enable != 0), or turn the motor off.
B2W_EXPORT void b2w_setRevoluteMotor(int64_t jointHandle,
                           float speed, float maxTorque, int32_t enable);

/// Limit a prismatic joint's travel to [lower, upper] along its axis
/// (enable != 0), or free it.
B2W_EXPORT void b2w_setPrismaticLimits(int64_t jointHandle,
                             float lower, float upper, int32_t enable);

/// Drive a prismatic joint at speed (units per second) with up to maxForce
/// (enable != 0), or turn the motor off.
B2W_EXPORT void b2w_setPrismaticMotor(int64_t jointHandle,
                            float speed, float maxForce, int32_t enable);

/// Change a distance joint's range. Its rest length becomes the middle of it.
B2W_EXPORT void b2w_setDistanceLimits(int64_t jointHandle, float minLen, float maxLen);

/// Give a distance joint a spring that pulls toward its rest length (the
/// middle of its range): hertz is how fast it swings, dampingRatio how soon
/// it settles (0 never, 1 without overshoot). With an open range the ends
/// still stop it; with equal lengths there is only the spring. hertz 0
/// takes the spring away.
B2W_EXPORT void b2w_setDistanceSpring(int64_t jointHandle,
                            float hertz, float dampingRatio);

/// Set a wheel joint's suspension: hertz, and dampingRatio as for
/// b2w_setDistanceSpring.
B2W_EXPORT void b2w_setWheelSpring(int64_t jointHandle,
                         float hertz, float dampingRatio);

/// Drive a wheel joint's wheel at speed (radians per second) with up to
/// maxTorque (enable != 0), or turn the motor off.
B2W_EXPORT void b2w_setWheelMotor(int64_t jointHandle,
                        float speed, float maxTorque, int32_t enable);

// ── Joint queries ────────────────────────────────────────────────────────────

/// The force the joint applied in the last step, in world space.
B2W_EXPORT void b2w_getJointReactionForce(int64_t jointHandle,
                                float* outFx, float* outFy);

/// The torque the joint applied in the last step.
B2W_EXPORT float b2w_getJointReactionTorque(int64_t jointHandle);

// ── Body type and placement ──────────────────────────────────────────────────

/// Body types, numerically b2BodyType's.
#define B2W_BODY_STATIC    0
#define B2W_BODY_KINEMATIC 1
#define B2W_BODY_DYNAMIC   2

/// Create a body of bodyType (a B2W_BODY_* value) at (posX, posY), turned by
/// angle. Returns its handle; 0 when the world has gone.
B2W_EXPORT int64_t b2w_createBody(int64_t worldHandle, int32_t bodyType,
                                  float posX, float posY, float angle);

/// Teleport a body. Box2D calls this fairly expensive (it moves the body's
/// shapes in the broad phase and drops their contacts' warm start): use it
/// for respawns, checkpoints and warps, and velocity for ordinary motion.
/// wake != 0 wakes the body too, which moving it alone does not.
B2W_EXPORT void b2w_setBodyTransform(int64_t bodyHandle,
                                     float x, float y, float angle,
                                     int32_t wake);

/// Set the body's angular velocity (radians per second).
B2W_EXPORT void b2w_setAngularVelocity(int64_t bodyHandle, float omega);

/// Change a body's type. Expensive, and it sums the mass from the shapes
/// again (call b2w_setBodyMass after it). The type it already has does
/// nothing.
B2W_EXPORT void    b2w_setBodyType(int64_t bodyHandle, int32_t bodyType);

/// The body's type; B2W_BODY_STATIC for a dead handle.
B2W_EXPORT int32_t b2w_getBodyType(int64_t bodyHandle);

/// Move a kinematic body to a transform over the next timeStep, by giving it
/// the velocity that gets it there. Bodies standing on it are carried along,
/// which teleporting would not do. wake != 0 wakes it.
B2W_EXPORT void b2w_setBodyTargetTransform(int64_t bodyHandle,
                                           float x, float y, float angle,
                                           float timeStep, int32_t wake);

// ── One-way platforms ────────────────────────────────────────────────────────
//
// A world pre-solve callback keeps a one-way shape's contacts only when the
// other body meets it from its solid side (within 60°). Its state is packed
// into each shape's user data, so shapes must not carry user data of their
// own.

#define B2W_SHAPE_FLAG_ONE_WAY  0x1u
#define B2W_ONEWAY_DIR_SHIFT    1
#define B2W_ONEWAY_FROM_ABOVE   0
#define B2W_ONEWAY_FROM_BELOW   1
#define B2W_ONEWAY_FROM_LEFT    2
#define B2W_ONEWAY_FROM_RIGHT   3

/// Make every shape on the body a one-way platform, solid only to what
/// comes from solidFromDirection (a B2W_ONEWAY_FROM_* value; +y down), or
/// solid again (enabled == 0). Applies to the shapes on the body now.
B2W_EXPORT void b2w_setBodyOneWay(int64_t bodyHandle,
                                  int32_t enabled,
                                  int32_t solidFromDirection);

// ── Spatial queries ──────────────────────────────────────────────────────────
//
// translation is the whole ray, direction times length. A shape is
// considered when the filter's mask has a bit of its category and its mask
// has a bit of the filter's category; ~0ull for both considers every shape.
// Sensor shapes are found like any other.

/// Cast a ray and report the closest hit: the body, the point, the surface
/// normal there, and how far along the ray it is (0 to 1). Returns 1 on a
/// hit, 0 on none (the out-parameters are then not written). A ray passes
/// the shapes it starts inside; b2w_castRayAll reports those.
B2W_EXPORT int32_t b2w_castRayClosest(int64_t worldHandle,
                                      float originX, float originY,
                                      float translationX, float translationY,
                                      uint64_t categoryBits, uint64_t maskBits,
                                      int64_t* outBody,
                                      float* outPointX, float* outPointY,
                                      float* outNormalX, float* outNormalY,
                                      float* outFraction);

/// Cast a ray and report up to maxHits hits, in no order, one per shape (a
/// body of several shapes can be there more than once). outBodies: maxHits
/// handles. outBuffer: maxHits * 5 floats, per hit
///   [pointX, pointY, normalX, normalY, fraction]
/// A shape the ray starts inside is a hit at fraction 0, at the origin, with
/// a zero normal. Returns how many it wrote.
B2W_EXPORT int32_t b2w_castRayAll(int64_t worldHandle,
                                  float originX, float originY,
                                  float translationX, float translationY,
                                  uint64_t categoryBits, uint64_t maskBits,
                                  int64_t* outBodies, float* outBuffer,
                                  int32_t maxHits);

/// Report up to maxBodies bodies, each once, with a shape whose bounding box
/// (grown a little, as Box2D keeps it) overlaps the box: more than what
/// truly overlaps, so test the shapes yourself when it matters. Returns how
/// many it wrote to outBodies.
B2W_EXPORT int32_t b2w_queryAABB(int64_t worldHandle,
                                 float minX, float minY, float maxX, float maxY,
                                 uint64_t categoryBits, uint64_t maskBits,
                                 int64_t* outBodies, int32_t maxBodies);

// ── Character movers ─────────────────────────────────────────────────────────
//
// The two queries a kinematic character controller is built on. The mover
// is a convex shape at origin: points (1 to 8 x, y pairs relative to it)
// grown by radius — two points for a capsule, four for a box. Sensors,
// ignoreBody (the character's own, or 0) and shapes the filter rejects are
// passed over, and a one-way platform counts only from its solid side.

/// The surfaces the mover touches, as Box2D collision planes. outPlanes:
/// maxPlanes * 5 floats, per plane
///   [normalX, normalY, offset, pointX, pointY]
/// The normal points toward the mover; offset is how far the mover reaches
/// into the surface; the point, on the surface, is relative to origin.
/// outBodies: maxPlanes handles, the body of each plane. Returns how many
/// planes it wrote.
B2W_EXPORT int32_t b2w_moverCollide(int64_t worldHandle,
                                    float originX, float originY,
                                    const float* points, int32_t pointCount,
                                    float radius,
                                    uint64_t categoryBits, uint64_t maskBits,
                                    int64_t ignoreBody,
                                    float* outPlanes, int64_t* outBodies,
                                    int32_t maxPlanes);

/// How much of translation the mover can travel before it touches
/// something, from 0 to 1 (1: all of it). What it touches at the start does
/// not stop it, and a chain stops it only from the chain's front.
B2W_EXPORT float b2w_moverCast(int64_t worldHandle,
                               float originX, float originY,
                               const float* points, int32_t pointCount,
                               float radius,
                               float translationX, float translationY,
                               uint64_t categoryBits, uint64_t maskBits,
                               int64_t ignoreBody);

// ── Damping and materials ────────────────────────────────────────────────────

/// Slow the body's movement: its velocity v becomes v / (1 + h * damping)
/// every sub-step of length h. 0, the default, never slows it.
B2W_EXPORT void b2w_setBodyLinearDamping(int64_t bodyHandle, float damping);

/// Slow the body's turning the same way.
B2W_EXPORT void b2w_setBodyAngularDamping(int64_t bodyHandle, float damping);

/// Set the friction of every shape on the body (chains included), from the
/// next step on: ice, mud.
B2W_EXPORT void b2w_setBodyFriction(int64_t bodyHandle, float friction);

/// Set the restitution of every shape on the body (chains included), from
/// the next step on: bounce pads.
B2W_EXPORT void b2w_setBodyRestitution(int64_t bodyHandle, float restitution);

/// b2w_setBodyFilter with all 64 bits of category and mask.
B2W_EXPORT void b2w_setBodyFilter64(int64_t bodyHandle,
                                    uint64_t categoryBits, uint64_t maskBits,
                                    int32_t groupIndex);

// ── NativeFinalizer callbacks ────────────────────────────────────────────────
//
// For a Dart NativeFinalizer (void(void*)), as a safety net behind explicit
// destroys. The token is the handle as a pointer
// (Pointer<Void>.fromAddress(handle)). The GC may call these on any thread,
// at any time, in any order — at an isolate's shutdown a world can go before
// its bodies — so they only queue the handle, and the next b2w_createWorld,
// b2w_createBody (or its forwarders), b2w_destroyWorld, b2w_destroyBody or
// b2w_step destroys it on the caller's thread. A body whose world went first
// is simply gone by then.

/// Queue a world for destruction.
B2W_EXPORT void b2w_finalizer_world(void* token);

/// Queue a body for destruction. On a 32-bit platform a pointer keeps only a
/// body handle's low 32 bits, so this does nothing there: the body goes with
/// its world.
B2W_EXPORT void b2w_finalizer_body(void* token);

#ifdef __cplusplus
}
#endif
