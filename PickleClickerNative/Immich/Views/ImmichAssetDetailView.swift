import SwiftUI

struct ImmichAssetDetailView: View {
    let assets: [ImmichAsset]
    let initialAssetID: String
    let configuration: ImmichClientConfiguration

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAssetID: String
    @State private var zoomScale: CGFloat = 1

    init(assets: [ImmichAsset], initialAssetID: String, configuration: ImmichClientConfiguration) {
        self.assets = assets
        self.initialAssetID = initialAssetID
        self.configuration = configuration
        _selectedAssetID = State(initialValue: initialAssetID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NativeAppTheme.background.ignoresSafeArea()

                TabView(selection: $selectedAssetID) {
                    ForEach(assets) { asset in
                        assetPage(for: asset)
                            .tag(asset.id)
                            .padding(.horizontal, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground(.black)
    }

    @ViewBuilder
    private func assetPage(for asset: ImmichAsset) -> some View {
        VStack(spacing: 16) {
            if asset.isVideo {
                SharedRemoteVideoPlayer(request: ImmichAPIClient(configuration: configuration).videoPlaybackRequest(for: asset))
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                SharedRemoteImage(
                    request: ImmichAPIClient(configuration: configuration).originalRequest(for: asset),
                    contentMode: .fit,
                    maxPixelSize: 2400
                ) {
                    ProgressView()
                }
                .scaleEffect(zoomScale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            zoomScale = min(max(value.magnification, 1), 5)
                        }
                        .onEnded { _ in
                            if zoomScale < 1.02 {
                                zoomScale = 1
                            }
                        }
                )
                .frame(maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(asset.originalFileName)
                    .font(.system(size: 16, weight: .semibold))
                Text(asset.localDateTime.replacingOccurrences(of: "T", with: " "))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
    }
}
