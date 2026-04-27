import Foundation

enum PickleNumberFormat: String, CaseIterable, Identifiable {
    case engineering
    case shortScale
    case longScale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .engineering:
            return "Engineering"
        case .shortScale:
            return "Short Names"
        case .longScale:
            return "Long Names"
        }
    }

    var example: String {
        switch self {
        case .engineering:
            return "1.23e15"
        case .shortScale:
            return "1.23 QA"
        case .longScale:
            return "1.23 quadrillion"
        }
    }
}

enum PickleGameFormatter {
    private static let shortScaleSuffixes = [
        "", "K", "M", "B", "T", "QA", "QI", "SX", "SP", "OC", "NO",
        "DC", "UD", "DD", "TD", "QAD", "QID",
    ]

    private static let longScaleSuffixes = [
        "", "thousand", "million", "billion", "trillion", "quadrillion", "quintillion",
        "sextillion", "septillion", "octillion", "nonillion", "decillion",
        "undecillion", "duodecillion", "tredecillion", "quattuordecillion", "quindecillion",
    ]

    static func string(for number: Double, format: PickleNumberFormat) -> String {
        if !number.isFinite {
            return number.isInfinite ? "∞" : "0.00"
        }

        if abs(number) < 10 {
            return String(format: "%.2f", number)
        }

        let rounded = number.rounded()

        if abs(rounded) < 1000 {
            return String(Int(rounded))
        }

        switch format {
        case .engineering:
            return engineering(rounded)
        case .shortScale:
            return namedScale(rounded, suffixes: shortScaleSuffixes)
        case .longScale:
            return namedScale(rounded, suffixes: longScaleSuffixes)
        }
    }

    private static func namedScale(_ number: Double, suffixes: [String]) -> String {
        let tier = Int(floor(log10(abs(number)) / 3))
        guard tier > 0 else {
            return String(Int(number.rounded()))
        }

        let safeTier = min(tier, suffixes.count - 1)
        let scaled = number / pow(10, Double(safeTier * 3))
        let formatted = scaled >= 100 ? String(format: "%.0f", scaled) : String(format: "%.2f", scaled)
        let suffix = suffixes[safeTier]
        return suffix.isEmpty ? formatted : "\(formatted) \(suffix)"
    }

    private static func engineering(_ number: Double) -> String {
        guard number != 0 else { return "0" }
        let exponent = Int(floor(log10(abs(number)) / 3) * 3)
        let scaled = number / pow(10, Double(exponent))
        let value = scaled >= 100 ? String(format: "%.0f", scaled) : String(format: "%.2f", scaled)
        return "\(value)e\(exponent)"
    }
}

struct PickleRealmTier: Identifiable, Hashable {
    let name: String
    let qiThreshold: Double
    let qiMultiplier: Double
    let powerMultiplier: Double

    var id: String { name }
}

struct PickleEncounterTier: Identifiable, Hashable {
    let key: String
    let name: String
    let powerRequirement: Double
    let baseReward: Double
    let baseDuration: Double
    let autoBaseCost: Double
    let unlockRealmIndex: Int
    let hiddenRealmRank: Int

    var id: String { key }
}

struct PickleRepeatableUpgrade: Identifiable, Hashable {
    enum Lane: String {
        case idleCultivation
        case training
    }

    enum EffectKind: String {
        case idleQi
        case tapQi
        case hybridQi
    }

    let key: String
    let name: String
    let lane: Lane
    let effectKind: EffectKind
    let baseCost: Double
    let growth: Double
    let baseEffect: Double
    let unlockRealmIndex: Int
    let hiddenRealmRank: Int

    var id: String { key }
}

struct PickleArtifact: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case weapon
        case manual
        case technique

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weapon:
                return "Weapons"
            case .manual:
                return "Manuals"
            case .technique:
                return "Techniques"
            }
        }
    }

    let key: String
    let name: String
    let category: Category
    let cost: Double
    let powerMultiplier: Double
    let tapMultiplier: Double
    let idleMultiplier: Double
    let crystalMultiplier: Double
    let autoSpeedMultiplier: Double
    let unlockRealmIndex: Int
    let hiddenRealmRank: Int

    var id: String { key }
}

struct PickleAscensionUpgrade: Identifiable, Hashable {
    enum Branch: String {
        case rootedBrineCore
        case saltforgedBody
        case heavenlyFermentation
        case ancestorArmory
        case hiddenRealms
    }

    let key: String
    let name: String
    let description: String
    let branch: Branch
    let maxRank: Int

    var id: String { key }
}

struct PickleGameStatsV2: Codable, Hashable {
    var lifetimeQiAcrossRuns: Double = 0
    var lifetimeCrystalsAcrossRuns: Double = 0
    var manualCultivations: Int = 0
    var manualCombats: Int = 0
    var ascensions: Int = 0
}

