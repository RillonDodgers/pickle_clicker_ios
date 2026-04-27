import XCTest
@testable import PickleClickerNative

final class PickleGameEconomyTests: XCTestCase {
    private let calculator = PickleEconomyCalculator()

    func testRepeatableGeometricCostGrowth() {
        let upgrade = PickleBalance.trainingUpgrades[0]
        XCTAssertEqual(calculator.repeatableCost(upgrade, owned: 0), 8)
        XCTAssertEqual(calculator.repeatableCost(upgrade, owned: 1), 9)
        XCTAssertEqual(calculator.repeatableCost(upgrade, owned: 5), 15)
    }

    func testMilestoneMultiplierApplication() {
        XCTAssertEqual(PickleBalance.milestoneMultiplier(for: 0), 1)
        XCTAssertEqual(PickleBalance.milestoneMultiplier(for: 10), 2)
        XCTAssertEqual(PickleBalance.milestoneMultiplier(for: 25), 4)
        XCTAssertEqual(PickleBalance.milestoneMultiplier(for: 50), 8)
        XCTAssertEqual(PickleBalance.milestoneMultiplier(for: 100), 16)
    }

    func testDeterministicCombatEfficiency() {
        var snapshot = PickleGameSnapshot()
        snapshot.realmIndex = 2
        let encounter = PickleBalance.encounters[0]

        let lowReward = calculator.rewardPerAttempt(for: encounter, snapshot: snapshot)

        snapshot.ownedArtifacts["brine_blade"] = true
        snapshot.realmIndex = 7
        let highReward = calculator.rewardPerAttempt(for: encounter, snapshot: snapshot)

        XCTAssertGreaterThan(highReward, lowReward)
        XCTAssertLessThanOrEqual(highReward, encounter.baseReward * calculator.artifactMultipliers(snapshot).crystal * calculator.ascensionCrystalMultiplier(snapshot) + 0.001)
    }

    func testPrestigeRewardCalculation() {
        XCTAssertEqual(PickleBalance.daoSeeds(for: 0), 0)
        XCTAssertEqual(PickleBalance.daoSeeds(for: 100_000), 1)
        XCTAssertEqual(PickleBalance.daoSeeds(for: 900_000), 3)
        XCTAssertEqual(PickleBalance.daoSeeds(for: 1_600_000), 4)
    }

    func testRealmThresholdsAreMonotonicAndReasonable() {
        let thresholds = PickleBalance.realms.dropLast().map(\.qiThreshold)
        XCTAssertEqual(thresholds, thresholds.sorted())

        let ratios = zip(thresholds, thresholds.dropFirst()).map { $1 / $0 }
        XCTAssertTrue(ratios.allSatisfy { $0 <= 6.0 })
        let averageRatio = ratios.reduce(0, +) / Double(ratios.count)
        XCTAssertGreaterThanOrEqual(averageRatio, 2.2)
        XCTAssertLessThanOrEqual(averageRatio, 3.5)
    }

    func testFreshSimulationHitsCoreMilestones() {
        let report = PickleBalanceSimulation().runFreshPlaythrough(targetAscensions: 3)

        XCTAssertNotNil(report.firstCombatSeconds)
        XCTAssertNotNil(report.firstArtifactSeconds)
        XCTAssertNotNil(report.firstAutoCombatSeconds)
        XCTAssertGreaterThanOrEqual(report.ascensionTimes.count, 3)

        XCTAssertLessThan(report.firstCombatSeconds ?? .infinity, 360)
        XCTAssertLessThan(report.ascensionTimes[0], 2_700)
        XCTAssertGreaterThan(report.ascensionTimes[0], 1_800)
        XCTAssertLessThan(report.ascensionTimes[1], report.ascensionTimes[0])
    }

    func testVisiblePreAscensionRowsStayWithinPaybackTarget() {
        var snapshot = PickleGameSnapshot()
        snapshot.realmIndex = PickleBalance.ascensionUnlockRealm - 1
        snapshot.qi = 500_000

        for upgrade in calculator.visibleCultivationUpgrades(snapshot) + calculator.visibleTrainingUpgrades(snapshot) {
            let laneDelta = calculator.laneDelta(for: upgrade, snapshot: snapshot)
            XCTAssertLessThanOrEqual(laneDelta.paybackSeconds ?? .infinity, 180, upgrade.name)
        }
    }

    func testV2StorageLoadsCleanlyFromEmptyDefaults() {
        let suiteName = "PickleGameStorageTests.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let storage = PickleGameStorage(defaults: defaults)
        let snapshot = storage.loadSnapshot()
        XCTAssertEqual(snapshot, PickleGameSnapshot())
    }

    func testV1SaveIsIgnored() throws {
        let suiteName = "PickleGameStorageTests.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let legacy = PickleGameSnapshot(qi: 42)
        let data = try JSONEncoder().encode(legacy)
        defaults.set(data, forKey: "pickle_xianxia_native_state_v1")

        let storage = PickleGameStorage(defaults: defaults)
        let snapshot = storage.loadSnapshot()
        XCTAssertEqual(snapshot.qi, 0)
        XCTAssertNil(defaults.data(forKey: storage.snapshotKey))
    }
}

