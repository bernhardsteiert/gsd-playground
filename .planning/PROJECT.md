# Kart Rush

## What This Is

A 3D arcade kart racing game that runs as a Progressive Web App (PWA) in the mobile browser — no install required, just open a link. Players race solo against 3 AI opponents on a single fun track, with low-poly cartoon visuals, touch button controls, and basic power-ups in the style of Mario Kart.

## Core Value

A race you can actually play and finish on your phone, touchscreen controls that feel responsive, in under 60 seconds from opening the link.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Game runs as a PWA in mobile browser (iOS Safari, Android Chrome) without install
- [ ] 3D low-poly cartoon visual style rendered via WebGL (Three.js)
- [ ] Single race track with visible boundaries and lap counter
- [ ] Player kart controlled via on-screen touch buttons (left/right steer zones, auto-accelerate)
- [ ] 3 AI opponent karts that navigate the track
- [ ] Basic power-ups spawned on track (speed boost, item to slow opponents)
- [ ] Race start countdown (3-2-1-GO)
- [ ] Finish line detection with race results screen (positions)
- [ ] Works in landscape orientation on phone

### Out of Scope

- Multiplayer (online or local) — solo MVP first
- Multiple tracks — validate core loop on one track first
- Character/kart selection — reduces scope without hurting core value
- Account system / leaderboards — no backend needed for v1
- Gyroscope tilt controls — touch buttons chosen for reliability across devices
- Native iOS/Android app — PWA delivers without app store friction

## Context

- Target runtime: mobile browser (iOS Safari 16+, Android Chrome)
- Rendering: Three.js (WebGL) — best-supported 3D library for browser games
- PWA: service worker + manifest for add-to-home-screen capability
- No backend: all game logic runs client-side
- Controls: left half of screen = steer left, right half = steer right, always accelerating forward
- Orientation: landscape mode recommended, UI should prompt rotation on portrait

## Constraints

- **Platform**: Browser-only PWA — no native APIs, no app store
- **Performance**: Must run at 30+ FPS on a mid-range smartphone (e.g., iPhone 11 / Pixel 4)
- **Bundle size**: Keep asset sizes small for fast load on mobile data
- **No backend**: Fully client-side, no server required
- **Rendering**: WebGL via Three.js — no canvas 2D fallback needed

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Three.js for 3D rendering | Most mature browser 3D library, good mobile WebGL support, large community | — Pending |
| PWA over native app | No app store friction, share via URL, reaches any mobile device instantly | — Pending |
| Touch buttons over gyroscope | More reliable across all devices, no permission prompts, predictable behavior | — Pending |
| Solo only for v1 | Eliminates backend requirement, reduces complexity, validates core race loop first | — Pending |
| Low-poly cartoon style | Fast to render on mobile GPU, easy to create without 3D artists, fun aesthetic | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-20 after initialization*