struct PickleGameSnapshot: Codable, Hashable {
    var qi: Double = 0
    var lifetimeQi: Double = 0
    var brineCrystals: Double = 0
    var daoSeeds: Double = 0
    var realmIndex: Int = 0
    var repeatableCounts: [String: Int] = [:]
    var ownedArtifacts: [String: Bool] = [:]
    var autoEncounterCounts: [String: Int] = [:]
    var ascensionUpgradeRanks: [String: Int] = [:]
    var stats: PickleGameStatsV2 = .init()
    var lastTick: TimeInterval? = nil
}

struct PickleArtifactMultiplierSet: Hashable {
    var power: Double = 1
    var tap: Double = 1
    var idle: Double = 1
    var crystal: Double = 1
    var autoSpeed: Double = 1
}

struct PickleProductionStats: Hashable {
    var tapQi: Double
    var qiPerSecond: Double
    var idleQiPerSecond: Double
    var crystalsPerSecond: Double
    var combatPower: Double
    var qiMultiplier: Double
    var powerMultiplier: Double
    var artifactMultipliers: PickleArtifactMultiplierSet
}

struct PickleLaneDelta: Hashable {
    let deltaTapQi: Double
    let deltaQiPerSecond: Double
    let paybackSeconds: Double?
}

struct PickleSimulationReport: Hashable {
    var firstCombatSeconds: Double?
    var firstArtifactSeconds: Double?
    var firstAutoCombatSeconds: Double?
    var ascensionTimes: [Double] = []
}

enum PickleBalance {
    static let baseTapQi: Double = 1
    static let defaultManualTapRate: Double = 4
    static let maxOfflineSeconds: Double = 8 * 60 * 60
    static let ascensionUnlockRealm = 6
    static let idleGrowth: Double = 1.15
    static let trainingGrowth: Double = 1.14
    static let autoCombatGrowth: Double = 1.13
    static let daoSeedDivisor: Double = 100_000

    static let realms: [PickleRealmTier] = [
        .init(name: "Mortal", qiThreshold: 15, qiMultiplier: 1.00, powerMultiplier: 1.00),
        .init(name: "Early Houtian", qiThreshold: 40, qiMultiplier: 1.14, powerMultiplier: 1.16),
        .init(name: "Middle Houtian", qiThreshold: 100, qiMultiplier: 1.15, powerMultiplier: 1.17),
        .init(name: "Late Houtian", qiThreshold: 260, qiMultiplier: 1.17, powerMultiplier: 1.18),
        .init(name: "Early Xiantian", qiThreshold: 700, qiMultiplier: 1.19, powerMultiplier: 1.19),
        .init(name: "Middle Xiantian", qiThreshold: 1_900, qiMultiplier: 1.20, powerMultiplier: 1.20),
        .init(name: "Late Xiantian", qiThreshold: 5_000, qiMultiplier: 1.22, powerMultiplier: 1.21),
        .init(name: "Early Jindan", qiThreshold: 13_000, qiMultiplier: 1.24, powerMultiplier: 1.23),
        .init(name: "Middle Jindan", qiThreshold: 34_000, qiMultiplier: 1.26, powerMultiplier: 1.24),
        .init(name: "Late Jindan", qiThreshold: 88_000, qiMultiplier: 1.28, powerMultiplier: 1.26),
        .init(name: "Early Yuanying", qiThreshold: 230_000, qiMultiplier: 1.31, powerMultiplier: 1.28),
        .init(name: "Middle Yuanying", qiThreshold: 600_000, qiMultiplier: 1.33, powerMultiplier: 1.30),
        .init(name: "Late Yuanying", qiThreshold: 1_560_000, qiMultiplier: 1.36, powerMultiplier: 1.32),
        .init(name: "Early Dongxu", qiThreshold: 4_050_000, qiMultiplier: 1.39, powerMultiplier: 1.35),
        .init(name: "Middle Dongxu", qiThreshold: 10_500_000, qiMultiplier: 1.42, powerMultiplier: 1.38),
        .init(name: "Late Dongxu", qiThreshold: 27_000_000, qiMultiplier: 1.46, powerMultiplier: 1.41),
        .init(name: "Early Kongming", qiThreshold: 69_000_000, qiMultiplier: 1.50, powerMultiplier: 1.44),
        .init(name: "Middle Kongming", qiThreshold: 176_000_000, qiMultiplier: 1.55, powerMultiplier: 1.48),
        .init(name: "Late Kongming", qiThreshold: 448_000_000, qiMultiplier: 1.60, powerMultiplier: 1.52),
        .init(name: "Early Dujie", qiThreshold: 1_138_000_000, qiMultiplier: 1.66, powerMultiplier: 1.56),
        .init(name: "Middle Dujie", qiThreshold: 2_880_000_000, qiMultiplier: 1.72, powerMultiplier: 1.61),
        .init(name: "Dacheng", qiThreshold: .infinity, qiMultiplier: 1.80, powerMultiplier: 1.66),
    ]

