# Technology Stack

**Project:** Kart Rush — browser-based 3D mobile kart racing PWA
**Researched:** 2026-06-20
**Overall confidence:** HIGH (core stack), MEDIUM (asset pipeline specifics)

---

## Recommended Stack

### 3D Rendering: Three.js

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| three | 0.184.0 | 3D scene graph, WebGL/WebGPU rendering | 93k GitHub stars, 900k+ npm monthly downloads, best mobile WebGL support, largest community, smallest bundle (~168 kB gzipped), built-in GLTF loader |

**Use `WebGPURenderer` (not `WebGLRenderer`)** — since r171 (Sep 2025), Three.js ships a unified renderer. Import via `import * as THREE from 'three/webgpu'`. The renderer auto-detects WebGPU and falls back to WebGL 2 with zero code change. This future-proofs the game while maintaining full iOS Safari 16/17 compatibility via the WebGL 2 fallback path.

```typescript
import * as THREE from 'three/webgpu';

const renderer = new THREE.WebGPURenderer({
  canvas: document.querySelector('#canvas'),
  antialias: false,         // disable on mobile — use FXAA in post if needed
  powerPreference: 'high-performance',
});
await renderer.init();
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // cap at 2x — critical for mobile perf
renderer.setSize(window.innerWidth, window.innerHeight);
```

**Why not Babylon.js:** Bundle is ~1.4 MB vs Three.js's ~168 kB. Mobile load time on 4G matters here; shaving 1.2 MB is measurable. Babylon also brings physics, audio, and editor tooling you won't use for this project.

**Why not PlayCanvas:** Cloud-editor workflow doesn't fit a code-first game. PlayCanvas is well-suited for teams with non-technical artists; this is a solo/small-team pure-code project.

**Why not raw WebGL:** Massive development overhead with no benefit. Three.js abstracts the boilerplate without meaningful performance cost.

---

### Physics: Rapier 3D (`@dimforge/rapier3d-compat`)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| @dimforge/rapier3d-compat | 0.19.3 | Rigid-body physics, vehicle controller, collision | Rust/WASM — 3x+ performance vs cannon-es in benchmarks. Has native `DynamicRayCastVehicleController` class purpose-built for wheeled vehicles. Three.js ships an official example (`physics_rapier_vehicle_controller`). Active development with 2025 focus on browser WASM performance. |

The `-compat` variant bundles the WASM as base64 inside the JS file. This avoids WASM fetch issues with service workers and simplifies the Vite build. Slightly larger than raw rapier3d but eliminates an entire class of deployment headaches.

```typescript
import RAPIER from '@dimforge/rapier3d-compat';

await RAPIER.init(); // must await — WASM load is async
const world = new RAPIER.World({ x: 0, y: -9.81, z: 0 });

// Vehicle setup
const vehicleController = world.createVehicleController(chassisBody);
vehicleController.addWheel(/* position, direction, axle, suspension, radius */);
vehicleController.setWheelSteering(0, steerAngle);  // front wheels
vehicleController.setWheelEngineForce(2, engineForce); // rear wheels
vehicleController.setWheelBrake(0, brakeForce);
```

**Why not cannon-es:** Last published August 2022 (4 years ago). No active maintenance. `RaycastVehicle` works but requires manual tuning with no upstream bug fixes. Rapier benchmarks 3x faster with 1000 physics bodies — critical for a game with 4 karts + track colliders.

**Why not Ammo.js:** Emscripten-compiled C++ (Bullet), 1.4 MB+ WASM blob, harder to tree-shake. Verbose API. Rapier's API is cleaner and its WASM is smaller.

**Why not custom physics:** Vehicle suspension, wheel friction, and collision response are genuinely hard. Don't build what a battle-tested library provides.

---

