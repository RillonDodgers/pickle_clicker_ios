import OSLog
import SwiftUI

struct DanbooruFeedView: View {
    let initialQuery: String

    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel: DanbooruFeedViewModel
    @State private var selectedPostID: Int?

    init(initialQuery: String = "") {
        let normalizedInitialQuery = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialQuery = normalizedInitialQuery
        _viewModel = StateObject(wrappedValue: DanbooruFeedViewModel(initialQuery: normalizedInitialQuery))
    }

    var body: some View {
        DanbooruProtectedScreen(
            title: "Posts",
            tab: .posts,
            taskIdentity: taskIdentity,
            onLoad: loadFeed
        ) {
            loadingContent
        } content: {
            feedContent
        }
    }

    private var loadingContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    DanbooruPostCardSkeleton()
                }
            }
        }
    }

    private var feedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                searchHeader

                if let errorMessage = viewModel.errorMessage {
                    DanbooruErrorBanner(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ForEach(0 ..< 5, id: \.self) { _ in
                        DanbooruPostCardSkeleton()
                    }
                } else if viewModel.posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts Yet",
                        systemImage: "photo.stack",
                        description: Text(viewModel.emptyStateMessage)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(viewModel.posts) { post in
                        DanbooruPostCard(
                            post: post,
                            configuration: appModel.configuration,
                            onUpvote: { upvote(post) },
                            onDownvote: { downvote(post) },
                            onFavorite: { toggleFavorite(post) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectPost(post)
                        }
                        .onAppear {
                            loadMoreIfNeeded(for: post)
                        }
                    }

                    if viewModel.isLoadingNextPage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh(using: appModel.configuration)
        }
        .navigationDestination(item: $selectedPostID) { postID in
            DanbooruPostDetailView(postID: postID)
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
            DanbooruDiagnostics.state.info("FeedView isLoading changed value=\(newValue, privacy: .public)")
        }
        .onChange(of: viewModel.posts.count) { _, newValue in
            DanbooruDiagnostics.state.info("FeedView posts.count changed value=\(newValue, privacy: .public)")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            DanbooruDiagnostics.state.info("FeedView errorMessage changed value=\(newValue ?? "nil", privacy: .public)")
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search posts by tags", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 17, weight: .regular, design: .default))

                if !viewModel.searchText.isEmpty {
                    Button("Go", action: submitSearch)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                }

                if !viewModel.appliedQuery.isEmpty {
                    Button("Clear", action: clearSearch)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))

            if !viewModel.appliedQuery.isEmpty {
                Text("Showing results for: \(viewModel.appliedQuery)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            DanbooruEdgeDivider()
        }
    }

    private var taskIdentity: String {
        "\(appModel.reloadToken)|\(appModel.selectedTab)|\(appModel.configuration?.baseURL.absoluteString ?? "nil")|\(appModel.configuration?.login ?? "nil")|\(initialQuery)"
    }

    private func loadFeed() async {
        DanbooruDiagnostics.state.info("FeedView loadFeed invoked selectedTab=\(String(describing: appModel.selectedTab), privacy: .public)")
        await viewModel.ensureLoaded(using: appModel.configuration)
    }

    private func submitSearch() {
        Task {
            await viewModel.submitSearch(using: appModel.configuration)
        }
    }

    private func clearSearch() {
        Task {
            await viewModel.clearSearch(using: appModel.configuration)
        }
    }

    private func upvote(_ post: DanbooruPostCardState) {
        Task {
            await viewModel.upvote(post, configuration: appModel.configuration)
        }
    }

    private func downvote(_ post: DanbooruPostCardState) {
        Task {
            await viewModel.downvote(post, configuration: appModel.configuration)
        }
    }

    private func toggleFavorite(_ post: DanbooruPostCardState) {
        Task {
            await viewModel.toggleFavorite(post, configuration: appModel.configuration)
        }
    }

    private func selectPost(_ post: DanbooruPostCardState) {
        selectedPostID = post.id
    }

    private func loadMoreIfNeeded(for post: DanbooruPostCardState) {
        Task {
            await viewModel.loadMoreIfNeeded(currentItem: post, configuration: appModel.configuration)
        }
    }
}
