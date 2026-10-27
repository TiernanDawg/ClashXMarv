# Vanguard Arena
**Draft. Deploy. Dominate.**

An original, offline-first superhero-archetype lane battler. No Marvel/Supercell names, assets, sounds, or likenesses are used. Expo SDK 54 / React Native 0.81.4; pure deterministic simulation is separated from the React Native renderer.

## Run
Node.js 20+: `npm install`, `npm test`, `npm run simulate`, `npm start`.

## CI / IPA
Push to main or manually run **Vanguard Arena — quality gates and unsigned IPA**. Quality gates run lint, tests, a 1,000-match headless benchmark, procedural WAV generation/validation, and Expo iOS export before the macOS unsigned IPA job. Download the `Vanguard-Arena` artifact from the Actions run. Artifact retention is 14 days.

The IPA is unsigned and cannot be installed directly. Sideload with a signing tool such as SideStore, AltStore, Sideloadly, or a compatible sideloader, using your own Apple ID/signing profile. A free Apple ID typically requires refreshing the signature every 7 days. This workflow does not sign with or store your Apple credentials.

## Implemented in this slice
- Fixed 30 Hz deterministic simulation, seeded PRNG, timestamped deployment commands and state hash.
- Twenty original cards spanning troops, heroes, spells and buildings; the armory explains each card’s role, best use, counter, target profile, and routing.
- Four-card hand, next-card cycle, continuous energy, two lanes, bridge/arena coordinates, sentry/command towers, tower wake-up, spell impacts, status effects, buildings, entity cap, tower win and regulation/overtime resolution.
- Original SVG-style character art is drawn from code and card-specific silhouettes/palettes.
- Eight-rank offline trophy ladder with escalating bot tactics, distinct rival decks, trophy changes and saved profile.
- Drag/release tile placement, visible ranged projectiles and tower fire, floating damage feedback, impact effects, health bars and richer arena terrain.
- Bot decisions use rival difficulty, threats, card roles, spell clusters and lane pressure while retaining seeded reproducibility.
- Armory card explanations and an in-game explanation of deterministic match seeds.
- Deterministic regression tests, headless bot benchmark, generated synthesized WAV effects and CI quality gates.

## Known limitations
This remains an original offline prototype rather than a finished commercial release. Character art is layered vector illustration rather than hand-painted 3D or skeletal animation, and the arena uses an enriched 2D top-down/isometric-inspired renderer rather than a true 3D engine. Pathing follows simple lane/target movement rather than a complete bridge-aware navigation mesh. Hero abilities are combat effects, not separate charge-and-cast ultimate controls. There is no online multiplayer, shared leaderboard, 2v2, replay browser or live-service economy. Procedural WAVs are generated and verified in CI but are not integrated into gameplay playback. FPS/memory have not been profiled on a physical iPhone, and balance has not been validated through human playtests. The unsigned IPA requires signing/sideloading.


## Design and balance decisions (October 2026)

The battle loop follows strategic principles documented in Supercell's Clash Royale support material: continuous Elixir income, card-cycle awareness, positive-cost counters, tower-focused win conditions, and defending or counter-pushing rather than deploying blindly. This is an original offline implementation with original characters and rules, not a clone of proprietary assets.

Research signals used for the design:
- Supercell's official [Elixir guide](https://support.supercell.com/clash-royale/en/articles/elixir.html) explains resource regeneration and phase-based acceleration. Vanguard keeps its own timed energy phases so the economy remains deterministic and testable.
- Supercell's official [1v1 battle guide](https://support.supercell.com/clash-royale/en/articles/1v1-battle-2.html) emphasizes card cycling, efficient counters, win conditions, building pushes, and opposite-lane pressure. The bot uses threat, lane pressure, crowd value, affordable cards, and opponent difficulty rather than a simple random card rotation.
- A 2026 sample of public Clash Royale reviews summarized by OneStar repeatedly flags pay-to-win concerns, matchmaking/balance complaints, and bugs/crashes. Vanguard is offline-first with no purchases, no matchmaking, and no hidden resource cheats; balance still requires human playtesting.
- RoyaleAPI's 2025 player survey highlights tensions around perceived balance, matchmaking fairness, strategy mastery, and content variety. For this solo ladder, those signals favor transparent bot tiers, varied opponent decks, explicit card roles/counters, and reproducible seeds over a monetized progression system.
- Expo's [animation guidance](https://docs.expo.dev/develop/user-interface/animation/) recommends native-driven animation approaches for smoother interaction. This build currently uses SVG-rendered battle effects and a fixed-step simulation; the visual pass improves feedback without adding a heavyweight renderer dependency.

### Battle readability pass
- Attack windups now briefly draw a team-colored line to the unit's current target with a marked target ring.
- Units have stronger team halos and depth shadows, with a brighter hit flash and impact ticks when damage lands.
- Match seeds are recorded separately from the next seed: each newly started match advances the saved seed, while the battle HUD displays the exact seed used for that match.
