import OSLog
import SwiftUI

struct DanbooruRootView: View {
    @StateObject private var appModel: DanbooruAppModel

    @MainActor
    init(openAppHandler: @escaping (HiddenAppDestination) -> Void, closeHandler: @escaping () -> Void) {
        _appModel = StateObject(
            wrappedValue: DanbooruAppModel(
                settingsStore: DanbooruSettingsStore(),
                openAppHandler: openAppHandler,
                closeHandler: closeHandler
            )
        )
    }

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                DanbooruFeedView()
            }
            .tag(DanbooruAppModel.Tab.posts)
            .tabItem {
                Label("Posts", systemImage: "text.rectangle.page")
            }

            NavigationStack {
                DanbooruInboxView()
            }
            .tag(DanbooruAppModel.Tab.inbox)
            .tabItem {
                Label("Inbox", systemImage: "tray.full")
            }

            NavigationStack {
                DanbooruProfileView()
            }
            .tag(DanbooruAppModel.Tab.profile)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }

            NavigationStack {
                DanbooruForumView()
            }
            .tag(DanbooruAppModel.Tab.forum)
            .tabItem {
                Label("Forum", systemImage: "text.bubble")
            }

            NavigationStack {
                DanbooruSettingsView()
            }
            .tag(DanbooruAppModel.Tab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .environmentObject(appModel)
        .environment(\.hiddenAppActions, HiddenAppActions(
            openApp: appModel.openApp,
            close: appModel.closeDanbooru
        ))
        .tint(NativeAppTheme.tint)
        .task {
            await validateConfiguration()
        }
        .onAppear {
            logAppear()
        }
    }

    private func validateConfiguration() async {
        DanbooruDiagnostics.ui.info("DanbooruRootView validation task start")
        await appModel.validateConfigurationIfNeeded()
        DanbooruDiagnostics.ui.info("DanbooruRootView validation task finish")
    }

    private func logAppear() {
        DanbooruDiagnostics.ui.info("DanbooruRootView onAppear")
    }
}
