import AVFoundation
import AVKit
import Combine
import CryptoKit
import ImageIO
import SwiftUI
import UIKit

struct SharedRemoteMediaRequest: Hashable, Identifiable {
    let namespace: String
    let url: URL
    let headers: [String: String]
    let cacheIdentity: String
    var id: String { cacheIdentity }

    init(namespace: String, url: URL, headers: [String: String] = [:], cacheIdentity: String? = nil) {
        self.namespace = namespace
        self.url = url
        self.headers = headers
        self.cacheIdentity = cacheIdentity ?? "\(namespace)|\(url.absoluteString)|\(headers.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
    }
}

final class SharedImageMemoryCache {
    static let shared = SharedImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString, cost: image.diskCost)
    }
}

actor SharedDiskMediaCache {
    static let shared = SharedDiskMediaCache()

    private let fileManager = FileManager.default
    private let rootDirectoryURL: URL

    init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let folder = cachesDirectory
            .appendingPathComponent("PickleClickerNative", isDirectory: true)
            .appendingPathComponent("RemoteMedia", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        rootDirectoryURL = folder
    }

    func data(forKey key: String, namespace: String) -> Data? {
        try? Data(contentsOf: fileURL(forKey: key, namespace: namespace))
    }

    func save(_ data: Data, forKey key: String, namespace: String) {
        let directory = rootDirectoryURL.appendingPathComponent(namespace, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(forKey: key, namespace: namespace), options: .atomic)
    }

    private func fileURL(forKey key: String, namespace: String) -> URL {
        rootDirectoryURL
            .appendingPathComponent(namespace, isDirectory: true)
            .appendingPathComponent(Self.hashedFilename(for: key))
    }

    private static func hashedFilename(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class SharedRemoteImageLoader: ObservableObject {
    @MainActor @Published private(set) var image: UIImage?
    @MainActor private var loadedIdentity: String?

    func load(request: SharedRemoteMediaRequest?, maxPixelSize: CGFloat?) async {
        guard let request else {
            await MainActor.run {
                image = nil
                loadedIdentity = nil
            }
            return
        }

        let cacheKey = "\(request.cacheIdentity)|\(Int(maxPixelSize ?? 0))"
        let alreadyLoaded = await MainActor.run { loadedIdentity == cacheKey }
        guard !alreadyLoaded else { return }

        if let cachedImage = SharedImageMemoryCache.shared.image(forKey: cacheKey) {
            await MainActor.run {
                image = cachedImage
                loadedIdentity = cacheKey
            }
            return
        }

        if let cachedData = await SharedDiskMediaCache.shared.data(forKey: request.cacheIdentity, namespace: request.namespace) {
            let decodedImage = Self.decodeImage(data: cachedData, maxPixelSize: maxPixelSize)
            await MainActor.run {
                image = decodedImage
                loadedIdentity = cacheKey
            }
            if let decodedImage {
                SharedImageMemoryCache.shared.insert(decodedImage, forKey: cacheKey)
            }
            return
        }

        do {
            var urlRequest = URLRequest(url: request.url)
            urlRequest.timeoutInterval = 30
            request.headers.forEach { header, value in
                urlRequest.setValue(value, forHTTPHeaderField: header)
            }

            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let decodedImage = Self.decodeImage(data: data, maxPixelSize: maxPixelSize)
            await MainActor.run {
                image = decodedImage
                loadedIdentity = cacheKey
            }
            if let decodedImage {
                SharedImageMemoryCache.shared.insert(decodedImage, forKey: cacheKey)
            }
            await SharedDiskMediaCache.shared.save(data, forKey: request.cacheIdentity, namespace: request.namespace)
        } catch {
            await MainActor.run {
                image = nil
                loadedIdentity = nil
            }
        }
    }

    private static func decodeImage(data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return UIImage(data: data)
        }

        let pixelSize = Int(maxPixelSize ?? 1024)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(pixelSize, 1),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: image)
        }

        return UIImage(data: data)
    }
}

struct SharedRemoteImage<Placeholder: View>: View {
    let request: SharedRemoteMediaRequest?
    let contentMode: ContentMode
    let maxPixelSize: CGFloat?
    @ViewBuilder let placeholder: () -> Placeholder

    @StateObject private var loader = SharedRemoteImageLoader()

    init(
        request: SharedRemoteMediaRequest?,
        contentMode: ContentMode,
        maxPixelSize: CGFloat? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.request = request
        self.contentMode = contentMode
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: request?.cacheIdentity ?? "nil") {
            await loader.load(request: request, maxPixelSize: maxPixelSize)
        }
    }
}

private final class SharedPlayerViewController: AVPlayerViewController {
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }
}

struct SharedRemoteVideoPlayer: UIViewControllerRepresentable {
    let request: SharedRemoteMediaRequest

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = SharedPlayerViewController()
        controller.player = makePlayer()
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player == nil {
            uiViewController.player = makePlayer()
        }
    }

    private func makePlayer() -> AVPlayer {
        let asset = AVURLAsset(
            url: request.url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": request.headers]
        )
        return AVPlayer(playerItem: AVPlayerItem(asset: asset))
    }
}

private extension UIImage {
    var diskCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
