# Requirements: Kart Rush

**Defined:** 2026-06-20
**Core Value:** A race you can actually play and finish on your phone, touchscreen controls that feel responsive, in under 60 seconds from opening the link.

## v1 Requirements

### Race Loop

- [ ] **RACE-01**: Player sees 3-2-1-GO countdown before each race starts
- [ ] **RACE-02**: Race ends when player or any AI completes 3 laps; finish line detection triggers it
- [ ] **RACE-03**: Results screen shows final race positions (1st–4th) with option to race again

### Track

- [ ] **TRACK-01**: Single looping race track rendered with low-poly cartoon 3D visuals
- [ ] **TRACK-02**: Visible boundary walls keep karts on track; kart cannot drive off
- [ ] **TRACK-03**: Internal checkpoint system tracks each kart's lap progress and calculates race position
- [ ] **TRACK-04**: Item box objects placed at fixed spawn points around track; box respawns after a delay when collected

### Controls

- [ ] **CTRL-01**: On-screen touch controls: left half of screen steers left, right half steers right; kart auto-accelerates forward
- [ ] **CTRL-02**: Game designed for landscape orientation; portrait mode displays rotation prompt overlay

### AI Opponents

- [ ] **AI-01**: 3 AI kart opponents follow track waypoints, complete laps, and finish the race
- [ ] **AI-02**: AI applies subtle rubber-band speed adjustment to keep races competitive

### Items

- [ ] **ITEM-01**: Player kart can drive through item boxes to collect them; collected box respawns after a delay

### PWA

- [ ] **PWA-01**: Game installable as PWA via web app manifest (home screen icon, standalone mode)
- [ ] **PWA-02**: Service worker caches game assets for fast subsequent loads

## v2 Requirements

### Game Feel

- **FEEL-01**: Engine sound, item pickup sound, speed boost sound, hit sound
- **FEEL-02**: Speed lines or blur overlay when going fast
- **FEEL-03**: Screen shake when kart gets hit

### Race Features

- **RACE-04**: HUD showing current lap number and race position during race
- **RACE-05**: Pause and resume race
- **RACE-06**: Player kart respawns at last checkpoint if stuck (if boundary system proves insufficient)

### Items

- **ITEM-02**: Speed boost item — temporary speed increase when item box collected
- **ITEM-03**: Projectile item — shoot forward to slow an opponent
- **ITEM-04**: HUD icon showing currently held item
- **ITEM-05**: Position-weighted item distribution (better items when losing)
- **ITEM-06**: AI opponents use items against player

### Track

- **TRACK-05**: Minimap showing kart positions on track
- **TRACK-06**: Multiple tracks

### Progression

- **PROG-01**: Kart or character selection screen
- **PROG-02**: Local high score / best lap time

### Multiplayer

- **MULT-01**: Online multiplayer (real-time, 2–4 players)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Online multiplayer | Requires backend; eliminates no-server constraint |
| Gyroscope steering | Unreliable across devices; permission prompts on some browsers |
| Native iOS/Android app | PWA avoids app store friction; same gameplay |
| User accounts / leaderboards | No backend in v1 |
| Kart selection / customization | Reduces complexity without hurting core value |
| Drift mechanic | High complexity; validate base loop first |
| Multiple tracks | Validate core loop on one track first |
| In-app purchases | Out of scope entirely |
| Custom track editor | Far out of scope |

## Traceability

*Populated during roadmap creation.*

| Requirement | Phase | Status |
|-------------|-------|--------|
| RACE-01 | — | Pending |
| RACE-02 | — | Pending |
| RACE-03 | — | Pending |
| TRACK-01 | — | Pending |
| TRACK-02 | — | Pending |
| TRACK-03 | — | Pending |
| TRACK-04 | — | Pending |
| CTRL-01 | — | Pending |
| CTRL-02 | — | Pending |
| AI-01 | — | Pending |
| AI-02 | — | Pending |
| ITEM-01 | — | Pending |
| PWA-01 | — | Pending |
| PWA-02 | — | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 0 (roadmap pending)
- Unmapped: 14 ⚠️

---
*Requirements defined: 2026-06-20*
*Last updated: 2026-06-20 after initial definition*