    static let cultivationUpgrades: [PickleRepeatableUpgrade] = [
        .init(key: "moss_terrace", name: "Moss Terrace Breathing", lane: .idleCultivation, effectKind: .idleQi, baseCost: 12, growth: idleGrowth, baseEffect: 0.50, unlockRealmIndex: 0, hiddenRealmRank: 0),
        .init(key: "jade_brine_vat", name: "Jade Brine Vat", lane: .idleCultivation, effectKind: .idleQi, baseCost: 80, growth: idleGrowth, baseEffect: 2.20, unlockRealmIndex: 1, hiddenRealmRank: 0),
        .init(key: "pickled_meridian_array", name: "Pickled Meridian Array", lane: .idleCultivation, effectKind: .idleQi, baseCost: 460, growth: idleGrowth, baseEffect: 9.00, unlockRealmIndex: 2, hiddenRealmRank: 0),
        .init(key: "salted_spirit_grove", name: "Salted Spirit Grove", lane: .idleCultivation, effectKind: .idleQi, baseCost: 2_800, growth: idleGrowth, baseEffect: 38.00, unlockRealmIndex: 4, hiddenRealmRank: 0),
        .init(key: "thousand_jar_pagoda", name: "Thousand Jar Pagoda", lane: .idleCultivation, effectKind: .idleQi, baseCost: 17_000, growth: idleGrowth, baseEffect: 155.00, unlockRealmIndex: 6, hiddenRealmRank: 1),
        .init(key: "celestial_pickle_orchard", name: "Celestial Pickle Orchard", lane: .idleCultivation, effectKind: .idleQi, baseCost: 110_000, growth: idleGrowth, baseEffect: 640.00, unlockRealmIndex: 8, hiddenRealmRank: 2),
    ]

    static let trainingUpgrades: [PickleRepeatableUpgrade] = [
        .init(key: "iron_gut_tempering", name: "Iron Gut Tempering", lane: .training, effectKind: .tapQi, baseCost: 8, growth: trainingGrowth, baseEffect: 0.10, unlockRealmIndex: 0, hiddenRealmRank: 0),
        .init(key: "vinegar_meridian_cycle", name: "Vinegar Meridian Cycle", lane: .training, effectKind: .tapQi, baseCost: 36, growth: trainingGrowth, baseEffect: 0.18, unlockRealmIndex: 1, hiddenRealmRank: 0),
        .init(key: "brine_core_rotation", name: "Brine Core Rotation", lane: .training, effectKind: .hybridQi, baseCost: 200, growth: trainingGrowth, baseEffect: 0.11, unlockRealmIndex: 2, hiddenRealmRank: 0),
        .init(key: "fermentation_sutra", name: "Fermentation Sutra", lane: .training, effectKind: .hybridQi, baseCost: 1_100, growth: trainingGrowth, baseEffect: 0.18, unlockRealmIndex: 4, hiddenRealmRank: 0),
        .init(key: "dao_of_pickled_thunder", name: "Dao of Pickled Thunder", lane: .training, effectKind: .hybridQi, baseCost: 6_400, growth: trainingGrowth, baseEffect: 0.28, unlockRealmIndex: 6, hiddenRealmRank: 1),
        .init(key: "immortal_pickle_canon", name: "Immortal Pickle Canon", lane: .training, effectKind: .hybridQi, baseCost: 40_000, growth: trainingGrowth, baseEffect: 0.42, unlockRealmIndex: 8, hiddenRealmRank: 2),
    ]

    static let encounters: [PickleEncounterTier] = [
        .init(key: "brine_bandit", name: "Brine Bandit", powerRequirement: 18, baseReward: 0.8, baseDuration: 1.6, autoBaseCost: 25, unlockRealmIndex: 1, hiddenRealmRank: 0),
        .init(key: "vinegar_viper", name: "Vinegar Viper", powerRequirement: 36, baseReward: 2.4, baseDuration: 1.9, autoBaseCost: 75, unlockRealmIndex: 2, hiddenRealmRank: 0),
        .init(key: "dill_demon", name: "Dill Demon", powerRequirement: 72, baseReward: 8.0, baseDuration: 2.2, autoBaseCost: 220, unlockRealmIndex: 3, hiddenRealmRank: 0),
        .init(key: "fermentation_fiend", name: "Fermentation Fiend", powerRequirement: 140, baseReward: 24.0, baseDuration: 2.6, autoBaseCost: 650, unlockRealmIndex: 4, hiddenRealmRank: 0),
        .init(key: "cucumber_cultist", name: "Cucumber Cultist", powerRequirement: 265, baseReward: 70.0, baseDuration: 3.0, autoBaseCost: 1_800, unlockRealmIndex: 5, hiddenRealmRank: 0),
        .init(key: "gherkin_guardian", name: "Gherkin Guardian", powerRequirement: 470, baseReward: 200.0, baseDuration: 3.4, autoBaseCost: 5_400, unlockRealmIndex: 6, hiddenRealmRank: 0),
        .init(key: "pickle_patriarch", name: "Pickle Patriarch", powerRequirement: 800, baseReward: 560.0, baseDuration: 3.8, autoBaseCost: 15_000, unlockRealmIndex: 7, hiddenRealmRank: 1),
        .init(key: "brine_behemoth", name: "Brine Behemoth", powerRequirement: 1_350, baseReward: 1_500.0, baseDuration: 4.1, autoBaseCost: 42_000, unlockRealmIndex: 8, hiddenRealmRank: 1),
        .init(key: "vinegar_sovereign", name: "Vinegar Sovereign", powerRequirement: 2_200, baseReward: 4_100.0, baseDuration: 4.5, autoBaseCost: 115_000, unlockRealmIndex: 9, hiddenRealmRank: 1),
        .init(key: "dill_overlord", name: "Dill Overlord", powerRequirement: 3_500, baseReward: 11_000.0, baseDuration: 5.0, autoBaseCost: 320_000, unlockRealmIndex: 10, hiddenRealmRank: 2),
        .init(key: "ferment_emperor", name: "Fermentation Emperor", powerRequirement: 5_600, baseReward: 29_000.0, baseDuration: 5.6, autoBaseCost: 880_000, unlockRealmIndex: 11, hiddenRealmRank: 2),
    ]

