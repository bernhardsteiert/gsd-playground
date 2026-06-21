# Phase 1: Renderer, Track & Player Kart — Research

**Phase:** 1 — Renderer, Track & Player Kart
**Researched:** 2026-06-21
**Status:** Complete
**Sources:** .planning/research/{STACK,ARCHITECTURE,PITFALLS,SUMMARY}.md + 01-CONTEXT.md

---

## RESEARCH COMPLETE

---

## 1. Project Scaffold: Vite 8 + TypeScript 6 + Three.js 0.184

### Directory Structure

```
kart-rush/
├── index.html              # PWA shell — mounts <canvas id="c">
├── vite.config.ts
├── tsconfig.json
├── package.json
└── src/
    ├── main.ts             # Entry: async init → renderer → game loop
    ├── game/
    │   ├── GameManager.ts  # FSM owner (LOADING → RACING states)
    │   ├── GameLoop.ts     # Fixed-timestep accumulator
    │   └── InputSystem.ts  # Pointer events → boolean snapshot
    ├── scene/
    │   ├── Track.ts        # CatmullRomCurve3 → mesh + waypoints
    │   └── Kart.ts         # Player kart mesh + kinematic controller
    └── systems/
        └── CameraSystem.ts # cameraAnchor + lerp follow
```

### package.json (core deps only)

```json
{
  "dependencies": {
    "three": "0.184.0"
  },
  "devDependencies": {
    "vite": "8.0.16",
    "@types/three": "0.184.0",
    "typescript": "6.0.3"
  }
}
```

### vite.config.ts

```typescript
import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    target: 'es2022',     // required for async/await top-level in browsers
  },
  optimizeDeps: {
    include: ['three'],   // pre-bundle Three.js for fast cold starts
  },
});
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["DOM", "DOM.Iterable", "ESNext"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
```

### index.html

```html
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no" />
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { overflow: hidden; background: #000; }
      #c { display: block; width: 100dvw; height: 100dvh; touch-action: none; }
    </style>
  </head>
  <body>
    <canvas id="c"></canvas>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
```

**Critical:** `touch-action: none` on the canvas is mandatory (Pitfall 4) — prevents browser intercepting touch for scroll/zoom during gameplay.

---

## 2. WebGPURenderer Initialization

### Import Path (Breaking Change in r171+)

Three.js 0.184 ships two entrypoints:
- `import * as THREE from 'three'` — legacy, exports `WebGLRenderer` only
- `import * as THREE from 'three/webgpu'` — exports `WebGPURenderer` with auto-fallback

**Use `three/webgpu`** for this project (D-01 decision).

### Initialization Sequence

`WebGPURenderer.init()` is **async** — unlike `WebGLRenderer`, the GPU device enumeration is a Promise. This means `main.ts` must be async and await init before any scene objects are created.

```typescript
// src/main.ts
import * as THREE from 'three/webgpu';

async function main() {
  const canvas = document.querySelector<HTMLCanvasElement>('#c')!;

  // --- RENDERER CREATION (all immutable settings set here) ---
  const renderer = new THREE.WebGPURenderer({
    canvas,
    antialias: false,          // D-01: must be false — set at construction, immutable
    powerPreference: 'high-performance',
    alpha: false,
    stencil: false,
  });

  await renderer.init();       // mandatory async step for WebGPURenderer

  // D-01: immutable settings — set AFTER init(), BEFORE first render
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.shadowMap.enabled = false;  // D-01: no shadows

  // Handle resize
  window.addEventListener('resize', () => {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
  });

  // D-03: WebGL context loss (set at renderer creation)
  canvas.addEventListener('webglcontextlost', (e) => {
    e.preventDefault();        // signal we'll attempt recovery
    showContextLostOverlay();
  });
  canvas.addEventListener('webglcontextrestored', () => {
    hideContextLostOverlay();
    // renderer is reused; Three.js restores internally
  });

  // Build scene, start game loop...
}

main();
```

### WebGPU vs WebGL Fallback Detection

