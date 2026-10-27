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
- Twenty original cards spanning troops, heroes, spells and buildings; cost, role, target, range, health, damage, speed, splash, deploy delay and animation metadata are data-driven.
- Four-card hand, next-card cycle, continuous energy, two lanes, bridge/arena coordinates, sentry/command towers, tower wake-up, spell impacts, status effects, buildings, entity cap, tower win and regulation/overtime resolution.
- Original SVG-style character art is drawn from code and card-specific silhouettes/palettes.
- Bot deployment, local match screen, collection gallery, settings/debug panel, battle restart.
- Deterministic regression tests, headless bot benchmark, generated synthesized WAV effects and CI quality gates.

## Known limitations
This is a substantial playable foundation, not a finished commercial clone. Full drag placement and sophisticated bridge-aware pathfinding, all hero ultimates, high-quality character rigging/cinematics, persistent collection/economy/crates/quests/season, replay browser/share sheet, 2v2, and the optional online module are not complete. Procedural audio is synthesized atmospheric test audio, not studio sound design. FPS has not been measured on a physical iPhone; the CI benchmark measures simulation throughput only. Match balance data is experimental and not validated through human playtests. The unsigned artifact has not been tested on a physical iPhone until a human installs it with a valid signing method.