    static let artifacts: [PickleArtifact] = [
        .init(key: "brine_blade", name: "Brine Blade", category: .weapon, cost: 15, powerMultiplier: 2.0, tapMultiplier: 1.0, idleMultiplier: 1.0, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 1, hiddenRealmRank: 0),
        .init(key: "pickle_fork_manual", name: "Pickle Fork Manual", category: .manual, cost: 22, powerMultiplier: 1.0, tapMultiplier: 1.55, idleMultiplier: 1.0, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 1, hiddenRealmRank: 0),
        .init(key: "starter_fermentation", name: "Starter Fermentation", category: .technique, cost: 30, powerMultiplier: 1.0, tapMultiplier: 1.0, idleMultiplier: 1.80, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 2, hiddenRealmRank: 0),
        .init(key: "vinegar_edge", name: "Vinegar Edge", category: .weapon, cost: 110, powerMultiplier: 1.85, tapMultiplier: 1.0, idleMultiplier: 1.0, crystalMultiplier: 1.15, autoSpeedMultiplier: 1.0, unlockRealmIndex: 3, hiddenRealmRank: 0),
        .init(key: "thousand_jar_scripture", name: "Thousand Jar Scripture", category: .manual, cost: 165, powerMultiplier: 1.0, tapMultiplier: 1.65, idleMultiplier: 1.20, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 4, hiddenRealmRank: 0),
        .init(key: "salt_sea_array", name: "Salt Sea Array", category: .technique, cost: 240, powerMultiplier: 1.0, tapMultiplier: 1.0, idleMultiplier: 2.10, crystalMultiplier: 1.10, autoSpeedMultiplier: 1.0, unlockRealmIndex: 4, hiddenRealmRank: 0),
        .init(key: "fermentation_fang", name: "Fermentation Fang", category: .weapon, cost: 900, powerMultiplier: 2.20, tapMultiplier: 1.0, idleMultiplier: 1.0, crystalMultiplier: 1.20, autoSpeedMultiplier: 1.10, unlockRealmIndex: 6, hiddenRealmRank: 1),
        .init(key: "cucumber_crush_compendium", name: "Cucumber Crush Compendium", category: .manual, cost: 1_350, powerMultiplier: 1.0, tapMultiplier: 1.90, idleMultiplier: 1.30, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 6, hiddenRealmRank: 1),
        .init(key: "supreme_curing", name: "Supreme Curing", category: .technique, cost: 1_900, powerMultiplier: 1.0, tapMultiplier: 1.0, idleMultiplier: 2.40, crystalMultiplier: 1.15, autoSpeedMultiplier: 1.15, unlockRealmIndex: 7, hiddenRealmRank: 1),
        .init(key: "gherkin_greatsword", name: "Gherkin Greatsword", category: .weapon, cost: 7_200, powerMultiplier: 2.60, tapMultiplier: 1.0, idleMultiplier: 1.0, crystalMultiplier: 1.25, autoSpeedMultiplier: 1.15, unlockRealmIndex: 9, hiddenRealmRank: 2),
        .init(key: "immortal_pickle_manual", name: "Immortal Pickle Manual", category: .manual, cost: 9_600, powerMultiplier: 1.0, tapMultiplier: 2.20, idleMultiplier: 1.35, crystalMultiplier: 1.0, autoSpeedMultiplier: 1.0, unlockRealmIndex: 9, hiddenRealmRank: 2),
        .init(key: "transcendent_fermentation", name: "Transcendent Fermentation", category: .technique, cost: 12_800, powerMultiplier: 1.0, tapMultiplier: 1.0, idleMultiplier: 2.90, crystalMultiplier: 1.20, autoSpeedMultiplier: 1.20, unlockRealmIndex: 10, hiddenRealmRank: 2),
    ]

