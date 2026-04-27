import Combine
import Foundation
import SwiftUI

enum PickleGameTab: String, CaseIterable, Identifiable {
    case cultivate
    case combat
    case training
    case shop
    case legacy
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cultivate:
            return "Cultivate"
        case .combat:
            return "Combat"
        case .training:
            return "Training"
        case .shop:
            return "Shop"
        case .legacy:
            return "Ascend"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .cultivate:
            return "leaf.fill"
        case .combat:
            return "figure.boxing"
        case .training:
            return "figure.strengthtraining.traditional"
        case .shop:
            return "cart.fill"
        case .legacy:
            return "sparkles"
        case .settings:
            return "gearshape.fill"
        }
    }
}

struct PickleCultivationRowViewData: Identifiable {
    let id: String
    let title: String
    let owned: Int
    let cost: Double
    let nextGainQiPerSecond: Double
    let paybackSeconds: Double?
}

struct PickleTrainingRowViewData: Identifiable {
    let id: String
    let title: String
    let owned: Int
    let cost: Double
    let nextTapGain: Double
    let nextGainQiPerSecond: Double
    let paybackSeconds: Double?
}

struct PickleEncounterRowViewData: Identifiable {
    let id: String
    let name: String
    let powerRequirement: Double
    let rewardPerAttempt: Double
    let manualCrystalPerSecond: Double
    let autoOwned: Int
    let autoCost: Double
    let autoCrystalPerSecond: Double
}

struct PickleArtifactRowViewData: Identifiable {
    let id: String
    let name: String
    let category: PickleArtifact.Category
    let cost: Double
    let description: String
}

struct PickleAscensionUpgradeRowViewData: Identifiable {
    let id: String
    let name: String
    let description: String
    let rank: Int
    let maxRank: Int
    let nextCost: Double?
}

private enum PickleGameEngine {
    static func advance(snapshot: PickleGameSnapshot, now: TimeInterval) -> PickleGameSnapshot {
        var updated = snapshot
        let calculator = PickleEconomyCalculator()

        if updated.lastTick == nil {
            updated.lastTick = now
            return updated
        }

        var delta = now - (updated.lastTick ?? now)
        guard delta > 0 else { return updated }
        delta = min(delta, PickleBalance.maxOfflineSeconds)
        updated.lastTick = now

        let production = calculator.productionStats(for: updated)
        gainQi(production.qiPerSecond * delta, into: &updated)

        let crystalGain = production.crystalsPerSecond * delta
        if crystalGain > 0 {
            updated.brineCrystals += crystalGain
            updated.stats.lifetimeCrystalsAcrossRuns += crystalGain
        }

        resolveBreakthroughs(in: &updated, using: calculator)
        return updated
    }

    private static func gainQi(_ amount: Double, into snapshot: inout PickleGameSnapshot) {
        guard amount > 0 else { return }
        snapshot.qi += amount
        snapshot.lifetimeQi += amount
        snapshot.stats.lifetimeQiAcrossRuns += amount
    }

    private static func resolveBreakthroughs(in snapshot: inout PickleGameSnapshot, using calculator: PickleEconomyCalculator) {
        while calculator.canBreakthrough(snapshot) {
            snapshot.qi -= calculator.currentRealmThreshold(snapshot)
            snapshot.realmIndex += 1
        }
    }
}

@MainActor
final class PickleGameModel: ObservableObject {
    @Published var snapshot: PickleGameSnapshot
    @Published var activeTab: PickleGameTab = .cultivate
    @Published var numberFormat: PickleNumberFormat
    @Published var toastMessage: String?
    @Published var showAscensionConfirmation = false
    @Published private(set) var simulationReport = PickleSimulationReport()

    private let storage = PickleGameStorage()
    private let calculator = PickleEconomyCalculator()
    private let openApp: (HiddenAppDestination) -> Void
    private let engineQueue = DispatchQueue(label: "party.dillonrodgers.PickleClickerNative.pickle-game-engine", qos: .userInitiated)
    private var engineTimer: DispatchSourceTimer?
    private var autosaveTimer: DispatchSourceTimer?
    private var lastToastClearTask: Task<Void, Never>?
    private var isRunning = false

