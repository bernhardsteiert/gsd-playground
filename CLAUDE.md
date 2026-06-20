# Claude Code Instructions

## Workflow

This project uses [GSD (Get Shit Done)](https://github.com/taches-ai/get-shit-done-cc) for structured development.

**When asked to build, create, or implement anything new:**
- Do NOT start coding immediately
- Run the `/gsd-new-project` skill if no project has been initialized yet
- Run `/gsd-progress` if a project is already initialized, to pick up where work left off

Always follow the GSD discuss → plan → execute → verify cycle.

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Kart Rush**

A 3D arcade kart racing game that runs as a Progressive Web App (PWA) in the mobile browser — no install required, just open a link. Players race solo against 3 AI opponents on a single fun track, with low-poly cartoon visuals, touch button controls, and basic power-ups in the style of Mario Kart.

**Core Value:** A race you can actually play and finish on your phone, touchscreen controls that feel responsive, in under 60 seconds from opening the link.

### Constraints

- **Platform**: Browser-only PWA — no native APIs, no app store
- **Performance**: Must run at 30+ FPS on a mid-range smartphone (e.g., iPhone 11 / Pixel 4)
- **Bundle size**: Keep asset sizes small for fast load on mobile data
- **No backend**: Fully client-side, no server required
- **Rendering**: WebGL via Three.js — no canvas 2D fallback needed
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### 3D Rendering: Three.js
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| three | 0.184.0 | 3D scene graph, WebGL/WebGPU rendering | 93k GitHub stars, 900k+ npm monthly downloads, best mobile WebGL support, largest community, smallest bundle (~168 kB gzipped), built-in GLTF loader |
### Physics: Rapier 3D (`@dimforge/rapier3d-compat`)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| @dimforge/rapier3d-compat | 0.19.3 | Rigid-body physics, vehicle controller, collision | Rust/WASM — 3x+ performance vs cannon-es in benchmarks. Has native `DynamicRayCastVehicleController` class purpose-built for wheeled vehicles. Three.js ships an official example (`physics_rapier_vehicle_controller`). Active development with 2025 focus on browser WASM performance. |
### Build Tool: Vite 8
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| vite | 8.0.16 | Dev server, HMR, production bundler | Zero-config TS support, native ESM dev server, fast HMR for rapid game iteration, optimised chunking for Three.js tree-shaking |
| vite-plugin-pwa | 1.3.0 | Service worker generation, web app manifest | Zero-config PWA: generates Workbox service worker + manifest, caches all assets for offline play, Android Chrome install prompt |
### Language: TypeScript
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| typescript | 6.0.3 | Type-safe development | Three.js and Rapier ship first-class TS types. Catches physics sync bugs early (position type mismatches, missing awaits on async WASM init). |
### Touch Input: Native Pointer Events API
### Asset Pipeline: GLTF + gltf-transform
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| @gltf-transform/cli | 4.4.0 | Offline mesh + texture optimization | Build step: compress all `.glb` assets before shipping |
# One-time per asset: optimize geometry + compress textures
# For animation-heavy assets use meshopt instead of draco
# (draco cannot compress morph targets)
- ASTC on iOS (iPhone 6+)
- ETC2 on Android
- BC7 on desktop
- Track model: < 2 MB (post-compression)
- Each kart: < 300 kB
- Total initial bundle: < 5 MB including Three.js + Rapier
### Game Loop Pattern
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
## Installation
# Initialize project
# Core runtime
# PWA
# Asset pipeline (dev + CI only)
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
