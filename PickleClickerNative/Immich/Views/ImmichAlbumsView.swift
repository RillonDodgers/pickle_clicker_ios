import SwiftUI

struct ImmichAlbumsView: View {
    @EnvironmentObject private var appModel: ImmichAppModel
    @StateObject private var viewModel = ImmichAlbumsViewModel()

    var body: some View {
        NativeAppScreenContainer(title: "Albums", currentApp: .gallery) {
            content
                .task(id: taskIdentity) {
                    await appModel.validateConfigurationIfNeeded()
                    await viewModel.ensureLoaded(using: appModel.configuration)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if appModel.configuration == nil || !appModel.canLoadProtectedContent, appModel.validationStatus != .validating {
            NativeConfigurationRequiredView(
                title: "Immich Settings Needed",
                systemImage: "photo.badge.gearshape",
                description: "Add your Immich URL and API key in Settings before loading albums.",
                actionTitle: "Open Settings",
                action: appModel.switchToSettings
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let errorMessage = viewModel.errorMessage {
                        NativeErrorBanner(message: errorMessage)
                    }

                    if viewModel.isLoading && viewModel.albums.isEmpty {
                        albumsSkeleton
                    } else if viewModel.albums.isEmpty {
                        ContentUnavailableView(
                            "No Albums Yet",
                            systemImage: "rectangle.stack",
                            description: Text("Immich returned an empty album list.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        ForEach(viewModel.albums) { album in
                            NavigationLink {
                                ImmichAssetCollectionView(title: album.albumName, albumIDs: [album.id])
                            } label: {
                                albumRow(album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.reload(using: appModel.configuration)
            }
        }
    }

    private var taskIdentity: String {
        "\(appModel.reloadToken)|\(appModel.configuration?.baseURL.absoluteString ?? "nil")|\(appModel.configuration?.apiKey ?? "nil")"
    }

    private func albumRow(_ album: ImmichAlbumSummary) -> some View {
        let client = appModel.configuration.map { ImmichAPIClient(configuration: $0) }

        return NativeEdgeRow(compactVerticalPadding: 12) {
            HStack(spacing: 12) {
                Group {
                    if let thumbnailAssetID = album.albumThumbnailAssetId {
                        SharedRemoteImage(
                            request: client?.thumbnailRequest(forAssetID: thumbnailAssetID),
                            contentMode: .fill,
                            maxPixelSize: 240
                        ) {
                            Rectangle()
                                .fill(NativeAppTheme.secondaryBackground)
                        }
                    } else {
                        Rectangle()
                            .fill(NativeAppTheme.secondaryBackground)
                            .overlay {
                                Image(systemName: "photo.stack")
                                    .foregroundStyle(NativeAppTheme.tertiaryText)
                            }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(album.albumName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(album.assetCount) image\(album.assetCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeAppTheme.tertiaryText)
            }
        }
    }

    private var albumsSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 8, id: \.self) { _ in
                NativeEdgeRow(compactVerticalPadding: 12) {
                    HStack(spacing: 12) {
                        NativeSkeletonBlock(width: 64, height: 64, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 8) {
                            NativeSkeletonBlock(width: 160, height: 16, cornerRadius: 8)
                            NativeSkeletonBlock(width: 80, height: 12, cornerRadius: 8)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