    static let ascensionUpgrades: [PickleAscensionUpgrade] = [
        .init(key: "rooted_brine_core", name: "Rooted Brine Core", description: "+10% all Qi per rank", branch: .rootedBrineCore, maxRank: 5),
        .init(key: "saltforged_body", name: "Saltforged Body", description: "+10% combat rewards per rank", branch: .saltforgedBody, maxRank: 5),
        .init(key: "heavenly_fermentation", name: "Heavenly Fermentation", description: "+10% auto-combat speed per rank", branch: .heavenlyFermentation, maxRank: 5),
        .init(key: "ancestor_armory", name: "Ancestor Armory", description: "Start each run with early artifacts", branch: .ancestorArmory, maxRank: 5),
        .init(key: "hidden_realms", name: "Hidden Realms", description: "Unlock deeper training, combat, and shop tiers", branch: .hiddenRealms, maxRank: 5),
    ]

    static let ancestorArmoryArtifactOrder = [
        "brine_blade",
        "pickle_fork_manual",
        "starter_fermentation",
        "vinegar_edge",
        "thousand_jar_scripture",
    ]

    static func milestoneMultiplier(for owned: Int) -> Double {
        guard owned > 0 else { return 1 }

        var checkpoints = 0
        if owned >= 10 { checkpoints += 1 }
        if owned >= 25 { checkpoints += 1 }
        if owned >= 50 { checkpoints += 1 }
        if owned > 50 { checkpoints += max(0, (owned - 50) / 50) }
        return pow(2, Double(checkpoints))
    }

    static func geometricCost(baseCost: Double, growth: Double, owned: Int) -> Double {
        floor(baseCost * pow(growth, Double(owned)))
    }

    static func daoSeeds(for lifetimeQi: Double) -> Double {
        floor(sqrt(max(0, lifetimeQi) / daoSeedDivisor))
    }
}

struct PickleEconomyCalculator {
    func productionStats(for snapshot: PickleGameSnapshot) -> PickleProductionStats {
        let qiMultiplier = cumulativeRealmQiMultiplier(realmIndex: snapshot.realmIndex) * ascensionQiMultiplier(snapshot) * artifactMultipliers(snapshot).tap / artifactMultipliers(snapshot).tap
        let powerMultiplier = cumulativeRealmPowerMultiplier(realmIndex: snapshot.realmIndex)
        let artifacts = artifactMultipliers(snapshot)
        let training = trainingContributions(snapshot)
        let tapQi = PickleBalance.baseTapQi
            * cumulativeRealmQiMultiplier(realmIndex: snapshot.realmIndex)
            * ascensionQiMultiplier(snapshot)
            * artifacts.tap
            * (1 + training.tapBonus + training.hybridBonus)

        let idleMultiplier = cumulativeRealmQiMultiplier(realmIndex: snapshot.realmIndex)
            * ascensionQiMultiplier(snapshot)
            * artifacts.idle
            * (1 + training.hybridBonus)

        let idleQiPerSecond = visibleCultivationUpgrades(snapshot).reduce(into: 0.0) { partial, upgrade in
            let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
            guard owned > 0 else { return }
            partial += upgrade.baseEffect * Double(owned) * PickleBalance.milestoneMultiplier(for: owned) * idleMultiplier
        }

        let combatPower = 10
            * cumulativeRealmPowerMultiplier(realmIndex: snapshot.realmIndex)
            * artifacts.power

        let crystalsPerSecond = visibleEncounters(snapshot).reduce(into: 0.0) { partial, encounter in
            let autoOwned = snapshot.autoEncounterCounts[encounter.key, default: 0]
            guard autoOwned > 0 else { return }
            let reward = rewardPerAttempt(for: encounter, snapshot: snapshot, power: combatPower, artifacts: artifacts)
            let speed = artifacts.autoSpeed * ascensionAutoSpeedMultiplier(snapshot)
            partial += (reward / encounter.baseDuration) * Double(autoOwned) * speed
        }

        return PickleProductionStats(
            tapQi: tapQi,
            qiPerSecond: idleQiPerSecond,
            idleQiPerSecond: idleQiPerSecond,
            crystalsPerSecond: crystalsPerSecond,
            combatPower: combatPower,
            qiMultiplier: qiMultiplier,
            powerMultiplier: powerMultiplier,
            artifactMultipliers: artifacts
        )
    }

    func canBreakthrough(_ snapshot: PickleGameSnapshot) -> Bool {
        snapshot.realmIndex < PickleBalance.realms.count - 1 && snapshot.qi >= currentRealmThreshold(snapshot)
    }

    func currentRealmThreshold(_ snapshot: PickleGameSnapshot) -> Double {
        guard snapshot.realmIndex < PickleBalance.realms.count - 1 else { return .infinity }
        return PickleBalance.realms[snapshot.realmIndex].qiThreshold
    }

    func visibleCultivationUpgrades(_ snapshot: PickleGameSnapshot) -> [PickleRepeatableUpgrade] {
        PickleBalance.cultivationUpgrades.filter { isUnlocked($0, snapshot: snapshot) }
    }

    func visibleTrainingUpgrades(_ snapshot: PickleGameSnapshot) -> [PickleRepeatableUpgrade] {
        PickleBalance.trainingUpgrades.filter { isUnlocked($0, snapshot: snapshot) }
    }

