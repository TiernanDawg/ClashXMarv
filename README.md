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


### Community-grievance review (public forums and player survey)

A review of the 2025 RoyaleAPI player survey and recent r/ClashRoyale discussions found recurring complaints about pay-to-win/over-levelled matchups, opaque or frustrating matchmaking, card balance, progression grind and limited reward choice, bugs/performance, and emote spam. These are recurring themes in sampled discussions, not proof that every player agrees.

Design responses and additional recommended features:
- **Fair-play queue:** keep battle levels normalized by default and expose both player and bot card levels before the match; never alter bot elixir or secretly change its deck to force a result.
- **Transparent bot difficulty:** show a difficulty label and a short post-match explanation of the bot's threat response. Keep decisions imperfect and seeded so replays are reproducible.
- **Practice lab:** add a no-trophy sandbox with selectable starting elixir, target dummies, and repeatable enemy pushes so players can learn counters without losing progress.
- **Deck diagnostics:** warn about missing air defense, swarm answers, spell coverage, and a clear win condition; explain why each suggested change helps instead of silently changing the deck.
- **Replay and learning tools:** preserve the battle log and allow replaying a match, then show elixir spent, tower damage, and major positive/negative trades. This directly addresses complaints about difficulty learning and confusing losses.
- **Progression without walls:** keep chests/rewards earnable offline, show exact timers and costs, and avoid premium-only cards or paid upgrades. A rotating free challenge can encourage trying underused cards without forcing collection completion.
- **Emote controls:** make mute immediate and persistent, with no gameplay penalty; retain a small cooldown and cap opponent emotes.
- **Stability over spectacle:** keep effects bounded, make reduced-motion/high-contrast settings easy to find, and run deterministic simulation tests in CI.

Sources reviewed:
- RoyaleAPI's 2025 player-survey analysis: https://royaleapi.com/blog/player-survey-2025?lang=en
- Recent community discussion of over-levelled/pay-to-win frustration: https://www.reddit.com/r/ClashRoyale/comments/1p52lld/i_hate_pay_to_win_players_with_all_my_life/
- Recent community discussion of matchmaking and level gaps: https://www.reddit.com/r/ClashRoyale/comments/1wh9fur/is_the_matchmaking_rigged_on_purpose/
- High-engagement community thread on emote spam and muting: https://www.reddit.com/r/ClashRoyale/comments/1vtowwu/why_are_everyone_so_toxic_on_every_single_game/

## Implemented game systems

- **Battle:** deterministic 20 Hz simulation, 3-minute regulation plus 2-minute overtime, correct x1/x2/x3 elixir phase boundaries, card cycling, random starting hand, sleeping/waking King Towers, princess-tower deployment pockets, crowns, sudden death, and remaining-tower-HP tiebreak.
- **Placement/pathing:** tap-select and direct drag-to-deploy, finger-offset ghost, valid/invalid tile colors, snap-to-tile placement, tile-change haptics, invalid-release cancellation, ground bridge steering, flying movement, soft collision, and target filters.
- **Roster:** all 91 requested parody names are present. The data-driven catalog includes per-analog stat profiles for most classic roles, rarity, elixir, target type, range, speed, hit speed, level scaling, and composed behavior flags.
- **Behavior components:** swarm deployment, ranged/splash attacks, flying, tunnel deployment, charge, jump impact, ramping beam, spawners, death-spawn, poison/earthquake/graveyard timed effects, stun, slow, invisibility, clone, Mirror, rage, shield absorption, healer aura, and Elixir Collector generation.
- **AI:** the rival tracks its own hand, cycle and elixir, responds to threats, values air defense and grouped spell value, counter-pushes when unpressured, varies lanes, and reacts faster across trophy bands without free elixir.
- **Meta:** trophy road and 13 procedural arena palettes, King XP, card levels 1–13 with rarity-dependent copy/gold requirements, average-level bot matching, four chest slots with live ETAs, a four-hour free chest, a 10-crown daily chest, daily quests, a free monthly 10-tier reward track, gold-only card-copy shop, profile, battle log, and replayable saved player deployment actions.
- **Polish/settings:** procedural menu/battle music with elixir-phase layers, synthesized SFX, six cooldown-limited emotes, opponent-emote mute, hit squash/flash, damage numbers, crown/tower events, victory confetti, high contrast, reduce motion, large text, left-handed hand order, haptics, and pause/save when the app becomes inactive.
- **Diagnostics:** `BattleSelfTest.run(matches: 1_000)` is executed by the GitHub Actions iOS Simulator test step. It asserts finite values, arena bounds, no prolonged stationary units without nearby targets, and match completion.

## Validation boundaries

The implementation uses original procedural presentation and a shared behavior engine; it does not reproduce proprietary assets or extracted game code. Card values are close-role tuning approximations rather than an authoritative historical balance dump, and some effects are simplified. Per-card attack tones are synthesized from each card's name rather than handcrafted recordings. Remaining differences include unique bespoke idle/walk/attack/death rigs for every individual card, exact spell falloff/target caps for every analog, and a complete pooling strategy for every SpriteKit effect. The 1,000-match deterministic bot self-test runs in CI. Live battle state is saved to versioned local JSON and validated/restored after relaunch. The unsigned IPA must be signed before installation. Drag/drop, accessibility, battery/thermal behavior, 60/120 FPS, and crash-free operation still require real-device validation.


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
