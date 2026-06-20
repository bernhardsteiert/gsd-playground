# Research Summary: Kart Rush

**Synthesized:** 2026-06-20
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md, PROJECT.md

---

## Executive Summary

Kart Rush is a browser-based 3D arcade kart racing PWA targeting mobile (iOS Safari 16+, Android Chrome). The domain is well-understood — Mario Kart-style kart racers have a clear feature canon, and the Three.js ecosystem has mature solutions for every subsystem required. Research consensus is strong: use Three.js 0.184 with `WebGPURenderer` (auto-fallback to WebGL 2), custom kinematic vehicle physics rather than a full rigid-body engine, and a fixed-timestep game loop. The architecture is straightforward — a coordinator-driven loop with a top-level FSM, no full ECS framework needed at this scope.

The highest risk area is mobile platform constraints: iOS Safari imposes hard limits on orientation lock, WebGL context recovery after backgrounding, and Web Audio unlock that cannot be worked around — only mitigated with defensive patterns established from day one. Performance on mid-range phones is the other primary constraint; pixel ratio capping, draw call budgeting via InstancedMesh, disabled real-time shadows, and a sub-5 MB asset budget are non-negotiable requirements, not polish items.

The recommended build order unblocks the core race loop as fast as possible: renderer foundation first, then track and player kart, then AI opponents, then the complete FSM with HUD, then power-ups, and finally PWA hardening. Each phase leaves something runnable. The feature set for v1 is clearly bounded — no multiplayer, no multiple tracks, no persistence, no kart selection — and research confirms this is the correct scope for validating the core value proposition.

---

## Key Findings

### Stack (from STACK.md) — Confidence: HIGH

| Technology | Version | Role |
|------------|---------|------|
| Three.js (WebGPURenderer) | 0.184.0 | 3D rendering; auto-detects WebGPU, falls back to WebGL 2 |
| TypeScript | 6.0.3 | Type-safe development; Three.js ships first-class types |
| Vite | 8.0.16 | Dev server, HMR, production bundler with tree-shaking |
| vite-plugin-pwa | 1.3.0 | Service worker + manifest generation via Workbox |
| @gltf-transform/cli | 4.4.0 | Offline asset pipeline: Draco/meshopt compression + KTX2 textures |

**Physics decision:** Research explicitly recommends a **custom kinematic controller** — velocity + steering math + raycasting for wall detection — rather than Rapier or cannon-es. This is how Mario Kart works: karts are scripted objects that look like they obey physics. Full physics engines add bundle weight and are hard to tune for arcade feel on mobile. cannon-es is also abandoned (last published August 2022).

**Touch input:** Native Pointer Events API directly — no library. `{ passive: false }` plus CSS `touch-action: none` on the canvas.

**Asset budgets:** Track < 2 MB, each kart < 300 kB, total initial bundle < 5 MB including Three.js.

**Critical renderer settings (set at creation, immutable):**
- `antialias: false` — MSAA is expensive on mobile tile-based GPUs
- `setPixelRatio(Math.min(window.devicePixelRatio, 2))` — cap pixel ratio unconditionally
- `shadowMap.enabled = false` — PCFSoftShadowMap alone can consume 40-60% of frame budget on mobile

### Features (from FEATURES.md) — Confidence: HIGH

**Table stakes (must ship in v1):**
- Core race loop: 3-2-1-GO countdown, lap counter, position indicator (1st-4th), finish line detection, results screen
- Track: visible boundaries, checkpoint system (~20-50 trigger volumes), respawn on going off-track
- Touch controls: left/right steer zones, auto-accelerate, item use button, orientation rotation prompt
- Power-ups: item boxes on track, speed boost, projectile to slow opponents, item HUD display
- AI: 3 waypoint-following opponents that complete races, with subtle rubber-banding
- Mobile UX: pause/resume, loading screen with progress, race-again flow
- PWA: web app manifest, cache-first service worker, HTTPS
- Game feel (juice): engine sound, item pickup/boost/hit sounds, speed lines/blur overlay

**Differentiators (defer to v2+):**
- Drift mechanic with mini-turbo boost reward (high complexity, strong differentiator)
- Position-weighted item distribution
- Dynamic music intensity
- Minimap (defer unless playtesting reveals disorientation)
- "Add to Home Screen" proactive prompt

**Anti-features (never build in v1):**
Online multiplayer, split-screen, kart selection, global leaderboards, multiple tracks, gyroscope steering, kart progression system, in-app purchases, custom track editor, detailed suspension physics, AI difficulty settings.