    init(openApp: @escaping (HiddenAppDestination) -> Void) {
        self.openApp = openApp
        self.snapshot = storage.loadSnapshot()
        self.numberFormat = storage.loadNumberFormat()
        self.calculator.grantAncestorArtifacts(into: &self.snapshot)
        loadSimulationReport()
    }

    deinit {
        engineTimer?.cancel()
        autosaveTimer?.cancel()
    }

    var currentRealmName: String {
        PickleBalance.realms[min(snapshot.realmIndex, PickleBalance.realms.count - 1)].name
    }

    var breakthroughThreshold: Double {
        calculator.currentRealmThreshold(snapshot)
    }

    var canBreakthrough: Bool {
        calculator.canBreakthrough(snapshot)
    }

    var qiProgress: Double {
        guard breakthroughThreshold.isFinite, breakthroughThreshold > 0 else { return 1 }
        return min(snapshot.qi / breakthroughThreshold, 1)
    }

    var production: PickleProductionStats {
        calculator.productionStats(for: snapshot)
    }

    var tapQi: Double { production.tapQi }
    var qiPerSecond: Double { production.qiPerSecond }
    var crystalsPerSecond: Double { production.crystalsPerSecond }
    var combatPower: Double { production.combatPower }
    var projectedDaoSeeds: Double { calculator.ascensionPreview(for: snapshot) }
    var hiddenRealmsRank: Int { calculator.hiddenRealmsRank(snapshot) }

    var ascensionUnlocked: Bool {
        snapshot.realmIndex >= PickleBalance.ascensionUnlockRealm || snapshot.daoSeeds > 0 || snapshot.stats.ascensions > 0
    }

    var availableTabs: [PickleGameTab] {
        PickleGameTab.allCases.filter { $0 != .legacy || ascensionUnlocked }
    }

    var cultivationRows: [PickleCultivationRowViewData] {
        calculator.visibleCultivationUpgrades(snapshot).map { upgrade in
            let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
            let cost = calculator.repeatableCost(upgrade, owned: owned)
            let laneDelta = calculator.laneDelta(for: upgrade, snapshot: snapshot)
            return PickleCultivationRowViewData(
                id: upgrade.key,
                title: upgrade.name,
                owned: owned,
                cost: cost,
                nextGainQiPerSecond: laneDelta.deltaQiPerSecond,
                paybackSeconds: laneDelta.paybackSeconds
            )
        }
    }

    var trainingRows: [PickleTrainingRowViewData] {
        calculator.visibleTrainingUpgrades(snapshot).map { upgrade in
            let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
            let cost = calculator.repeatableCost(upgrade, owned: owned)
            let laneDelta = calculator.laneDelta(for: upgrade, snapshot: snapshot)
            return PickleTrainingRowViewData(
                id: upgrade.key,
                title: upgrade.name,
                owned: owned,
                cost: cost,
                nextTapGain: laneDelta.deltaTapQi,
                nextGainQiPerSecond: laneDelta.deltaQiPerSecond,
                paybackSeconds: laneDelta.paybackSeconds
            )
        }
    }

    var encounterRows: [PickleEncounterRowViewData] {
        calculator.visibleEncounters(snapshot).map { encounter in
            let autoOwned = snapshot.autoEncounterCounts[encounter.key, default: 0]
            return PickleEncounterRowViewData(
                id: encounter.key,
                name: encounter.name,
                powerRequirement: encounter.powerRequirement,
                rewardPerAttempt: calculator.rewardPerAttempt(for: encounter, snapshot: snapshot),
                manualCrystalPerSecond: calculator.manualCrystalPerSecond(for: encounter, snapshot: snapshot),
                autoOwned: autoOwned,
                autoCost: calculator.autoEncounterCost(encounter, owned: autoOwned),
                autoCrystalPerSecond: calculator.crystalPerSecond(for: encounter, snapshot: snapshot)
            )
        }
    }

    var artifactRows: [PickleArtifact.Category: [PickleArtifactRowViewData]] {
        Dictionary(grouping: calculator.visibleArtifacts(snapshot).map { artifact in
            PickleArtifactRowViewData(
                id: artifact.key,
                name: artifact.name,
                category: artifact.category,
                cost: artifact.cost,
                description: calculator.artifactDescription(artifact, format: format)
            )
        }, by: \.category)
    }

