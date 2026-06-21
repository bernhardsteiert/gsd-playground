# Domain Pitfalls

**Domain:** Browser-based 3D mobile kart racing game (PWA, Three.js, iOS Safari + Android Chrome)
**Researched:** 2026-06-20

---

## Critical Pitfalls

These cause rewrites, completely broken experiences, or make the game unshippable on target platforms.

---

### Pitfall 1: Pixel Ratio Rendering at Full Device DPI

**What goes wrong:** Using `renderer.setPixelRatio(window.devicePixelRatio)` without a cap causes the GPU to render at 3x or even 5x resolution on modern phones. A device with a 3x ratio renders 9x the pixels compared to 1x, which collapses frame rate.

**Why it happens:** Developers assume matching device pixel ratio is always correct. It is for static pages; it is destructive for real-time 3D.

**Consequences:** Frame rate drops to 10–15 FPS on mid-range phones. On iPhone 14/15, pixel ratios reach 3; some Android flagships reach 3.5+.

**Prevention:** Cap unconditionally: `renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))`. The perceptible difference between 2x and 3x is negligible; the GPU cost is not.

**Detection warning signs:** Frame rate is fine in desktop Chrome DevTools mobile emulation (which simulates ratio 2) but terrible on real device.

**Phase to address:** Phase 1 (renderer bootstrap) — set this once during WebGLRenderer creation and never touch it again.

---

### Pitfall 2: PCFSoftShadowMap on Mobile GPU

**What goes wrong:** The default recommendation for "good-looking shadows" in Three.js tutorials is `renderer.shadowMap.type = THREE.PCFSoftShadowMap`. On mobile GPUs this causes a severe performance penalty — the linear interpolation pass is extremely costly on mobile/Adreno/Mali GPUs.

**Why it happens:** Tutorials are written for desktop. PCFSoftShadowMap was explicitly identified as unsuitable for mobile devices and VR headsets in the Three.js codebase itself.

**Consequences:** Shadow rendering alone can consume 40–60% of the frame budget on mid-range mobile. Drop from 30 FPS to under 20 FPS.

**Prevention:** For a kart racer, use one of these strategies in order of preference:
1. Disable real shadows entirely (`renderer.shadowMap.enabled = false`), use a baked lightmap or a simple blob shadow (a flat circle decal under each kart).
2. If shadows are needed, use `THREE.BasicShadowMap` with a small shadow map resolution (512x512 max).
3. Never use `PCFSoftShadowMap` on mobile without profiling on a real device first.

**Detection warning signs:** GPU frame time spikes. Check with Safari's Timeline profiler or Chrome's GPU DevTools.

**Phase to address:** Phase 1 (scene/renderer setup). Establish "no real-time shadows on mobile" as a project rule before any kart or track assets are added.

---

### Pitfall 3: WebGL Context Lost on iOS When Tab is Backgrounded

**What goes wrong:** On iOS 17+ Safari, backgrounding the tab (switching to another app or the home screen) causes Three.js to emit `WebGLRenderer: Context Lost`. The canvas goes blank. The user returns to a white screen.

