import SwiftUI
import SpriteKit
import UIKit
import Combine

private enum Screen: Equatable { case home, deck, cards, ladder, profile, settings, battle, shop, log, tutorial }
private let ink = Color(red: 0.035, green: 0.055, blue: 0.10)
private let panel = Color(red: 0.075, green: 0.105, blue: 0.17)
private let accent = Color(red: 0.39, green: 0.79, blue: 0.98)
private let gold = Color(red: 1.0, green: 0.78, blue: 0.30)

struct RootView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: Screen = .home
    @StateObject private var battleHolder = BattleHolder()
    private var battle: BattleModel? { battleHolder.model }
    @State private var scene = ArenaScene(size: CGSize(width: 360, height: 640))
    @State private var detail: CardDefinition?
    @State private var lastResultSaved = false
    @State private var arenaRect: CGRect = .zero
    @State private var draggingCardID: String?
    @State private var tutorialStep = 0
    @State private var emoteIndex = 0
    private let emotes = ["NICE!", "OOPS", "WOW", "WELL PLAYED", "GOOD GAME", "THINK"]
    @State private var toast = ""
    private let timer = Timer.publish(every: Balance.tick, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            switch screen {
            case .home: home
            case .deck: deckBuilder
            case .cards: cardCollection
            case .ladder: ladder
            case .profile: playerProfile
            case .settings: settings
            case .battle: battleView
            case .shop: shop
            case .log: battleLog
            case .tutorial: tutorial
            }
        }
        .foregroundStyle(.white)
        .animation(.easeOut(duration: 0.22), value: screen == .battle)
        .sheet(item: $detail) { CardDetailView(card: $0) }
        .overlay(alignment: .top) {
            if !toast.isEmpty {
                Text(toast).font(.footnote.bold()).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule()).padding(.top, 8).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { updateMusic(); if profile.profile.meta?.tutorialCompleted != true { screen = .tutorial } }
        .onChange(of: screen) { _ in updateMusic() }
        .onChange(of: profile.profile.settings.music) { _ in updateMusic() }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                profile.persist()
                ProceduralAudio.shared.setMusic(mode: screen == .battle ? .battle : .menu, enabled: false)
            } else { updateMusic() }
        }
        .onReceive(timer) { _ in
            guard scenePhase == .active, screen == .battle, let battle, !battle.isFinished else { return }
            battle.setOpponentEmotesMuted(profile.profile.settings.muteOpponentEmotes)
            battle.tick()
            updateMusic()
            scene.showDamageNumbers = profile.profile.settings.damageNumbers
            scene.reduceMotion = profile.profile.settings.reduceMotion
            scene.highContrast = profile.profile.settings.highContrast
            scene.hapticsEnabled = profile.profile.settings.haptics
            scene.render(battle)
            if battle.isFinished && !lastResultSaved { battle.saveRecord(profile: profile); lastResultSaved = true }
        }
    }

    private var tutorial: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("TRAINING CAMP").font(.caption.bold()).tracking(2).foregroundStyle(accent); Spacer(); Button("SKIP") { finishTutorial() }.font(.caption.bold()).foregroundStyle(.white.opacity(0.65)) }
            Spacer()
            Image(systemName: ["hand.draw.fill", "drop.fill", "arrow.left.arrow.right", "trophy.fill"][min(3, tutorialStep)]).font(.system(size: 76)).foregroundStyle(accent).frame(maxWidth: .infinity)
            Text(["Deploy with precision", "Manage your elixir", "Control both lanes", "Win crowns"][min(3, tutorialStep)]).font(.system(size: 30, weight: .black, design: .rounded))
            Text([
                "Tap a card, then tap a valid tile on your side. You can also drag the card from your hand and release over the arena. Red tiles are invalid; cancelling spends no elixir.",
                "Cards cost elixir. It regenerates over time, reaches a cap of ten, and speeds up in double and triple elixir. Avoid spending your whole bar without a plan.",
                "Ground units cross the river at the two bridges. Air units can fly over it. Defend your towers, then counter-push when the rival spends too much.",
                "Destroy a Princess Tower for a crown. Destroy the King Tower for an instant three-crown win. A tied match enters sudden-death overtime."
            ][min(3, tutorialStep)]).font(.body).foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack { Text("\(tutorialStep + 1) OF 4").font(.caption.bold()).foregroundStyle(.white.opacity(0.5)); Spacer(); Button(tutorialStep == 3 ? "START PLAYING" : "NEXT") { if tutorialStep == 3 { finishTutorial() } else { withAnimation(.easeOut(duration: 0.2)) { tutorialStep += 1 } } }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 190) }
        }.padding(24)
    }
    private func finishTutorial() {
        profile.update { p in
            var meta = p.meta ?? MetaProgression()
            meta.tutorialCompleted = true
            p.meta = meta
        }
        screen = .home
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("VANGUARD").font(.system(size: 13, weight: .black, design: .rounded)).tracking(3).foregroundStyle(accent)
                        Text("ARENA").font(.system(size: 36, weight: .black, design: .rounded))
                    }
                    Spacer()
                    Button { screen = .settings } label: { Image(systemName: "slider.horizontal.3").font(.title3.bold()).frame(width: 48, height: 48).background(panel, in: Circle()) }
                        .accessibilityLabel("Settings")
                }
                HStack(spacing: 12) {
                    statCard("TROPHIES", "\(profile.profile.trophies)", "trophy.fill", gold)
                    statCard("KING LEVEL", "\(profile.profile.kingLevel)", "crown.fill", accent)
                    statCard("GOLD", "\(profile.profile.gold)", "circle.hexagongrid.fill", gold)
                }
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [Color(red: 0.11, green: 0.32, blue: 0.55), Color(red: 0.15, green: 0.14, blue: 0.34), Color(red: 0.27, green: 0.12, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().fill(.white.opacity(0.08)).frame(width: 210).offset(x: 190, y: -55)
                    Image(systemName: "bolt.shield.fill").font(.system(size: 112)).foregroundStyle(.white.opacity(0.16)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(22)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("OFFLINE LADDER").font(.caption.bold()).tracking(1.8).foregroundStyle(accent)
                        Text("Ready for battle?").font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Earn trophies against tactical AI rivals. No network, ads, or purchases.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                        Button(action: startBattle) {
                            HStack { Image(systemName: "swords"); Text("BATTLE"); Spacer(); Image(systemName: "arrow.right") }
                                .font(.headline.bold()).padding(.horizontal, 20).frame(height: 56)
                                .background(LinearGradient(colors: [accent, Color(red: 0.23, green: 0.59, blue: 0.94)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(ink)
                        }.padding(.top, 5)
                    }.padding(22)
                }.frame(height: 290).clipShape(RoundedRectangle(cornerRadius: 28))
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("YOUR DECK").font(.headline.bold()); Spacer(); Button("EDIT DECK") { screen = .deck }.font(.caption.bold()).foregroundStyle(accent) }
                    HStack(spacing: 8) {
                        ForEach(profile.profile.selectedDeck.prefix(8), id: \.self) { id in
                            if let card = CardCatalog.byID[id] { MiniCard(card: card) }
                        }
                    }
                    HStack(spacing: 12) {
                        navTile("Collection", "rectangle.stack.fill", .cards)
                        navTile("Trophy Road", "map.fill", .ladder)
                        navTile("Profile", "person.crop.circle.fill", .profile)
                    }
                    HStack(spacing: 12) {
                        navTile("Daily Supply", "gift.fill", .shop)
                        navTile("Battle Log", "clock.arrow.circlepath", .log)
                    }
                }
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title2)
                    VStack(alignment: .leading, spacing: 3) { Text("FAIR BY DESIGN").font(.caption.bold()); Text("All cards are free to unlock through play. Rivals use the same level baseline.").font(.caption).foregroundStyle(.white.opacity(0.65)) }
                }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 18))
            }.padding(20)
        }
    }
    private func statCard(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint).font(.headline)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(title).font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(.white.opacity(0.52))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(panel, in: RoundedRectangle(cornerRadius: 18))
    }
    private func navTile(_ title: String, _ icon: String, _ destination: Screen) -> some View {
        Button { screen = destination } label: {
            VStack(spacing: 9) { Image(systemName: icon).font(.title2).foregroundStyle(accent); Text(title).font(.caption.bold()).lineLimit(1) }
                .frame(maxWidth: .infinity).frame(height: 82).background(panel, in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private var deckBuilder: some View {
        VStack(spacing: 0) {
            header("Battle Deck", back: .home)
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text("\(profile.profile.selectedDeck.count)/8 CARDS").font(.headline.bold()); Text("Average elixir \(String(format: "%.1f", averageCost)) · 4-card cycle \(cycleCost)").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                Spacer()
                if profile.profile.selectedDeck.count == 8 { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2) }
            }.padding(16)
            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { i in
                    if i < profile.profile.selectedDeck.count, let card = CardCatalog.byID[profile.profile.selectedDeck[i]] {
                        Button { toggleDeck(card) } label: { MiniCard(card: card).overlay(alignment: .topTrailing) { Image(systemName: "minus.circle.fill").foregroundStyle(.white).background(.black, in: Circle()).offset(x: 3, y: -3) } }
                    } else { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4])).frame(height: 92).overlay(Text("\(i + 1)").foregroundStyle(.white.opacity(0.3))) }
                }
            }.padding(.horizontal, 14)
            if !hasAirDefense || !hasWinCondition {
                HStack(spacing: 8) { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(gold); Text(!hasAirDefense && !hasWinCondition ? "Add air defense and a tower win condition." : (!hasAirDefense ? "Warning: this deck has limited air defense." : "Warning: add a reliable tower win condition.")).font(.caption) }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 12)).padding(14)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(CardCatalog.all) { card in
                        Button { toggleDeck(card) } label: {
                            HStack(spacing: 10) {
                                CardGlyph(card: card, size: 44)
                                VStack(alignment: .leading, spacing: 3) { Text(card.name).font(.subheadline.bold()).lineLimit(1); Text("\(card.cost) elixir · \(card.rarity.rawValue)").font(.caption2).foregroundStyle(accent) }
                                Spacer(minLength: 0)
                                if profile.profile.selectedDeck.contains(card.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } else if !isUnlocked(card) { Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.45)) }
                            }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(profile.profile.selectedDeck.contains(card.id) ? accent.opacity(0.7) : .clear, lineWidth: 1.5))
                        }.buttonStyle(.plain).disabled(!isUnlocked(card)).opacity(isUnlocked(card) ? 1 : 0.42)
                    }
                }.padding(.horizontal, 14).padding(.bottom, 12)
            }
            Button { screen = .home } label: { Text("SAVE DECK").font(.headline.bold()).frame(maxWidth: .infinity).frame(height: 52).background(profile.profile.selectedDeck.count == 8 ? accent : .gray, in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(ink) }
                .disabled(profile.profile.selectedDeck.count != 8).padding(14)
        }
    }
    private var averageCost: Double { let cards = profile.profile.selectedDeck.compactMap { CardCatalog.byID[$0] }; return cards.isEmpty ? 0 : Double(cards.reduce(0) { $0 + $1.cost }) / Double(cards.count) }
    private var cycleCost: Int { profile.profile.selectedDeck.prefix(4).compactMap { CardCatalog.byID[$0]?.cost }.reduce(0, +) }
    private var hasAirDefense: Bool { profile.profile.selectedDeck.contains { CardCatalog.byID[$0]?.targetsAir == true } }
    private var hasWinCondition: Bool { profile.profile.selectedDeck.contains { id in guard let c = CardCatalog.byID[id] else { return false }; return c.behavior.contains(.buildingTarget) || c.analog.lowercased().contains("balloon") || c.analog.lowercased().contains("giant") || c.analog.lowercased().contains("hog rider") } }
    private func isUnlocked(_ card: CardDefinition) -> Bool { profile.profile.unlocked.contains(card.id) || profile.profile.trophies >= CardCatalog.unlockThreshold(for: card) }
    private func toggleDeck(_ card: CardDefinition) {
        if profile.profile.selectedDeck.contains(card.id) {
            profile.update { p in p.selectedDeck.removeAll { $0 == card.id } }
            return
        }
        guard isUnlocked(card) else { toast = "Unlock this card by earning trophies"; return }
        profile.update { p in if p.selectedDeck.count < 8 { p.selectedDeck.append(card.id) } }
    }
    private var cardCollection: some View {
        VStack(spacing: 0) {
            header("Card Collection", back: .home)
            HStack { Text("\(CardCatalog.all.count) original cards").font(.subheadline); Spacer(); Text("Tap for stats").font(.caption).foregroundStyle(.white.opacity(0.5)) }.padding(16)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(CardCatalog.all) { card in Button { detail = card } label: { HStack(spacing: 10) { CardGlyph(card: card, size: 48); VStack(alignment: .leading, spacing: 4) { Text(card.name).font(.subheadline.bold()).lineLimit(1); Text("\(card.cost) elixir").font(.caption).foregroundStyle(accent); Text(card.rarity.rawValue.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(gold) }; Spacer(minLength: 0) }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 15)) } }
                }.padding(14)
            }
        }
    }
    private var ladder: some View {
        VStack(spacing: 0) {
            header("Trophy Road", back: .home)
            VStack(spacing: 12) {
                Image(systemName: "trophy.circle.fill").font(.system(size: 64)).foregroundStyle(gold).padding(.top, 18)
                Text("\(profile.profile.trophies)").font(.system(size: 38, weight: .black, design: .rounded))
                Text("CURRENT TROPHIES").font(.caption.bold()).tracking(2).foregroundStyle(.white.opacity(0.55))
            }.frame(maxWidth: .infinity).padding(.bottom, 20)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, through: 12, by: 1)), id: \.self) { rank in
                        let threshold = rank * 300
                        let arenaName = rank == 0 ? "Training Grounds" : ["Iron Circuit", "Neon District", "Mystic Ruins", "Skyline Siege", "Quantum Core", "Shadow Sector", "Titan Foundry", "Stellar Rift", "Doom Citadel", "Cosmic Gate", "Eternal Nexus"][min(10, max(0, rank - 1))]
                        HStack(spacing: 14) {
                            ZStack { Circle().fill(rank * 300 <= profile.profile.trophies ? accent.opacity(0.22) : .white.opacity(0.05)).frame(width: 48, height: 48); Image(systemName: rank == 12 ? "crown.fill" : "shield.fill").foregroundStyle(rank * 300 <= profile.profile.trophies ? gold : .white.opacity(0.35)) }
                            VStack(alignment: .leading, spacing: 3) { Text(rank == 12 ? "Legendary Summit" : "Arena \(rank + 1)").font(.headline.bold()); Text("\(threshold) trophies · \(arenaName)").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                            Spacer(); if profile.profile.trophies >= threshold { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                        }.padding(12).background(panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(16)
            }
        }
    }
    private var playerProfile: some View {
        VStack(spacing: 16) {
            header("Player Profile", back: .home)
            Image(systemName: "person.crop.circle.fill").font(.system(size: 76)).foregroundStyle(accent).padding(.top, 24)
            Text("ARENA COMMANDER").font(.headline.bold()).tracking(1.5)
            Text("King Level \(profile.profile.kingLevel)").font(.title2.bold())
            HStack(spacing: 10) { statCard("WINS", "\(profile.profile.wins)", "checkmark.circle.fill", .green); statCard("LOSSES", "\(profile.profile.losses)", "xmark.circle.fill", .red); statCard("CROWNS", "\(profile.profile.crowns)", "crown.fill", gold) }.padding(.horizontal, 16)
            HStack { Text("XP PROGRESS"); Spacer(); Text("\(profile.profile.xp % 100)/100") }.font(.caption.bold()).padding(.horizontal, 18)
            ProgressView(value: Double(profile.profile.xp % 100), total: 100).tint(accent).padding(.horizontal, 18)
            Spacer()
            Button("VIEW BATTLE LOG") { screen = .log }.buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
    }
    private var settings: some View {
        VStack(spacing: 0) {
            header("Settings", back: .home)
            Form {
                Section("Audio & Feedback") {
                    settingToggle("Sound effects", keyPath: \.sound)
                    settingToggle("Music", keyPath: \.music)
                    settingToggle("Haptics", keyPath: \.haptics)
                    settingToggle("Damage numbers", keyPath: \.damageNumbers)
                }
                Section("Controls & Accessibility") {
                    settingToggle("Left-handed layout", keyPath: \.leftHanded)
                    settingToggle("Mute rival emotes", keyPath: \.muteOpponentEmotes)
                    settingToggle("Reduce motion", keyPath: \.reduceMotion)
                    settingToggle("High contrast", keyPath: \.highContrast)
                    settingToggle("Large text", keyPath: \.largeText)
                }
                Section("Progress") {
                    Button("Open Daily Supply") { screen = .shop }
                    Button("Claim free chest", action: claimFreeChest)
                    Button("Reset all progress", role: .destructive) { profile.reset(); toast = "Progress reset" }
                }
            }.scrollContentBackground(.hidden)
        }
    }
    private func settingToggle(_ title: String, keyPath: WritableKeyPath<GameSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { profile.profile.settings[keyPath: keyPath] }, set: { value in profile.update { $0.settings[keyPath: keyPath] = value } }))
    }
    private func claimFreeChest() {
        let now = Date()
        guard now.timeIntervalSince(profile.profile.lastFreeChest) >= 4 * 3600 else { toast = "Free chest is still on cooldown"; return }
        profile.update { $0.lastFreeChest = now; $0.gold += 150; $0.gems += 3 }
        toast = "Chest opened · +150 gold · +3 gems"
    }
    private var shop: some View {
        ScrollView {
            VStack(spacing: 14) {
                header("Daily Supply", back: .home)
                HStack { Label("\(profile.profile.gold) gold", systemImage: "circle.hexagongrid.fill").foregroundStyle(gold); Spacer(); Label("\(profile.profile.gems) gems", systemImage: "diamond.fill").foregroundStyle(accent) }.font(.subheadline.bold()).padding(.horizontal, 18)
                VStack(alignment: .leading, spacing: 10) {
                    Text("CHEST SLOTS").font(.headline.bold()).tracking(1)
                    ForEach(0..<4, id: \.self) { slot in
                        if let chest = (profile.profile.meta?.chestSlots ?? []).indices.contains(slot) ? profile.profile.meta?.chestSlots[slot] : nil {
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill").font(.title2).foregroundStyle(chest.isReady ? gold : accent).frame(width: 42, height: 42).background(panel, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 3) { Text("\(chest.type) Chest").font(.subheadline.bold()); Text(chest.isReady ? "Ready to open" : "Unlocks in \(eta(chest.remaining))").font(.caption).foregroundStyle(.white.opacity(0.58)) }
                                Spacer()
                                if chest.isReady { Button("OPEN") { claimChestSlot(chest.id) }.font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9).background(gold, in: Capsule()).foregroundStyle(ink) }
                            }.padding(11).background(panel, in: RoundedRectangle(cornerRadius: 15))
                        } else {
                            HStack { Image(systemName: "lock.open").foregroundStyle(.white.opacity(0.35)); Text("Empty slot · win a battle to earn a chest").font(.caption).foregroundStyle(.white.opacity(0.55)); Spacer() }.padding(13).background(panel.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }.padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("DAILY QUESTS").font(.headline.bold()).tracking(1); Spacer(); Text("Resets daily").font(.caption).foregroundStyle(.white.opacity(0.5)) }
                    ForEach(profile.profile.meta?.dailyQuests ?? []) { quest in
                        HStack(spacing: 10) {
                            Image(systemName: quest.claimed ? "checkmark.circle.fill" : "target").foregroundStyle(quest.claimed ? .green : accent).font(.title3)
                            VStack(alignment: .leading, spacing: 3) { Text(quest.title).font(.subheadline.bold()); Text("\(min(quest.progress, quest.target))/\(quest.target) · +\(quest.rewardGold) gold, +\(quest.rewardXP) XP").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                            Spacer()
                            if quest.progress >= quest.target && !quest.claimed { Button("CLAIM") { claimQuest(quest.id) }.font(.caption.bold()).padding(9).background(accent, in: Capsule()).foregroundStyle(ink) }
                            else if quest.claimed { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) }
                        }.padding(11).background(panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("FREE SEASON TRACK").font(.headline.bold()).tracking(1); Spacer(); Text("\(profile.profile.meta?.seasonXP ?? 0) XP").font(.caption.bold()).foregroundStyle(gold) }
                    Text("Monthly rewards. No premium track or purchases.").font(.caption).foregroundStyle(.white.opacity(0.55))
                    ForEach(0..<10, id: \.self) { tier in
                        let required = (tier + 1) * 100
                        let claimed = profile.profile.meta?.claimedSeasonTiers.contains(tier) ?? false
                        HStack {
                            ZStack { Circle().fill(gold.opacity(0.18)).frame(width: 36, height: 36); Text("\(tier + 1)").font(.caption.bold()).foregroundStyle(gold) }
                            VStack(alignment: .leading, spacing: 2) { Text("Reward tier \(tier + 1)").font(.subheadline.bold()); Text("\(required) season XP · \(150 + tier * 50) gold").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                            Spacer()
                            if claimed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if (profile.profile.meta?.seasonXP ?? 0) >= required { Button("CLAIM") { claimSeasonTier(tier) }.font(.caption.bold()).padding(9).background(gold, in: Capsule()).foregroundStyle(ink) }
                            else { Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.25)) }
                        }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 13))
                    }
                }.padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 10) {
                    Text("CARD SHOP").font(.headline.bold()).tracking(1)
                    Text("Gold-only offers. Every card can be earned through play.").font(.caption).foregroundStyle(.white.opacity(0.55))
                    ForEach(Array(CardCatalog.all.prefix(6))) { card in
                        let level = profile.profile.levels[card.id] ?? 1
                        let copies = profile.profile.meta?.cardCopies?[card.id] ?? 0
                        let required = copyRequirement(level)
                        VStack(spacing: 8) {
                            HStack { CardGlyph(card: card, size: 48); VStack(alignment: .leading) { Text(card.name).font(.subheadline.bold()); Text("Level \(level)/13 · \(copies)/\(required) copies · \(card.rarity.rawValue)").font(.caption).foregroundStyle(.white.opacity(0.55)) }; Spacer() }
                            HStack {
                                Button("COPY · \(copyPrice(card))g") { buyCard(card) }.font(.caption.bold()).padding(9).frame(maxWidth: .infinity).background(accent.opacity(0.18), in: Capsule())
                                Button("UPGRADE · \(upgradePrice(card, level: level))g") { upgradeCard(card) }.font(.caption.bold()).padding(9).frame(maxWidth: .infinity).background(copies >= required && level < 13 ? gold : .gray.opacity(0.3), in: Capsule()).foregroundStyle(copies >= required && level < 13 ? ink : .white.opacity(0.45)).disabled(copies < required || level >= 13)
                            }
                        }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 20)
        }
    }
    private func eta(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
    private func claimChestSlot(_ id: UUID) {
        profile.update { p in
            var meta = p.meta ?? MetaProgression()
            guard let index = meta.chestSlots.firstIndex(where: { $0.id == id }), meta.chestSlots[index].isReady else { p.meta = meta; return }
            let chest = meta.chestSlots.remove(at: index)
            p.gold += chest.gold
            p.gems += chest.gems
            let eligible = CardCatalog.all.filter { p.unlocked.contains($0.id) || p.trophies >= CardCatalog.unlockThreshold(for: $0) }
            var copies = meta.cardCopies ?? [:]
            for n in 0..<chest.copies where !eligible.isEmpty {
                let card = eligible[(p.crowns + n + p.wins) % eligible.count]
                copies[card.id, default: 0] += 1
            }
            meta.cardCopies = copies
            p.meta = meta
        }
        toast = "Chest rewards claimed"
    }
    private func claimQuest(_ id: String) {
        profile.update { p in
            var meta = p.meta ?? MetaProgression()
            guard let index = meta.dailyQuests.firstIndex(where: { $0.id == id }), !meta.dailyQuests[index].claimed, meta.dailyQuests[index].progress >= meta.dailyQuests[index].target else { p.meta = meta; return }
            meta.dailyQuests[index].claimed = true
            p.gold += meta.dailyQuests[index].rewardGold
            p.xp += meta.dailyQuests[index].rewardXP
            p.kingLevel = min(50, 1 + p.xp / 100)
            p.meta = meta
        }
        toast = "Quest reward claimed"
    }
    private func claimSeasonTier(_ tier: Int) {
        profile.update { p in
            var meta = p.meta ?? MetaProgression()
            guard tier >= 0 && tier < 10 && meta.seasonXP >= (tier + 1) * 100 && !meta.claimedSeasonTiers.contains(tier) else { p.meta = meta; return }
            meta.claimedSeasonTiers.append(tier)
            p.gold += 150 + tier * 50
            if (tier + 1) % 5 == 0 { p.gems += 2 }
            p.meta = meta
        }
        toast = "Season reward claimed"
    }
    private func copyPrice(_ card: CardDefinition) -> Int {
        switch card.rarity { case .common: return 40; case .rare: return 100; case .epic: return 250; case .legendary: return 500 }
    }
    private func copyRequirement(_ currentLevel: Int) -> Int {
        let values = [2, 4, 10, 20, 50, 100, 200, 400, 800, 1_000, 2_000, 5_000]
        return values[min(values.count - 1, max(0, currentLevel - 1))]
    }
    private func upgradePrice(_ card: CardDefinition, level: Int) -> Int {
        let rarityCost: Int
        switch card.rarity { case .common: rarityCost = 20; case .rare: rarityCost = 60; case .epic: rarityCost = 120; case .legendary: rarityCost = 240 }
        return rarityCost * max(1, level)
    }
    private func buyCard(_ card: CardDefinition) {
        guard isUnlocked(card) else { toast = "Unlock this card on Trophy Road first"; return }
        let price = copyPrice(card)
        guard profile.profile.gold >= price else { toast = "Not enough gold"; return }
        profile.update { p in
            p.gold -= price
            var meta = p.meta ?? MetaProgression()
            var copies = meta.cardCopies ?? [:]
            copies[card.id, default: 0] += 1
            meta.cardCopies = copies
            p.meta = meta
        }
        toast = "Bought one \(card.name) copy"
    }
    private func upgradeCard(_ card: CardDefinition) {
        let level = profile.profile.levels[card.id] ?? 1
        guard level < 13 else { toast = "Card is already level 13"; return }
        let required = copyRequirement(level)
        let copies = profile.profile.meta?.cardCopies?[card.id] ?? 0
        let price = upgradePrice(card, level: level)
        guard copies >= required else { toast = "Need \(required) copies to upgrade"; return }
        guard profile.profile.gold >= price else { toast = "Need \(price) gold to upgrade"; return }
        profile.update { p in
            p.gold -= price
            p.levels[card.id] = level + 1
            var meta = p.meta ?? MetaProgression()
            var stored = meta.cardCopies ?? [:]
            stored[card.id] = max(0, (stored[card.id] ?? 0) - required)
            meta.cardCopies = stored
            p.meta = meta
            p.xp += level * 5
            p.kingLevel = min(50, 1 + p.xp / 100)
        }
        toast = "\(card.name) upgraded to level \(level + 1)"
    }
    private var battleLog: some View {
        VStack(spacing: 0) {
            header("Battle Log", back: .profile)
            if profile.profile.battleLog.isEmpty { Spacer(); Image(systemName: "clock.arrow.circlepath").font(.system(size: 44)).foregroundStyle(.white.opacity(0.25)); Text("Your battles will appear here").foregroundStyle(.white.opacity(0.55)); Spacer() }
            else {
                List(profile.profile.battleLog) { record in
                    Button { startReplay(record) } label: {
                        HStack { Image(systemName: record.result == "VICTORY" ? "trophy.fill" : "shield.fill").foregroundStyle(record.result == "VICTORY" ? gold : .red); VStack(alignment: .leading) { Text(record.result).font(.headline); Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }; Spacer(); VStack(alignment: .trailing) { Text("\(record.crowns) crowns").font(.caption.bold()); Text(record.actions == nil ? "No replay data" : "Tap to replay").font(.caption2).foregroundStyle(.secondary) } }
                    }.disabled(record.actions == nil).listRowBackground(panel)
                }.scrollContentBackground(.hidden)
            }
        }
    }
    private var battleView: some View {
        VStack(spacing: 8) {
            HStack {
                Button { battle?.cancelSelection(); screen = .home } label: { Image(systemName: "xmark").frame(width: 42, height: 42).background(panel, in: Circle()) }.accessibilityLabel("Leave battle")
                Spacer()
                VStack(spacing: 2) { Text(battle?.timeText ?? "3:00").font(.title2.monospacedDigit().bold()); Text("RIVAL  ·  \(battle?.redCrowns ?? 0)  —  \(battle?.blueCrowns ?? 0)  ·  YOU").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.7)) }
                Spacer()
                Button {
                    let label = emotes[emoteIndex % emotes.count]
                    if battle?.emote(label) == true {
                        ProceduralAudio.shared.play(.emote, enabled: profile.profile.settings.sound)
                        emoteIndex += 1
                    }
                } label: { Image(systemName: "face.smiling").frame(width: 42, height: 42).background(panel, in: Circle()) }.accessibilityLabel("Send emote")
            }.padding(.horizontal, 12)
            if let battle, !battle.banner.isEmpty {
                Text(battle.banner).font(.caption.bold()).tracking(2).foregroundStyle(gold).padding(.vertical, 4)
            }
            if let battle {
                GeometryReader { proxy in
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .onAppear { arenaRect = proxy.frame(in: .named("battle")) }
                        .onChange(of: proxy.size) { _ in arenaRect = proxy.frame(in: .named("battle")) }
                }.frame(height: 440).clipShape(RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 8)
                HStack(spacing: 6) {
                    ForEach(0..<10, id: \.self) { i in Capsule().fill(Double(i) < battle.blueElixir ? Color.purple : .white.opacity(0.10)).frame(height: 8) }
                    Text(String(format: "%.1f", battle.blueElixir)).font(.caption.bold().monospacedDigit()).frame(width: 30)
                }.padding(.horizontal, 12)
                HStack(spacing: 7) {
                    ForEach(profile.profile.settings.leftHanded ? Array(battle.hand.reversed()) : battle.hand, id: \.self) { id in
                        if let card = CardCatalog.byID[id] {
                            Button { battle.select(id); scene.render(battle) } label: {
                                VStack(spacing: 4) { CardGlyph(card: card, size: 48, displayCost: battle.cost(for: id)); Text(card.name).font(.system(size: 9, weight: .bold)).lineLimit(1); Text("\(battle.cost(for: id))").font(.caption2.bold()).foregroundStyle(gold) }
                                    .frame(maxWidth: .infinity).frame(height: 88).background(battle.selectedCard == id ? accent.opacity(0.24) : panel, in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(battle.selectedCard == id ? accent : .clear, lineWidth: 2))
                                    .opacity(battle.blueElixir >= Double(battle.cost(for: id)) ? 1 : 0.38)
                            }.buttonStyle(.plain)
                                .simultaneousGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("battle"))
                                    .onChanged { value in
                                        if draggingCardID == nil {
                                            draggingCardID = id
                                            battle.select(id)
                                        }
                                        if arenaRect.width > 0 && arenaRect.contains(value.location) {
                                            let x = Double((value.location.x - arenaRect.minX) / arenaRect.width) * Balance.arenaWidth
                                            let y = Double((arenaRect.maxY - value.location.y) / arenaRect.height) * Balance.arenaHeight
                                            scene.updatePlacementGhost(x: x, y: y, valid: battle.isValidPlacement(x: x, y: y))
                                        }
                                    }
                                    .onEnded { value in
                                        defer { draggingCardID = nil }
                                        if arenaRect.width > 0 && arenaRect.contains(value.location), battle.selectedCard == id {
                                            let x = Double((value.location.x - arenaRect.minX) / arenaRect.width) * Balance.arenaWidth
                                            let y = Double((arenaRect.maxY - value.location.y) / arenaRect.height) * Balance.arenaHeight
                                            let deployed = battle.isValidPlacement(x: x, y: y) && battle.deploySelected(x: x, y: y)
                                             if deployed {
                                                 ProceduralAudio.shared.haptic(.medium, enabled: profile.profile.settings.haptics)
                                                 ProceduralAudio.shared.play(.deploy, enabled: profile.profile.settings.sound)
                                             } else {
                                                 battle.cancelSelection()
                                             }
                                        } else {
                                            battle.cancelSelection()
                                        }
                                        scene.render(battle)
                                    })
                                .disabled(battle.blueElixir < Double(battle.cost(for: id)))
                        }
                    }
                }.padding(.horizontal, 8)
                HStack {
                    Text("NEXT").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.45))
                    if let next = CardCatalog.byID[battle.nextCard] { CardGlyph(card: next, size: 28); Text(next.name).font(.caption.bold()) }
                    Spacer()
                    if battle.selectedCard != nil { Button("CANCEL") { battle.cancelSelection(); scene.render(battle) }.font(.caption.bold()).foregroundStyle(accent) }
                }.padding(.horizontal, 14)
                if let result = battle.result {
                    VStack(spacing: 8) {
                        Text(result).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(result == "VICTORY" ? gold : .white)
                        Button("CONTINUE") { screen = .home; self.battleHolder.model = nil; lastResultSaved = false }.buttonStyle(PrimaryButtonStyle())
                    }.padding(.horizontal, 24).padding(.bottom, 10)
                } else {
                    Text(battle.selectedCard == nil ? "Choose a card, then tap or drag onto your side." : "Drag across the arena and release to deploy.").font(.caption2).foregroundStyle(.white.opacity(0.55)).padding(.bottom, 4)
                }
            }
        }.padding(.top, 4).coordinateSpace(name: "battle").overlay { if battle?.result == "VICTORY" { ConfettiView().allowsHitTesting(false) } }
    }
    private func updateMusic() {
        let phase = screen == .battle ? ((battle?.elapsed ?? 0) >= 240 ? 3 : ((battle?.elapsed ?? 0) >= 120 ? 2 : 1)) : 1
        ProceduralAudio.shared.setMusic(mode: screen == .battle ? .battle : .menu, phase: phase, enabled: profile.profile.settings.music)
    }
    private func startReplay(_ record: BattleRecord) {
        let model = BattleModel(deck: record.deck ?? profile.profile.selectedDeck, seed: record.seed, replayActions: record.actions ?? [], isReplaying: true, cardLevels: profile.profile.levels, trophies: profile.profile.trophies)
        battleHolder.model = model
        lastResultSaved = true
        scene = ArenaScene(size: CGSize(width: 360, height: 640))
        scene.themeIndex = min(12, max(0, profile.profile.trophies / 300))
        scene.battle = model
        scene.onDrop = { x, y in
            let deployed = model.isValidPlacement(x: x, y: y) && model.deploySelected(x: x, y: y)
            if deployed {
                ProceduralAudio.shared.haptic(.medium, enabled: profile.profile.settings.haptics)
                ProceduralAudio.shared.play(.deploy, enabled: profile.profile.settings.sound)
            } else { model.cancelSelection() }
            scene.render(model)
        }
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.showDamageNumbers = profile.profile.settings.damageNumbers
        scene.reduceMotion = profile.profile.settings.reduceMotion
        scene.highContrast = profile.profile.settings.highContrast
        scene.hapticsEnabled = profile.profile.settings.haptics
        screen = .battle
        scene.render(model)
    }
    private func startBattle() {
        let model = BattleModel(deck: profile.profile.selectedDeck, cardLevels: profile.profile.levels, trophies: profile.profile.trophies)
        battle = model; lastResultSaved = false
        scene = ArenaScene(size: CGSize(width: 360, height: 640))
        scene.themeIndex = min(12, max(0, profile.profile.trophies / 300))
        scene.battle = model
        scene.scaleMode = .resizeFill
        scene.onDrop = { x, y in
            let deployed = model.isValidPlacement(x: x, y: y) && model.deploySelected(x: x, y: y)
            if deployed {
                ProceduralAudio.shared.haptic(.medium, enabled: profile.profile.settings.haptics)
                ProceduralAudio.shared.play(.deploy, enabled: profile.profile.settings.sound)
            } else { model.cancelSelection() }
            scene.render(model)
        }
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        screen = .battle
        scene.showDamageNumbers = profile.profile.settings.damageNumbers
        scene.reduceMotion = profile.profile.settings.reduceMotion
        scene.highContrast = profile.profile.settings.highContrast
        scene.hapticsEnabled = profile.profile.settings.haptics
        scene.render(model)
    }
    private func header(_ title: String, back: Screen) -> some View {
        HStack(spacing: 12) {
            Button { screen = back } label: { Image(systemName: "chevron.left").font(.headline.bold()).frame(width: 42, height: 42).background(panel, in: Circle()) }.accessibilityLabel("Back")
            Text(title).font(.system(size: 26, weight: .black, design: .rounded))
            Spacer()
        }.padding(16)
    }
}

