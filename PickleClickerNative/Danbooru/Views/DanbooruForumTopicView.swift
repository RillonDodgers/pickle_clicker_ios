import SwiftUI

struct DanbooruForumTopicView: View {
    let topic: DanbooruForumTopic

    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel = DanbooruForumTopicViewModel()
    @State private var selectedRoute: DanbooruNavigationRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let errorMessage = viewModel.errorMessage {
                    DanbooruErrorBanner(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        DanbooruCommentSkeleton()
                    }
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "No Replies Yet",
                        systemImage: "text.bubble",
                        description: Text("This topic doesn't have any visible forum posts yet.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(viewModel.posts) { post in
                        DanbooruEdgeRow(compactVerticalPadding: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    DanbooruUserLink(
                                        userID: post.creatorID,
                                        username: viewModel.displayName(for: post.creatorID),
                                        accentColor: viewModel.isTopicCreator(post.creatorID, topicCreatorID: topic.creatorID) ? .orange : NativeAppTheme.tint
                                    ) { target in
                                        selectedRoute = .profile(target)
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    if viewModel.isTopicCreator(post.creatorID, topicCreatorID: topic.creatorID) {
                                        Text("OP")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color.orange.opacity(0.12)))
                                    }
                                    Spacer()
                                    if let createdAt = post.createdAt {
                                        Text(createdAt.formatted(.relative(presentation: .named)))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                DanbooruDTextView(
                                    text: post.body,
                                    uiFont: .systemFont(ofSize: 15),
                                    foregroundColor: .white,
                                    baseURL: appModel.configuration?.baseURL
                                ) { action in
                                    handleDTextAction(action)
                                }
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Topic")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedRoute) { route in
            DanbooruNavigationDestination(route: route)
        }
        .task(id: "\(topic.id)|\(appModel.reloadToken)|\(appModel.settingsStore.settings.forumPostSortOrderRawValue)") {
            await viewModel.load(
                topicID: topic.id,
                configuration: appModel.configuration,
                commentSortOrder: appModel.settingsStore.settings.forumPostSortOrder,
                topicCreatorID: topic.creatorID
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            DanbooruEdgeRow(compactVerticalPadding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(.system(size: 21, weight: .semibold, design: .default))

                    HStack(spacing: 12) {
                        Image(systemName: "person")
                        DanbooruUserLink(
                            userID: topic.creatorID,
                            username: viewModel.displayName(for: topic.creatorID)
                        ) { target in
                            selectedRoute = .profile(target)
                        }
                        Label("\(topic.responseCount)", systemImage: "text.bubble")
                        if let createdAt = topic.createdAt {
                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        if topic.isSticky {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                        if topic.isLocked {
                            Label("Locked", systemImage: "lock.fill")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func handleDTextAction(_ action: DanbooruDTextAction) {
        let result = DanbooruActionRouter.routingResult(for: action, baseURL: appModel.configuration?.baseURL)
        if let route = result.route {
            selectedRoute = route
        }
    }
}
