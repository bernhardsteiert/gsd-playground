# Walking Skeleton: Kart Rush

**Phase:** 1 — Renderer, Track & Player Kart
**Created:** 2026-06-21
**Status:** Defined

---

## What the Skeleton Delivers

When Phase 1 completes, opening `localhost:5173` (or the deployed URL) on a real phone:

1. Vite dev server starts — `npm run dev` serves in < 2 seconds
2. Browser loads a black canvas, then a 3D scene appears
3. FPS counter visible in `document.title` (e.g., "58 FPS | 12 draws")
4. A low-poly looping race track is visible — grey road ribbon over a ground plane
5. A red box kart sits on the track and immediately begins driving forward
6. Tapping the left half of the screen steers the kart left; right half steers right
7. Kart cannot leave the track — invisible boundary walls push it back
8. A chase camera follows the kart smoothly from behind
9. Backgrounding the app and returning shows "Tap to resume" overlay, not a black screen

This proves: renderer initializes (WebGPU/WebGL), game loop ticks at 60Hz physics, track geometry renders, kinematic kart controller works, pointer events reach game logic, camera follow system works, context loss recovery works.

---

## Architectural Decisions

### Renderer
| Decision | Value | Rationale |
|----------|-------|-----------|
| Renderer | `WebGPURenderer` (`three/webgpu` import) | Auto-falls back to WebGL2 on iOS; future-proof |
| `antialias` | `false` (immutable at construction) | +10-20% GPU savings; 2x DPI screens don't need MSAA |
| `pixelRatio` | `Math.min(devicePixelRatio, 2)` | Prevents 3x DPI phones burning 9x pixels |
| `shadowMap.enabled` | `false` | Saves ~40% GPU budget on mobile |
| Init sequence | `await renderer.init()` THEN `setPixelRatio` + `setSize` | WebGPURenderer GPU enumeration is async |

### Physics / Vehicle Controller
| Decision | Value | Rationale |
|----------|-------|-----------|
| Engine | None (custom kinematic) | No Rapier/Cannon bundle weight; kart physics are simple enough |
| Timestep | Fixed 60Hz accumulator, `MAX_DELTA = 0.1` | Deterministic physics at all frame rates; caps tab-resume jump |
| Acceleration | Auto-forward, steering = Y-axis angular velocity | Mario Kart arcade feel |
| Wall detection | Left + right raycasts per tick against invisible `wallObjects[]` | No broad-phase needed; < 50 draw calls |

### Track Generation
| Decision | Value | Rationale |
|----------|-------|-----------|
| Spline | `CatmullRomCurve3` (closed, ~14-20 control points) | Single source of truth for road mesh, waypoints, and boundary walls |
| Road mesh | `TubeGeometry` (RADIAL_SEGMENTS=3 for flat road) | Simple, closed, follows curve automatically |
| Track width | 10 units (`TUBE_RADIUS = 5`) | Fits 4 karts side-by-side |
| Boundary walls | 60 invisible `BoxGeometry` segments placed along spline edges | Raycasted by kart; no visible barrier needed in Phase 1 |
| Waypoints export | `trackCurve.getSpacedPoints(40)` | Phase 2 AI controller reads these |

### Camera
| Decision | Value | Rationale |
|----------|-------|-----------|
| Anchor | Separate `Object3D` (not kart child) | Absorbs micro-jitter from kinematic corrections |
| Lerp factor | 0.08 per frame | Smooth follow without nauseating lag |
| Look-ahead | `kart.position + velocity * 0.5` | Anticipates corners, reduces motion sickness |

### Input
| Decision | Value | Rationale |
|----------|-------|-----------|
| API | Native Pointer Events (`pointerdown`, `pointerup`, `pointercancel`) | Single W3C standard; works mouse + touch + stylus |
| `passive` | `false` on all listeners | Allows `preventDefault()` to block scroll/zoom |
| Touch zones | Invisible 50/50 screen split | No UI buttons in Phase 1; whole screen is the control surface |
| State | `Map<pointerId, 'left'|'right'>` → boolean snapshot | Multi-finger safe; physics reads snapshot, never raw events |

### Resilience
| Decision | Value | Rationale |
|----------|-------|-----------|
| Context loss | `webglcontextlost` → `event.preventDefault()` + "Tap to resume" overlay → `location.reload()` | iOS context restore is unreliable; reload is the safe path |
| Tab hide/resume | `visibilitychange` → `lastTimestamp = 0` on resume | Prevents physics explosion after tab switch |

---

## Directory Layout

```
kart-rush/
├── index.html                    # Canvas shell — touch-action:none on #c
├── vite.config.ts                # ES2022 target, pre-bundle three
├── tsconfig.json                 # ESNext modules, bundler resolution, strict
├── package.json                  # three@0.184.0, vite@8.0.16, typescript@6.0.3
└── src/
    ├── main.ts                   # async init: renderer → scene → input → track → kart → camera → loop
    ├── game/
    │   ├── GameLoop.ts           # Fixed-timestep accumulator + visibilitychange handler
    │   └── InputSystem.ts        # Pointer events → { left: boolean, right: boolean } snapshot
    ├── scene/
    │   ├── Track.ts              # CatmullRomCurve3 → road mesh + wall meshes + waypoints export
    │   └── Kart.ts               # Box+wheel mesh + kinematic controller (update) + wall raycasts
    ├── systems/
    │   └── CameraSystem.ts       # cameraAnchor lerp-follow + look-ahead
    └── utils/
        └── contextLoss.ts        # webglcontextlost/restored handlers + overlay UI
```

---

## What Phase 2 Inherits

| Export / Interface | From | Used By |
|-------------------|------|---------|
| `waypoints: THREE.Vector3[]` (40 points) | `src/scene/Track.ts` | AI waypoint follower |
| `trackCurveRef: CatmullRomCurve3` | `src/scene/Track.ts` | Checkpoint plane generation |
| `wallObjects: THREE.Object3D[]` | `src/scene/Track.ts` | Shared with AI kart raycasters |
| `inputState: { left: boolean, right: boolean }` | `src/game/InputSystem.ts` | Race FSM (pause/menu overrides) |
| `GameLoop` start/stop | `src/game/GameLoop.ts` | Race countdown freeze in Phase 3 |
| `CameraSystem` | `src/systems/CameraSystem.ts` | Extended in Phase 2 for position HUD look-at |

---

## Tech Stack

| Package | Version | Role |
|---------|---------|------|
| `three` | `0.184.0` | 3D scene graph + WebGPU/WebGL renderer |
| `vite` | `8.0.16` | Dev server + production bundler |
| `typescript` | `6.0.3` | Type safety |
| `@types/three` | `0.184.0` | Three.js TypeScript types |

No physics engine. No UI framework. No PWA plugin (Phase 4).

---

## Performance Targets

| Metric | Target | Enforcement |
|--------|--------|-------------|
| FPS | 30+ on iPhone 11 / Pixel 4 | `document.title` FPS display in DEV mode |
| Draw calls | < 50 | `renderer.info.render.calls` logged in DEV |
| Pixel ratio | ≤ 2x | `Math.min(devicePixelRatio, 2)` |
| Shadows | 0 real-time | `shadowMap.enabled = false` (immutable) |
| Antialias | Off | `antialias: false` (immutable at construction) |

---

*Walking Skeleton defined: 2026-06-21*
*Establishes all patterns subsequent phases build on without renegotiating.*
