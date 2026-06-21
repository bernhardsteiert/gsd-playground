# Architecture Patterns: Browser 3D Kart Racing (Three.js)

**Domain:** Browser-based 3D mobile kart racing game (PWA)
**Project:** Kart Rush
**Researched:** 2026-06-20
**Overall confidence:** HIGH (core patterns verified across multiple sources and live projects)

---

## Recommended Architecture

The system is organized as a coordinator-driven game loop with a central GameLoop module
driving all subsystems on each tick. State is managed by a flat FSM at the top level. No
full ECS framework is needed at this scope — simple class-per-system composition is enough
and reduces bundle size.

```
┌─────────────────────────────────────────────────────────┐
│                      index.html / PWA shell             │
│  manifest.json + service-worker.js                      │
└────────────────────────┬────────────────────────────────┘
                         │ boots
                         ▼
┌─────────────────────────────────────────────────────────┐
│                     AssetLoader                         │
│  LoadingManager → GLTFLoader / TextureLoader            │
│  Emits: onProgress(pct), onComplete()                   │
└────────────────────────┬────────────────────────────────┘
                         │ onComplete triggers
                         ▼
┌─────────────────────────────────────────────────────────┐
│                     GameManager (FSM)                   │
│  States: LOADING → COUNTDOWN → RACING → FINISH          │
│  Owns: scene, renderer, clock; orchestrates subsystems  │
└──┬──────────────┬──────────────┬──────────────┬─────────┘
   │              │              │              │
   ▼              ▼              ▼              ▼
InputSystem   PhysicsWorld   SceneGraph    UIOverlay
(touch)       (collision +   (Three.js)    (HTML/CSS HUD)
              movement)
   │              │              │
   └──────────────▼──────────────┘
              GameLoop
         requestAnimationFrame
         fixed-step accumulator
              │
    ┌─────────┼─────────────┐
    ▼         ▼             ▼
 KartCtrl  AIController  CameraSystem
 (player)  (x3 opponents)
    │
    ▼
 PowerUpSystem
 CheckpointSystem
```

---

## Component Boundaries

| Component | Responsibility | Talks To |
|-----------|---------------|----------|
| **AssetLoader** | Wraps THREE.LoadingManager; batches all GLTF models + textures; emits progress 0-100% | GameManager (signals boot complete) |
| **GameManager** | Top-level FSM owner; creates and destroys state contexts; owns WebGLRenderer and THREE.Clock | All subsystems |
| **GameLoop** | `requestAnimationFrame` loop with fixed-timestep accumulator (16ms / 60Hz physics); provides `dt` to each subsystem | PhysicsWorld, KartController, AIController, CameraSystem, UIOverlay |
| **InputSystem** | Normalises touch events into a persistent boolean state object `{ left, right }`; never reads input inside physics code | KartController reads from it |
| **PhysicsWorld** | Lightweight custom collision layer (no full engine needed at kart scope); track boundary rays + kart vs. pickup sphere tests | KartController, AIController, PowerUpSystem |
| **SceneGraph** | THREE.Scene hierarchy; parent groups for Track, Karts, Pickups, Environment | GameManager mounts; all visual systems write into it |
| **KartController** | Reads InputSystem; applies acceleration, steering, drag; writes kart transform; raises events on wall hit | PhysicsWorld, CheckpointSystem |
| **AIController** | One instance per AI kart; waypoint follower with proportional steering; optional speed scale for difficulty | PhysicsWorld, CheckpointSystem |
| **CameraSystem** | Attaches to player kart; lerp-based chase cam with look-ahead offset | SceneGraph (reads kart transform) |
| **CheckpointSystem** | Sequential invisible trigger planes along the track spline; tracks each kart's lap progress and current position | KartController, AIController, UIOverlay |
| **PowerUpSystem** | Spawns pickup meshes at fixed world positions; sphere-cast to detect collection; applies timed effects | KartController, AIController, SceneGraph |
| **UIOverlay** | Plain HTML/CSS layer over the canvas; renders HUD (lap counter, position, countdown timer, results screen) | GameManager (state events), CheckpointSystem |

