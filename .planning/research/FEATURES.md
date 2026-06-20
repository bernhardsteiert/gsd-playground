# Feature Landscape

**Domain:** Browser-based 3D mobile arcade kart racing game (PWA)
**Project:** Kart Rush
**Researched:** 2026-06-20
**Overall confidence:** HIGH for table stakes (strong consensus from Mario Kart series, mobile racing genre); MEDIUM for differentiators (market position inference)

---

## Table Stakes

Features players expect in any arcade kart racing game. Missing any of these and the product feels broken or unfinished.

### Core Race Loop

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| 3-2-1-GO countdown | Universal racing convention; sets intent and tension before race starts | Low | Show large numbers, add audio cue and flash effect |
| Lap counter (current / total) | Players must know progress; no counter = no sense of closure | Low | Display "Lap 2/3" in HUD top-center |
| Position indicator (1st/2nd/3rd/4th) | Core competitive feedback even in solo play | Medium | Computed from checkpoint progress across all karts |
| Finish line detection | Race must have a definitive end | Medium | Trigger on crossing start/finish line after correct lap count |
| Race results screen | Players expect a summary of outcome before returning to menu | Low | Show final positions, race time, "Race Again" button |
| Visible start/finish line | Visual anchor for lap concept | Low | Textured stripe across track with checkered flag art |

### Track and Navigation

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Visible track boundaries | Karts must be prevented from going off-track; guardrails or walls | Medium | Collision geometry on track edges; visual barrier mesh |
| Checkpoint system | Required for accurate lap counting and position ranking; without it players can shortcut | Medium | ~20-50 invisible trigger volumes around track; each kart tracks last checkpoint hit |
| Respawn on going off-track | Players expect to be recovered if they fall or get stuck | Medium | Teleport kart to last checkpoint position after short delay |
| Minimap or track layout hint | Not universal in kart games but strongly expected; players need spatial awareness | Medium | Simple 2D overhead representation with kart dots; can be deferred if too complex |

### Touch Controls (Mobile-First)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Left/right steer zones | Project requirement; thumb-zone placement for comfort | Low | Bottom-left = steer left, bottom-right = steer right; large tap targets |
| Auto-accelerate | Reduces controls to one action; standard for mobile kart games | Low | Always moving forward; no throttle button needed |
| Item use button | Players need a dedicated tap target to fire collected power-ups | Low | Large button in thumb zone (e.g., right thumb above steer zone) |
| Visible touch targets | Controls must be visible, especially for first-time players | Low | Semi-transparent HUD overlay; directional arrows or icons |
| Orientation lock prompt | Game is landscape-only; portrait players need a rotation nudge | Low | CSS media query overlay: "Rotate your device to play" |

### Power-Ups

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Item boxes on track | Physical collectibles that grant power-ups; universal kart game mechanic | Medium | Spinning box objects on fixed spawn points; respawn after pickup |
| Speed boost (mushroom-type) | Players expect at least one offensive/speed item | Low | Temporary velocity multiplier (1.5x-2x) for 2-3 seconds |
| Projectile to slow opponents | Core combat mechanic of kart genre; feel incomplete without it | Medium | Forward-fired projectile that stuns/slows hit kart for 2 seconds |
| Item HUD display | Player must know what item they are holding | Low | Small icon in corner of HUD |

### AI Opponents

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| AI karts that follow the track | Players need racing targets; completely static AI ruins the feel | Medium | Waypoint-based navigation; karts steer toward sequential waypoints |
| AI that actually finishes races | AI must cross finish line in reasonable time to produce a result screen | Medium | Tuning issue; AI must not get stuck on corners |
| Rubber banding (subtle) | Players in last place should not fall hopelessly behind; genre convention | Medium | AI speed modifier: slightly faster when player is ahead, slightly slower when player is behind |

