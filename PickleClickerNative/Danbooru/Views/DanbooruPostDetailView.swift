import SwiftUI

struct DanbooruPostDetailView: View {
    let postID: Int

    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel = DanbooruPostDetailViewModel()
    @State private var selectedRoute: DanbooruNavigationRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let errorMessage = viewModel.errorMessage {
                    DanbooruErrorBanner(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.post == nil {
                    DanbooruSkeletonBlock(width: nil, height: 320, cornerRadius: 18)
                    VStack(alignment: .leading, spacing: 8) {
                        DanbooruSkeletonBlock(width: nil, height: 22)
                        DanbooruSkeletonBlock(width: 220, height: 18)
                        DanbooruSkeletonBlock(width: 180, height: 14)
                    }
                    Divider()
                    DanbooruSkeletonBlock(width: 100, height: 20)
                    ForEach(0 ..< 3, id: \.self) { _ in
                        DanbooruCommentSkeleton()
                    }
                }

                if let post = viewModel.post {
                    mediaView(for: post)

                    if !post.allTagNames.isEmpty {
                        tagsSection(for: post)
                    }

                    DanbooruEdgeRow(compactVerticalPadding: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.primaryText)
                                .font(.system(size: 21, weight: .semibold, design: .default))
                            Text(post.secondaryText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Label("\(post.score)", systemImage: "arrow.up")
                                Label("\(post.favoriteCount)", systemImage: "heart")
                                if let rating = post.rating {
                                    Text(rating.uppercased())
                                }
                                if let createdAt = post.createdAt {
                                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                    }

                    DanbooruCompactSectionHeader(title: "Comments")

                    if viewModel.comments.isEmpty {
                        Text("No comments yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(viewModel.comments) { comment in
                            DanbooruEdgeRow(compactVerticalPadding: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        DanbooruUserLink(
                                            userID: comment.creatorID,
                                            username: viewModel.displayName(for: comment),
                                            accentColor: viewModel.isOriginalPoster(comment) ? .orange : NativeAppTheme.tint
                                        ) { target in
                                            selectedRoute = .profile(target)
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        if viewModel.isOriginalPoster(comment) {
                                            Text("OP")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.orange)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                                        }
                                        Spacer()
                                        if let createdAt = comment.createdAt {
                                            Text(createdAt.formatted(.relative(presentation: .named)))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if let body = comment.body, !body.isEmpty {
                                        DanbooruDTextView(
                                            text: body,
                                            uiFont: .systemFont(ofSize: 15),
                                            foregroundColor: .white,
                                            baseURL: appModel.configuration?.baseURL
                                        ) { action in
                                            handleDTextAction(action)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedRoute) { route in
            DanbooruNavigationDestination(route: route)
        }
        .toolbar {
            if let post = viewModel.post {
                ToolbarItem(placement: .topBarTrailing) {
                    DanbooruSaveToImmichButton(post: post, configuration: appModel.configuration) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .task(id: "\(postID)|\(appModel.reloadToken)|\(appModel.settingsStore.settings.postCommentSortOrderRawValue)") {
            await viewModel.load(
                postID: postID,
                configuration: appModel.configuration,
                commentSortOrder: appModel.settingsStore.settings.postCommentSortOrder
            )
        }
    }

    @ViewBuilder
    private func mediaView(for post: DanbooruPostCardState) -> some View {
        if post.isVideo,
           let url = post.fullImageURL ?? post.imageURL,
           let configuration = appModel.configuration {
            DanbooruAuthenticatedVideoPlayer(url: url, configuration: configuration)
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipped()
        } else {
            DanbooruAuthenticatedImage(
                url: post.fullImageURL ?? post.imageURL,
                configuration: appModel.configuration,
                contentMode: .fit,
                maxPixelSize: 1600
            ) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemFill))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    private func tagsSection(for post: DanbooruPostCardState) -> some View {
        DanbooruEdgeRow(compactVerticalPadding: 12) {
            DisclosureGroup {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(post.allTagNames, id: \.self) { tag in
                        Button {
                            selectedRoute = .feed(tag)
                        } label: {
                            Text(tag.replacingOccurrences(of: "_", with: " "))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.orange.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Text("Tags")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(post.allTagNames.count)")
                        .font(.system(size: 12, weight: .medium))
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