    func visibleArtifacts(_ snapshot: PickleGameSnapshot) -> [PickleArtifact] {
        PickleBalance.artifacts.filter { artifact in
            snapshot.ownedArtifacts[artifact.key] != true && snapshot.realmIndex >= artifact.unlockRealmIndex && hiddenRealmsRank(snapshot) >= artifact.hiddenRealmRank
        }
    }

    func visibleEncounters(_ snapshot: PickleGameSnapshot) -> [PickleEncounterTier] {
        PickleBalance.encounters.filter { encounter in
            snapshot.realmIndex >= encounter.unlockRealmIndex && hiddenRealmsRank(snapshot) >= encounter.hiddenRealmRank
        }
    }

    func ascensionRank(for branch: PickleAscensionUpgrade.Branch, snapshot: PickleGameSnapshot) -> Int {
        let key = PickleBalance.ascensionUpgrades.first(where: { $0.branch == branch })?.key
        return key.map { snapshot.ascensionUpgradeRanks[$0, default: 0] } ?? 0
    }

    func artifactMultipliers(_ snapshot: PickleGameSnapshot) -> PickleArtifactMultiplierSet {
        PickleBalance.artifacts.reduce(into: PickleArtifactMultiplierSet()) { partial, artifact in
            guard snapshot.ownedArtifacts[artifact.key] == true else { return }
            partial.power *= artifact.powerMultiplier
            partial.tap *= artifact.tapMultiplier
            partial.idle *= artifact.idleMultiplier
            partial.crystal *= artifact.crystalMultiplier
            partial.autoSpeed *= artifact.autoSpeedMultiplier
        }
    }

    func rewardPerAttempt(for encounter: PickleEncounterTier, snapshot: PickleGameSnapshot) -> Double {
        let stats = productionStats(for: snapshot)
        return rewardPerAttempt(for: encounter, snapshot: snapshot, power: stats.combatPower, artifacts: stats.artifactMultipliers)
    }

    func crystalPerSecond(for encounter: PickleEncounterTier, snapshot: PickleGameSnapshot) -> Double {
        let autoOwned = snapshot.autoEncounterCounts[encounter.key, default: 0]
        guard autoOwned > 0 else { return 0 }
        let reward = rewardPerAttempt(for: encounter, snapshot: snapshot)
        let speed = artifactMultipliers(snapshot).autoSpeed * ascensionAutoSpeedMultiplier(snapshot)
        return (reward / encounter.baseDuration) * Double(autoOwned) * speed
    }

    func manualCrystalPerSecond(for encounter: PickleEncounterTier, snapshot: PickleGameSnapshot) -> Double {
        rewardPerAttempt(for: encounter, snapshot: snapshot) / encounter.baseDuration
    }

    func repeatableCost(_ upgrade: PickleRepeatableUpgrade, owned: Int) -> Double {
        PickleBalance.geometricCost(baseCost: upgrade.baseCost, growth: upgrade.growth, owned: owned)
    }

    func autoEncounterCost(_ encounter: PickleEncounterTier, owned: Int) -> Double {
        PickleBalance.geometricCost(baseCost: encounter.autoBaseCost, growth: PickleBalance.autoCombatGrowth, owned: owned)
    }

    func laneDelta(for upgrade: PickleRepeatableUpgrade, snapshot: PickleGameSnapshot, manualTapRate: Double = PickleBalance.defaultManualTapRate) -> PickleLaneDelta {
        var updated = snapshot
        updated.repeatableCounts[upgrade.key, default: 0] += 1

        let current = productionStats(for: snapshot)
        let next = productionStats(for: updated)
        let deltaTap = max(0, next.tapQi - current.tapQi)
        let deltaQiPerSecond = max(0, next.idleQiPerSecond - current.idleQiPerSecond + ((next.tapQi - current.tapQi) * manualTapRate))
        let cost = repeatableCost(upgrade, owned: snapshot.repeatableCounts[upgrade.key, default: 0])
        let payback = deltaQiPerSecond > 0 ? cost / deltaQiPerSecond : nil

        return PickleLaneDelta(deltaTapQi: deltaTap, deltaQiPerSecond: deltaQiPerSecond, paybackSeconds: payback)
    }

    func artifactDescription(_ artifact: PickleArtifact, format: (Double) -> String) -> String {
        var parts: [String] = []
        if artifact.powerMultiplier > 1 { parts.append("x\(String(format: "%.2f", artifact.powerMultiplier)) power") }
        if artifact.tapMultiplier > 1 { parts.append("x\(String(format: "%.2f", artifact.tapMultiplier)) tap Qi") }
        if artifact.idleMultiplier > 1 { parts.append("x\(String(format: "%.2f", artifact.idleMultiplier)) idle Qi") }
        if artifact.crystalMultiplier > 1 { parts.append("x\(String(format: "%.2f", artifact.crystalMultiplier)) crystals") }
        if artifact.autoSpeedMultiplier > 1 { parts.append("x\(String(format: "%.2f", artifact.autoSpeedMultiplier)) auto speed") }
        let effectText = parts.joined(separator: " · ")
        return "\(effectText) · \(format(artifact.cost)) 💎"
    }