### Mobile UX

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pause button | Players need to be able to pause; no pause = frustration on interruption | Low | Tap button in HUD corner; freeze game loop, show resume overlay |
| Resume from pause | Paired with pause | Low | Resume button on pause overlay |
| Loading screen with progress | WebGL assets take time; blank screen feels broken | Low | Progress bar or spinner during asset load phase |
| Race-again flow | After result screen, one tap back to racing; friction here loses players | Low | "Race Again" and "Main Menu" on result screen |

### PWA

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Web App Manifest | Required for "Add to Home Screen" capability; without it PWA install is unavailable | Low | manifest.json with name, icons, display: standalone, orientation: landscape |
| Service worker (cache-first) | Required to pass PWA installability criteria; provides offline play after first load | Medium | Cache all game assets on first visit using cache-first strategy |
| HTTPS | Required for service workers and PWA install; no HTTPS = no service worker | Low | Hosting requirement; any static host (Vercel, Netlify) provides this |

### Game Feel (Juice)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Engine sound / motor audio | Silence during racing feels dead; audio provides speed feedback | Low | Loop a motor audio clip, pitch-shift with speed |
| Item pickup sound | Audio confirmation of collecting item box | Low | Short sound effect on item box trigger |
| Boost sound effect | Auditory feedback when boost activates | Low | Whoosh or engine roar burst |
| Item fire sound | Confirms player action | Low | Launch sound on item use |
| Hit/stun sound | Feedback when kart is hit by projectile | Low | Impact sound + brief camera shake |
| Speed lines / blur | Visual speed cue at high velocity | Low | Radial screen-space overlay or particle trails |

---

## Differentiators

Features that are not universally expected but create competitive advantage or delight. These distinguish the product from generic browser racing games.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Drift mechanic with boost reward | Classic Mario Kart feel; holding steer through corners charges a mini-turbo | High | Requires drift physics state, charge timer, spark VFX, boost release; consider Phase 2 |
| Position-weighted item distribution | Stronger items for lower positions (rubber-banding via items, not just AI speed) | Medium | Pick different item tables based on player's current position; increases fairness feel |
| Kart-specific particle trails | Exhaust smoke, wheel dust on dirt patches; makes karts feel alive | Medium | Three.js particle systems per kart; can be a performance risk on low-end phones |
| Projectile has art (banana peel, shell) | Recognizable item art vs generic sphere increases game personality | Low-Medium | Asset creation effort but high payoff for genre fans |
| Countdown animation polish | Large 3D numbers drop in or zoom; more exciting than flat 2D text | Low | Camera effects + animation on countdown numbers |
| Post-race replay or highlight | Show player crossing finish line or a kart collision moment | Very High | Requires recording state history; likely out of scope for v1 |
| Per-surface speed modifiers | Grass = slower, boost pads = faster; tracks feel varied and tactical | Medium | Raycast surface type detection on kart position |
| Dynamic music intensity | Music pitch or layer shifts as player gains/loses position | Medium | Web Audio API layering; adds cinematic quality |
| "Add to Home Screen" prompt | Proactively prompt install; converts casual visit to returning player | Low | Use beforeinstallprompt event on Android Chrome; show prompt after race completion |

---

## Anti-Features

Features to deliberately NOT build in v1. Each has a specific reason and a mitigation strategy.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Online multiplayer | Requires backend (WebSockets/WebRTC), server infrastructure, matchmaking, latency handling — entirely new project | Validate core race loop solo; add multiplayer as a separate milestone only after loop feels good |
| Local split-screen | Halves available resolution and frame budget; complex viewport management | Out of scope — mobile screen too small for split-screen anyway |
| Character or kart selection screen | Adds art assets, UI flow, and customization data without improving core gameplay | Use one fixed player kart; differentiate visually only if differentiators are needed |
| Global leaderboards | Requires backend, auth, anti-cheat; backend-free constraint makes this impossible in v1 | Show local best-time in-game; no persistence needed |
| Multiple tracks | Each track requires layout design, testing, AI waypoints, and balancing | Perfect one track; multi-track is a validated follow-on milestone |
| Gyroscope / tilt steering | Requires permissions on some platforms, inconsistent across iOS/Android, confusing to users | Touch zones chosen for reliability; do not add tilt as an option |
| Kart upgrade / progression system | Metagame loop; requires persistence, balance design, economy | Out of scope for v1 — game is session-complete, no account needed |
| Social share / screenshots | Nice but non-trivial; screenshot API limited in browsers | Defer; the PWA URL is itself shareable |
| In-app purchases | Monetization model decision required before implementing; complicates everything | Validate that people want to play first |
| Custom track editor | Complex UI, massive scope; Track editor is a game in itself | Single fixed track; editor is a v3+ feature if ever |
| Detailed physics simulation (suspension, weight transfer) | Performance cost on mobile; mismatched with low-poly cartoon aesthetic | Arcade physics: fixed turn radius, instant grip, no suspension; feels snappy not realistic |
| AI difficulty settings | Complexity in UI and AI systems; complicates initial design | Start with one difficulty; tune AI so the race is winnable but competitive |