**Why it happens:** iOS aggressively reclaims GPU memory from backgrounded web pages. This has been an open issue in Three.js since at least 2023 (GitHub issue #26829) and affects Babylon.js, Pixi.js, and vanilla WebGL equally.

**Consequences:** Players who switch apps mid-race (e.g., check a message) return to a broken game with no obvious recovery path.

**Prevention:**
- Listen for `webglcontextlost` and call `event.preventDefault()` to signal you will attempt recovery.
- Listen for `webglcontextrestored` and re-initialize the renderer and all GPU resources.
- Also listen for the `visibilitychange` event: when `document.hidden` becomes `true`, pause the game loop; on `false`, resume and check renderer state.
- Accept that full recovery is unreliable and consider a graceful fallback: show a "Tap to resume" screen that forces a page reload if the context cannot be restored.

**Detection warning signs:** Console shows `THREE.WebGLRenderer: Context Lost.` during testing. Reproduce by opening the game in iOS Safari, switching to another app for 10+ seconds, then returning.

**Phase to address:** Phase 1 (game loop setup). Build the `visibilitychange` handler from the start. Context recovery should be a Phase 2 hardening task.

---

### Pitfall 4: Touch Events Intercepted by Browser Gesture Handling

**What goes wrong:** Adding `touchstart`/`touchmove` event listeners without `{ passive: false }` makes it impossible to call `preventDefault()`, so the browser still performs its default behaviors: pinch-zoom, scroll, and pull-to-refresh. During gameplay, players accidentally zoom in or trigger the iOS Safari address bar.

**Why it happens:** Chrome 56+ changed the default for document-level touch listeners to `passive: true` to improve scrolling performance. Developers who don't explicitly set `{ passive: false }` get the error "Unable to preventDefault inside passive event listener."

**Consequences:** Mid-race the page zooms in or scrolls, disorienting the player. Pull-to-refresh fires on Android Chrome when steering up. This is unrecoverable without a page reload.

**Prevention:**
- Set `touch-action: none` via CSS on the game canvas element. This is the most reliable single fix.
- Add all canvas touch listeners with `{ passive: false }`.
- Add `user-scalable=no` to the viewport meta tag (note: iOS 10+ ignores this for accessibility reasons, so CSS `touch-action` is still required).
- Block `contextmenu` event to prevent long-press menus on Android.

**Detection warning signs:** "Unable to preventDefault inside passive event listener" in browser console. Pinch-zoom possible during gameplay.

**Phase to address:** Phase 2 (touch controls implementation). Do not add touch listeners without `{ passive: false }` and `touch-action: none`.

---

### Pitfall 5: iOS Fullscreen and Orientation Lock Incompatibility

**What goes wrong:** The `Screen Orientation API` (`screen.orientation.lock('landscape')`) is not supported on iOS Safari. The web manifest `"orientation": "landscape"` field is also ignored on iOS. On iPhone, `requestFullscreen()` is not available at all (only on iPad).

**Why it happens:** Apple's iOS Safari intentionally limits these APIs. As of mid-2026, there is no native orientation lock for iPhone Safari PWAs.

**Consequences:** Players open the game in portrait and are not forced into landscape. The 3D scene renders in the wrong aspect ratio and touch zones are misaligned.

**Prevention:**
- Use a CSS media query for portrait orientation to show a dedicated "Rotate your phone" overlay.
- Apply a CSS `transform: rotate(90deg)` to the entire app in portrait mode as a software fallback (works but produces letterboxing).
- On Android, call `screen.orientation.lock('landscape')` inside a user gesture handler (button tap), not automatically on page load.
- Accept that iPhone users in Safari (non-PWA) cannot be force-locked to landscape — provide a clear visual prompt instead.

**Detection warning signs:** Game renders in portrait on iOS without a rotation prompt.

**Phase to address:** Phase 2 (PWA setup and layout). Design the rotation prompt as a first-class screen, not an afterthought.

---

### Pitfall 6: Web Audio API Blocked on iOS Until User Gesture

**What goes wrong:** iOS Safari blocks all `AudioContext` playback until a user interaction occurs. Attempting to play audio (engine sounds, countdown beeps, music) before a touch event results in silence with no error thrown.

**Why it happens:** Apple's autoplay policy requires explicit user consent for audio. Additionally, if the device's physical ringer switch is set to silent/vibrate, Safari blocks Web Audio entirely — this is separate from the user gesture requirement.

**Consequences:** The game's countdown sound, music, and effects play silently. Developers test on desktop where this restriction doesn't apply and ship a broken audio experience.

**Prevention:**
- Create a single `AudioContext` and call `.resume()` inside the first touch handler (e.g., the game's "Start Race" button tap).
- Do not create `Audio()` objects for sound effects — use `AudioContext` with `AudioBuffer` exclusively, as `Audio()` objects cause jank on mobile on each `play()` call.
- Show a "Tap to Start" screen as the game entry point. This serves double duty: user gesture for audio unlock + orientation check.
- Document the ringer switch issue in QA notes; it is not fixable in code.

**Detection warning signs:** Audio works fine on desktop, silent on iOS Safari. Check `audioContext.state` — it will be `"suspended"` until unlocked.

**Phase to address:** Phase 3 (audio/game loop integration). Audio unlock must be part of the first interaction screen design.

---

## Moderate Pitfalls

These cause poor game feel, user frustration, or significant debugging time, but are recoverable without rewrites.

---

### Pitfall 7: Frame-Rate-Dependent Physics (No Fixed Timestep)

**What goes wrong:** Updating physics with `delta` directly from `requestAnimationFrame` causes the simulation to run faster at 60 FPS and slower at 30 FPS. Kart speed, collision response, and AI behavior all become inconsistent.

**Why it happens:** Tutorials often pass the raw rAF delta to `world.step(delta)`. This is convenient but physically incorrect.

**Consequences:** On a device that drops to 20 FPS during heavy scenes, karts slow down and physics behave erratically. On different devices, the same race feels different. Tunneling (karts passing through walls at high speed) becomes more likely at low frame rates where one physics step covers a large distance.

**Prevention:**
- Use a fixed timestep accumulator pattern: accumulate real elapsed time and step the physics engine in fixed increments (1/60 s).
- Cap the maximum accumulated time per frame (e.g., 4 steps max) to prevent the "spiral of death" when frames are very slow.
- Interpolate rendered position between the previous and current physics state for smooth visuals.
- For cannon-es: `world.fixedStep(1/60, deltaTime, 3)` provides this built-in.

**Detection warning signs:** Kart speed changes when frame rate drops. Physics behaves differently on a powerful laptop vs. a mid-range phone.

**Phase to address:** Phase 2 (physics integration). Establish fixed timestep before any vehicle tuning begins.

---

### Pitfall 8: High Draw Call Count

**What goes wrong:** Each unique mesh+material combination in the scene generates a separate GPU draw call. A track with 50 road segments, 20 trees, 10 barriers, and 4 karts can easily exceed 200 draw calls — well above the mobile target of 50 or fewer.

**Why it happens:** Naively adding objects to the scene without batching. Using separate meshes for each lamp post, each tree, each barrier.

**Consequences:** CPU-GPU command overhead becomes the bottleneck before the GPU is even saturated. Frame rate suffers even when scenes look simple.

**Prevention:**
- Use `THREE.InstancedMesh` for any object repeated more than 3 times (trees, barriers, item boxes).
- Merge static geometry (the track surface, grass, walls) into a single `BufferGeometry` using `BufferGeometryUtils.mergeGeometries()`.
- Use texture atlases so multiple objects share one material.
- Profile with `renderer.info.render.calls` — log this every frame during development and set an alert if it exceeds 50.

**Detection warning signs:** `renderer.info.render.calls` above 50. CPU-side frame time is high even when the scene is visually simple.

**Phase to address:** Phase 2 (track and scene building). Establish instancing strategy before populating the track with decorations.

---

### Pitfall 9: Antialias Cost on Mobile

**What goes wrong:** `new THREE.WebGLRenderer({ antialias: true })` enables MSAA. On desktop this is GPU-side and cheap. On mobile GPUs, MSAA is expensive on tile-based architectures (most mobile GPUs use tile-based deferred rendering where MSAA resolving is costly).

**Why it happens:** `antialias: true` is the tutorial default. The renderer cannot change this setting after creation.

**Consequences:** 10–20% increase in GPU frame time on mid-range mobile for a marginal visual improvement, particularly because high pixel ratios (even capped at 2x) already minimize visible aliasing.

**Prevention:**
- Set `antialias: false` for mobile. At 2x pixel ratio on a 6-inch display, aliasing is barely perceptible.
- If anti-aliasing is desired, use FXAA as a post-processing pass (lower overhead on mobile tile GPUs than MSAA).
- Detect mobile at startup and conditionally enable/disable: use `navigator.userAgentData` or a simple screen width heuristic.

**Detection warning signs:** GPU frame time is higher than expected. Testing with `antialias: false` and measuring the difference.

**Phase to address:** Phase 1 (renderer creation). Cannot be changed at runtime.

---

### Pitfall 10: Rubber-Band AI That Feels Like Cheating

**What goes wrong:** Implementing rubber-band AI by giving losing opponents a direct speed boost makes players feel cheated — they cannot maintain a lead regardless of skill, and opponents magically catch up without making better decisions.

**Why it happens:** Speed multiplier rubber-banding is the simplest implementation of catch-up mechanics and is widely seen in tutorials. The Mario Kart franchise uses it, but subtly and in conjunction with item probability weighting.

**Consequences:** Players complain the AI "cheats." The race result feels predetermined. Skilled play feels unrewarded.

**Prevention:**
- Do not apply raw speed multipliers to AI karts. Instead, weight item/power-up distribution: losing AI gets better items more often.
- Scale AI decision quality (waypoint smoothing, cornering speed) rather than raw speed.
- If speed rubber-banding is used, cap it at a modest multiplier (1.1x max) and only activate it when the gap is large (> 2 kart lengths).
- Ensure AI opponents can also lose — they should make occasional visible mistakes (wide corners, slow acceleration after a collision) so players feel they earned the win.

**Detection warning signs:** In playtesting, players comment that opponents always catch up no matter how well they race.

**Phase to address:** Phase 3 (AI implementation). Establish rubber-band policy before any AI speed tuning.

---

### Pitfall 11: Camera Lag That Reads as Sluggish Controls

**What goes wrong:** A third-person follow camera that uses a high spring/lerp factor (slow to follow) makes the kart feel like it responds slowly to input, even when the physics are instant. Players perceive camera lag as control lag.

**Why it happens:** Overly smooth cameras are aesthetically pleasing in cutscenes but fight the player's expectation of immediate visual feedback during gameplay.

**Consequences:** Controls feel unresponsive. Players steer more aggressively to compensate, causing overcorrection and a frustrating spiral.

**Prevention:**
- Keep camera follow latency low: a lerp factor of 0.1–0.15 per frame at 60 FPS gives smooth motion without feeling detached.
- Separate camera position follow (can lag slightly) from camera look-at target (should be nearly instant or at the kart's predicted future position).
- Camera should anticipate: aim ahead of the kart in the direction of velocity, not directly at the kart's current position.
- Playtest by having someone unfamiliar with the project play for 2 minutes. If their first comment is about controls feeling slow, tighten the camera.

**Detection warning signs:** Subjective feeling of control lag during playtesting, despite confirmed-instant input handling.

**Phase to address:** Phase 2 (camera system). Camera tuning is iterative — allocate explicit tuning time before declaring a phase complete.

---

### Pitfall 12: GLTF/Asset Loading Blocking the Main Thread

**What goes wrong:** Loading large GLTF models synchronously or without texture decompression off the main thread freezes the page during load. `TextureLoader` and `ImageBitmapLoader` both have known main-thread blocking issues in Three.js, particularly when decoding sRGB textures.

**Why it happens:** `loader.load()` is callback-based but the decode and GPU upload steps happen synchronously on the main thread. A single 2MB GLTF with multiple textures can freeze the main thread for 200–500ms on mobile.

**Consequences:** A visible freeze (white screen or static frame) during the loading screen. On mobile, this can cause "page not responding" warnings.

**Prevention:**
- Use `loader.loadAsync()` with `async/await` for cleaner async loading.
- Use KTX2/Basis compressed textures with the `KTX2Loader` — these decompress on the GPU rather than the CPU.
- Show a proper loading progress bar using `THREE.LoadingManager` callbacks so users know loading is happening.
- Keep individual asset files small: aim for the entire game to be under 5MB total compressed (track, 4 karts, UI, audio).
- Pre-bundle assets via Vite to avoid waterfall loading of many small files.

**Detection warning signs:** Main thread shows long tasks (>50ms) in Chrome DevTools Performance tab during asset loading.

**Phase to address:** Phase 2 (asset pipeline). Establish asset budget and loading strategy before creating game assets.

---

### Pitfall 13: Waypoint AI Cutting Corners or Getting Stuck

**What goes wrong:** A simple waypoint-following AI that aims directly at the next waypoint will cut inside corners aggressively, taking lines that look unrealistic, and can clip into track boundaries on tight bends. Too few waypoints cause the AI to take only one line and feel robotic.

**Why it happens:** Waypoints placed along the track center are straightforward but don't encode ideal racing lines. Direct waypoint-to-waypoint aiming produces straight-line paths between points.

**Consequences:** AI opponents visually clip through barriers. If CCD or collision response is imperfect, the AI kart gets stuck against walls and stops racing.

**Prevention:**
- Place waypoints at the racing line, not the track center, for the single track in scope.
- Add a small random lateral offset (±0.5 kart widths) to each AI's waypoint target so opponents take slightly different lines and don't drive in a single-file convoy.
- Add a stuck-detection timeout: if an AI kart's speed falls below a threshold for >2 seconds, teleport it back to the nearest waypoint facing forward (a common rescue mechanic).
- Keep the waypoint count moderate: 30–60 waypoints for a lap-length track is sufficient.

**Detection warning signs:** AI kart clips through the inner wall on corners. Two AI karts occupy the same pixel-precise line. An opponent stops moving after a collision.

**Phase to address:** Phase 3 (AI implementation). Stuck-detection rescue logic is a separate sub-task.

---

### Pitfall 14: PWA Update Serving Stale Cached Assets

**What goes wrong:** After deploying a bug fix or asset update, players on mobile receive the old cached version because the service worker continues to serve from cache. The stale version can persist for days.

**Why it happens:** A cache-first service worker strategy caches assets aggressively (which is correct for offline support) but requires explicit cache invalidation on updates. If the service worker file itself is cached with a long TTL, even updates to the worker go undetected.

**Consequences:** Players report a bug that you fixed days ago. Asset changes (new track, fixed model) are invisible to returning users.

**Prevention:**
- Use Workbox (via Vite plugin) with `generateSW` — it handles cache versioning automatically via asset hash suffixes.
- Never cache the service worker script itself at the HTTP level — set `Cache-Control: no-cache` on `sw.js`.
- Implement a "new version available, refresh?" prompt using the `waiting` service worker lifecycle event so users can explicitly update.
- During development, use "Update on reload" in Chrome DevTools Application tab to always get fresh assets.

**Detection warning signs:** You deployed a fix but reports of the old bug continue. `Application > Service Workers` in DevTools shows a worker in "waiting" state.

**Phase to address:** Phase 4 (PWA/offline setup). Service worker update flow must be built before beta testing.

---

## Minor Pitfalls

These are annoying and discoverable quickly but easy to fix once identified.

---

### Pitfall 15: Three.js Memory Leaks from Undisposed Geometries and Textures

**What goes wrong:** Three.js does not automatically free GPU memory when objects go out of scope. Geometries, materials, and textures allocated on the GPU persist until explicitly disposed. In a game that reloads levels or removes objects at runtime (e.g., power-up pick-ups, explosions), this causes gradual GPU memory growth.

**Prevention:** Call `geometry.dispose()`, `material.dispose()`, and `texture.dispose()` on every removed object. For textures loaded from GLTF with ImageBitmap, also call `texture.source.data.close()` before `texture.dispose()` (Three.js bug #23953). Create a `disposeObject(object3D)` helper that traverses the object tree and disposes all descendants.

**Phase to address:** Phase 2 (scene management). Create the dispose helper once; use it everywhere objects are removed.

---

### Pitfall 16: requestAnimationFrame State After Tab Hidden

**What goes wrong:** When a player switches tabs or receives a phone call, `rAF` pauses on most browsers. When they return, the next `rAF` delta is the full elapsed time (potentially 30–60 seconds), which causes physics and animation to "jump" or explode.

**Prevention:** Listen to the `visibilitychange` event. When `document.hidden` becomes `true`, pause the game loop and record the pause time. On resume, clamp the first delta to a maximum of 100ms regardless of actual elapsed time.

**Phase to address:** Phase 2 (game loop). One-time implementation, high reward.

---

### Pitfall 17: Texture Sizes Not Power-of-Two (NPOT)

**What goes wrong:** Three.js automatically resizes non-power-of-two textures to the nearest power of two via a canvas element. The resized canvas is never garbage collected due to internal references, causing a persistent memory leak. NPOT textures also cannot use mipmapping on older WebGL implementations.

**Prevention:** Export all textures at power-of-two dimensions (256, 512, 1024). For a low-poly game, most textures should be 512x512 or smaller. Use a Vite asset pipeline step to enforce this.

**Phase to address:** Phase 2 (asset pipeline definition). Set the rule before creating any textures.

---

### Pitfall 18: Ghost Touches and Multi-Touch Interference

**What goes wrong:** On capacitive touchscreens, the palm of the hand or cheek resting against the screen generates phantom touch events. With a split left/right control scheme, a palm touch on one side can override steering direction or trigger both sides simultaneously.

**Prevention:**
- Track touch identifiers (`touch.identifier`) per zone, not just "any touch in this zone."
- The "left half = steer left, right half = steer right" scheme is robust: evaluate which half each touch is in independently. Multiple simultaneous touches should not conflict.
- Ignore touches from more than 2 simultaneous contact points (a third touch point is almost always accidental).

**Phase to address:** Phase 2 (touch controls). Test on a real device with the phone held in two hands, not just desktop emulation.

---

### Pitfall 19: CORS Errors with GLTF Files During Local Development

**What goes wrong:** Opening `index.html` directly from the filesystem (`file://`) causes CORS errors when Three.js attempts to fetch GLTF files and their textures. GLTFs with separate `.bin` and texture files fail entirely.

**Prevention:** Always develop with a local HTTP server (`npx vite` or `npx serve`). Never use `file://` for development. Document this in the project README. Using GLB (binary GLTF) instead of multi-file GLTF reduces the risk of missing references and simplifies asset serving.

**Phase to address:** Phase 1 (project bootstrap). Set up Vite from day one.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Renderer bootstrap | Pixel ratio, antialias, shadow map type | Set all three during WebGLRenderer creation — they are either immutable or hard to change later |
| Game loop | Fixed timestep, visibility hidden delta | Establish accumulator pattern before physics integration |
| Touch controls | Passive listeners, pinch-zoom, palm touches | CSS `touch-action: none` + `{ passive: false }` before any gameplay testing |
| Track and scene | Draw call count, NPOT textures, memory leaks | Add `renderer.info.render.calls` logging from the start |
| Physics integration | Vehicle instability, tunneling at high speed | Use cannon-es `RaycastVehicle`; tune suspension stiffness; test at max kart speed |
| AI implementation | Rubber-band cheating, waypoint sticking | Restrict speed multipliers; add stuck-detection teleport |
| Camera system | Camera lag reading as control lag | Separate position lerp from look-ahead; playtest with naive users |
| Audio integration | iOS AudioContext locked | Unlock on first touch; use AudioBuffer not Audio() |
| PWA/service worker | Stale cache on deploy, iOS 50MB limit | Use Workbox with hash-suffixed assets; keep total asset size under 10MB |
| iOS fullscreen/landscape | No orientation lock on iPhone | CSS media query rotation prompt is the only reliable fallback |
| Context loss | iOS backgrounding destroys WebGL context | `webglcontextlost` + `visibilitychange` handler from the start |

---

## Sources

- Three.js mobile performance: [100 Three.js Tips (2026)](https://www.utsubo.com/blog/threejs-best-practices-100-tips) | [Three.js Journey Performance Tips](https://threejs-journey.com/lessons/performance-tips)
- Shadow map types: [Three.js forum: PCF Soft shadow performance](https://github.com/mrdoob/three.js/issues/15577) | [Mastering Shadows in Three.js](https://dev.to/peter3riding/mastering-shadows-in-threejs-setup-configuration-and-optimization-39nn)
- WebGL context loss: [Three.js forum: Context Lost iOS 17](https://discourse.threejs.org/t/three-js-broken-on-ios-17-with-context-lost/58025) | [GitHub issue #26829](https://github.com/mrdoob/three.js/issues/26829)
- Touch events: [Chrome passive event listeners](https://developer.chrome.com/blog/scrolling-intervention) | [MDN touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action) | [Passive listener trap](https://vcfvct.wordpress.com/2026/01/25/debugging-touch-controls-in-vanilla-js-the-passive-listener-trap/)
- iOS PWA limitations: [PWA iOS Limitations 2026](https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide) | [Vinova iOS PWA guide](https://vinova.sg/navigating-safari-ios-pwa-limitations/)
- Screen orientation: [MDN ScreenOrientation.lock](https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation/lock) | [PWA Orientation Lock](https://hearthero.medium.com/locking-orientation-for-ionic-pwas-7c75c5bb3639)
- Web Audio iOS: [Autoplay guide MDN](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay) | [Unlock Web Audio Safari](https://www.mattmontag.com/web/unlock-web-audio-in-safari-for-ios-and-macos)
- Fixed timestep: [Fix Your Timestep! (Gaffer on Games)](http://vodacek.zvb.cz/archiv/681.html) | [cannon-es docs](https://pmndrs.github.io/cannon-es/docs/)
- Rubber-band AI: [Game Design Snacks: Rubber band AI](https://game-design-snacks.fandom.com/wiki/Poorly_implemented_rubber_band_AI_in_driving/racing_games_frustrates_the_player)
- Asset loading: [Three.js issue: SRGB blocking main thread](https://github.com/mrdoob/three.js/issues/22631) | [Evil Martians: OffscreenCanvas](https://evilmartians.com/chronicles/faster-webgl-three-js-3d-graphics-with-offscreencanvas-and-web-workers)
- Memory management: [Three.js memory leak: texture dispose](https://github.com/mrdoob/three.js/issues/23953) | [How to dispose of objects](https://neofixer.arizona.edu/css/CSSOrbit/asteroidJS/three/docs/manual/en/introduction/How-to-dispose-of-objects.html)
- PWA caching: [web.dev PWA Update](https://web.dev/learn/pwa/update) | [Taming PWA Cache](https://iinteractive.com/resources/blog/taming-pwa-cache-behavior)
- Cannon-es vehicle: [Three.js forum: Cannon.js racing game tutorial](https://discourse.threejs.org/t/tutorial-on-using-three-js-with-physics-library-cannon-js-to-create-a-car-racing-game/5279)
- Visibility / rAF throttle: [MDN Page Visibility API](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API) | [Chrome timer throttling](https://developer.chrome.com/blog/timer-throttling-in-chrome-88)