    func ascensionCost(for upgrade: PickleAscensionUpgrade, snapshot: PickleGameSnapshot) -> Double? {
        let currentRank = snapshot.ascensionUpgradeRanks[upgrade.key, default: 0]
        guard currentRank < upgrade.maxRank else { return nil }
        return pow(2, Double(currentRank))
    }

    func ascensionPreview(for snapshot: PickleGameSnapshot) -> Double {
        PickleBalance.daoSeeds(for: snapshot.lifetimeQi)
    }

    func fullResetSnapshot(preservingMetaFrom snapshot: PickleGameSnapshot) -> PickleGameSnapshot {
        var reset = PickleGameSnapshot()
        reset.daoSeeds = snapshot.daoSeeds
        reset.ascensionUpgradeRanks = snapshot.ascensionUpgradeRanks
        reset.stats = snapshot.stats
        grantAncestorArtifacts(into: &reset)
        return reset
    }

    func grantAncestorArtifacts(into snapshot: inout PickleGameSnapshot) {
        let rank = ascensionRank(for: .ancestorArmory, snapshot: snapshot)
        guard rank > 0 else { return }

        for key in PickleBalance.ancestorArmoryArtifactOrder.prefix(rank) {
            snapshot.ownedArtifacts[key] = true
        }
    }

    func hiddenRealmsRank(_ snapshot: PickleGameSnapshot) -> Int {
        ascensionRank(for: .hiddenRealms, snapshot: snapshot)
    }

    func ascensionQiMultiplier(_ snapshot: PickleGameSnapshot) -> Double {
        1 + (Double(ascensionRank(for: .rootedBrineCore, snapshot: snapshot)) * 0.10)
    }

    func ascensionCrystalMultiplier(_ snapshot: PickleGameSnapshot) -> Double {
        1 + (Double(ascensionRank(for: .saltforgedBody, snapshot: snapshot)) * 0.10)
    }

    func ascensionAutoSpeedMultiplier(_ snapshot: PickleGameSnapshot) -> Double {
        1 + (Double(ascensionRank(for: .heavenlyFermentation, snapshot: snapshot)) * 0.10)
    }

    func cumulativeRealmQiMultiplier(realmIndex: Int) -> Double {
        guard realmIndex > 0 else { return 1 }
        return PickleBalance.realms.prefix(realmIndex + 1).reduce(1) { $0 * $1.qiMultiplier }
    }

    func cumulativeRealmPowerMultiplier(realmIndex: Int) -> Double {
        guard realmIndex > 0 else { return 1 }
        return PickleBalance.realms.prefix(realmIndex + 1).reduce(1) { $0 * $1.powerMultiplier }
    }

    func trainingContributions(_ snapshot: PickleGameSnapshot) -> (tapBonus: Double, hybridBonus: Double) {
        visibleTrainingUpgrades(snapshot).reduce(into: (tapBonus: 0.0, hybridBonus: 0.0)) { partial, upgrade in
            let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
            guard owned > 0 else { return }
            let effect = upgrade.baseEffect * Double(owned) * PickleBalance.milestoneMultiplier(for: owned)
            switch upgrade.effectKind {
            case .tapQi:
                partial.tapBonus += effect
            case .hybridQi:
                partial.hybridBonus += effect
            case .idleQi:
                break
            }
        }
    }

    func rewardPerAttempt(for encounter: PickleEncounterTier, snapshot: PickleGameSnapshot, power: Double, artifacts: PickleArtifactMultiplierSet) -> Double {
        let efficiency = pow(min(1, power / encounter.powerRequirement), 2)
        return encounter.baseReward * efficiency * artifacts.crystal * ascensionCrystalMultiplier(snapshot)
    }

    func isUnlocked(_ upgrade: PickleRepeatableUpgrade, snapshot: PickleGameSnapshot) -> Bool {
        snapshot.realmIndex >= upgrade.unlockRealmIndex && hiddenRealmsRank(snapshot) >= upgrade.hiddenRealmRank
    }
}

struct PickleBalanceSimulation {
    private let calculator = PickleEconomyCalculator()

    func runFreshPlaythrough(targetAscensions: Int = 3) -> PickleSimulationReport {
        var snapshot = PickleGameSnapshot()
        calculator.grantAncestorArtifacts(into: &snapshot)

        var report = PickleSimulationReport()
        var elapsed = 0.0
        var localRunStart = 0.0

        while report.ascensionTimes.count < targetAscensions && elapsed < 18_000 {
            stepSimulation(snapshot: &snapshot)
            elapsed += 1

            if report.firstCombatSeconds == nil, snapshot.stats.lifetimeCrystalsAcrossRuns + snapshot.brineCrystals > 0 {
                report.firstCombatSeconds = elapsed
            }
            if report.firstArtifactSeconds == nil, !snapshot.ownedArtifacts.isEmpty {
                report.firstArtifactSeconds = elapsed
            }
            if report.firstAutoCombatSeconds == nil, snapshot.autoEncounterCounts.values.contains(where: { $0 > 0 }) {
                report.firstAutoCombatSeconds = elapsed
            }

            let seeds = calculator.ascensionPreview(for: snapshot)
            if seeds >= 1, snapshot.realmIndex >= PickleBalance.ascensionUnlockRealm {
                snapshot.daoSeeds += seeds
                snapshot.stats.ascensions += 1
                report.ascensionTimes.append(elapsed - localRunStart)
                localRunStart = elapsed
                snapshot = calculator.fullResetSnapshot(preservingMetaFrom: snapshot)
            }
        }

        return report
    }

