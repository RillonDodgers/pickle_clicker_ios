import SwiftUI

struct DanbooruAuthenticatedVideoPlayer: View {
    let url: URL
    let configuration: DanbooruClientConfiguration

    var body: some View {
        SharedRemoteVideoPlayer(request: request)
    }

    private var request: SharedRemoteMediaRequest {
        SharedRemoteMediaRequest(
            namespace: "danbooru",
            url: authenticatedURL,
            headers: [
                "Accept": "*/*",
                "User-Agent": "BooruMobile/1.0 (iOS)",
                "Cookie": "atf-anti-bot=\(configuration.atfAntiBotCookie)"
            ],
            cacheIdentity: "\(configuration.baseURL.absoluteString)|\(configuration.login)|\(url.absoluteString)|video"
        )
    }

    private var authenticatedURL: URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "login", value: configuration.login))
        queryItems.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        components?.queryItems = queryItems
        return components?.url ?? url
    }
}