```typescript
// After renderer.init():
const isWebGPU = renderer.backend?.constructor?.name?.includes('WebGPU') ?? false;
console.log(`Renderer: ${isWebGPU ? 'WebGPU' : 'WebGL 2'}`);
```

This is informational only — the game runs identically on both paths. Do not branch on this.

---

## 3. Fixed-Timestep Game Loop (D-02)

The accumulator pattern ensures physics determinism across all frame rates (Pitfall 7).

```typescript
// src/game/GameLoop.ts
const FIXED_DT = 1 / 60;     // 16.67ms physics step
const MAX_DELTA = 0.1;        // D-02: cap at 100ms — prevents explosion on tab resume

let lastTimestamp = 0;
let accumulator = 0;

function loop(timestamp: number) {
  const rawDt = (timestamp - lastTimestamp) / 1000;
  lastTimestamp = timestamp;
  const dt = Math.min(rawDt, MAX_DELTA);   // clamp (Pitfall 16)

  accumulator += dt;
  while (accumulator >= FIXED_DT) {
    // Physics systems update at fixed rate
    kartController.update(FIXED_DT);
    accumulator -= FIXED_DT;
  }

  // Camera uses real dt (smooth interpolation between physics states)
  cameraSystem.update(dt);

  renderer.render(scene, camera);
  requestAnimationFrame(loop);
}

// Start the loop
requestAnimationFrame((ts) => {
  lastTimestamp = ts;      // initialize to avoid giant first delta
  requestAnimationFrame(loop);
});
```

### visibilitychange Handler (D-03)

```typescript
// D-03: pause loop on tab hide, cap delta on resume
document.addEventListener('visibilitychange', () => {
  if (document.hidden) {
    // Game is backgrounded — rAF will pause automatically
    // but record that we were paused
    isPaused = true;
  } else {
    isPaused = false;
    // Force lastTimestamp reset so next delta is clamped by MAX_DELTA
    lastTimestamp = 0;
  }
});
```

**Why `lastTimestamp = 0`:** When tab is resumed, `timestamp - lastTimestamp` would be enormous (potentially 30+ seconds). Setting `lastTimestamp = 0` makes `rawDt` = `timestamp/1000` (huge), which the `Math.min(rawDt, MAX_DELTA)` clamp reduces to 100ms — the kart advances at most ~1.7 fixed steps on the first resume frame.

---

## 4. Track: CatmullRomCurve3 → Mesh + Waypoints (D-04)

### Spline Definition

```typescript
// src/scene/Track.ts
import * as THREE from 'three/webgpu';

// ~20 control points for a fun oval-with-chicane layout
const TRACK_POINTS = [
  new THREE.Vector3(  0,  0,  30),  // start/finish
  new THREE.Vector3( 15,  0,  25),
  new THREE.Vector3( 30,  0,  15),
  new THREE.Vector3( 35,  0,   0),
  new THREE.Vector3( 30,  0, -15),
  new THREE.Vector3( 20,  0, -28),
  new THREE.Vector3(  5,  0, -35),
  new THREE.Vector3(-10,  0, -30),  // inner chicane right
  new THREE.Vector3(-20,  0, -20),
  new THREE.Vector3(-30,  0, -10),  // wide left bend
  new THREE.Vector3(-35,  0,   5),
  new THREE.Vector3(-30,  0,  20),
  new THREE.Vector3(-15,  0,  30),
  new THREE.Vector3(  0,  0,  35),
];

const trackCurve = new THREE.CatmullRomCurve3(TRACK_POINTS, true);  // true = closed
```

### Road Mesh Generation

`TubeGeometry` extrudes along a curve with configurable radius (= half track width).

