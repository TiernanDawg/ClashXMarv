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
