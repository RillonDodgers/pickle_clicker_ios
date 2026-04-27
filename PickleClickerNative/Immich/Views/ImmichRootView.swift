import SwiftUI

struct ImmichRootView: View {
    @StateObject private var appModel: ImmichAppModel

    @MainActor
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        _appModel = StateObject(
            wrappedValue: ImmichAppModel(
                settingsStore: ImmichSettingsStore(),
                openAppHandler: openAppHandler,
                closeHandler: closeHandler
            )
        )
    }

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                ImmichLibraryView()
            }
            .tag(ImmichAppModel.Tab.library)
            .tabItem {
                Label("Library", systemImage: "photo.on.rectangle.angled")
            }

            NavigationStack {
                ImmichAlbumsView()
            }
            .tag(ImmichAppModel.Tab.albums)
            .tabItem {
                Label("Albums", systemImage: "rectangle.stack")
            }

            NavigationStack {
                ImmichTagsView()
            }
            .tag(ImmichAppModel.Tab.tags)
            .tabItem {
                Label("Tags", systemImage: "tag")
            }

            NavigationStack {
                ImmichSettingsView()
            }
            .tag(ImmichAppModel.Tab.settings)
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
        .task {
            await appModel.validateConfigurationIfNeeded()
        }
    }
}