```typescript
const TRACK_WIDTH = 10;   // D-04: 8–10 units wide for 4 karts
const TUBE_RADIUS = TRACK_WIDTH / 2;
const TUBE_SEGMENTS = 200;  // smoothness along length
const RADIAL_SEGMENTS = 3;  // flat road: just top, left-wall, right-wall

// Road surface mesh
const roadGeometry = new THREE.TubeGeometry(
  trackCurve,
  TUBE_SEGMENTS,
  TUBE_RADIUS,
  RADIAL_SEGMENTS,
  true              // closed
);
const roadMaterial = new THREE.MeshLambertMaterial({
  color: 0x444444,
  flatShading: true,   // D-06: low-poly cartoon look
});
const roadMesh = new THREE.Mesh(roadGeometry, roadMaterial);
scene.add(roadMesh);
```

**Alternative for flat road:** Instead of TubeGeometry (which creates a tube), create a custom ribbon mesh by sampling points along the curve and building quads. TubeGeometry is simpler to start and can be replaced later.

### AI Waypoints (D-04 — expose for Phase 2)

```typescript
// 40 evenly-spaced points around the loop — share with AIController in Phase 2
const WAYPOINT_COUNT = 40;
export const waypoints: THREE.Vector3[] = trackCurve.getSpacedPoints(WAYPOINT_COUNT);
export const trackCurveRef = trackCurve;  // also export for boundary generation
```

### Boundary Walls (D-05)

Two invisible wall meshes (inner and outer edges of the track) generated from the spline:

```typescript
// Place thin BoxGeometry walls along the track edges
// Inner and outer walls are offset perpendicular to the curve tangent
const WALL_THICKNESS = 0.5;
const WALL_HEIGHT = 2;

// Sample points and tangents at intervals, place wall segments
const N_WALL_SEGS = 60;
for (let i = 0; i < N_WALL_SEGS; i++) {
  const t = i / N_WALL_SEGS;
  const point = trackCurve.getPointAt(t);
  const tangent = trackCurve.getTangentAt(t).normalize();
  const normal = new THREE.Vector3(-tangent.z, 0, tangent.x); // perpendicular in XZ

  // Outer wall
  const outerPos = point.clone().addScaledVector(normal, TUBE_RADIUS + WALL_THICKNESS / 2);
  const outerWall = makeWallSegment(outerPos, tangent, WALL_THICKNESS, WALL_HEIGHT);
  scene.add(outerWall);

  // Inner wall
  const innerPos = point.clone().addScaledVector(normal, -(TUBE_RADIUS + WALL_THICKNESS / 2));
  const innerWall = makeWallSegment(innerPos, tangent, WALL_THICKNESS, WALL_HEIGHT);
  scene.add(innerWall);
}
```

**For raycasting:** Add the wall meshes to a `wallObjects: THREE.Object3D[]` array. KartController casts rays into this array.

---

## 5. Player Kart: Kinematic Controller (D-07, D-08)

No physics engine. The kart is a scripted object with direct transform manipulation.

### Kart State

```typescript
// KartController state
const kartState = {
  position: new THREE.Vector3(0, 0, 30),   // start at first control point
  velocity: new THREE.Vector3(),
  heading: 0,                               // rotation around Y (radians)
  speed: 0,
};

const MAX_SPEED = 20;        // units/sec forward
const ACCELERATION = 8;
const DRAG = 5;              // friction coefficient
const STEER_SPEED = 2.2;    // radians/sec max turn rate
```

### Update Loop (called per fixed tick)

```typescript
function updateKart(dt: number, input: { left: boolean; right: boolean }) {
  // D-08: auto-accelerate forward
  kartState.speed = Math.min(kartState.speed + ACCELERATION * dt, MAX_SPEED);

  // Apply drag
  kartState.speed *= (1 - DRAG * dt);

  // D-08: steering = angular velocity around Y
  if (input.left)  kartState.heading += STEER_SPEED * dt;
  if (input.right) kartState.heading -= STEER_SPEED * dt;

  // Compute velocity from heading + speed
  kartState.velocity.set(
    Math.sin(kartState.heading) * kartState.speed,
    0,
    Math.cos(kartState.heading) * kartState.speed,
  );

  // Tentative next position
  const nextPos = kartState.position.clone().addScaledVector(kartState.velocity, dt);

  // D-08: Wall collision via raycasts (lateral)
  const lateralResult = checkWallCollision(nextPos, kartState.heading);
  if (lateralResult.hit) {
    // Zero the lateral velocity component — bounce kart back along wall normal
    const wallNormal = lateralResult.normal;
    const dot = kartState.velocity.dot(wallNormal);
    if (dot < 0) {
      kartState.velocity.addScaledVector(wallNormal, -dot * 1.2); // 1.2 = slight bounce
    }
    nextPos.copy(kartState.position.clone().addScaledVector(kartState.velocity, dt));
  }

  kartState.position.copy(nextPos);

  // Apply to mesh
  kartMesh.position.copy(kartState.position);
  kartMesh.rotation.y = kartState.heading;
}
```

