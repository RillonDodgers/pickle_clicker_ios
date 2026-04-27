import SwiftUI

struct ImmichTagsView: View {
    @EnvironmentObject private var appModel: ImmichAppModel
    @StateObject private var viewModel = ImmichTagsViewModel()

    var body: some View {
        NativeAppScreenContainer(title: "Tags", currentApp: .gallery) {
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
                description: "Add your Immich URL and API key in Settings before loading tags.",
                actionTitle: "Open Settings",
                action: appModel.switchToSettings
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let errorMessage = viewModel.errorMessage {
                        NativeErrorBanner(message: errorMessage)
                    }

                    if viewModel.isLoading && viewModel.tags.isEmpty {
                        tagsSkeleton
                    } else if viewModel.tags.isEmpty {
                        ContentUnavailableView(
                            "No Tags Yet",
                            systemImage: "tag",
                            description: Text("Immich returned an empty tag list.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            NavigationLink {
                                ImmichAssetCollectionView(title: tag.tag.displayName, tagIDs: [tag.tag.id])
                            } label: {
                                tagRow(tag)
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

    private func tagRow(_ tag: ImmichTagCount) -> some View {
        NativeEdgeRow(compactVerticalPadding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NativeAppTheme.secondaryTint.opacity(0.18))
                    Image(systemName: "tag.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(NativeAppTheme.tint)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tag.tag.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(tag.assetCount) image\(tag.assetCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NativeAppTheme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeAppTheme.tertiaryText)
            }
        }
    }

    private var tagsSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 10, id: \.self) { _ in
                NativeEdgeRow(compactVerticalPadding: 12) {
                    HStack(spacing: 12) {
                        NativeSkeletonBlock(width: 64, height: 64, cornerRadius: 12)
                        VStack(alignment: .leading, spacing: 8) {
                            NativeSkeletonBlock(width: 140, height: 16, cornerRadius: 8)
                            NativeSkeletonBlock(width: 90, height: 12, cornerRadius: 8)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