### Build Tool: Vite 8

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| vite | 8.0.16 | Dev server, HMR, production bundler | Zero-config TS support, native ESM dev server, fast HMR for rapid game iteration, optimised chunking for Three.js tree-shaking |
| vite-plugin-pwa | 1.3.0 | Service worker generation, web app manifest | Zero-config PWA: generates Workbox service worker + manifest, caches all assets for offline play, Android Chrome install prompt |

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        globPatterns: ['**/*.{js,css,html,png,gltf,glb,ktx2,webp}'],
        maximumFileSizeToCacheInBytes: 10 * 1024 * 1024, // 10MB for game assets
      },
      manifest: {
        name: 'Kart Rush',
        short_name: 'KartRush',
        display: 'fullscreen',
        orientation: 'landscape',
        background_color: '#000000',
        theme_color: '#FF6600',
        icons: [/* 192x192, 512x512 */],
      },
    }),
  ],
  build: {
    target: 'es2022',
    rollupOptions: {
      output: {
        manualChunks: {
          three: ['three'],
          rapier: ['@dimforge/rapier3d-compat'],
        },
      },
    },
  },
});
```

**Why not webpack:** Slower builds, more configuration overhead. Vite is the community standard for browser games in 2025.

**Why not Parcel:** Less ecosystem tooling for game-specific optimizations.

**Important PWA caveat — iOS Safari:** The `orientation: 'landscape'` manifest key is NOT supported on iOS Safari. You cannot lock screen orientation on iOS via manifest or the Screen Orientation API when running in Safari. Mitigation: overlay a "please rotate your device" UI when `window.innerWidth < window.innerHeight`, which covers all platforms reliably.

---

### Language: TypeScript

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| typescript | 6.0.3 | Type-safe development | Three.js and Rapier ship first-class TS types. Catches physics sync bugs early (position type mismatches, missing awaits on async WASM init). |

Target `ES2022` in `tsconfig.json` — matches the baseline for iOS 16+ and Android Chrome on modern phones.

---

### Touch Input: Native Pointer Events API

**No library needed.** Use the W3C Pointer Events API directly:

```typescript
canvas.addEventListener('pointerdown', onPointerDown, { passive: true });
canvas.addEventListener('pointerup', onPointerUp, { passive: true });
canvas.addEventListener('pointermove', onPointerMove, { passive: true });
```

`passive: true` is critical — it signals to the browser that the handler won't call `preventDefault()`, allowing the browser to scroll/zoom without waiting for the event handler. This eliminates the 300ms jank on touch interactions.

For this game's control scheme (left half = steer left, right half = steer right, auto-accelerate), track active pointer IDs per touch zone. No gesture library is needed for this simple two-zone layout.

**Why not Touch Events API:** Pointer Events is the W3C standard, fully supported on all modern mobile browsers (iOS 13+, Android Chrome). Touch Events are still supported but the unified Pointer Events model handles mouse+touch+stylus with one code path.

**Why not a library (Hammer.js, etc.):** 12 kB bundle overhead for tap/swipe detection the game doesn't need. Two screen zones + pointerdown/up is 20 lines of code.

---

### Asset Pipeline: GLTF + gltf-transform

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| @gltf-transform/cli | 4.4.0 | Offline mesh + texture optimization | Build step: compress all `.glb` assets before shipping |

**Recommended asset preparation pipeline:**

```bash
# One-time per asset: optimize geometry + compress textures
npx @gltf-transform/cli optimize kart.glb kart.optimized.glb \
  --compress draco \
  --texture-compress ktx2

# For animation-heavy assets use meshopt instead of draco
# (draco cannot compress morph targets)
npx @gltf-transform/cli optimize track.glb track.optimized.glb \
  --compress meshopt \
  --texture-compress ktx2
```

KTX2 with Basis Universal supercompression transcodes at load time to:
- ASTC on iOS (iPhone 6+)
- ETC2 on Android
- BC7 on desktop

GPU-compressed textures stay compressed in VRAM — critical for mobile's limited GPU memory. A low-poly kart game's textures should fit comfortably under 50 MB VRAM total.

Three.js loads KTX2 via the built-in `KTX2Loader` (requires the `basis_transcoder` WASM worker in the public directory).

**Target asset budgets:**
- Track model: < 2 MB (post-compression)
- Each kart: < 300 kB
- Total initial bundle: < 5 MB including Three.js + Rapier

---

### Game Loop Pattern

No external game loop library needed. Use a fixed-timestep pattern on top of `requestAnimationFrame`:

```typescript
const FIXED_DT = 1 / 60; // 60Hz physics
let accumulator = 0;
let lastTime = performance.now();