---

## Data Flow

### Per-Frame Update Order (inside GameLoop)

```
1. InputSystem.poll()              — snapshot current touch state
2. PhysicsWorld.step(fixedDt)      — integrate positions, resolve collisions
3. KartController.update(fixedDt)  — apply player input → kart velocity → position
4. AIController[].update(fixedDt)  — each AI kart: steer toward next waypoint
5. CheckpointSystem.check()        — test kart positions against trigger planes
6. PowerUpSystem.check()           — test kart positions against pickup spheres
7. CameraSystem.update(dt)         — lerp camera to follow position (uses render dt, not fixed)
8. UIOverlay.sync()                — push lap/position data to DOM
9. renderer.render(scene, camera)  — draw frame
```

The fixed-timestep accumulator pattern decouples physics (step 2-6) from rendering (step 9).
Physics always advances in 16ms chunks regardless of frame rate. Rendering happens once per
`requestAnimationFrame` callback, interpolating between physics states if the frame rate
exceeds the physics rate.

### Information Flows

```
Touch events → InputSystem.state → KartController
KartController.transform → SceneGraph (kart mesh position)
KartController.transform → CameraSystem (chase target)
KartController.lapData → CheckpointSystem → UIOverlay
CheckpointSystem.raceOrder → UIOverlay (positions 1-4)
PhysicsWorld.collisions → PowerUpSystem → KartController (effect applied)
GameManager.state → UIOverlay (show/hide countdown, results)
AssetLoader.onComplete → GameManager (transition LOADING→COUNTDOWN)
```

---

## Game State Machine

```
LOADING
  │ AssetLoader.onComplete
  ▼
COUNTDOWN  (3 → 2 → 1 → GO, 4-second timer)
  │ timer expires
  ▼
RACING
  │ any kart crosses finish after 3 laps
  ▼
FINISH  (brief camera pull-back, confetti)
  │ 2-second delay
  ▼
RESULTS  (position table, "Play Again" button)
  │ user taps replay
  ▼
COUNTDOWN  (reset all karts to starting grid)
```

State transitions are dispatched as events from GameManager. UIOverlay subscribes and
swaps DOM panels. PhysicsWorld and controllers are paused during LOADING, COUNTDOWN,
FINISH, and RESULTS — only RACING runs the full update loop.

---

## Scene Graph Structure

```
THREE.Scene
├── AmbientLight
├── DirectionalLight (sun, casts shadows disabled for perf)
├── TrackGroup
│   ├── TrackMesh (extruded road from CatmullRomCurve3)
│   ├── BoundaryMeshes[] (invisible colliders on road edges)
│   ├── EnvironmentMesh (terrain plane, skybox)
│   └── DecorationInstances (InstancedMesh: trees, cones, barriers)
├── KartGroup
│   ├── PlayerKart
│   │   ├── BodyMesh (GLTF)
│   │   └── WheelGroup (4x child meshes, rotate on drive)
│   └── AIKart[3]
│       └── (same structure as PlayerKart)
├── PickupGroup
│   └── PowerUpMesh[] (spawn/despawn as items collected)
├── ParticleGroup (boost trails, impact sparks)
└── Camera (attached child of CameraAnchor, not of kart)
```

Note: Camera is NOT parented to the kart mesh. A separate `cameraAnchor` Object3D follows
the kart via lerp. This prevents camera jitter from physics micro-corrections.

---

## Key Subsystem Designs

### Game Loop — Fixed Timestep Accumulator

```javascript
const FIXED_DT = 1 / 60;          // 16.67ms physics step
let accumulator = 0;
const MAX_ACCUMULATOR = 0.1;       // panic cap: discard time if tab was hidden

function loop(timestamp) {
  const rawDt = (timestamp - lastTimestamp) / 1000;
  lastTimestamp = timestamp;
  const dt = Math.min(rawDt, MAX_ACCUMULATOR);   // clamp on focus restore

  accumulator += dt;
  while (accumulator >= FIXED_DT) {
    physicsWorld.step(FIXED_DT);
    kartController.update(FIXED_DT);
    aiControllers.forEach(ai => ai.update(FIXED_DT));
    checkpointSystem.check();
    powerUpSystem.check();
    accumulator -= FIXED_DT;
  }

  cameraSystem.update(dt);         // visual smoothing uses real dt
  uiOverlay.sync();
  renderer.render(scene, camera);
  requestAnimationFrame(loop);
}
```

