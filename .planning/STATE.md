# Project State: Kart Rush

**Last updated:** 2026-06-20
**Session:** Roadmap creation

---

## Project Reference

**Core Value:** A race you can actually play and finish on your phone, touchscreen controls that feel responsive, in under 60 seconds from opening the link.

**Current Focus:** Phase 1 — Renderer, Track & Player Kart

---

## Current Position

**Phase:** 1
**Plan:** None yet (roadmap just created)
**Status:** Not started
**Progress:** 0/4 phases complete

```
Phase 1 [          ] Not started
Phase 2 [          ] Not started
Phase 3 [          ] Not started
Phase 4 [          ] Not started
```

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Phases defined | 4 |
| Requirements mapped | 14/14 |
| Plans complete | 0 |
| Phases complete | 0 |

---

## Accumulated Context

### Decisions

- **Renderer settings are immutable at creation** — `antialias: false`, pixel ratio capped at 2, `shadowMap.enabled = false`. These cannot be changed after renderer creation (Three.js constraint). Phase 1 must establish all three before any game logic exists.
- **Custom kinematic vehicle controller** — No physics engine (cannon-es abandoned; Rapier adds bundle weight). Velocity + steering math + raycasting for wall detection.
- **CheckpointSystem is prerequisite for AI** — TRACK-03 and AI-01 ship together in Phase 2; lap tracking and position calculation share the same system.
- **Touch controls via native Pointer Events API** — No library. `{ passive: false }` + CSS `touch-action: none` on canvas. iOS orientation lock is impossible via API; CSS media query rotation overlay is the only solution.
- **Coarse granularity** — Research recommended 7 phases; compressed to 4 per granularity config.

### Critical Pitfalls to Watch

- Phase 1: Cap pixel ratio, disable shadows, disable antialias — all at renderer creation
- Phase 1: Add `webglcontextlost` listener and `visibilitychange` handler immediately
- Phase 2: CSS `touch-action: none` + `{ passive: false }` on all touch listeners
- Phase 2: Rubber-band AI speed multiplier capped at 1.1x max; AI must visibly make mistakes
- Phase 3: iOS Web Audio unlock — create AudioContext, call `.resume()` inside first touch handler
- Phase 4: Workbox with hash-suffixed assets; `Cache-Control: no-cache` on sw.js to prevent stale PWA cache

### Todos

- [ ] Run `/gsd:plan-phase 1` to create Phase 1 plan

### Blockers

None.

---

## Session Continuity

**To resume:** Run `/gsd:progress` to see current state, then `/gsd:plan-phase 1` to begin planning.

**Phase order:** 1 → 2 → 3 → 4 (sequential; each depends on previous)

**Build order rationale (from research):** Renderer+Loop → Track+Kart+Controls → AI+Checkpoints → Race FSM+Results → Items → PWA. Phases 4-5-6 of research build order compressed into Phase 3 (race FSM + items in one phase); Phase 7 becomes Phase 4 (PWA).
