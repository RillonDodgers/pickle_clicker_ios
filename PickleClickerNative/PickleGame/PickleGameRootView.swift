import SwiftUI

private enum PickleGameTheme {
    static let background = Color(red: 0.03, green: 0.05, blue: 0.03)
    static let card = Color(red: 0.02, green: 0.04, blue: 0.03)
    static let cardStroke = Color(red: 0.17, green: 0.22, blue: 0.14)
    static let gold = Color(red: 0.91, green: 0.76, blue: 0.30)
    static let lime = Color(red: 0.84, green: 0.91, blue: 0.45)
    static let emerald = Color(red: 0.38, green: 0.96, blue: 0.72)
    static let cyan = Color(red: 0.31, green: 0.86, blue: 0.98)
    static let text = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let muted = Color(red: 0.63, green: 0.61, blue: 0.58)
    static let weak = Color(red: 0.46, green: 0.47, blue: 0.42)
    static let purple = Color(red: 0.76, green: 0.48, blue: 0.97)
}

struct PickleGameRootView: View {
    @StateObject private var model: PickleGameModel
    @State private var settingsTitleTapCount = 0
    @Environment(\.scenePhase) private var scenePhase

    init(openAppHandler: @escaping (HiddenAppDestination) -> Void) {
        _model = StateObject(wrappedValue: PickleGameModel(openApp: openAppHandler))
    }

