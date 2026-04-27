import SwiftUI

struct ImmichLibraryView: View {
    @EnvironmentObject private var appModel: ImmichAppModel
    @StateObject private var viewModel = ImmichLibraryViewModel()
    @State private var selectedAssetID: String?
    @State private var gridItemWidth: CGFloat = 110
    private let gridSpacing: CGFloat = 2

    var body: some View {
        NativeAppScreenContainer(title: "Gallery", currentApp: .gallery) {
            content
                .task(id: taskIdentity) {
                    await appModel.validateConfigurationIfNeeded()
                    await viewModel.ensureLoaded(using: appModel.configuration)
                }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedAssetID != nil },
                set: { if !$0 { selectedAssetID = nil } }
            )
        ) {
            if let assetID = selectedAssetID, let configuration = appModel.configuration {
                ImmichAssetDetailView(
                    assets: viewModel.assets,
                    initialAssetID: assetID,
                    configuration: configuration
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if appModel.configuration == nil || !appModel.canLoadProtectedContent, appModel.validationStatus != .validating {
            NativeConfigurationRequiredView(
                title: "Immich Settings Needed",
                systemImage: "photo.badge.gearshape",
                description: "Add your Immich URL and API key in Settings before loading the gallery.",
                actionTitle: "Open Settings",
                action: appModel.switchToSettings
            )
        } else {
            GeometryReader { geometry in
                let layout = gridLayout(for: geometry.size.width)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        controlsBar

                        if let errorMessage = viewModel.errorMessage {
                            NativeErrorBanner(message: errorMessage)
                        }

                        if viewModel.isLoading && viewModel.assets.isEmpty {
                            skeletonGrid(tileSide: layout.tileSide, columns: layout.columns)
                        } else if viewModel.assets.isEmpty {
                            ContentUnavailableView(
                                "No Assets Yet",
                                systemImage: "photo.on.rectangle",
                                description: Text("Immich returned an empty library.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                        } else {
                            LazyVGrid(columns: layout.columns, spacing: gridSpacing) {
                                ForEach(viewModel.assets) { asset in
                                    assetTile(for: asset, tileSide: layout.tileSide)
                                        .onAppear {
                                            Task {
                                                await viewModel.loadMoreIfNeeded(currentItem: asset, configuration: appModel.configuration)
                                            }
                                        }
                                }
                            }
                            .padding(.top, 4)
                        }

                        if viewModel.isLoadingNextPage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .refreshable {
                    await viewModel.reload(using: appModel.configuration)
                }
            }
        }
    }

    private var taskIdentity: String {
        "\(appModel.reloadToken)|\(appModel.configuration?.baseURL.absoluteString ?? "nil")|\(appModel.configuration?.apiKey ?? "nil")"
    }

    private func gridLayout(for availableWidth: CGFloat) -> (columns: [GridItem], tileSide: CGFloat) {
        let columnCount = max(Int((availableWidth + gridSpacing) / (gridItemWidth + gridSpacing)), 1)
        let totalSpacing = CGFloat(columnCount - 1) * gridSpacing
        let tileSide = floor((availableWidth - totalSpacing) / CGFloat(columnCount))
        let columns = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
        return (columns, tileSide)
    }

    private var controlsBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("All Photos")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(viewModel.assets.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NativeAppTheme.secondaryText)
            }

            HStack(spacing: 10) {
                Image(systemName: "square.grid.4x3.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(NativeAppTheme.tertiaryText)

                Slider(value: $gridItemWidth, in: 78 ... 160, step: 2) {
                    Text("Grid size")
                }
                .tint(NativeAppTheme.tint)

                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(NativeAppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            NativeAppTheme.background
                .opacity(0.96)
                .blur(radius: 8)
        )
    }

    @ViewBuilder
    private func assetTile(for asset: ImmichAsset, tileSide: CGFloat) -> some View {
        let client = appModel.configuration.map { ImmichAPIClient(configuration: $0) }

        Button {
            selectedAssetID = asset.id
        } label: {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(NativeAppTheme.secondaryBackground)

                SharedRemoteImage(
                    request: client?.thumbnailRequest(for: asset),
                    contentMode: .fill,
                    maxPixelSize: max(tileSide * 3, 320)
                ) {
                    Rectangle()
                        .fill(Color(.tertiarySystemFill))
                        .redacted(reason: .placeholder)
                }
                .frame(width: tileSide, height: tileSide)
                .clipped()

                if asset.isVideo {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.58))
                        Image(systemName: "video.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                    .padding(6)
                }
            }
            .frame(width: tileSide, height: tileSide)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func skeletonGrid(tileSide: CGFloat, columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(0 ..< 24, id: \.self) { _ in
                Rectangle()
                    .fill(NativeAppTheme.secondaryBackground)
                    .frame(height: tileSide)
                    .overlay {
                        Rectangle()
                            .fill(Color(.tertiarySystemFill))
                            .redacted(reason: .placeholder)
                    }
            }
        }
        .padding(.top, 4)
    }
}