Rationale: fixed physics ensures deterministic kart behaviour across devices running at
different frame rates. The MAX_ACCUMULATOR cap prevents a spiral-of-death when the browser
tab is backgrounded and then restored.

### Camera System — Chase Cam with Look-Ahead

```javascript
// Each frame (real dt, not fixed):
const OFFSET_LOCAL = new THREE.Vector3(0, 2.5, -6);  // behind and above

// Project where kart is heading 0.5s ahead
const lookAheadPoint = kartPosition.clone()
  .addScaledVector(kartVelocity, 0.5);

// Lerp camera anchor position
cameraAnchor.position.lerp(
  kartPosition.clone().add(OFFSET_LOCAL.applyQuaternion(kartQuaternion)),
  0.08   // low value = smooth but slightly laggy
);

// Camera looks toward look-ahead point
camera.lookAt(lookAheadPoint);
```

Lerp factor 0.08 gives smooth follow without feeling disconnected. Values above 0.3 feel
jittery. Look-ahead shifts the focal point slightly forward of the kart so players can
see upcoming corners.

### Input System — Touch State Snapshot

```javascript
// Persistent state object — never read event objects in physics code
const input = { left: false, right: false };

canvas.addEventListener('touchstart', e => {
  for (const touch of e.changedTouches) {
    if (touch.clientX < window.innerWidth / 2) input.left = true;
    else input.right = true;
  }
}, { passive: true });

canvas.addEventListener('touchend', e => {
  // Re-evaluate from all active touches (not just changed)
  input.left = false; input.right = false;
  for (const touch of e.touches) {
    if (touch.clientX < window.innerWidth / 2) input.left = true;
    else input.right = true;
  }
}, { passive: true });
```

Using `e.touches` (all active) on touchend rather than `e.changedTouches` (removed)
prevents ghost states when multiple fingers lift at different times.

### AI Controller — Waypoint Steering

```javascript
class AIController {
  // waypointPath: Array<THREE.Vector3> evenly distributed around track
  // targetWaypointIndex: current target in sequence

  update(dt) {
    const target = this.waypointPath[this.targetWaypointIndex];
    const toTarget = target.clone().sub(this.kart.position);

    // Proportional steering: angle between kart forward and target direction
    const forward = new THREE.Vector3(0, 0, 1).applyQuaternion(this.kart.quaternion);
    const cross = forward.cross(toTarget.normalize());
    const steer = Math.sign(cross.y) * Math.min(Math.abs(cross.y), 1.0);

    this.kart.applySteer(steer * AI_STEER_SPEED * dt);
    this.kart.applyAcceleration(AI_SPEED * dt);

    // Advance waypoint when close enough
    if (toTarget.length() < WAYPOINT_REACH_RADIUS) {
      this.targetWaypointIndex = (this.targetWaypointIndex + 1) % this.waypointPath.length;
    }
  }
}
```

Speed-scale the AI (0.85–1.0x player speed) as a simple difficulty knob. No rubber banding
needed for a solo MVP — keep it honest and tune speed scale until it feels fair.

### Track Representation

The track is defined by a CatmullRomCurve3 (closed loop of ~20 control points). From this
curve three things are derived at startup:

1. **Visual mesh** — `TubeGeometry` or custom ribbon mesh extruded from the curve with
   road width. Use MeshLambertMaterial for cheap per-vertex lighting.
2. **Waypoint array** — `curve.getSpacedPoints(40)` gives 40 evenly-spaced 3D points used
   by AI controllers. Store as a plain array on a shared `TrackData` object.
3. **Checkpoint planes** — Every 8th waypoint becomes an invisible trigger plane
   (BoxGeometry with visible=false) for lap counting.

