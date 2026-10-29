# Vanguard Arena

A native, portrait iOS 16+ offline arena card battler built with SwiftUI and SpriteKit. All visual art is drawn procedurally from shapes and SF Symbols; combat sounds are synthesized at runtime. There are no third-party runtime dependencies, network requirements, ads, login, clans, or purchases.

## Build an unsigned IPA on GitHub

1. Open the repository’s **Actions** tab.
2. Select **Vanguard Arena — unsigned iOS IPA** and choose **Run workflow** (or push a change under `VanguardArena/`).
3. Wait for the green check, open that run, and download **Vanguard-Arena-unsigned-IPA** from Artifacts.
4. Sign and sideload the downloaded IPA with SideStore, AltStore, Sideloadly, or another compatible signer. An unsigned IPA cannot be installed directly. The workflow never uses your Apple ID or signing credentials.

The CI workflow validates all 91 roster names, runs XcodeGen, builds and archives the iOS target with code signing disabled, packages the archived app under `Payload/`, checks the archive structure, and uploads the IPA for 14 days.

## Project layout

- `project.yml` — XcodeGen specification, target `VanguardArena`, bundle ID `com.tiernan.vanguardarena`, iOS 16 minimum.
- `VanguardArena/App.swift` — native app entry.
- `VanguardArena/ContentView.swift` — home, deck builder, card collection and stat sheets, trophy road, profile, shop, settings, battle HUD.
- `VanguardArena/CardCatalog.swift` — all 91 requested parody-name cards, data-driven stats, rarities, descriptions, and composable behavior flags.
- `VanguardArena/GameEngine.swift` — deterministic 20 Hz fixed-step battle simulation, energy, card cycling, towers, AI rival, combat, spells, overtime, results and progression updates.
- `VanguardArena/ArenaScene.swift` — procedural SpriteKit arena, two bridges, tower/unit silhouettes, team colors, health bars, placement ghost, tile feedback, and combat text.
- `VanguardArena/Balance.swift` — centralized economy and timing constants.
- `VanguardArena/SaveStore.swift` — versioned Codable save, input sanitization, and corruption fallback.
- `VanguardArena/ProceduralAudio.swift` — synthesized audio tones and haptic fallback.

## Design decisions and grievance audit

- **Pay-to-win / paid advantages:** no purchases, ads, login, or online service; progression rewards are earned locally. Battle card levels currently use a normalized level baseline for fair matches.
- **Chest walls / grind:** a four-hour free chest grants gold and gems; the small offline ladder grants gold, XP and trophies after a match. No paid chest or premium-only card.
- **Matchmaking fairness:** a single-player AI rival uses a limited energy pool and delayed card decisions. There is no rubber-banding or hidden online matchmaking.
- **Misdrops:** tap-select then arena-tap and direct arena touch/drag placement are supported, with tile validity colors, a ghost offset, tile snapping and haptic feedback. Invalid placements do not spend elixir.
- **Targeting / pathing clarity:** card stat sheets expose range, speed, targets, HP, damage and DPS. Ground units steer toward either bridge lane; flyers ignore river lane steering.
- **Hidden stats:** card collection opens a complete per-card stat sheet and analog/role explanation.
- **Emote toxicity:** a four-second emote cooldown is included; rival emote muting is a setting.
- **Onboarding:** the home screen explains the offline ladder and the battle HUD labels the card selection and placement action.
- **Balance transparency:** card numbers are centralized in the catalog and level scaling is one shared function; card behavior is composed from reusable flags rather than 91 subclasses.
- **Lag / disconnects:** the game is offline and uses a seeded PRNG and fixed 20 Hz simulation. There are no network sessions to disconnect.
- **Battery / heat:** the simulation ticks at 20 Hz and SpriteKit renders the board. Visual effects are short-lived; no downloaded textures or continuous network work.
- **Accessibility:** native SwiftUI controls, VoiceOver labels on key controls, team color distinction, reduce-motion, high-contrast and large-text preferences are provided.
- **Progress safety:** saves use atomic JSON writes, a schema version, validated card IDs and a safe fallback if decoding fails.

## Scope notes

This is a native, buildable game implementation, not a claim of byte-for-byte mechanical parity with a commercial game. The 91-card roster is present and data-driven, but card stats are tuned starting values, not extracted proprietary balance data. Some analog mechanics are represented through shared behaviors rather than individually animated bespoke logic. Procedural sound is synthesized in code. The unsigned IPA still requires signing before installation. Physical-device frame-rate, battery, accessibility, and balance validation must be measured on real hardware; CI compilation alone does not establish 60/120 FPS or a crash-free release.
