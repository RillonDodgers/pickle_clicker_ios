import SwiftUI

struct DanbooruAuthenticatedImage<Placeholder: View>: View {
    let url: URL?
    let configuration: DanbooruClientConfiguration?
    let contentMode: ContentMode
    let maxPixelSize: CGFloat?
    @ViewBuilder let placeholder: () -> Placeholder

    init(
        url: URL?,
        configuration: DanbooruClientConfiguration?,
        contentMode: ContentMode,
        maxPixelSize: CGFloat? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.configuration = configuration
        self.contentMode = contentMode
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder
    }

    var body: some View {
        SharedRemoteImage(
            request: request,
            contentMode: contentMode,
            maxPixelSize: maxPixelSize,
            placeholder: placeholder
        )
    }

    private var request: SharedRemoteMediaRequest? {
        guard let url, let configuration else { return nil }
        return SharedRemoteMediaRequest(
            namespace: "danbooru",
            url: authenticatedURL(for: url, configuration: configuration),
            headers: [
                "Accept": "image/*",
                "User-Agent": "BooruMobile/1.0 (iOS)",
                "Cookie": "atf-anti-bot=\(configuration.atfAntiBotCookie)"
            ],
            cacheIdentity: "\(configuration.baseURL.absoluteString)|\(configuration.login)|\(url.absoluteString)"
        )
    }

    private func authenticatedURL(for url: URL, configuration: DanbooruClientConfiguration) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "login", value: configuration.login))
        queryItems.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        components?.queryItems = queryItems
        return components?.url ?? url
    }
}