Wall/boundary collision: place invisible thin BoxGeometry walls along the curve edges (inner
and outer). Use Three.js raycasting from each kart outward left/right to detect proximity
and apply a rebound impulse. Full physics mesh collision is not needed for this scope.

### Asset Loading Pipeline

```javascript
const manager = new THREE.LoadingManager();
manager.onProgress = (url, loaded, total) => {
  updateProgressBar((loaded / total) * 100);
};
manager.onLoad = () => {
  hideLoadingScreen();
  gameManager.transition('COUNTDOWN');
};

// All loaders share the same manager
const gltfLoader = new GLTFLoader(manager);
const textureLoader = new THREE.TextureLoader(manager);

// Kick off all loads before loop starts
gltfLoader.load('/assets/kart.glb', gltf => { kartModel = gltf.scene; });
gltfLoader.load('/assets/track.glb', gltf => { trackModel = gltf.scene; });
textureLoader.load('/assets/ground.webp', tex => { groundTexture = tex; });
```

Loading screen is an HTML overlay (not Three.js). It disappears when `onLoad` fires.
This avoids black-screen time on mobile where first frame can take 500ms+.

### Performance Configuration (Mobile)

```javascript
const renderer = new THREE.WebGLRenderer({
  canvas,
  antialias: false,        // OFF on mobile — use FXAA post-pass if needed
  powerPreference: 'high-performance',
  alpha: false,
  stencil: false,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));  // cap at 1.5x
renderer.shadowMap.enabled = false;   // no real-time shadows on mobile
```

Draw call budget: target < 50 draw calls per frame.
- Track: 1 draw call (single merged mesh)
- Kart bodies: 4 draw calls (1 per kart, shared material)
- Wheels: 1 draw call via InstancedMesh (16 wheels total)
- Decorations (trees, cones): 1-2 InstancedMesh calls
- Pickups: 1 InstancedMesh call
- Environment: 1-2 draw calls

Texture strategy: pack all kart/track textures into a single 1024x1024 atlas. Use WebP
format. Reduces texture bind switches (a major mobile GPU cost).

---

## Suggested Build Order (Dependency Chain)

Building in this order means each phase has something runnable and testable:

```
Phase 1: Renderer + Loop Foundation
  WebGLRenderer setup → requestAnimationFrame loop → THREE.Clock → empty scene renders
  No game logic. Just: black screen with FPS counter. Validates mobile renderer settings.

Phase 2: Track + Camera
  CatmullRomCurve3 → road mesh → static camera looking at track
  Validates asset pipeline and track geometry before adding karts.

Phase 3: Player Kart + Physics
  KartController → velocity/steering math → wall raycasting → kart moves on track
  InputSystem (keyboard first, add touch after physics is stable)

Phase 4: Camera System
  CameraAnchor + lerp follow → look-ahead → chase cam tracks player kart
  Depends on Phase 3 (needs a kart to follow)

Phase 5: AI Karts
  Waypoint array from track curve → AIController x3 → karts drive autonomously
  Checkpoint system can be roughed in here for position tracking

Phase 6: Game State Machine + HUD
  FSM: LOADING → COUNTDOWN → RACING → FINISH → RESULTS
  UIOverlay: lap counter, position, countdown, results screen

Phase 7: Asset Loading Screen
  LoadingManager + progress bar HTML overlay → replaces Phase 1 direct load

Phase 8: Power-Ups
  Pickup spawns → sphere collision → speed boost effect → slow-opponent effect
  Depends on stable kart physics (Phase 3) and AI (Phase 5)

Phase 9: Mobile Polish
  Touch input tuning → pixel ratio cap → draw call audit → orientation lock
  PWA manifest + service worker

Phase 10: Low-Poly Art Pass
  Replace placeholder boxes with GLB models: kart, track decorations, environment
  InstancedMesh for repeated objects. Texture atlas. MeshLambertMaterial.
```

---

## Anti-Patterns to Avoid

### Parenting Camera to Kart Mesh
**What goes wrong:** Physics micro-corrections (kart bounces on uneven track) jitter
directly into the camera view, making the game feel nauseating.
**Instead:** A separate Object3D (`cameraAnchor`) lerp-follows the kart. Camera is a child
of that anchor, not of the kart.

