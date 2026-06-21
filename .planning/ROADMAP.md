# Roadmap: Kart Rush

**Project:** Kart Rush
**Core Value:** A race you can actually play and finish on your phone, touchscreen controls that feel responsive, in under 60 seconds from opening the link.
**Granularity:** Coarse
**Mode:** yolo / mvp
**Created:** 2026-06-20

---

## Phases

- [ ] **Phase 1: Renderer, Track & Player Kart** - Immutable renderer settings established; player can drive around a 3D track with touch controls
- [ ] **Phase 2: AI Opponents & Checkpoint System** - 3 AI karts race the player; lap progress and race position tracked for all 4 karts
- [ ] **Phase 3: Race Loop, Items & Results** - Full playable race from countdown through results screen with item boxes functional
- [ ] **Phase 4: PWA Hardening & Orientation Polish** - Game installs as PWA, caches assets offline, and handles portrait/landscape orientation

---

## Phase Details

### Phase 1: Renderer, Track & Player Kart
**Goal**: Player can drive a kart around a complete 3D track on a real mobile phone at 30+ FPS
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: TRACK-01, TRACK-02, CTRL-01
**Success Criteria** (what must be TRUE):
  1. Opening the game on a mid-range phone (iPhone 11 / Pixel 4) shows a 3D low-poly track rendered at 30+ FPS with the FPS counter visible
  2. Player kart accelerates forward automatically and steers left/right via touch zones on the left and right halves of the screen
  3. Kart cannot drive off the track — boundary walls stop lateral movement and bounce the kart back
  4. Chase camera follows the kart smoothly without nauseating jitter or lag
  5. WebGL context is recovered gracefully when app is backgrounded and reopened (no black screen)
**Plans:** 2 plans
Plans:
- [ ] 01-01-PLAN.md — Project scaffold + WebGPURenderer init + fixed-timestep game loop + context loss recovery
- [ ] 01-02-PLAN.md — CatmullRomCurve3 track + invisible boundary walls + kinematic kart controller + touch input + chase camera
**UI hint**: yes

### Phase 2: AI Opponents & Checkpoint System
**Goal**: 3 AI kart opponents race around the track alongside the player, with lap progress and race position tracked accurately for all 4 karts
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: TRACK-03, AI-01, AI-02
**Success Criteria** (what must be TRUE):
  1. 3 AI karts start at the grid and drive continuously around the track, completing full laps without getting permanently stuck
  2. An on-screen position indicator correctly shows each kart's race position (1st–4th) at any point during a race
  3. Lap counter increments correctly for the player kart and each AI kart as they cross the finish line
  4. AI karts that fall far behind the player visibly speed up slightly (rubber-band); AI that gets too far ahead does not cheat noticeably
**Plans**: TBD

### Phase 3: Race Loop, Items & Results
**Goal**: The game can be played start-to-finish — countdown, racing, finish detection, results, and race-again — with item boxes active on track
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: RACE-01, RACE-02, RACE-03, TRACK-04, ITEM-01
**Success Criteria** (what must be TRUE):
  1. A 3-2-1-GO countdown overlay appears before each race and karts cannot move until GO fires
  2. Race ends automatically when any kart completes 3 laps; finish line detection is reliable and never triggers prematurely or late
  3. Results screen shows final positions (1st–4th) for all 4 karts and offers a "Race Again" button that restarts cleanly
  4. Item box objects appear at fixed positions around the track; a collected box disappears and respawns after a visible delay
  5. Player kart can drive through an item box to collect it (box disappears on contact)
**Plans**: TBD
**UI hint**: yes

### Phase 4: PWA Hardening & Orientation Polish
**Goal**: Game is installable from the browser, loads fast on repeat visits, and prompts portrait-mode users to rotate their device
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: PWA-01, PWA-02, CTRL-02
**Success Criteria** (what must be TRUE):
  1. On Android Chrome and iOS Safari, the browser offers an "Add to Home Screen" prompt; launching from the home screen icon opens the game in standalone mode with no browser chrome
  2. After the first load, refreshing the page (or opening offline) loads the game from cache without a network request
  3. Opening the game in portrait mode on a phone shows a rotation prompt overlay; rotating to landscape dismisses it and the game is playable
**Plans**: TBD
**UI hint**: yes

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Renderer, Track & Player Kart | 0/2 | Not started | - |
| 2. AI Opponents & Checkpoint System | 0/0 | Not started | - |
| 3. Race Loop, Items & Results | 0/0 | Not started | - |
| 4. PWA Hardening & Orientation Polish | 0/0 | Not started | - |