    private func stepSimulation(snapshot: inout PickleGameSnapshot) {
        let production = calculator.productionStats(for: snapshot)
        let tapGain = production.tapQi * PickleBalance.defaultManualTapRate
        snapshot.qi += tapGain + production.qiPerSecond
        snapshot.lifetimeQi += tapGain + production.qiPerSecond
        snapshot.stats.lifetimeQiAcrossRuns += tapGain + production.qiPerSecond

        while calculator.canBreakthrough(snapshot) {
            snapshot.qi -= calculator.currentRealmThreshold(snapshot)
            snapshot.realmIndex += 1
        }

        if let bestEncounter = calculator.visibleEncounters(snapshot).max(by: { calculator.manualCrystalPerSecond(for: $0, snapshot: snapshot) < calculator.manualCrystalPerSecond(for: $1, snapshot: snapshot) }) {
            let manualReward = calculator.rewardPerAttempt(for: bestEncounter, snapshot: snapshot)
            snapshot.brineCrystals += manualReward
            snapshot.stats.lifetimeCrystalsAcrossRuns += manualReward
        }

        snapshot.brineCrystals += production.crystalsPerSecond
        snapshot.stats.lifetimeCrystalsAcrossRuns += production.crystalsPerSecond

        runPurchaseLoop(snapshot: &snapshot)
    }

    private func runPurchaseLoop(snapshot: inout PickleGameSnapshot) {
        while true {
            if tryBuyBestRepeatable(snapshot: &snapshot) { continue }
            if tryBuyBestArtifact(snapshot: &snapshot) { continue }
            if tryBuyBestAutoCombat(snapshot: &snapshot) { continue }
            break
        }
    }

    private func tryBuyBestRepeatable(snapshot: inout PickleGameSnapshot) -> Bool {
        let upgrades = calculator.visibleCultivationUpgrades(snapshot) + calculator.visibleTrainingUpgrades(snapshot)
        let candidates = upgrades.compactMap { upgrade -> (PickleRepeatableUpgrade, Double, Double)? in
            let owned = snapshot.repeatableCounts[upgrade.key, default: 0]
            let cost = calculator.repeatableCost(upgrade, owned: owned)
            guard cost <= snapshot.qi else { return nil }
            let delta = calculator.laneDelta(for: upgrade, snapshot: snapshot)
            guard let payback = delta.paybackSeconds, payback.isFinite else { return nil }
            return (upgrade, cost, payback)
        }

        guard let best = candidates.min(by: { $0.2 < $1.2 }), best.2 <= 180 else { return false }
        snapshot.qi -= best.1
        snapshot.repeatableCounts[best.0.key, default: 0] += 1
        return true
    }

    private func tryBuyBestArtifact(snapshot: inout PickleGameSnapshot) -> Bool {
        let candidates = calculator.visibleArtifacts(snapshot)
            .filter { $0.cost <= snapshot.brineCrystals }
            .sorted { lhs, rhs in
                let lhsScore = (lhs.powerMultiplier * lhs.tapMultiplier * lhs.idleMultiplier * lhs.crystalMultiplier * lhs.autoSpeedMultiplier)
                let rhsScore = (rhs.powerMultiplier * rhs.tapMultiplier * rhs.idleMultiplier * rhs.crystalMultiplier * rhs.autoSpeedMultiplier)
                return lhsScore / lhs.cost > rhsScore / rhs.cost
            }

        guard let artifact = candidates.first else { return false }
        snapshot.brineCrystals -= artifact.cost
        snapshot.ownedArtifacts[artifact.key] = true
        return true
    }

    private func tryBuyBestAutoCombat(snapshot: inout PickleGameSnapshot) -> Bool {
        let candidates = calculator.visibleEncounters(snapshot).compactMap { encounter -> (PickleEncounterTier, Double, Double)? in
            let owned = snapshot.autoEncounterCounts[encounter.key, default: 0]
            let cost = calculator.autoEncounterCost(encounter, owned: owned)
            guard cost <= snapshot.brineCrystals else { return nil }

            var updated = snapshot
            updated.autoEncounterCounts[encounter.key, default: 0] += 1
            let current = calculator.productionStats(for: snapshot).crystalsPerSecond
            let next = calculator.productionStats(for: updated).crystalsPerSecond
            let delta = next - current
            guard delta > 0 else { return nil }
            return (encounter, cost, cost / delta)
        }

        guard let best = candidates.min(by: { $0.2 < $1.2 }), best.2 <= 180 else { return false }
        snapshot.brineCrystals -= best.1
        snapshot.autoEncounterCounts[best.0.key, default: 0] += 1
        return true
    }
}