    init(model: PickleGameModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PickleGameBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    activePanel
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 140)
            }

            if let toastMessage = model.toastMessage {
                toast(message: toastMessage)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            bottomTabBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.start()
        }
        .onDisappear {
            model.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            model.handleScenePhase(newPhase)
        }
        .alert("Ascend", isPresented: $model.showAscensionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Ascend", role: .destructive) {
                model.ascend()
            }
        } message: {
            Text("This ends the current run, keeps Dao Seeds and ascension upgrades, and starts a fresh cycle.")
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center) {
                compactMetric(label: "Qi/tap", value: model.format(model.tapQi), color: PickleGameTheme.emerald)
                    .frame(maxWidth: .infinity, alignment: .leading)
                compactMetric(label: "⚔", value: model.format(model.combatPower), color: PickleGameTheme.text)
                    .frame(maxWidth: .infinity, alignment: .center)
                compactMetric(label: "💎", value: model.format(model.snapshot.brineCrystals), color: PickleGameTheme.cyan)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(model.activeTab == .cultivate ? model.currentRealmName : model.activeTab.title)
                .font(.system(size: 44, weight: .black, design: .serif))
                .foregroundStyle(PickleGameTheme.gold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var activePanel: some View {
        switch model.activeTab {
        case .cultivate:
            cultivatePanel
        case .combat:
            combatPanel
        case .training:
            trainingPanel
        case .shop:
            shopPanel
        case .legacy:
            legacyPanel
        case .settings:
            settingsPanel
        }
    }

    private var cultivatePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                model.cultivate()
            } label: {
                Image("PickleMonk")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .shadow(color: PickleGameTheme.gold.opacity(0.18), radius: 18, x: 0, y: 8)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 16) {
                        metric(label: "Qi", value: model.format(model.snapshot.qi), color: PickleGameTheme.text)
                        metric(label: "Next", value: model.breakthroughThreshold.isInfinite ? "∞" : model.format(model.breakthroughThreshold), color: PickleGameTheme.text)
                    }

                    Spacer()

                    Text("\(model.format(model.qiPerSecond)) Qi/sec")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PickleGameTheme.weak)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PickleGameTheme.card)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [PickleGameTheme.lime, PickleGameTheme.emerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, proxy.size.width * model.qiProgress))
                    }
                }
                .frame(height: 28)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "Cultivation Arrays", subtitle: "Idle formations turn stillness into Qi. Costs follow geometric growth and spike at milestone counts.")
                statLine("Manual Qi/sec", model.format(model.tapQi * PickleBalance.defaultManualTapRate))
                statLine("Idle Qi/sec", model.format(model.production.idleQiPerSecond))
                statLine("Lifetime Qi", model.format(model.snapshot.lifetimeQi))
            }

            ForEach(model.cultivationRows) { row in
                upgradeRow(
                    title: row.title,
                    subtitle: "\(row.owned) owned · +\(model.format(row.nextGainQiPerSecond)) Qi/sec next",
                    costLabel: model.format(row.cost),
                    footer: row.paybackSeconds.map { "Payback \(model.formatDuration($0))" } ?? "Payback n/a",
                    disabled: model.snapshot.qi < row.cost
                ) {
                    model.buyCultivationUpgrade(row.id)
                }
            }
        }
    }

    private var combatPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Combat", subtitle: "Deterministic encounters transmute power into Brine Crystals. Manual attempts are instant; auto arrays scale with speed multipliers.")
            statLine("Crystal/sec", model.format(model.crystalsPerSecond))

            if model.encounterRows.isEmpty {
                emptyState("Break through a few early realms to expose local pickle demons.")
            }

            ForEach(model.encounterRows) { row in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(PickleGameTheme.text)
                        Text("Req \(model.format(row.powerRequirement)) ⚔ · \(model.format(row.rewardPerAttempt)) 💎/attempt")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(PickleGameTheme.muted)
                        Text("Manual \(model.format(row.manualCrystalPerSecond)) 💎/sec · Auto \(model.format(row.autoCrystalPerSecond)) 💎/sec")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(PickleGameTheme.weak)
                    }
                    Spacer(minLength: 8)
                    if row.autoOwned > 0 {
                        Text("×\(row.autoOwned)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PickleGameTheme.cyan)
                    }
                    iconActionButton(systemImage: "bolt.fill", tint: PickleGameTheme.cyan, disabled: model.snapshot.brineCrystals < row.autoCost) {
                        model.buyAutoCombat(row.id)
                    }
                    .overlay(alignment: .bottom) {
                        Text(model.format(row.autoCost))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(PickleGameTheme.muted)
                            .offset(y: 16)
                    }
                    iconActionButton(systemImage: "flame.fill", tint: Color(red: 1.0, green: 0.78, blue: 0.78), disabled: false) {
                        model.fight(row.id)
                    }
                }
                .padding(.vertical, 4)
                Divider().overlay(PickleGameTheme.cardStroke)
            }
        }
    }

    private var trainingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Training", subtitle: "Manual arts and hybrid sutras improve tap Qi first, then both tap and idle production.")
            statLine("Tap Qi", model.format(model.tapQi))

            ForEach(model.trainingRows) { row in
                upgradeRow(
                    title: row.title,
                    subtitle: "\(row.owned) owned · +\(model.format(row.nextTapGain)) tap · +\(model.format(row.nextGainQiPerSecond)) Qi/sec",
                    costLabel: model.format(row.cost),
                    footer: row.paybackSeconds.map { "Payback \(model.formatDuration($0))" } ?? "Payback n/a",
                    disabled: model.snapshot.qi < row.cost
                ) {
                    model.buyTrainingUpgrade(row.id)
                }
            }
        }
    }

    private var shopPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Artifact Vault", subtitle: "One-time artifacts deliver chunky multipliers. Categories stay weapon, manual, and technique.")

            ForEach(PickleArtifact.Category.allCases) { category in
                Text(category.title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(PickleGameTheme.gold.opacity(0.8))

                let rows = model.artifactRows[category, default: []]
                if rows.isEmpty {
                    emptyState("Nothing visible in this vault tier yet.")
                } else {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(PickleGameTheme.text)
                                Text(row.description)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(PickleGameTheme.muted)
                            }
                            Spacer()
                            iconActionButton(systemImage: "cart.badge.plus", tint: PickleGameTheme.text, disabled: model.snapshot.brineCrystals < row.cost) {
                                model.buyArtifact(row.id)
                            }
                        }
                        .padding(.vertical, 3)
                        Divider().overlay(PickleGameTheme.cardStroke)
                    }
                }
            }
        }
    }

    private var legacyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Ascension", subtitle: "End the run, bank Dao Seeds, and rank up permanent branches.")
            statLine("Dao Seeds", model.format(model.snapshot.daoSeeds))
            statLine("Ascend Now", "+\(model.format(model.projectedDaoSeeds))")
            statLine("Hidden Realms", "Rank \(model.hiddenRealmsRank)")

            Button("Ascend") {
                model.confirmAscension()
            }
            .buttonStyle(PickleActionButtonStyle(kind: .purple))
            .disabled(!model.ascensionUnlocked || model.projectedDaoSeeds <= 0)

            Divider().overlay(PickleGameTheme.purple.opacity(0.22))

            ForEach(model.ascensionUpgradeRows) { row in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(PickleGameTheme.text)
                        Text("\(row.description) · Rank \(row.rank)/\(row.maxRank)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(PickleGameTheme.muted)
                    }
                    Spacer()
                    if let nextCost = row.nextCost {
                        Button(model.format(nextCost)) {
                            model.buyAscensionUpgrade(row.id)
                        }
                        .buttonStyle(PickleActionButtonStyle(kind: .purple))
                        .disabled(model.snapshot.daoSeeds < nextCost)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PickleGameTheme.weak)
                    }
                }
                .padding(.vertical, 3)
                Divider().overlay(PickleGameTheme.purple.opacity(0.22))
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Settings",
                subtitle: "Display, run telemetry, and local progress.",
                titleTapAction: registerSettingsTitleTap
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("RUN STATS")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(PickleGameTheme.muted)
                statLine("Current Run Qi", model.format(model.snapshot.lifetimeQi))
                statLine("Lifetime Qi", model.format(model.snapshot.stats.lifetimeQiAcrossRuns))
                statLine("Lifetime Crystals", model.format(model.snapshot.stats.lifetimeCrystalsAcrossRuns))
                statLine("Manual Cultivations", "\(model.snapshot.stats.manualCultivations)")
                statLine("Manual Combats", "\(model.snapshot.stats.manualCombats)")
                statLine("Ascensions", "\(model.snapshot.stats.ascensions)")
            }

            Divider().overlay(PickleGameTheme.cardStroke)

            VStack(alignment: .leading, spacing: 8) {
                Text("SIM BALANCE")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(PickleGameTheme.muted)
                statLine("First Combat", model.formatDuration(model.simulationReport.firstCombatSeconds))
                statLine("First Artifact", model.formatDuration(model.simulationReport.firstArtifactSeconds))
                statLine("First Auto", model.formatDuration(model.simulationReport.firstAutoCombatSeconds))
                ForEach(Array(model.simulationReport.ascensionTimes.enumerated()), id: \.offset) { index, value in
                    statLine("Ascension \(index + 1)", model.formatDuration(value))
                }
            }

            Divider().overlay(PickleGameTheme.cardStroke)

            VStack(alignment: .leading, spacing: 8) {
                Text("NUMBER FORMAT")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(PickleGameTheme.muted)

                ForEach(PickleNumberFormat.allCases) { format in
                    Button {
                        model.setNumberFormat(format)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text(format.example)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(PickleGameTheme.muted)
                            }
                            Spacer()
                            if model.numberFormat == format {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(PickleGameTheme.emerald)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PickleGameTheme.text)
                    Divider().overlay(PickleGameTheme.cardStroke)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("LOCAL DATA")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(PickleGameTheme.muted)
                Text("The v2 economy deliberately ignores old v1 saves.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PickleGameTheme.muted)
                Button("Reset Local Progress") {
                    model.resetLocalProgress()
                }
                .buttonStyle(PickleActionButtonStyle(kind: .red))
            }
        }
    }

    private func registerSettingsTitleTap() {
        guard AppConfiguration.isDeveloperOptionsEnabled else { return }
        settingsTitleTapCount += 1
        guard settingsTitleTapCount >= 10 else { return }
        settingsTitleTapCount = 0
        if model.activeTab == .settings {
            model.openDestination(.channing)
        }
    }

    private var bottomTabBar: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(model.availableTabs) { tab in
                            Button {
                                model.selectTab(tab)
                            } label: {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .accessibilityLabel(tab.title)
                            .foregroundStyle(model.activeTab == tab ? PickleGameTheme.text : PickleGameTheme.muted)
                            .glassEffect(
                                model.activeTab == tab
                                    ? .regular.tint(PickleGameTheme.gold.opacity(0.35)).interactive()
                                    : .regular.tint(Color.white.opacity(0.08)).interactive(),
                                in: .capsule
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(Color.white.opacity(0.06)), in: .rect(cornerRadius: 28))
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            } else {
                HStack(spacing: 8) {
                    ForEach(model.availableTabs) { tab in
                        Button {
                            model.selectTab(tab)
                        } label: {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel(tab.title)
                        .buttonStyle(PickleTabButtonStyle(isActive: model.activeTab == tab))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String, titleTapAction: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let titleTapAction {
                    Button {
                        titleTapAction()
                    } label: {
                        Text(title.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .tracking(2)
                            .foregroundStyle(PickleGameTheme.muted)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(PickleGameTheme.muted)
                }
            }
            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PickleGameTheme.muted)
        }
    }

    private func metric(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(label):")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PickleGameTheme.muted)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func compactMetric(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PickleGameTheme.muted)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func upgradeRow(title: String, subtitle: String, costLabel: String, footer: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PickleGameTheme.text)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PickleGameTheme.muted)
                    Text(footer)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(PickleGameTheme.weak)
                }
                Spacer()
                Text(costLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(PickleGameTheme.muted)
                iconActionButton(systemImage: "plus", tint: PickleGameTheme.emerald, disabled: disabled, action: action)
            }
            .padding(.vertical, 4)

            Divider().overlay(PickleGameTheme.cardStroke)
        }
    }

    private func iconActionButton(systemImage: String, tint: Color, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? PickleGameTheme.weak : tint)
        .background(Circle().fill(PickleGameTheme.card))
        .overlay(Circle().stroke(PickleGameTheme.cardStroke, lineWidth: 1))
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PickleGameTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PickleGameTheme.text)
        }
    }

    private func toast(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(PickleGameTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(PickleGameTheme.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PickleGameTheme.gold.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(PickleGameTheme.weak)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private struct PickleGameBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PickleGameTheme.background,
                Color(red: 0.05, green: 0.07, blue: 0.04),
                Color(red: 0.02, green: 0.03, blue: 0.02),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .top) {
            RadialGradient(
                colors: [
                    PickleGameTheme.gold.opacity(0.18),
                    PickleGameTheme.lime.opacity(0.08),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 420
            )
        }
        .overlay(alignment: .center) {
            RadialGradient(
                colors: [
                    PickleGameTheme.emerald.opacity(0.08),
                    .clear,
                ],
                center: .center,
                startRadius: 80,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}

private enum PickleActionKind {
    case gold
    case emerald
    case cyan
    case purple
    case red
    case neutral
}

private struct PickleActionButtonStyle: ButtonStyle {
    let kind: PickleActionKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(foregroundColor.opacity(configuration.isPressed ? 0.92 : 1))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor.opacity(configuration.isPressed ? 0.9 : 1), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }

    private var foregroundColor: Color {
        switch kind {
        case .gold:
            return PickleGameTheme.gold
        case .emerald:
            return PickleGameTheme.emerald
        case .cyan:
            return PickleGameTheme.cyan
        case .purple:
            return PickleGameTheme.text
        case .red:
            return Color(red: 1, green: 0.73, blue: 0.73)
        case .neutral:
            return PickleGameTheme.text
        }
    }

    private var borderColor: Color {
        switch kind {
        case .gold:
            return PickleGameTheme.gold.opacity(0.45)
        case .emerald:
            return PickleGameTheme.emerald.opacity(0.3)
        case .cyan:
            return PickleGameTheme.cyan.opacity(0.3)
        case .purple:
            return PickleGameTheme.purple.opacity(0.45)
        case .red:
            return Color(red: 0.92, green: 0.46, blue: 0.46).opacity(0.45)
        case .neutral:
            return PickleGameTheme.cardStroke
        }
    }

    private func background(configuration: Configuration) -> some ShapeStyle {
        switch kind {
        case .gold:
            return Color(red: 0.25, green: 0.19, blue: 0.06).opacity(configuration.isPressed ? 0.96 : 1)
        case .emerald:
            return Color(red: 0.08, green: 0.21, blue: 0.16).opacity(configuration.isPressed ? 0.96 : 1)
        case .cyan:
            return Color(red: 0.06, green: 0.19, blue: 0.22).opacity(configuration.isPressed ? 0.96 : 1)
        case .purple:
            return Color(red: 0.16, green: 0.08, blue: 0.21).opacity(configuration.isPressed ? 0.96 : 1)
        case .red:
            return Color(red: 0.24, green: 0.10, blue: 0.10).opacity(configuration.isPressed ? 0.96 : 1)
        case .neutral:
            return PickleGameTheme.card.opacity(configuration.isPressed ? 0.96 : 1)
        }
    }
}

private struct PickleTabButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .foregroundStyle(isActive ? PickleGameTheme.text : PickleGameTheme.muted)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isActive ? Color(red: 0.28, green: 0.21, blue: 0.07) : PickleGameTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isActive ? PickleGameTheme.gold.opacity(0.55) : PickleGameTheme.cardStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

#if DEBUG
private extension PickleGameModel {
    static func previewModel(tab: PickleGameTab) -> PickleGameModel {
        let model = PickleGameModel(openApp: { _ in })
        model.snapshot.qi = 12_500
        model.snapshot.lifetimeQi = 145_000
        model.snapshot.brineCrystals = 1_240
        model.snapshot.daoSeeds = 6
        model.snapshot.realmIndex = 7
        model.snapshot.repeatableCounts = [
            "moss_terrace": 12,
            "jade_brine_vat": 9,
            "pickled_meridian_array": 6,
            "iron_gut_tempering": 15,
            "vinegar_meridian_cycle": 10,
            "brine_core_rotation": 7,
            "fermentation_sutra": 4,
        ]
        model.snapshot.ownedArtifacts = [
            "brine_blade": true,
            "pickle_fork_manual": true,
            "starter_fermentation": true,
            "vinegar_edge": true,
        ]
        model.snapshot.autoEncounterCounts = [
            "dill_demon": 3,
            "fermentation_fiend": 2,
        ]
        model.snapshot.ascensionUpgradeRanks = [
            "rooted_brine_core": 2,
            "saltforged_body": 1,
            "heavenly_fermentation": 1,
            "ancestor_armory": 2,
            "hidden_realms": 1,
        ]
        model.snapshot.stats = PickleGameStatsV2(
            lifetimeQiAcrossRuns: 2_800_000,
            lifetimeCrystalsAcrossRuns: 31_000,
            manualCultivations: 900,
            manualCombats: 210,
            ascensions: 2
        )
        model.activeTab = tab
        return model
    }
}

#Preview("Cultivate") {
    PickleGameRootView(model: .previewModel(tab: .cultivate))
}

#Preview("Combat") {
    PickleGameRootView(model: .previewModel(tab: .combat))
}

#Preview("Training") {
    PickleGameRootView(model: .previewModel(tab: .training))
}

#Preview("Shop") {
    PickleGameRootView(model: .previewModel(tab: .shop))
}

#Preview("Ascend") {
    PickleGameRootView(model: .previewModel(tab: .legacy))
}
#endif