### Wall Collision Raycasting

```typescript
const _raycaster = new THREE.Raycaster();

function checkWallCollision(pos: THREE.Vector3, heading: number) {
  const KART_HALF_WIDTH = 1.0;  // cast to left and right

  // Left side ray
  const leftDir = new THREE.Vector3(
    Math.cos(heading),
    0,
    -Math.sin(heading),
  );
  _raycaster.set(pos, leftDir);
  const leftHits = _raycaster.intersectObjects(wallObjects);

  if (leftHits.length > 0 && leftHits[0].distance < KART_HALF_WIDTH) {
    return { hit: true, normal: leftHits[0].face!.normal.clone() };
  }

  // Right side ray
  const rightDir = leftDir.clone().negate();
  _raycaster.set(pos, rightDir);
  const rightHits = _raycaster.intersectObjects(wallObjects);

  if (rightHits.length > 0 && rightHits[0].distance < KART_HALF_WIDTH) {
    return { hit: true, normal: rightHits[0].face!.normal.clone() };
  }

  return { hit: false, normal: null };
}
```

---

## 6. InputSystem: Touch State Snapshot (D-10, D-11)

```typescript
// src/game/InputSystem.ts
export const inputState = { left: false, right: false };

export function initInputSystem(canvas: HTMLCanvasElement) {
  // D-10: passive:false required to call preventDefault() in future if needed
  canvas.addEventListener('pointerdown', onPointerDown, { passive: false });
  canvas.addEventListener('pointerup', onPointerUp, { passive: false });
  canvas.addEventListener('pointercancel', onPointerUp, { passive: false });
}

function onPointerDown(e: PointerEvent) {
  e.preventDefault();  // block context menu, scroll, etc.
  const mid = window.innerWidth / 2;
  if (e.clientX < mid) inputState.left = true;
  else inputState.right = true;
}

function onPointerUp(e: PointerEvent) {
  e.preventDefault();
  // Re-evaluate from scratch (multi-pointer safe)
  // On pointer up, we don't know which side to clear without tracking pointer IDs.
  // Simple approach: track active pointers per side.
}
```

**Multi-touch pointer tracking (correct approach):**

```typescript
const activePointers = new Map<number, 'left' | 'right'>();

function onPointerDown(e: PointerEvent) {
  const side = e.clientX < window.innerWidth / 2 ? 'left' : 'right';
  activePointers.set(e.pointerId, side);
  updateInputState();
}

function onPointerUp(e: PointerEvent) {
  activePointers.delete(e.pointerId);
  updateInputState();
}

function updateInputState() {
  inputState.left = false;
  inputState.right = false;
  for (const side of activePointers.values()) {
    if (side === 'left') inputState.left = true;
    else inputState.right = true;
  }
}
```

**D-10:** Physics reads `inputState` once per fixed tick — never directly from events.

---

## 7. Chase Camera System (D-09)