**Feature dependency chain (drives build order):**
```
Checkpoint system -> position calculation -> HUD indicator
Checkpoint system -> lap counting -> finish detection -> result screen
AI waypoints -> AI lap counting -> AI finishes -> full result screen
Touch steer zones -> all player movement
Loading screen -> any gameplay
```

### Architecture (from ARCHITECTURE.md) — Confidence: HIGH

**Pattern:** Coordinator-driven game loop. Central `GameLoop` drives all subsystems each tick. Top-level FSM (`GameManager`) owns state. No ECS framework — simple class-per-system composition.

**FSM states:** `LOADING -> COUNTDOWN -> RACING -> FINISH -> RESULTS -> COUNTDOWN` (cycle)

**Component responsibilities:**
- `AssetLoader` — wraps `THREE.LoadingManager`, emits progress 0-100%
- `GameManager` — FSM owner, owns renderer and clock, orchestrates all subsystems
- `GameLoop` — fixed-timestep accumulator (16ms / 60Hz physics), provides `dt` to each subsystem
- `InputSystem` — snapshots touch state into `{ left, right }` boolean object; physics never reads events directly
- `KartController` — reads InputSystem; applies velocity/steering/drag; raises wall hit events
- `AIController` — one instance per AI kart; waypoint follower with proportional steering
- `CameraSystem` — lerp-based chase cam attached to separate `cameraAnchor` Object3D (NOT the kart mesh)
- `CheckpointSystem` — sequential invisible trigger planes; tracks each kart's lap progress and race position
- `PowerUpSystem` — sphere-cast pickup detection; applies timed effects
- `UIOverlay` — plain HTML/CSS over canvas; subscribes to GameManager state events

**Per-frame update order (inside fixed step):**
1. `InputSystem.poll()` -> 2. `KartController.update()` -> 3. `AIController[].update()` -> 4. `CheckpointSystem.check()` -> 5. `PowerUpSystem.check()` -> 6. `CameraSystem.update()` (real dt) -> 7. `UIOverlay.sync()` -> 8. `renderer.render()`

**Track representation:** `CatmullRomCurve3` (closed loop, ~20 control points) generates visual mesh, AI waypoint array (40 evenly-spaced points via `curve.getSpacedPoints(40)`), and checkpoint planes (every 8th waypoint).

**Scene graph draw call target:** < 50 draw calls per frame. All repeated objects (trees, barriers, item boxes, wheels) use `InstancedMesh`. Static geometry merged via `BufferGeometryUtils.mergeGeometries()`.

**Confirmed anti-patterns:**
- Camera parented to kart mesh (physics jitter goes directly into view) — use separate lerp anchor
- Reading input events inside physics update (async timing inconsistency) — snapshot to boolean state
- Full physics engine for vehicle (hard to tune, bundle cost) — custom kinematic controller
- Variable delta time physics (kart speed is frame-rate dependent) — fixed timestep accumulator
- Real-time shadows on mobile — bake or use blob shadow decal

### Pitfalls (from PITFALLS.md) — Confidence: HIGH

**Critical (must address before affected system ships):**

1. **Pixel ratio uncapped** (Phase 1) — cap at 2x; 3x pixel ratio = 9x pixels = 10-15 FPS on mid-range phones
2. **PCFSoftShadowMap on mobile** (Phase 1) — disable real-time shadows entirely; PCF soft shadows consume 40-60% of frame budget on mobile GPUs
3. **WebGL context lost on iOS backgrounding** (Phase 1 setup, Phase 2 hardening) — `webglcontextlost` listener + `visibilitychange` handler from day one; graceful "Tap to resume" fallback
4. **Touch events intercepted by browser** (Phase 2) — CSS `touch-action: none` on canvas + `{ passive: false }` on all listeners; pinch-zoom and pull-to-refresh will fire without this
5. **iOS orientation lock impossible** (Phase 2) — Screen Orientation API and manifest `orientation` field both ignored on iOS Safari; CSS media query rotation overlay is the only solution
6. **Web Audio blocked until user gesture on iOS** (Phase 3) — create one `AudioContext`, call `.resume()` inside first touch handler; "Tap to Start" entry screen solves this; never use `Audio()` objects for sound effects

**Moderate (address in relevant phase):**

7. Frame-rate-dependent physics — fixed-timestep accumulator before any physics tuning
8. High draw call count — InstancedMesh + geometry merging; log `renderer.info.render.calls` from Phase 1; alert if > 50
9. Rubber-band AI feeling like cheating — cap speed multiplier at 1.1x max; prefer item weighting over raw speed; AI must visibly make mistakes
10. Camera lag reading as control lag — lerp factor 0.1-0.15; separate position follow from look-ahead aim point
11. GLTF loading blocking main thread — KTX2 compressed textures; `LoadingManager` progress bar; keep total assets under 5 MB
12. Waypoint AI getting stuck — 30-60 waypoints; ±0.5 kart-width lateral jitter; stuck-detection teleport after 2 seconds below speed threshold
13. PWA stale cache after deploy — Workbox with hash-suffixed assets; `Cache-Control: no-cache` on sw.js; "new version available" prompt