final class DanbooruDTextTests: XCTestCase {
    func testNestedQuoteAndExpandParse() {
        let blocks = DanbooruDTextParser.parse("""
        [quote]
        Outer

        [quote]
        Inner
        [/quote]
        [/quote]

        [expand=More]
        h4#demo. Heading
        [/expand]
        """)

        XCTAssertEqual(blocks.count, 2)

        guard case let .quote(quoteBlocks) = blocks[0] else {
            return XCTFail("Expected quote block")
        }
        XCTAssertTrue(quoteBlocks.contains { block in
            if case .quote = block { return true }
            return false
        })

        guard case let .expand(title, expandBlocks) = blocks[1] else {
            return XCTFail("Expected expand block")
        }
        XCTAssertEqual(title, "More")
        guard case let .heading(level, anchor, _) = expandBlocks.first else {
            return XCTFail("Expected heading inside expand")
        }
        XCTAssertEqual(level, 4)
        XCTAssertEqual(anchor, "demo")
    }

    func testInlineLinksParseMentionsAndIDLinks() {
        let nodes = DanbooruDTextParser.parseInline("@evazion user #42 post #99 {{tag_one tag_two|Label}} [[Wiki Page|Alias]]")
        let actions = collectActions(nodes)

        XCTAssertTrue(actions.contains(.userName("evazion")))
        XCTAssertTrue(actions.contains(.user(id: 42, name: nil)))
        XCTAssertTrue(actions.contains(.post(99)))
        XCTAssertTrue(actions.contains(.tag("tag_one tag_two")))
        XCTAssertTrue(actions.contains(.wiki("Wiki Page")))
    }

    func testMalformedInlineTagFallsBackSafely() {
        let nodes = DanbooruDTextParser.parseInline("[b]broken")
        XCTAssertEqual(nodes, [.text("[b]broken")])
    }

    private func collectActions(_ nodes: [DanbooruDTextInlineNode]) -> [DanbooruDTextAction] {
        nodes.flatMap { node in
            switch node {
            case .text, .lineBreak, .code(_):
                return [DanbooruDTextAction]()
            case let .styled(_, children):
                return collectActions(children)
            case let .link(children, action):
                return [action] + collectActions(children)
            }
        }
    }
}

final class DanbooruForumReadStateTests: XCTestCase {
    @MainActor
    func testForumTopicSortingPrioritizesPinnedThenLockedThenRecent() {
        let olderPinned = makeTopic(id: 1, updatedAt: Date(timeIntervalSince1970: 10), isSticky: true, isLocked: false)
        let lockedRecent = makeTopic(id: 2, updatedAt: Date(timeIntervalSince1970: 30), isSticky: false, isLocked: true)
        let normalNewest = makeTopic(id: 3, updatedAt: Date(timeIntervalSince1970: 40), isSticky: false, isLocked: false)
        let pinnedNewest = makeTopic(id: 4, updatedAt: Date(timeIntervalSince1970: 50), isSticky: true, isLocked: false)

        let sorted = DanbooruForumViewModel.sortTopics([normalNewest, lockedRecent, olderPinned, pinnedNewest])
        XCTAssertEqual(sorted.map(\.id), [4, 1, 2, 3])
    }

    func testForumReadStateFallsBackToLocalSeenTopics() async {
        let suiteName = "DanbooruForumReadStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = DanbooruForumReadStateStore(defaults: defaults)
        let host = "https://danbooru.donmai.us"
        let login = "pickle"

        let unreadBeforeOpen = await store.isTopicRead(topicID: 42, host: host, login: login, apiIsRead: nil)
        XCTAssertFalse(unreadBeforeOpen)

        await store.markTopicRead(topicID: 42, host: host, login: login)

        let readAfterOpen = await store.isTopicRead(topicID: 42, host: host, login: login, apiIsRead: nil)
        XCTAssertTrue(readAfterOpen)

        let differentLogin = await store.isTopicRead(topicID: 42, host: host, login: "other", apiIsRead: nil)
        XCTAssertFalse(differentLogin)

        let apiOverride = await store.isTopicRead(topicID: 99, host: host, login: login, apiIsRead: true)
        XCTAssertTrue(apiOverride)
    }

    private func makeTopic(
        id: Int,
        updatedAt: Date,
        isSticky: Bool,
        isLocked: Bool
    ) -> DanbooruForumTopic {
        DanbooruForumTopic(
            id: id,
            creatorID: 1,
            updaterID: 1,
            title: "Topic \(id)",
            responseCount: 0,
            isSticky: isSticky,
            isLocked: isLocked,
            isRead: false,
            isDeleted: false,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            categoryID: 0,
            minLevel: nil
        )
    }
}
