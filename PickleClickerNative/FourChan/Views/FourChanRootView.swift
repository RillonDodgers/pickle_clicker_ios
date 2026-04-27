import SwiftUI

struct FourChanRootView: View {
    @StateObject private var appModel: FourChanAppModel

    @MainActor
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        _appModel = StateObject(
            wrappedValue: FourChanAppModel(
                settingsStore: FourChanSettingsStore(),
                openAppHandler: openAppHandler,
                closeHandler: closeHandler
            )
        )
    }

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                FourChanBoardsView()
            }
            .tag(FourChanAppModel.Tab.boards)
            .tabItem {
                Label("Boards", systemImage: "list.bullet")
            }

            NavigationStack {
                FourChanSettingsView()
            }
            .tag(FourChanAppModel.Tab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .environmentObject(appModel)
        .environment(\.hiddenAppActions, HiddenAppActions(
            openApp: appModel.openApp,
            close: appModel.close
        ))
        .tint(NativeAppTheme.tint)
        .toolbarBackground(NativeAppTheme.chrome.opacity(0.94), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