    var ascensionUpgradeRows: [PickleAscensionUpgradeRowViewData] {
        PickleBalance.ascensionUpgrades.map { upgrade in
            PickleAscensionUpgradeRowViewData(
                id: upgrade.key,
                name: upgrade.name,
                description: upgrade.description,
                rank: snapshot.ascensionUpgradeRanks[upgrade.key, default: 0],
                maxRank: upgrade.maxRank,
                nextCost: calculator.ascensionCost(for: upgrade, snapshot: snapshot)
            )
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        snapshot.lastTick = Date().timeIntervalSince1970
        startEngineTimerIfNeeded()
        startAutosaveTimerIfNeeded()
    }

    func stop() {
        isRunning = false
        engineTimer?.cancel()
        engineTimer = nil
        autosaveTimer?.cancel()
        autosaveTimer = nil
        snapshot.lastTick = Date().timeIntervalSince1970
        persist()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            start()
        case .background, .inactive:
            stop()
        @unknown default:
            break
        }
    }

    func cultivate() {
        gainQi(tapQi)
        snapshot.stats.manualCultivations += 1
        resolveBreakthroughs()
        persist()
    }

    func buyCultivationUpgrade(_ id: String) {
        guard let upgrade = calculator.visibleCultivationUpgrades(snapshot).first(where: { $0.key == id }) else { return }
        buyRepeatable(upgrade)
    }

    func buyTrainingUpgrade(_ id: String) {
        guard let upgrade = calculator.visibleTrainingUpgrades(snapshot).first(where: { $0.key == id }) else { return }
        buyRepeatable(upgrade)
    }

    func fight(_ id: String) {
        guard let encounter = calculator.visibleEncounters(snapshot).first(where: { $0.key == id }) else { return }
        let reward = calculator.rewardPerAttempt(for: encounter, snapshot: snapshot)
        snapshot.brineCrystals += reward
        snapshot.stats.lifetimeCrystalsAcrossRuns += reward
        snapshot.stats.manualCombats += 1
        showToast("Refined \(format(reward)) Brine Crystals from \(encounter.name)")
        persist()
    }

    func buyAutoCombat(_ id: String) {
        guard let encounter = calculator.visibleEncounters(snapshot).first(where: { $0.key == id }) else { return }
        let owned = snapshot.autoEncounterCounts[encounter.key, default: 0]
        let cost = calculator.autoEncounterCost(encounter, owned: owned)
        guard snapshot.brineCrystals >= cost else { return }
        snapshot.brineCrystals -= cost
        snapshot.autoEncounterCounts[encounter.key, default: 0] += 1
        showToast("Bound one more \(encounter.name) hunt to your spirit array")
        persist()
    }

    func buyArtifact(_ id: String) {
        guard let artifact = calculator.visibleArtifacts(snapshot).first(where: { $0.key == id }) else { return }
        guard snapshot.brineCrystals >= artifact.cost else { return }
        snapshot.brineCrystals -= artifact.cost
        snapshot.ownedArtifacts[artifact.key] = true
        showToast("Claimed \(artifact.name)")
        persist()
    }

    func confirmAscension() {
        showAscensionConfirmation = true
    }

    func ascend() {
        guard ascensionUnlocked else { return }
        let seeds = projectedDaoSeeds
        guard seeds > 0 else { return }

        snapshot.daoSeeds += seeds
        snapshot.stats.ascensions += 1
        let totalSeeds = snapshot.daoSeeds
        snapshot = calculator.fullResetSnapshot(preservingMetaFrom: snapshot)
        snapshot.daoSeeds = totalSeeds
        showToast("Ascended for \(format(seeds)) Dao Seeds")
        persist()
    }

    func buyAscensionUpgrade(_ id: String) {
        guard let upgrade = PickleBalance.ascensionUpgrades.first(where: { $0.key == id }) else { return }
        guard let cost = calculator.ascensionCost(for: upgrade, snapshot: snapshot) else { return }
        guard snapshot.daoSeeds >= cost else { return }
        snapshot.daoSeeds -= cost
        snapshot.ascensionUpgradeRanks[upgrade.key, default: 0] += 1
        calculator.grantAncestorArtifacts(into: &snapshot)
        showToast("\(upgrade.name) reached rank \(snapshot.ascensionUpgradeRanks[upgrade.key, default: 0])")
        persist()
    }