struct MiniCard: View {
    let card: CardDefinition
    var body: some View {
        VStack(spacing: 4) { CardGlyph(card: card, size: 43); Text(card.name).font(.system(size: 8, weight: .bold)).lineLimit(1); Text("\(card.cost)").font(.caption2.bold()).foregroundStyle(gold) }
            .frame(maxWidth: .infinity).frame(height: 88).background(panel, in: RoundedRectangle(cornerRadius: 11))
    }
}
struct CardGlyph: View {
    let card: CardDefinition
    var size: CGFloat = 48
    var displayCost: Int? = nil
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24).fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(.white.opacity(0.16)).frame(width: size * 0.62).offset(x: size * 0.12, y: -size * 0.12)
            Image(systemName: symbol).font(.system(size: size * 0.40, weight: .black)).foregroundStyle(.white).shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            VStack { HStack { Text("\(displayCost ?? card.cost)").font(.system(size: size * 0.22, weight: .black)).foregroundStyle(.white).frame(width: size * 0.28, height: size * 0.28).background(.purple, in: Circle()); Spacer() }; Spacer() }.padding(3)
        }.frame(width: size, height: size).overlay(RoundedRectangle(cornerRadius: size * 0.24).stroke(.white.opacity(0.35), lineWidth: 1))
            .accessibilityLabel("\(card.name), \(card.cost) elixir")
    }
    private var symbol: String {
        if card.kind == .spell { return "sparkles" }
        if card.kind == .building { return "building.2.fill" }
        if card.behavior.contains(.flying) { return "bird.fill" }
        if card.behavior.contains(.ranged) { return "scope" }
        if card.behavior.contains(.splash) { return "burst.fill" }
        return "figure.fencing"
    }
    private var palette: [Color] {
        switch card.rarity { case .common: return [Color(red: 0.2, green: 0.48, blue: 0.70), Color(red: 0.08, green: 0.18, blue: 0.35)]; case .rare: return [Color(red: 0.95, green: 0.48, blue: 0.18), Color(red: 0.52, green: 0.15, blue: 0.12)]; case .epic: return [Color(red: 0.62, green: 0.30, blue: 0.94), Color(red: 0.25, green: 0.12, blue: 0.45)]; case .legendary: return [Color(red: 0.10, green: 0.72, blue: 0.68), Color(red: 0.04, green: 0.24, blue: 0.37)] }
    }
}
struct CardDetailView: View {
    let card: CardDefinition
    var body: some View {
        ZStack { ink.ignoresSafeArea(); ScrollView { VStack(spacing: 16) {
            CardGlyph(card: card, size: 116).padding(.top, 30)
            Text(card.name).font(.system(size: 28, weight: .black, design: .rounded))
            Text("\(card.rarity.rawValue.uppercased())  ·  \(card.kind.rawValue.uppercased())  ·  \(card.cost) ELIXIR").font(.caption.bold()).tracking(1).foregroundStyle(accent)
            Text(card.description).font(.body).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.72)).padding(.horizontal, 24)
            VStack(spacing: 0) {
                statRow("Hit points", card.kind == .spell ? "—" : "\(Int(card.hp))")
                statRow("Damage", "\(Int(card.damage))")
                statRow("Damage per second", card.kind == .spell ? "Instant" : "\(Int(card.dps))")
                statRow("Range", String(format: "%.1f tiles", card.range))
                statRow("Speed", card.speed == 0 ? "Stationary" : "\(Int(card.speed * 60)) tiles/min")
                statRow("Hit speed", String(format: "%.2f sec", card.hitSpeed))
                statRow("Targets", card.targetsAir ? "Ground + Air" : "Ground")
                statRow("Deploy delay", card.kind == .spell ? "Instant" : "1.0 sec")
                statRow("Analog", card.analog)
            }.background(panel, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 18)
            Spacer(minLength: 20)
        } } }
    }
    private func statRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.white.opacity(0.58)); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }.font(.subheadline).padding(.horizontal, 16).padding(.vertical, 12)
    }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline.bold()).foregroundStyle(ink).frame(maxWidth: .infinity).frame(height: 52)
            .background(accent.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 15))
            .scaleEffect(configuration.isPressed ? 0.98 : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed).padding(.horizontal, 16)
    }
}
@MainActor
final class BattleHolder: ObservableObject {
    @Published var model: BattleModel? {
        didSet {
            subscription = nil
            subscription = model?.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
    private var subscription: AnyCancellable?
}

private struct ConfettiView: View {
    @State private var phase: CGFloat = 0
    private let colors: [Color] = [.yellow, .cyan, .pink, .green, .purple, .orange]
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<36, id: \.self) { index in
                let width = max(1, Int(geometry.size.width))
                let height = max(1, Int(geometry.size.height))
                RoundedRectangle(cornerRadius: 1)
                    .fill(colors[index % colors.count])
                    .frame(width: 4, height: 8)
                    .rotationEffect(.degrees(Double(index * 37)))
                    .position(
                        x: CGFloat((index * 47) % width),
                        y: CGFloat((index * 31) % height) + phase * geometry.size.height
                    )
            }
        }
        .onAppear { withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}
