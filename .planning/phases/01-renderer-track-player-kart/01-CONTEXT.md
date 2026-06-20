# Phase 1: Renderer, Track & Player Kart - Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a player kart driving on a 3D looping race track in a mobile browser at 30+ FPS, with touch controls working on real hardware. This phase establishes all immutable renderer settings and the kinematic vehicle controller before any game logic is added.

**In scope:** Three.js WebGPURenderer setup, game loop (fixed-timestep), single looping track mesh with boundary walls, player kart with kinematic controller, chase camera, touch input (left/right zones), WebGL context loss handling.

**Out of scope:** AI opponents, checkpoints, race loop, countdown, results, items, PWA — all later phases.

</domain>

<decisions>
## Implementation Decisions

### Renderer
- **D-01:** Three.js WebGPURenderer with automatic WebGL 2 fallback (r0.184.0). Renderer settings are immutable at creation — set all three before any game logic: `antialias: false`, `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`, `shadowMap.enabled = false`.
- **D-02:** Fixed-timestep game loop at 60Hz physics via `requestAnimationFrame` accumulator. Cap delta at 100ms on resume from background (prevents physics explosion after tab switch).
- **D-03:** Add `webglcontextlost` listener and `visibilitychange` handler at renderer creation — graceful "Tap to resume" fallback on iOS backgrounding.

### Track
- **D-04:** Single looping track generated from a `CatmullRomCurve3` (closed loop, ~20 control points). The same spline generates the visual road mesh, the 40-point AI waypoint array (for Phase 2), and checkpoint planes (for Phase 2). Track width: enough for 4 karts side-by-side (~8–10 units wide).
- **D-05:** Boundary walls implemented as invisible collision planes derived from the track spline edges. Kart detects wall proximity via raycasting and bounces laterally. No visible barrier mesh required but low-poly cartoon barriers can be added as polish.
- **D-06:** Low-poly cartoon visual style — flat-shaded geometry (`flatShading: true` on MeshStandardMaterial or MeshLambertMaterial), bright solid colors, no real-time shadows (baked or none). Track surface, grass/ground surround, and a few decoration objects (trees/cones as InstancedMesh) to keep draw calls < 50.

### Player Kart
- **D-07:** Custom kinematic vehicle controller — no physics engine. Kart position updated via velocity + steering math each fixed tick. Speed, turn rate, drag tuned for arcade feel. Kart is a simple low-poly mesh (box body + 4 cylinder wheels as InstancedMesh or child meshes).
- **D-08:** Auto-accelerates forward at all times. Steering applies angular velocity around Y axis. Wall collision detected via forward + side raycasts; lateral component zeroed on wall contact.

### Camera
- **D-09:** Chase camera: separate `cameraAnchor` Object3D that lerp-follows the kart (factor ~0.1). Camera is a child of the anchor, positioned behind and above the kart. Camera is NOT parented directly to kart mesh — prevents physics micro-jitter reaching the view.

### Touch Controls
- **D-10:** Native Pointer Events API — no library. CSS `touch-action: none` on canvas. `{ passive: false }` on all pointer listeners. Left half of screen = steer left, right half = steer right. InputSystem snapshots boolean state `{ left: boolean, right: boolean }` each frame; KartController reads snapshot (never raw events).
- **D-11:** Touch zones are invisible — no visible button UI in Phase 1. Whole screen splits 50/50.

### Project Setup
- **D-12:** Vite 8 + TypeScript 6 project. Entry: `src/main.ts`. Three.js imported as ES module. No framework (React/Vue) — game canvas owns the DOM.

### Claude's Discretion
- Exact kart mesh geometry and color palette — simple placeholder acceptable in Phase 1
- Track control point positions and exact turn count — researcher/planner can design a fun layout
- Exact lerp factors for camera smoothing — tune during implementation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project goals, constraints, core value, key decisions
- `.planning/REQUIREMENTS.md` — v1 requirements; Phase 1 covers TRACK-01, TRACK-02, CTRL-01

### Research
- `.planning/research/STACK.md` — Technology stack with versions and rationale
- `.planning/research/ARCHITECTURE.md` — Component architecture, update order, scene graph design, anti-patterns
- `.planning/research/PITFALLS.md` — 19 pitfalls with prevention strategies; Phase 1 critical pitfalls: §Pixel ratio uncapped, §PCFSoftShadowMap on mobile, §WebGL context lost on iOS backgrounding
- `.planning/research/SUMMARY.md` — Synthesized findings and recommended build order

### Roadmap
- `.planning/ROADMAP.md` — Phase 1 success criteria and phase boundaries

No external specs or ADRs — all decisions captured above and in research docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — greenfield project

### Established Patterns
- None yet — this phase establishes the foundational patterns all subsequent phases follow

### Integration Points
- Track spline (`CatmullRomCurve3`) must be designed to also serve as the AI waypoint source (Phase 2) — export or expose the curve and its 40 evenly-spaced points from the Track module
- `InputSystem` boolean snapshot must be the single interface between touch events and game logic — Phase 2 AI and Phase 3 race FSM both read from the same game loop

</code_context>

<specifics>
## Specific Ideas

- User wants to start building immediately — no additional visual or gameplay preferences specified beyond what's in PROJECT.md (low-poly cartoon, Mario Kart arcade feel, touch controls)
- No specific track shape preference — open to researcher/planner designing a fun looping circuit

</specifics>

<deferred>
## Deferred Ideas

None — user went straight to building without raising additional ideas.

</deferred>

---

*Phase: 1-Renderer, Track & Player Kart*
*Context gathered: 2026-06-20*