**Minor (establish rules early):**

14. Three.js memory leaks — `disposeObject()` helper traversing the object tree
15. rAF delta explosion after tab hidden — clamp first delta on `visibilitychange` resume to 100ms max
16. Non-power-of-two textures — all textures at 256/512/1024px; enforce in asset pipeline
17. Ghost touches (palm/cheek) — track touch identifiers per zone; ignore 3+ simultaneous contacts

---

## Implications for Roadmap

Research consensus from ARCHITECTURE.md and FEATURES.md aligns on the same build order. Suggested 7-phase structure:

### Phase 1 — Renderer and Loop Foundation
**Rationale:** Mobile renderer settings are immutable at creation. Establish performance baseline before any game logic exists. Validates target device frame rate before building anything on top.
**Delivers:** Canvas with WebGPURenderer running at target FPS on a real mid-range phone; FPS counter visible; `renderer.info.render.calls` logging active.
**Must avoid:** Pitfalls 1 (pixel ratio), 2 (shadows), 9 (antialias) — all set at renderer creation, cannot be changed at runtime.
**Research flag:** Standard patterns. No deep research needed.

### Phase 2 — Track + Player Kart + Touch Controls
**Rationale:** Everything else depends on a kart moving on a track. Establishes the custom kinematic controller and touch input system before AI or power-ups are added. Camera must be proven non-nauseating before any further gameplay testing.
**Delivers:** Player can drive around the full track with touch controls. Kart bounces off track boundaries. Chase camera follows. Visibilitychange and context loss handlers in place.
**Features:** CatmullRomCurve3 track mesh, boundary raycasting, InputSystem, KartController, CameraSystem.
**Must avoid:** Pitfalls 4 (passive touch listeners), 7 (variable delta physics), 11 (GLTF blocking), 15 (memory leaks), 16 (rAF tab hidden delta).
**Research flag:** Camera tuning is iterative — allocate explicit time before declaring phase complete.

### Phase 3 — AI Opponents + Checkpoint System
**Rationale:** CheckpointSystem is a prerequisite for position tracking and lap counting, which unblocks the HUD and result screen. AI opponents must race before full race experience can be tested end-to-end.
**Delivers:** 3 AI karts race the player; lap progress tracked for all 4 karts; position indicator works.
**Features:** AIController x3, CheckpointSystem, lap counting, position ranking.
**Must avoid:** Pitfall 12 (waypoint AI getting stuck) — stuck-detection teleport is a required sub-task. Pitfall 9 (rubber-band cheating) — speed multiplier policy decided before AI tuning begins.
**Research flag:** AI waypoint placement and rubber-banding policy need a decision during planning.

### Phase 4 — Complete Race Loop FSM + HUD
**Rationale:** GameManager FSM and UIOverlay deliver the full race experience: countdown to results to race-again. Without this phase the game cannot be played start-to-finish.
**Delivers:** Full playable race from countdown through results screen with working race-again loop.
**Features:** GameManager FSM (LOADING/COUNTDOWN/RACING/FINISH/RESULTS), UIOverlay, finish line detection, results screen, pause/resume, loading progress bar.
**Must avoid:** Pitfall 3 (WebGL context lost) — visibilitychange handler must already be in place from Phase 2.
**Research flag:** Standard patterns. No deep research needed.

### Phase 5 — Power-Ups
**Rationale:** Power-ups depend on stable kart physics (Phase 2) and AI (Phase 3). Item effects on AI karts require the CheckpointSystem position data.
**Delivers:** Item boxes on track, speed boost and projectile items functional for player and AI, item HUD icon.
**Features:** PowerUpSystem, item box spawns with respawn, speed boost effect, projectile collision, item HUD display.
**Research flag:** Projectile collision approach (sphere cast vs. dedicated trigger) may benefit from focused research during planning.

### Phase 6 — Audio, Juice, and Mobile Polish
**Rationale:** Audio and visual feedback are table stakes for game feel but depend on the core loop being complete. iOS audio constraints make this a risk area requiring careful implementation. Orientation rotation prompt is required for all users opening in portrait.
**Delivers:** Full audio, speed lines/blur overlay, orientation rotation prompt, "Tap to Start" entry screen (which doubles as the iOS audio unlock gesture).
**Features:** AudioContext unlock via "Tap to Start" screen, engine/item/boost/hit sounds, speed line overlay, item pickup flash.
**Must avoid:** Pitfall 6 (iOS AudioContext) — "Tap to Start" screen is the unlock mechanism, not an afterthought.
**Research flag:** Audio file formats (MP3 vs. OGG vs. WebM) for iOS/Android Web Audio API need confirmation during planning.

