import SwiftUI

struct FourChanBoardsView: View {
    @EnvironmentObject private var appModel: FourChanAppModel
    @State private var boards: [FourChanBoard] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var searchText = ""

    private let client = FourChanAPIClient()

    var body: some View {
        NativeAppScreenContainer(title: "Boards", currentApp: .channing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    searchHeader

                    if let errorMessage {
                        NativeErrorBanner(message: errorMessage)
                    }

                    if isLoading && boards.isEmpty {
                        ForEach(0 ..< 8, id: \.self) { _ in
                            NativeEdgeRow(compactVerticalPadding: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    NativeSkeletonBlock(width: 72, height: 12)
                                    NativeSkeletonBlock(width: 160, height: 16)
                                    NativeSkeletonBlock(width: nil, height: 12)
                                }
                            }
                        }
                    } else if filteredBoards.isEmpty {
                        ContentUnavailableView(
                            "No Boards Found",
                            systemImage: "text.magnifyingglass",
                            description: Text(searchText.isEmpty ? "No 4chan boards matched the current filters." : "Try a different board name or code.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        ForEach(filteredBoards) { board in
                            NavigationLink(value: board) {
                                NativeEdgeRow(compactVerticalPadding: 12) {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(alignment: .center, spacing: 8) {
                                                NativePill(
                                                    title: board.displayPath,
                                                    fill: NativeAppTheme.chrome.opacity(0.42),
                                                    foreground: .white
                                                )

                                                if board.isWorksafe {
                                                    NativePill(
                                                        title: "SFW",
                                                        fill: NativeAppTheme.success.opacity(0.18),
                                                        foreground: NativeAppTheme.success
                                                    )
                                                }
                                            }

                                            Text(board.title)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)

                                            Text(board.summary)
                                                .font(.system(size: 13))
                                                .foregroundStyle(NativeAppTheme.secondaryText)
                                                .lineLimit(2)
                                        }

                                        Spacer(minLength: 12)

                                        VStack(alignment: .trailing, spacing: 8) {
                                            boardMetaValue("\(board.pages ?? 0)", label: "pages")
                                            boardMetaValue(formattedFileSize(board.maxFilesize), label: "max file")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .task {
                await loadBoards()
            }
            .refreshable {
                await loadBoards(force: true)
            }
            .navigationDestination(for: FourChanBoard.self) { board in
                FourChanCatalogView(board: board)
            }
        }
    }

    private var filteredBoards: [FourChanBoard] {
        let visibleBoards = appModel.settingsStore.settings.onlyShowWorksafeBoards
            ? boards.filter(\.isWorksafe)
            : boards

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return visibleBoards }

        return visibleBoards.filter {
            $0.board.localizedCaseInsensitiveContains(query)
                || $0.title.localizedCaseInsensitiveContains(query)
                || ($0.metaDescription?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            NativeEdgeRow(compactVerticalPadding: 12) {
                HStack {
                    NativePill(title: "4chan", fill: Color.white.opacity(0.06), foreground: .white)
                    Spacer()
                    Text("\(filteredBoards.count)/\(visibleBoardCount) boards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }
            }

            NativeEdgeRow(compactVerticalPadding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("4chan Directory")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Compact board list with local filtering over the fetched directory.")
                        .font(.system(size: 14))
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }
            }

            NativeEdgeRow(compactVerticalPadding: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appModel.settingsStore.settings.onlyShowWorksafeBoards ? "Filter fetched work-safe boards" : "Filter fetched boards")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NativeAppTheme.secondaryText)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(NativeAppTheme.tertiaryText)

                        TextField("Search board name or code", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 15))
                }
            }
        }
        .padding(.top, 8)
    }

    private var visibleBoardCount: Int {
        appModel.settingsStore.settings.onlyShowWorksafeBoards
            ? boards.filter(\.isWorksafe).count
            : boards.count
    }

    private func boardMetaValue(_ value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NativeAppTheme.tertiaryText)
                .tracking(0.6)
        }
    }

    private func formattedFileSize(_ bytes: Int?) -> String {
        guard let bytes, bytes > 0 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func loadBoards(force: Bool = false) async {
        guard !isLoading || force else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            boards = try await client.fetchBoards()
        } catch {
            if isAsyncCancellationError(error) {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
