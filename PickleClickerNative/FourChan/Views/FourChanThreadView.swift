import SwiftUI

struct FourChanThreadView: View {
    let board: FourChanBoard
    let threadID: Int

    @StateObject private var viewModel = FourChanThreadViewModel()
    @State private var selectedMediaRequest: SharedRemoteMediaRequest?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                threadHeader

                if let errorMessage = viewModel.errorMessage {
                    NativeErrorBanner(message: errorMessage)
                }

                if viewModel.isLoading && viewModel.posts.isEmpty {
                    ForEach(0 ..< 6, id: \.self) { _ in
                        NativeSectionCardSkeleton(titleWidth: 160, rowCount: 4)
                    }
                } else {
                    ForEach(viewModel.posts, id: \.no) { post in
                        NativeEdgeRow(compactVerticalPadding: 12) {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.authorLine)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(post.now ?? "#\(post.no)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(NativeAppTheme.tertiaryText)
                                }

                                if let commentHTML = post.com, !commentHTML.isEmpty {
                                    SharedHTMLText(html: commentHTML)
                                        .font(.system(size: 15))
                                }

                                if let request = post.mediaRequest(boardID: board.board) {
                                    mediaPreview(for: post, request: request)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(NativeAppTheme.background)
        .navigationTitle("Thread #\(threadID)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FourChanSaveToImmichButton(
                    boardID: board.board,
                    posts: viewModel.posts,
                    mode: .thread
                ) {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
        .task {
            await viewModel.ensureLoaded(boardID: board.board, threadID: threadID)
        }
        .refreshable {
            await viewModel.reload(boardID: board.board, threadID: threadID)
        }
        .sheet(item: $selectedMediaRequest) { request in
            NavigationStack {
                ZStack {
                    NativeAppTheme.background.ignoresSafeArea()

                    SharedRemoteImage(request: request, contentMode: .fit, maxPixelSize: 2200) {
                        ProgressView()
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            selectedMediaRequest = nil
                        }
                    }
                }
            }
            .presentationBackground(.black)
        }
    }

    private var threadHeader: some View {
        NativeInsetSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NativePill(title: board.displayPath, fill: NativeAppTheme.chrome.opacity(0.42), foreground: .white)
                    NativePill(title: "Thread #\(threadID)", fill: NativeAppTheme.secondaryTint.opacity(0.18), foreground: NativeAppTheme.tint)
                    Spacer()
                }

                Text("Discussion")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Posts stay in place when you back out. Pull to refresh only when you want the latest replies.")
                    .font(.system(size: 14))
                    .foregroundStyle(NativeAppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func mediaPreview(for post: FourChanPost, request: SharedRemoteMediaRequest) -> some View {
        if post.isVideoAttachment {
            SharedRemoteVideoPlayer(request: request)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contextMenu {
                    FourChanSaveToImmichButton(
                        boardID: board.board,
                        posts: viewModel.posts,
                        mode: .post(post)
                    ) {
                        Label("Save To Immich", systemImage: "square.and.arrow.down")
                    }
                }
        } else {
            Button {
                selectedMediaRequest = request
            } label: {
                SharedRemoteImage(request: request, contentMode: .fit, maxPixelSize: 1400) {
                    NativeSkeletonBlock(width: nil, height: 220, cornerRadius: 14)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .contextMenu {
                FourChanSaveToImmichButton(
                    boardID: board.board,
                    posts: viewModel.posts,
                    mode: .post(post)
                ) {
                    Label("Save To Immich", systemImage: "square.and.arrow.down")
                }
            }
        }
    }
}