function gameLoop() {
  requestAnimationFrame(gameLoop);
  const now = performance.now();
  let dt = (now - lastTime) / 1000;
  lastTime = now;

  // Clamp to prevent spiral of death on tab re-focus
  if (dt > 0.25) dt = 0.25;
  accumulator += dt;

  while (accumulator >= FIXED_DT) {
    world.step(); // Rapier physics at fixed 60Hz
    updateKartLogic(FIXED_DT);
    accumulator -= FIXED_DT;
  }

  // Interpolate render position between physics frames
  renderer.render(scene, camera);
}
```

This keeps physics deterministic at 60Hz regardless of whether the device runs at 60Hz, 90Hz, or 120Hz refresh rates. Without this, a player on a 120Hz phone moves twice as fast as one on 60Hz.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| 3D Rendering | Three.js 0.184 | Babylon.js | 8x larger bundle (1.4 MB vs 168 kB); built-in physics/editor not needed |
| 3D Rendering | Three.js 0.184 | PlayCanvas | Cloud-editor workflow; not suited for code-first small team |
| 3D Rendering | Three.js 0.184 | Raw WebGL | Massive boilerplate with no performance upside |
| Renderer API | WebGPURenderer | WebGLRenderer | WebGPURenderer auto-falls back; WebGPU is faster where available (Safari 26, Chrome, Firefox) |
| Physics | Rapier 0.19.3 | cannon-es 0.20.0 | cannon-es last published 2022, no maintenance; 3x slower |
| Physics | Rapier 0.19.3 | Ammo.js | 1.4 MB WASM, verbose API, no maintenance advantage |
| Physics | Rapier 0.19.3 | Custom arcade physics | Vehicle suspension is genuinely hard; Rapier's `DynamicRayCastVehicleController` covers the use case |
| Build Tool | Vite 8 | webpack | Slower builds, more config overhead |
| Touch Input | Native Pointer Events | Hammer.js | 12 kB overhead for unneeded gestures; two-zone scheme is simple |
| Touch Input | Native Pointer Events | Touch Events API | Pointer Events is the unified W3C standard; same support matrix on target platforms |
| Orientation Lock | CSS media query + overlay | Screen Orientation API | `lock()` not supported in iOS Safari; manifest orientation not honoured either |

---

## Installation

```bash
# Initialize project
npm create vite@latest kart-rush -- --template vanilla-ts
cd kart-rush

# Core runtime
npm install three @dimforge/rapier3d-compat

# PWA
npm install -D vite-plugin-pwa

# Asset pipeline (dev + CI only)
npm install -D @gltf-transform/cli
```

---

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| Three.js as renderer | HIGH | npm (93k stars, 900k downloads/mo), official docs |
| WebGPURenderer + WebGL fallback | HIGH | Three.js official docs, r171 release notes |
| Rapier for physics | HIGH | Official Rapier docs, Three.js official example `physics_rapier_vehicle_controller`, benchmarks |
| cannon-es being unmaintained | HIGH | npm last-published date: August 2022 |
| Vite 8 + vite-plugin-pwa | HIGH | npm versions confirmed, official docs |
| KTX2 texture compression | MEDIUM | Multiple sources agree; implementation details need validation during Phase 1 |
| iOS orientation lock limitation | HIGH | MDN docs, multiple PWA guides confirm |
| iOS 16+ WebGL support | HIGH | WebGL on iOS since iOS 8; specific WebGPU requires iOS 26 (Safari 26) |
| Fixed timestep game loop | HIGH | Standard game dev practice; multiple sources confirm need for mobile 120Hz devices |

---

## Sources

- Three.js npm: https://www.npmjs.com/package/three (version 0.184.0 confirmed)
- Three.js WebGPURenderer docs: https://threejs.org/manual/en/webgpurenderer.html
- Three.js Rapier vehicle example: https://threejs.org/examples/physics_rapier_vehicle_controller.html
- Rapier DynamicRayCastVehicleController: https://rapier.rs/javascript3d/classes/DynamicRayCastVehicleController.html
- Rapier npm (`@dimforge/rapier3d-compat`): https://www.npmjs.com/package/@dimforge/rapier3d-compat (0.19.3)
- Dimforge 2025 review: https://dimforge.com/blog/2026/01/09/the-year-2025-in-dimforge/
- vite-plugin-pwa: https://vite-pwa-org.netlify.app/guide/
- Three.js mobile performance: https://tympanus.net/codrops/2025/02/11/building-efficient-three-js-scenes-optimize-performance-while-maintaining-quality/
- Web game engines 2026: https://app.cinevva.com/blog/2026-06-09-web-game-engines-2026-comparison.html
- WebGPU browser support: https://webo360solutions.com/blog/webgpu-browser-support/
- gltf-transform CLI: https://gltf-transform.dev/cli
- Pointer Events vs Touch Events: https://weblogtrips.com/technology/touch-events-vs-pointer-events-mobile-ui-2026/
- PWA iOS limitations: https://brainhub.eu/library/pwa-on-ios
- Screen Orientation API: https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/lock
- Three.js vs Babylon.js bundle size: https://blog.logrocket.com/three-js-vs-babylon-js/
- cannon-es GitHub: https://github.com/pmndrs/cannon-es
