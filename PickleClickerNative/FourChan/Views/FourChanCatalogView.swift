import SwiftUI

struct FourChanCatalogView: View {
    let board: FourChanBoard

    @StateObject private var viewModel = FourChanCatalogViewModel()
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                boardHeader

                if let errorMessage = viewModel.errorMessage {
                    NativeErrorBanner(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.threads.isEmpty {
                    ForEach(0 ..< 6, id: \.self) { _ in
                        NativeSectionCardSkeleton(titleWidth: 180, rowCount: 3)
                    }
                } else if filteredThreads.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Threads Yet" : "No Matching Threads",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text(searchText.isEmpty ? "This board's catalog is empty right now." : "Try a different search within the fetched thread list.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(filteredThreads, id: \.no) { thread in
                        NavigationLink(value: thread.threadID) {
                            NativeEdgeRow(compactVerticalPadding: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    thumbnail(for: thread)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(thread.titleText)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)

                                        if let plainComment = thread.plainComment, !plainComment.isEmpty {
                                            Text(plainComment)
                                                .font(.system(size: 14))
                                                .foregroundStyle(NativeAppTheme.secondaryText)
                                                .lineLimit(4)
                                        }

                                        HStack(spacing: 8) {
                                            NativePill(title: "\(thread.replies ?? 0) replies", fill: NativeAppTheme.surface, foreground: .white)
                                            NativePill(title: "\(thread.images ?? 0) images", fill: NativeAppTheme.secondaryTint.opacity(0.16), foreground: NativeAppTheme.tint)
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(NativeAppTheme.background)
        .navigationTitle(board.displayPath)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.ensureLoaded(boardID: board.board)
        }
        .refreshable {
            await viewModel.reload(boardID: board.board)
        }
        .navigationDestination(for: Int.self) { threadID in
            FourChanThreadView(board: board, threadID: threadID)
        }
    }

    private var boardHeader: some View {
        NativeInsetSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NativePill(title: board.displayPath, fill: NativeAppTheme.chrome.opacity(0.42), foreground: .white)
                    Spacer()
                    Text("\(filteredThreads.count)/\(viewModel.threads.count) threads")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }

                Text(board.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                NativeSearchField(
                    title: "Filter fetched threads",
                    text: $searchText,
                    prompt: "Search subject or comment"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var filteredThreads: [FourChanPost] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.threads }

        return viewModel.threads.filter { thread in
            thread.titleText.localizedCaseInsensitiveContains(query)
                || (thread.plainComment?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    @ViewBuilder
    private func thumbnail(for thread: FourChanPost) -> some View {
        if let request = thread.thumbnailRequest(boardID: board.board) {
            SharedRemoteImage(request: request, contentMode: .fill, maxPixelSize: 320) {
                NativeSkeletonBlock(width: 88, height: 88, cornerRadius: 12)
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(NativeAppTheme.secondaryBackground)
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }
        }
    }
}
