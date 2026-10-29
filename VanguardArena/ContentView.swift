import SwiftUI
import SpriteKit
import UIKit

private enum Screen: Equatable { case home, deck, cards, ladder, profile, settings, battle, shop, log }
private let ink = Color(red: 0.035, green: 0.055, blue: 0.10)
private let panel = Color(red: 0.075, green: 0.105, blue: 0.17)
private let accent = Color(red: 0.39, green: 0.79, blue: 0.98)
private let gold = Color(red: 1.0, green: 0.78, blue: 0.30)

struct RootView: View {
    @EnvironmentObject private var profile: ProfileStore
    @State private var screen: Screen = .home
    @State private var battle: BattleModel?
    @State private var scene = ArenaScene(size: CGSize(width: 360, height: 640))
    @State private var detail: CardDefinition?
    @State private var lastResultSaved = false
    @State private var arenaRect: CGRect = .zero
    @State private var draggingCardID: String?
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
        .onReceive(timer) { _ in
            guard screen == .battle, let battle, !battle.isFinished else { return }
            battle.tick()
            scene.render(battle)
            if battle.isFinished && !lastResultSaved { battle.saveRecord(profile: profile); lastResultSaved = true }
        }
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
                                if profile.profile.selectedDeck.contains(card.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }.padding(10).background(panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(profile.profile.selectedDeck.contains(card.id) ? accent.opacity(0.7) : .clear, lineWidth: 1.5))
                        }.buttonStyle(.plain)
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
    private func toggleDeck(_ card: CardDefinition) {
        profile.update { p in
            if let index = p.selectedDeck.firstIndex(of: card.id) { p.selectedDeck.remove(at: index) }
            else if p.selectedDeck.count < 8 { p.selectedDeck.append(card.id) }
        }
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
                    Button("Claim free chest", action: claimChest)
                    Button("Reset all progress", role: .destructive) { profile.reset(); toast = "Progress reset" }
                }
            }.scrollContentBackground(.hidden)
        }
    }
    private func settingToggle(_ title: String, keyPath: WritableKeyPath<GameSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { profile.profile.settings[keyPath: keyPath] }, set: { value in profile.update { $0.settings[keyPath: keyPath] = value } }))
    }
    private func claimChest() {
        let now = Date()
        guard now.timeIntervalSince(profile.profile.lastFreeChest) >= 4 * 3600 else { toast = "Free chest is still on cooldown"; return }
        profile.update { $0.lastFreeChest = now; $0.gold += 150; $0.gems += 3 }
        toast = "Chest opened · +150 gold · +3 gems"
    }
    private var shop: some View {
        VStack(spacing: 16) {
            header("Daily Supply", back: .home)
            Text("A gold-only shop. No purchases, ads, or premium-only cards.").font(.subheadline).foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 20)
            ForEach(Array(CardCatalog.all.prefix(6))) { card in
                HStack { CardGlyph(card: card, size: 52); VStack(alignment: .leading) { Text(card.name).font(.headline); Text("Card copies · \(card.rarity.rawValue)").font(.caption).foregroundStyle(.white.opacity(0.55)) }; Spacer(); Button("100 gold") { buyCard(card) }.font(.caption.bold()).padding(10).background(accent.opacity(0.2), in: Capsule()) }
                    .padding(12).background(panel, in: RoundedRectangle(cornerRadius: 15)).padding(.horizontal, 16)
            }
            Spacer()
        }
    }
    private func buyCard(_ card: CardDefinition) {
        guard profile.profile.gold >= 100 else { toast = "Not enough gold"; return }
        profile.update { p in p.gold -= 100; if !p.unlocked.contains(card.id) { p.unlocked.append(card.id) }; p.levels[card.id, default: 1] = min(13, p.levels[card.id, default: 1] + 1) }
        toast = "\(card.name) upgraded"
    }
    private var battleLog: some View {
        VStack(spacing: 0) {
            header("Battle Log", back: .profile)
            if profile.profile.battleLog.isEmpty { Spacer(); Image(systemName: "clock.arrow.circlepath").font(.system(size: 44)).foregroundStyle(.white.opacity(0.25)); Text("Your battles will appear here").foregroundStyle(.white.opacity(0.55)); Spacer() }
            else {
                List(profile.profile.battleLog) { record in
                    HStack { Image(systemName: record.result == "VICTORY" ? "trophy.fill" : "shield.fill").foregroundStyle(record.result == "VICTORY" ? gold : .red); VStack(alignment: .leading) { Text(record.result).font(.headline); Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(record.crowns) crowns").font(.caption.bold()) }.listRowBackground(panel)
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
                Button { _ = battle?.emote("NICE!") } label: { Image(systemName: "face.smiling").frame(width: 42, height: 42).background(panel, in: Circle()) }.accessibilityLabel("Send emote")
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
                    ForEach(battle.hand, id: \.self) { id in
                        if let card = CardCatalog.byID[id] {
                            Button { battle.select(id); scene.render(battle) } label: {
                                VStack(spacing: 4) { CardGlyph(card: card, size: 48); Text(card.name).font(.system(size: 9, weight: .bold)).lineLimit(1); Text("\(card.cost)").font(.caption2.bold()).foregroundStyle(gold) }
                                    .frame(maxWidth: .infinity).frame(height: 88).background(battle.selectedCard == id ? accent.opacity(0.24) : panel, in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(battle.selectedCard == id ? accent : .clear, lineWidth: 2))
                                    .opacity(battle.blueElixir >= Double(card.cost) ? 1 : 0.38)
                            }.buttonStyle(.plain)
                                .simultaneousGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("battle"))
                                    .onChanged { value in
                                        if draggingCardID == nil {
                                            draggingCardID = id
                                            battle.select(id)
                                        }
                                    }
                                    .onEnded { value in
                                        defer { draggingCardID = nil }
                                        if arenaRect.width > 0 && arenaRect.contains(value.location), battle.selectedCard == id {
                                            let x = Double((value.location.x - arenaRect.minX) / arenaRect.width) * Balance.arenaWidth
                                            let y = Double((arenaRect.maxY - value.location.y) / arenaRect.height) * Balance.arenaHeight
                                            _ = battle.deploySelected(x: x, y: y)
                                            ProceduralAudio.shared.haptic(.medium, enabled: profile.profile.settings.haptics)
                                            ProceduralAudio.shared.play(.deploy, enabled: profile.profile.settings.sound)
                                        } else {
                                            battle.cancelSelection()
                                        }
                                        scene.render(battle)
                                    })
                                .disabled(battle.blueElixir < Double(card.cost))
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
                        Button("CONTINUE") { screen = .home; self.battle = nil; lastResultSaved = false }.buttonStyle(PrimaryButtonStyle())
                    }.padding(.horizontal, 24).padding(.bottom, 10)
                } else {
                    Text(battle.selectedCard == nil ? "Choose a card, then tap or drag onto your side." : "Drag across the arena and release to deploy.").font(.caption2).foregroundStyle(.white.opacity(0.55)).padding(.bottom, 4)
                }
            }
        }.padding(.top, 4).coordinateSpace(name: "battle")
    }
    private func startBattle() {
        let model = BattleModel(deck: profile.profile.selectedDeck)
        battle = model; lastResultSaved = false
        scene = ArenaScene(size: CGSize(width: 360, height: 640))
        scene.battle = model
        scene.onDrop = { x, y in _ = model.deploySelected(x: x, y: y); scene.render(model) }
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        screen = .battle
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
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24).fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(.white.opacity(0.16)).frame(width: size * 0.62).offset(x: size * 0.12, y: -size * 0.12)
            Image(systemName: symbol).font(.system(size: size * 0.40, weight: .black)).foregroundStyle(.white).shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            VStack { HStack { Text("\(card.cost)").font(.system(size: size * 0.22, weight: .black)).foregroundStyle(.white).frame(width: size * 0.28, height: size * 0.28).background(.purple, in: Circle()); Spacer() }; Spacer() }.padding(3)
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