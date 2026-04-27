import SwiftUI

struct DanbooruForumView: View {
    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel = DanbooruForumViewModel()
    @State private var selectedTopic: DanbooruForumTopic?
    @State private var selectedRoute: DanbooruNavigationRoute?

    var body: some View {
        DanbooruProtectedScreen(
            title: "Forum",
            tab: .forum,
            taskIdentity: "\(appModel.reloadToken)|\(appModel.selectedTab)",
            onLoad: loadForum
        ) {
            loadingContent
        } content: {
            content
        }
    }

    private var loadingContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0 ..< 6, id: \.self) { _ in
                    DanbooruSectionCardSkeleton(titleWidth: 180, rowCount: 3)
                }
            }
        }
    }

    private var content: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                DanbooruErrorBanner(message: errorMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if viewModel.isLoading && viewModel.topics.isEmpty {
                ForEach(0 ..< 6, id: \.self) { _ in
                    DanbooruSectionCardSkeleton(titleWidth: 180, rowCount: 3)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else if viewModel.topics.isEmpty {
                ContentUnavailableView(
                    "No Forum Topics",
                    systemImage: "text.bubble",
                    description: Text("Forum topics will show up here once they load.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.topics) { topic in
                    Button {
                        Task {
                            await viewModel.markTopicRead(topic.id, using: appModel.configuration)
                        }
                        selectedTopic = topic
                    } label: {
                        forumRow(topic)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(item: $selectedTopic) { topic in
            DanbooruForumTopicView(topic: topic)
        }
        .navigationDestination(item: $selectedRoute) { route in
            DanbooruNavigationDestination(route: route)
        }
        .refreshable {
            await viewModel.reload(using: appModel.configuration)
        }
    }

    @ViewBuilder
    private func forumRow(_ topic: DanbooruForumTopic) -> some View {
        let unread = topic.isRead == false
        DanbooruEdgeRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    if topic.isSticky {
                        NativePill(
                            title: "Pinned",
                            fill: unread ? Color(red: 0.42, green: 0.31, blue: 0.05).opacity(0.82) : Color.orange.opacity(0.18),
                            foreground: unread ? Color(red: 1.0, green: 0.88, blue: 0.47) : .orange
                        )
                        .overlay(alignment: .leading) {
                            Image(systemName: "pin.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(unread ? Color(red: 1.0, green: 0.88, blue: 0.47) : .orange)
                                .padding(.leading, 9)
                        }
                    }
                    if topic.isLocked {
                        NativePill(
                            title: "Locked",
                            fill: unread ? Color(red: 0.32, green: 0.27, blue: 0.08).opacity(0.76) : NativeAppTheme.secondaryBackground,
                            foreground: unread ? Color(red: 1.0, green: 0.86, blue: 0.4) : NativeAppTheme.secondaryText
                        )
                        .overlay(alignment: .leading) {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(unread ? Color(red: 1.0, green: 0.86, blue: 0.4) : NativeAppTheme.secondaryText)
                                .padding(.leading, 9)
                        }
                    }
                    Spacer(minLength: 0)
                    if unread {
                        NativePill(
                            title: "Unread",
                            fill: Color(red: 0.39, green: 0.31, blue: 0.05).opacity(0.85),
                            foreground: Color(red: 1.0, green: 0.9, blue: 0.5)
                        )
                    }
                }
                .padding(.bottom, 2)

                Text(topic.title)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(unread ? Color(red: 1.0, green: 0.94, blue: 0.72) : .primary)

                HStack(spacing: 12) {
                    Image(systemName: "person")
                    DanbooruUserLink(
                        userID: topic.creatorID,
                        username: viewModel.displayName(for: topic.creatorID),
                        accentColor: unread ? Color(red: 1.0, green: 0.9, blue: 0.55) : NativeAppTheme.tint
                    ) { target in
                        selectedRoute = .profile(target)
                    }
                    Image(systemName: "text.bubble")
                    Text("\(topic.responseCount)")
                    if let updatedAt = topic.updatedAt {
                        Text(updatedAt.formatted(.relative(presentation: .named)))
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(unread ? Color(red: 0.95, green: 0.85, blue: 0.46) : .secondary)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unread ? Color(red: 0.33, green: 0.25, blue: 0.05).opacity(0.5) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(unread ? Color(red: 0.92, green: 0.78, blue: 0.25).opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func loadForum() async {
        await viewModel.reload(using: appModel.configuration)
    }
}