    func resetLocalProgress() {
        snapshot = .init()
        calculator.grantAncestorArtifacts(into: &snapshot)
        activeTab = .cultivate
        persist()
    }

    func setNumberFormat(_ format: PickleNumberFormat) {
        numberFormat = format
        storage.saveNumberFormat(format)
    }

    func selectTab(_ tab: PickleGameTab) {
        activeTab = tab
    }

    func format(_ number: Double) -> String {
        PickleGameFormatter.string(for: number, format: numberFormat)
    }

    func formatDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite else { return "n/a" }
        if seconds < 60 {
            return "\(Int(seconds.rounded()))s"
        }

        let minutes = Int(seconds) / 60
        let rem = Int(seconds) % 60
        return "\(minutes)m \(rem)s"
    }

    func openDestination(_ destination: HiddenAppDestination) {
        persist()
        openApp(destination)
    }

    private func buyRepeatable(_ upgrade: PickleRepeatableUpgrade) {
        let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
        let cost = calculator.repeatableCost(upgrade, owned: owned)
        guard snapshot.qi >= cost else { return }
        snapshot.qi -= cost
        snapshot.repeatableCounts[upgrade.key, default: 0] += 1
        showToast("\(upgrade.name) advanced to \(snapshot.repeatableCounts[upgrade.key, default: 0])")
        persist()
    }

    private func gainQi(_ amount: Double) {
        guard amount > 0 else { return }
        snapshot.qi += amount
        snapshot.lifetimeQi += amount
        snapshot.stats.lifetimeQiAcrossRuns += amount
    }

    private func resolveBreakthroughs() {
        while calculator.canBreakthrough(snapshot) {
            snapshot.qi -= calculator.currentRealmThreshold(snapshot)
            snapshot.realmIndex += 1
            showToast("Breakthrough! \(currentRealmName)")
            if snapshot.realmIndex == PickleBalance.ascensionUnlockRealm {
                showToast("Ascension has opened. The Dao now remembers your runs.")
            }
        }
    }

    private func tick() {
        snapshot = PickleGameEngine.advance(snapshot: snapshot, now: Date().timeIntervalSince1970)
    }

    private func startEngineTimerIfNeeded() {
        guard engineTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: engineQueue)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                let currentSnapshot = await MainActor.run { () -> PickleGameSnapshot? in
                    guard self.isRunning else { return nil }
                    return self.snapshot
                }
                guard let currentSnapshot else { return }

                let updatedSnapshot = PickleGameEngine.advance(
                    snapshot: currentSnapshot,
                    now: Date().timeIntervalSince1970
                )

                await MainActor.run {
                    guard self.isRunning else { return }
                    self.snapshot = updatedSnapshot
                }
            }
        }
        engineTimer = timer
        timer.resume()
    }

    private func startAutosaveTimerIfNeeded() {
        guard autosaveTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: engineQueue)
        timer.schedule(deadline: .now() + .seconds(30), repeating: .seconds(30))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning else { return }
                self.persist()
            }
        }
        autosaveTimer = timer
        timer.resume()
    }

    private func loadSimulationReport() {
        Task.detached(priority: .utility) {
          let report = await PickleBalanceSimulation().runFreshPlaythrough(targetAscensions: 3)
            await MainActor.run {
                self.simulationReport = report
            }
        }
    }

    private func persist() {
        storage.saveSnapshot(snapshot)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        lastToastClearTask?.cancel()
        lastToastClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}

struct PickleGameStorage {
    let snapshotKey = "pickle_xianxia_native_state_v2"
    let legacySnapshotKey = "pickle_xianxia_native_state_v1"
    let settingsKey = "pickle_xianxia_native_number_format_v2"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> PickleGameSnapshot {
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(PickleGameSnapshot.self, from: data) else {
            return .init()
        }

        return snapshot
    }

    func saveSnapshot(_ snapshot: PickleGameSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func loadNumberFormat() -> PickleNumberFormat {
        guard let rawValue = defaults.string(forKey: settingsKey),
              let format = PickleNumberFormat(rawValue: rawValue) else {
            return .engineering
        }

        return format
    }

    func saveNumberFormat(_ format: PickleNumberFormat) {
        defaults.set(format.rawValue, forKey: settingsKey)
    }
}