---

## Feature Dependencies

```
Checkpoint system → Position calculation → Position HUD indicator
Checkpoint system → Lap counting → Finish detection → Result screen
Finish detection → Result screen → Race-again flow

Item box spawns → Item pickup → Item HUD display
Item pickup → Speed boost (fire/use)
Item pickup → Projectile (fire → collision detection → hit stun effect)

AI waypoint pathing → AI lap counting → AI finishes race → Full result screen (positions for all karts)

Service worker → Offline play → PWA installability
Web app manifest → PWA installability → Add to Home Screen prompt

Touch steer zones → All player movement
Orientation lock prompt → Touch controls usable (landscape required)
Loading screen → Any gameplay
```

---

## MVP Recommendation

Build strictly in this order to unblock the race loop as fast as possible:

**Phase 1 — Playable Race (table stakes only):**
1. Track with visible boundaries and checkpoint triggers
2. Player kart with touch steer zones and auto-accelerate
3. Lap counter + position indicator
4. 3-2-1-GO countdown
5. Finish line detection + results screen
6. Race-again button

**Phase 2 — AI and Power-Ups (table stakes completion):**
7. AI waypoint navigation (3 opponents)
8. Rubber-banding AI speed modifier
9. Item boxes + speed boost
10. Projectile item to affect opponents
11. Item HUD display

**Phase 3 — Polish and PWA (table stakes + juice):**
12. Audio: engine, boost, hit, item sounds
13. Basic particle effects (speed lines, item pickup flash)
14. Pause / resume
15. Orientation rotation prompt
16. Web App Manifest + service worker (PWA)
17. Loading progress bar

**Defer to later milestones:**
- Drift mechanic with boost (high complexity, strong differentiator — Phase 4+)
- Position-weighted item distribution (refinement after core items work)
- Dynamic music (after audio basics are solid)
- "Add to Home Screen" proactive prompt (after PWA is wired up)
- Minimap (can ship without; add if playtesting reveals disorientation)

---

## Sources

- Mario Kart Racing Wiki — item and checkpoint system documentation: https://mariokart.fandom.com/wiki/Item
- Game Developer Magazine — rubber banding as design requirement: https://www.gamedeveloper.com/design/rubber-banding-as-a-design-requirement
- Game Wisdom — rubber banding AI in game design: https://game-wisdom.com/critical/rubber-banding-ai-game-design
- Mobile Free To Play — touch control design principles: https://mobilefreetoplay.com/touch-control-design-less-is-more/
- Web Game Dev — PWA for browser games: https://www.webgamedev.com/publishing/pwa
- MDN Web Docs — Progressive Web Apps: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps
- ResearchGate — waypoint pathfinding in kart racing AI: https://www.researchgate.net/publication/251924142_An_effective_method_of_pathfinding_in_a_car_racing_game
- Easton Dev Blog — game feel feedback timing: https://eastondev.com/blog/en/posts/dev/20260521-game-feedback-feel/
- HyperX Arena — item box and power-up design: https://hyperxarenalasvegas.com/item-box-breakdown-power-ups/
- Mario Wiki — drift and mini-turbo mechanics: https://www.mariowiki.com/Drift