### Phase 7 — PWA, Assets, and Launch Hardening
**Rationale:** Service worker and final asset pipeline are the last gate before public distribution. Low-poly GLB models replace placeholder geometry. Stale cache update flow must be in place before any external testing.
**Delivers:** Installable PWA with offline support, KTX2-compressed assets, sub-5 MB bundle, "new version available" update prompt.
**Features:** vite-plugin-pwa (Workbox generateSW), web app manifest, KTX2 asset compression pipeline via @gltf-transform/cli, stale cache update flow, asset budget validation.
**Must avoid:** Pitfall 14 (stale PWA cache) — `Cache-Control: no-cache` on sw.js and Workbox hash-suffixed assets required.
**Research flag:** KTX2 basis_transcoder WASM worker placement in Vite public directory needs validation.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (Three.js, Vite, TypeScript) | HIGH | Version-confirmed from npm; official docs; clear decision rationale for all alternatives |
| Physics approach (custom kinematic) | HIGH | Multiple sources confirm; Three.js community supports this pattern; Rapier and cannon-es explicitly ruled out for this scope |
| Features (table stakes) | HIGH | Strong domain consensus from Mario Kart series and mobile racing genre; feature dependencies clearly charted |
| Architecture (FSM + coordinator) | HIGH | Pattern verified across multiple live projects; component boundaries and update order well-documented |
| Mobile pitfalls (iOS constraints) | HIGH | MDN docs and multiple PWA guides confirm; no workarounds exist — mitigations are specific and actionable |
| Asset pipeline (KTX2) | MEDIUM | Multiple sources agree on the approach; basis_transcoder worker setup needs hands-on validation |
| AI rubber-banding tuning | MEDIUM | Policy is clear; specific multiplier values and waypoint counts require playtesting iteration |
| Minimap implementation | LOW | Deferred; not researched in depth; revisit after Phase 3 if playtesting reveals player disorientation |

**Overall confidence: HIGH**

---

## Gaps to Address During Planning

1. **Projectile collision approach** — sphere cast vs. dedicated trigger body; needs decision in Phase 5 planning.
2. **KTX2 basis transcoder setup** — the `basis_transcoder.wasm` worker placement in Vite public directory needs validation during Phase 7 planning.
3. **Audio file formats** — MP3 vs. OGG vs. WebM for Web Audio API on iOS/Android; confirm during Phase 6 planning.
4. **AI waypoint count and placement** — 30-60 recommended by research; exact placement relative to track spline requires hands-on iteration during Phase 3.
5. **Minimap** — flagged as optional; assess need empirically during Phase 3 once AI and checkpoint system are working.

---

## Sources (Aggregated)

- Three.js npm + docs: https://threejs.org / https://www.npmjs.com/package/three (v0.184.0)
- Three.js Rapier vehicle example: https://threejs.org/examples/physics_rapier_vehicle_controller.html
- Rapier (dimforge): https://rapier.rs / https://dimforge.com/blog/2026/01/09/the-year-2025-in-dimforge/
- vite-plugin-pwa: https://vite-pwa-org.netlify.app/guide/
- gltf-transform CLI: https://gltf-transform.dev/cli
- MDN — Screen Orientation API, touch-action, Page Visibility API, Autoplay policy
- Three.js GitHub issues: context lost (#26829), texture dispose (#23953), SRGB blocking (#22631)
- Fix Your Timestep! (Gaffer on Games): http://vodacek.zvb.cz/archiv/681.html
- Mario Kart Racing Wiki — item and checkpoint system: https://mariokart.fandom.com/wiki/Item
- Game Developer Magazine — rubber banding as design requirement: https://www.gamedeveloper.com/design/rubber-banding-as-a-design-requirement
- Web game engines 2026 comparison: https://app.cinevva.com/blog/2026-06-09-web-game-engines-2026-comparison.html
- Three.js mobile performance: https://tympanus.net/codrops/2025/02/11/building-efficient-three-js-scenes-optimize-performance-while-maintaining-quality/
- PWA iOS limitations: https://brainhub.eu/library/pwa-on-ios / https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide
- Unlock Web Audio on iOS: https://www.mattmontag.com/web/unlock-web-audio-in-safari-for-ios-and-macos
- draw-calls on mobile: https://threejsroadmap.com/blog/draw-calls-the-silent-killer