### Reading Input Events Inside Physics Update
**What goes wrong:** Events fire asynchronously on the main thread. Reading inside the fixed
step loop can cause different kart behaviour depending on when the browser dispatches events.
**Instead:** InputSystem snapshots touch state into a boolean object at the start of each
`requestAnimationFrame` callback. Physics reads that snapshot.

### Full Physics Engine for a Kart Game
**What goes wrong:** CANNON.js or Rapier add 100-300 KB to bundle size and complex vehicle
physics that is hard to tune to feel fun. Mobile CPUs struggle with full rigid-body vehicle
simulation at 60Hz.
**Instead:** Custom kinematic controller (velocity + steering math + raycasting for walls).
Karts are not rigid bodies — they are scripted objects that look like they obey physics.
This is how Mario Kart works.

### Running Physics at Variable Delta Time
**What goes wrong:** Physics integrated with variable `dt` produces different results at
30 FPS vs 60 FPS. Karts travel different distances per second. Collision thresholds change.
**Instead:** Fixed-timestep accumulator. Physics always advances in 16ms chunks.

### Enabling Shadows on Mobile
**What goes wrong:** Shadow maps require additional render passes per light, easily halving
frame rate on mobile GPUs.
**Instead:** Bake shadows into diffuse textures, or use a simple blob shadow (projector
circle mesh under the kart).

### Separate Mesh Per Decoration Object
**What goes wrong:** 30 trees = 30 draw calls. On mobile, draw call overhead kills
performance before polygon count does.
**Instead:** InstancedMesh. All trees in one draw call. All trackside cones in one draw
call.

---

## Scalability Considerations

| Concern | MVP (1 track, 4 karts) | Future |
|---------|----------------------|--------|
| Draw calls | < 50, fine for mobile | Stay under 100 per frame |
| Texture memory | 1024px atlas, ~4 MB total | Add second atlas for new track assets |
| Physics | Custom raycasting, <1ms/frame | Still sufficient for up to 8 karts |
| AI | Waypoint steering, negligible CPU | Add rubber-banding or decision tree if needed |
| Tracks | 1 hardcoded spline | Parameterise CatmullRomCurve3 control points in JSON |
| Multiplayer | Not in scope | Would require rearchitecting physics to be server-authoritative |

---

## Sources

- Three.js scene graph: https://threejs.org/manual/en/scenegraph.html (official)
- Three.js GLTFLoader: https://threejs.org/docs/#examples/en/loaders/GLTFLoader (official)
- Fixed-timestep game loop pattern: https://isaacsukin.com/news/2015/01/detailed-explanation-javascript-game-loops-and-timing (MEDIUM confidence — WebSearch, widely cited)
- Three.js smooth chase camera forum: https://discourse.threejs.org/t/solved-smooth-chase-camera-for-an-object/3216 (MEDIUM confidence)
- CatmullRomCurve3 docs: https://threejs.org/docs/#api/en/extras/curves/CatmullRomCurve3 (official)
- Draw calls and mobile performance: https://threejsroadmap.com/blog/draw-calls-the-silent-killer (MEDIUM confidence)
- InstancedMesh docs: https://threejs.org/docs/pages/InstancedMesh.html (official)
- Mobile renderer settings: https://moldstud.com/articles/p-optimizing-three-js-for-mobile-platforms-tips-and-tricks (MEDIUM confidence — multiple sources agree)
- Waypoint AI in racing games: https://ejournal.unida.gontor.ac.id/index.php/FIJ/article/view/4678 (MEDIUM confidence)
- Checkpoint/lap system patterns: https://discussions.unity.com/t/implementing-a-lap-checkpoint-system-racing-game/92376 (MEDIUM confidence — Unity but pattern is engine-agnostic)
- Real kart racer reference: https://github.com/cconsta1/threejs_car_demo (HIGH — live code)
- Touch input for mobile games: https://www.aaronbell.com/mobile-touch-controls-from-scratch/ (MEDIUM confidence)