```typescript
// src/systems/CameraSystem.ts
const camera = new THREE.PerspectiveCamera(60, w / h, 0.1, 1000);
const cameraAnchor = new THREE.Object3D();  // NOT parented to kart
scene.add(cameraAnchor);
cameraAnchor.add(camera);

// Local offset: behind and above
camera.position.set(0, 2.5, -6);  // behind in kart's local space
camera.lookAt(new THREE.Vector3(0, 0, 0));  // look at anchor origin

// Per-frame (real dt, not fixed dt):
const LERP_FACTOR = 0.08;  // D-09: ~0.1, smooth without lag

function updateCamera(dt: number) {
  // Target position: kart position + offset in kart's direction
  const kartForward = new THREE.Vector3(
    Math.sin(kartState.heading),
    0,
    Math.cos(kartState.heading),
  );
  const targetPos = kartState.position.clone()
    .addScaledVector(kartForward, -6)   // 6 units behind
    .add(new THREE.Vector3(0, 2.5, 0)); // 2.5 units above

  // Lerp anchor to target
  cameraAnchor.position.lerp(targetPos, LERP_FACTOR);

  // Look-ahead: aim at kart's projected position 0.5s ahead
  const lookTarget = kartState.position.clone()
    .addScaledVector(kartState.velocity, 0.5);
  camera.lookAt(lookTarget);
}
```

**Anti-Pattern avoided (D-09):** Camera is NOT `kartMesh.add(camera)`. The separate `cameraAnchor` absorbs micro-jitter from kart physics corrections.

---

## 8. Kart Mesh (Low-Poly Placeholder, D-06, D-07)

Phase 1 uses procedural geometry. GLTF models come in a later art pass.

```typescript
// src/scene/Kart.ts
function createKartMesh(): THREE.Group {
  const group = new THREE.Group();

  // Body: box
  const bodyGeo = new THREE.BoxGeometry(1.2, 0.5, 2.0);
  const bodyMat = new THREE.MeshLambertMaterial({ color: 0xff3300, flatShading: true });
  const body = new THREE.Mesh(bodyGeo, bodyMat);
  body.position.y = 0.4;
  group.add(body);

  // Wheels: 4 cylinders
  const wheelGeo = new THREE.CylinderGeometry(0.35, 0.35, 0.25, 8);
  const wheelMat = new THREE.MeshLambertMaterial({ color: 0x222222, flatShading: true });
  const wheelPositions = [
    new THREE.Vector3( 0.7, 0.0,  0.7),   // front right
    new THREE.Vector3(-0.7, 0.0,  0.7),   // front left
    new THREE.Vector3( 0.7, 0.0, -0.7),   // rear right
    new THREE.Vector3(-0.7, 0.0, -0.7),   // rear left
  ];
  for (const pos of wheelPositions) {
    const wheel = new THREE.Mesh(wheelGeo, wheelMat);
    wheel.rotation.z = Math.PI / 2;  // orient axle along X
    wheel.position.copy(pos);
    group.add(wheel);
  }

  return group;
}
```

**D-06:** `flatShading: true` on `MeshLambertMaterial` is the key to low-poly cartoon look.
**MeshLambertMaterial vs MeshStandardMaterial:** Lambert is faster on mobile (no PBR math). Use Lambert for Phase 1; optionally upgrade to MeshStandardMaterial with emissive in later art pass.

---

## 9. Scene Lighting (D-06)

No real-time shadows. Two lights sufficient:

```typescript
// Ambient: fills all faces
const ambient = new THREE.AmbientLight(0xffffff, 0.6);
scene.add(ambient);

// Directional: gives shape to flat-shaded geometry
const sun = new THREE.DirectionalLight(0xffffff, 0.8);
sun.position.set(10, 20, 10);
sun.castShadow = false;  // D-01: explicit, even though shadowMap.enabled = false
scene.add(sun);
```

---

## 10. WebGL Context Loss Handler (D-03)

```typescript
function showContextLostOverlay() {
  const el = document.createElement('div');
  el.id = 'ctx-lost';
  el.style.cssText = `
    position: fixed; inset: 0; background: #000c;
    color: #fff; font: 24px sans-serif;
    display: flex; align-items: center; justify-content: center;
  `;
  el.textContent = 'Tap to resume';
  el.addEventListener('click', () => location.reload());
  document.body.appendChild(el);
}

function hideContextLostOverlay() {
  document.getElementById('ctx-lost')?.remove();
}
```

