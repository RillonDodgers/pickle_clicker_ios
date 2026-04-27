import SwiftUI

struct DanbooruProfileView: View {
    let target: DanbooruProfileTarget

    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel = DanbooruProfileViewModel()
    @State private var selectedPostID: Int?

    init(target: DanbooruProfileTarget = .currentUser) {
        self.target = target
    }

    var body: some View {
        DanbooruProtectedScreen(
            title: target.title,
            tab: .profile,
            requiresSelectedTabMatch: target == .currentUser,
            taskIdentity: "\(appModel.reloadToken)|\(appModel.selectedTab)|\(target.title)|\(target.userID.map(String.init) ?? "current")",
            onLoad: loadProfile
        ) {
            loadingContent
        } content: {
            content
        }
    }

    private var loadingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DanbooruSectionCardSkeleton(titleWidth: 90, rowCount: 3)
                DanbooruSectionCardSkeleton(titleWidth: 80, rowCount: 3)
                VStack(alignment: .leading, spacing: 0) {
                    DanbooruCompactSectionHeader(title: "Favorites")
                    ForEach(0 ..< 3, id: \.self) { _ in
                        DanbooruPostCardSkeleton()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingContent
        } else if let user = viewModel.user {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    accountSection(user: user)
                    activitySection(user: user)

                    VStack(alignment: .leading, spacing: 0) {
                        DanbooruCompactSectionHeader(title: "Favorites")

                        if viewModel.favoritePosts.isEmpty {
                            Text("No favorite posts yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(viewModel.favoritePosts) { post in
                                DanbooruPostCard(
                                    post: post,
                                    configuration: appModel.configuration,
                                    onUpvote: nil,
                                    onDownvote: nil,
                                    onFavorite: nil
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectPost(post)
                                }
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.reload(target: target, using: appModel.configuration)
            }
            .navigationDestination(item: $selectedPostID) { postID in
                DanbooruPostDetailView(postID: postID)
            }
        } else {
            ContentUnavailableView(
                "No Profile Data",
                systemImage: "person.circle",
                description: Text("We couldn't load the current user profile.")
            )
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
        }
    }

    private func accountSection(user: DanbooruUser) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DanbooruCompactSectionHeader(title: "Account")
            DanbooruEdgeRow { profileRow(title: "Name", value: user.name) }
            DanbooruEdgeRow { profileRow(title: "Level", value: user.levelString ?? user.level.map(String.init) ?? "Unknown") }
            DanbooruEdgeRow { profileRow(title: "Joined", value: user.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown") }
        }
    }

    private func activitySection(user: DanbooruUser) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DanbooruCompactSectionHeader(title: "Activity")
            DanbooruEdgeRow { profileRow(title: "Uploads", value: user.postUploadCount.map(String.init) ?? "0") }
            DanbooruEdgeRow { profileRow(title: "Notes", value: user.noteCount.map(String.init) ?? "0") }
            DanbooruEdgeRow { profileRow(title: "Favorites", value: user.favoriteCount.map(String.init) ?? "0") }
        }
    }

    private func loadProfile() async {
        await viewModel.reload(target: target, using: appModel.configuration)
    }

    private func selectPost(_ post: DanbooruPostCardState) {
        selectedPostID = post.id
    }
}
