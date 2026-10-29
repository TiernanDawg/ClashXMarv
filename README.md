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

## Implemented game systems

- **Battle:** deterministic 20 Hz simulation, 3-minute regulation plus 2-minute overtime, correct x1/x2/x3 elixir phase boundaries, card cycling, random starting hand, sleeping/waking King Towers, princess-tower deployment pockets, crowns, sudden death, and remaining-tower-HP tiebreak.
- **Placement/pathing:** tap-select and direct drag-to-deploy, finger-offset ghost, valid/invalid tile colors, snap-to-tile placement, tile-change haptics, invalid-release cancellation, ground bridge steering, flying movement, soft collision, and target filters.
- **Roster:** all 91 requested parody names are present. The data-driven catalog includes per-analog stat profiles for most classic roles, rarity, elixir, target type, range, speed, hit speed, level scaling, and composed behavior flags.
- **Behavior components:** swarm deployment, ranged/splash attacks, flying, tunnel deployment, charge, jump impact, ramping beam, spawners, death-spawn, poison/earthquake/graveyard timed effects, stun, slow, invisibility, clone, Mirror, rage, shield absorption, healer aura, and Elixir Collector generation.
- **AI:** the rival tracks its own hand, cycle and elixir, responds to threats, values air defense and grouped spell value, counter-pushes when unpressured, varies lanes, and reacts faster across trophy bands without free elixir.
- **Meta:** trophy road and 13 procedural arena palettes, King XP, card levels 1–13 with rarity-dependent copy/gold requirements, average-level bot matching, four chest slots with live ETAs, a four-hour free chest, a 10-crown daily chest, daily quests, a free monthly 10-tier reward track, gold-only card-copy shop, profile, battle log, and replayable saved player deployment actions.
- **Polish/settings:** procedural menu/battle music with elixir-phase layers, synthesized SFX, six cooldown-limited emotes, opponent-emote mute, hit squash/flash, damage numbers, crown/tower events, victory confetti, high contrast, reduce motion, large text, left-handed hand order, haptics, and pause/save when the app becomes inactive.
- **Diagnostics:** `BattleSelfTest.run(matches: 1_000)` is available in DEBUG builds to simulate bot-vs-bot matches and assert finite values, arena bounds, prolonged stationary units without nearby targets, and match completion.

## Validation boundaries

The implementation uses original procedural presentation and a shared behavior engine; it does not reproduce proprietary assets or extracted game code. Card values are close-role tuning approximations rather than an authoritative historical balance dump, and some effects are simplified. It does not yet have a unique bespoke idle/walk/attack/death rig and unique attack sound for every card, exact proprietary spell falloff for every analog, a bespoke idle/walk/attack/death rig for every individual card, exact proprietary spell falloff for every analog, or a completed 1,000-match report wired into CI. Live battle state is now saved to versioned local JSON and validated/restored after relaunch. The unsigned IPA must be signed before installation. Drag/drop, accessibility, battery/thermal behavior, 60/120 FPS, and crash-free operation still require real-device validation.


## Research notes and sources

The design audit treats these sources as reports of recurring player concerns, not as proof that every player agrees:

- [Supercell: Elixir](https://support.clashroyale.com/hc/en-us/articles/49484936933403-Elixir) documents the x1/x2/x3 resource phases. [Supercell: 1v1 Battle](https://support.supercell.com/clash-royale/en/articles/1v1-battle-2.html) explains elixir trades, the four-card cycle, and tower-targeting win conditions. These inform the phase clock, deck cycling, and tower pressure.
- [RoyaleAPI: 2025 Player Survey](https://royaleapi.com/blog/player-survey-2025?lang=en) lists perceived pay-to-win, balance, technical issues, strategy mastery, and matchmaking fairness among the survey concerns. [OneStar's 2026 Clash Royale review sample](https://onestar.sh/r/clash-royale) also groups complaints around monetization, matchmaking/balance, and bugs. Both are sampled feedback, not universal player opinion.
- [OneStar's 2026 Brawl Stars review sample](https://onestar.sh/p/brawl-stars) reports recurring matchmaking/balance and bug complaints. The response here is offline AI, deterministic energy accounting, and a clear battle HUD instead of network matchmaking.
- [Marvel Snap's official acquisition update](https://marvelsnap.com/marvel-snaps-foundational-focus/) acknowledges that new and returning players can find catching up difficult. [Steam review analysis of Marvel Snap](https://gameq.co/game/marvel-snap) also discusses acquisition and monetization concerns. Vanguard avoids premium-only cards and real-money acquisition entirely.
- [Marvel Contest of Champions Steam reviews](https://store.steampowered.com/app/3127280/Marvel_Contest_of_Champions/) praise roster variety while some mention grind, repetition, and technical problems. [Marvel Contest of Champions player forum feedback](https://forums.playcontestofchampions.com/en/discussion/412599/putting-the-game-on-probation) illustrates concerns about repetitive modes and pressure to keep up.
- [Marvel Strike Force's official economy update](https://marvelstrikeforce.com/es/updates/blog-update-8-10-26) discusses community reaction to changes in reward distribution. [Google Play reviews](https://play.google.com/store/apps/details?hl=en_CA&id=com.foxnextgames.m3) include conflicting views: some enjoy the volume of free content, while others describe a growing pay-to-keep-up burden. The local economy intentionally has no paid progression.
- [WIRED's report on Pokémon TCG Pocket trading backlash](https://www.wired.com/story/pokemon-tcg-pocket-trading-system-player-frustration/) describes complaints about restrictive trading costs and friction. Vanguard has no trading economy, duplicate-card market, or premium currency gate.
- [Legends of Runeterra user reviews on Metacritic](https://www.metacritic.com/game/legends-of-runeterra/user-reviews/?platform=pc) show contrasting opinions about its tactical gameplay, free-to-play generosity, and the reduced focus on PvP. Vanguard prioritizes offline play and keeps the AI ladder available without servers.

The sources support the product decisions above, but they do not validate this implementation's balance, accessibility, stability, or performance. Those still require automated testing and real-device playtesting.