**iOS Reality (Pitfall 3):** Full context restoration on iOS 17+ is unreliable. `webglcontextrestored` may not fire, or may fire but the renderer is in a broken state. The tap-to-reload fallback is the production-grade solution. Do not invest heavily in full renderer re-initialization in Phase 1.

---

## 11. Mobile Performance Budget

| Budget Item | Target | How to Enforce |
|-------------|--------|----------------|
| Draw calls per frame | < 50 | `renderer.info.render.calls` (log per frame in dev) |
| Pixel ratio | ≤ 2x | `Math.min(devicePixelRatio, 2)` |
| Shadows | 0 real-time | `shadowMap.enabled = false` |
| Antialias | Off (MSAA) | `antialias: false` (immutable) |
| Geometry | < 20k triangles total | Procedural meshes are small |
| Track decorations | 1 draw call via InstancedMesh | Trees/cones: single InstancedMesh |

**Dev monitoring:**

```typescript
// Add to game loop for development
if (import.meta.env.DEV) {
  document.title = `${Math.round(1 / dt)} FPS | ${renderer.info.render.calls} draws`;
}
```

---

## 12. Critical Pitfalls for Phase 1

From PITFALLS.md — must address in this phase:

| Pitfall | Risk | Prevention |
|---------|------|-----------|
| Pixel ratio uncapped | 30→10 FPS on iPhone 14 | `Math.min(devicePixelRatio, 2)` at renderer creation |
| PCFSoftShadowMap on mobile | -40% GPU budget | `shadowMap.enabled = false` |
| WebGL context lost on iOS | Blank screen on tab return | `webglcontextlost` listener + tap-to-reload overlay |
| Antialias MSAA | +10-20% GPU cost for no visible gain at 2x DPI | `antialias: false` (immutable at construction) |
| Variable-delta physics | Different kart speed at 30 vs 60 FPS | Fixed-timestep accumulator with 100ms cap |
| rAF resume jump | Physics explosion after tab switch | `visibilitychange` + `lastTimestamp = 0` on resume |
| CORS on file:// | GLTF fetch failure | Always use `vite` dev server, never `file://` |

---

## 13. Phase 1 File Plan (Proposed)

| File | What It Contains |
|------|-----------------|
| `index.html` | Canvas element, CSS (touch-action:none, full-bleed), script module entry |
| `src/main.ts` | async init: renderer → scene → input → track → kart → camera → game loop start |
| `src/game/GameLoop.ts` | Fixed-timestep accumulator, visibilitychange handler, rAF start/stop |
| `src/game/InputSystem.ts` | Pointer events → `{left, right}` boolean snapshot, pointer tracking map |
| `src/scene/Track.ts` | CatmullRomCurve3, TubeGeometry road mesh, boundary wall meshes, waypoints export |
| `src/scene/Kart.ts` | Box+cylinder kart mesh, kinematic controller (update), wall raycast |
| `src/systems/CameraSystem.ts` | cameraAnchor Object3D, lerp follow, look-ahead |
| `src/utils/contextLoss.ts` | webglcontextlost/restored handlers, overlay UI |

---

## 14. Success Criteria Mapping

| Success Criterion | Technical Requirements |
|------------------|----------------------|
| 30+ FPS on iPhone 11 / Pixel 4 with FPS counter visible | Pixel ratio ≤ 2, antialias off, shadows off, draw calls < 50, `document.title` FPS display |
| Touch steers kart left/right; auto-accelerates | InputSystem + KartController: auto-speed, steer from `inputState.left/right` |
| Kart cannot leave track — walls bounce laterally | Boundary wall meshes + lateral raycasts in KartController |
| Smooth chase camera, no jitter | cameraAnchor lerp (not kart-parented), lerp factor 0.08 |
| WebGL context recovered on iOS backgrounding | `webglcontextlost` + `visibilitychange` + tap-to-reload overlay |
