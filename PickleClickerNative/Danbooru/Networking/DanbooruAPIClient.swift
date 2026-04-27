import Foundation
import OSLog

enum DanbooruAPIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case requestFailed(reason: String)
    case unauthorized
    case notFound
    case throttled
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Enter a valid Danbooru URL, login, API key, and atf-anti-bot cookie first."
        case .invalidResponse:
            return "The server returned data the app couldn't understand."
        case let .requestFailed(reason):
            return reason
        case .unauthorized:
            return "Your login or API key was rejected."
        case .notFound:
            return "That resource could not be found."
        case .throttled:
            return "Danbooru rate limited this request. Try again in a bit."
        case .serverError:
            return "Danbooru had a temporary server issue."
        }
    }
}

private struct DanbooruSuccessEnvelope: Decodable {
    let success: Bool?
    let reason: String?
}

struct DanbooruDmailComposeRequest: Equatable {
    let toID: Int?
    let toName: String?
    let title: String
    let body: String
}

final class DanbooruAPIClient {
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let configuration: DanbooruClientConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: DanbooruClientConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.fractionalISO8601Formatter.date(from: value) ?? Self.plainISO8601Formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        decoder.keyDecodingStrategy = .useDefaultKeys
    }

    func fetchPosts(page: Int, tags: String? = nil, limit: Int = 20) async throws -> [DanbooruPost] {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(min(limit, 100))),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }

        return try await performDecodableRequest(
            path: "/posts.json",
            queryItems: queryItems
        )
    }

    func fetchDmails() async throws -> [DanbooruDmail] {
        try await performDecodableRequest(path: "/dmails.json")
    }

    func createDmail(_ composeRequest: DanbooruDmailComposeRequest) async throws -> DanbooruDmail {
        var formBody = [
            "dmail[title]": composeRequest.title,
            "dmail[body]": composeRequest.body
        ]

        if let toID = composeRequest.toID {
            formBody["dmail[to_id]"] = String(toID)
        } else if let toName = composeRequest.toName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !toName.isEmpty {
            formBody["dmail[to_name]"] = toName
        }

        return try await performDecodableRequest(
            path: "/dmails.json",
            method: "POST",
            formBody: formBody
        )
    }

    func fetchFavorites(userID: Int, page: Int = 1, limit: Int = 20) async throws -> [DanbooruFavoriteRecord] {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(min(limit, 100))),
            URLQueryItem(name: "user_id", value: String(userID))
        ]

        return try await performDecodableRequest(
            path: "/favorites.json",
            queryItems: queryItems
        )
    }

    func fetchPost(id: Int) async throws -> DanbooruPost {
        try await performDecodableRequest(path: "/posts/\(id).json")
    }

    func fetchUser(id: Int) async throws -> DanbooruUser {
        try await performDecodableRequest(path: "/users/\(id).json")
    }

    func fetchComments(postID: Int) async throws -> [DanbooruComment] {
        try await performDecodableRequest(
            path: "/comments.json",
            queryItems: [URLQueryItem(name: "search[post_id]", value: String(postID))]
        )
    }

    func fetchCurrentUser() async throws -> DanbooruUser {
        let users: [DanbooruUser] = try await performDecodableRequest(
            path: "/users.json",
            queryItems: [URLQueryItem(name: "search[name]", value: configuration.login)]
        )

        if let exactMatch = users.first(where: { $0.name.caseInsensitiveCompare(configuration.login) == .orderedSame }) {
            return exactMatch
        }

        guard let firstUser = users.first else {
            throw DanbooruAPIError.requestFailed(reason: "No user profile matched the configured login.")
        }

        return firstUser
    }

    func fetchForumTopics() async throws -> [DanbooruForumTopic] {
        try await performDecodableRequest(path: "/forum_topics.json")
    }

    func fetchForumPosts(topicID: Int) async throws -> [DanbooruForumPost] {
        try await performDecodableRequest(
            path: "/forum_posts.json",
            queryItems: [URLQueryItem(name: "search[topic_id]", value: String(topicID))]
        )
    }

    func vote(postID: Int, score: DanbooruVoteDirection) async throws {
        guard score != .neutral else { return }

        try await performVoidRequest(
            path: "/posts/\(postID)/votes.json",
            method: "POST",
            queryItems: [URLQueryItem(name: "score", value: score.apiValue)]
        )
    }

    func favorite(postID: Int) async throws {
        try await performVoidRequest(
            path: "/favorites.json",
            method: "POST",
            queryItems: [URLQueryItem(name: "post_id", value: String(postID))]
        )
    }

    func unfavorite(postID: Int) async throws {
        try await performVoidRequest(
            path: "/favorites/\(postID).json",
            method: "DELETE"
        )
    }

    private func performVoidRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: [String: String]? = nil,
        formBody: [String: String]? = nil
    ) async throws {
        let data = try await performRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            jsonBody: jsonBody,
            formBody: formBody
        )

        guard !data.isEmpty else { return }

        if let envelope = try? decoder.decode(DanbooruSuccessEnvelope.self, from: data),
           envelope.success == false {
            throw DanbooruAPIError.requestFailed(reason: envelope.reason ?? "The request could not be completed.")
        }
    }

    func makeAuthenticatedRequest(url: URL, accept: String? = nil) throws -> URLRequest {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "login", value: configuration.login))
        queryItems.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        components?.queryItems = queryItems

        guard let authenticatedURL = components?.url else {
            throw DanbooruAPIError.invalidConfiguration
        }

        var request = URLRequest(url: authenticatedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(accept ?? "*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("BooruMobile/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("atf-anti-bot=\(configuration.atfAntiBotCookie)", forHTTPHeaderField: "Cookie")
        return request
    }

    private func performDecodableRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        jsonBody: [String: String]? = nil,
        formBody: [String: String]? = nil
    ) async throws -> T {
        let data = try await performRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            jsonBody: jsonBody,
            formBody: formBody
        )

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DanbooruAPIError.invalidResponse
        }
    }

    private func performRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        jsonBody: [String: String]? = nil,
        formBody: [String: String]? = nil
    ) async throws -> Data {
        let startedAt = Date()
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        ) else {
            throw DanbooruAPIError.invalidConfiguration
        }

        var allQueryItems = queryItems
        allQueryItems.append(URLQueryItem(name: "login", value: configuration.login))
        allQueryItems.append(URLQueryItem(name: "api_key", value: configuration.apiKey))
        components.queryItems = allQueryItems
        guard let url = components.url else {
            throw DanbooruAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("BooruMobile/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("atf-anti-bot=\(configuration.atfAntiBotCookie)", forHTTPHeaderField: "Cookie")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        } else if let formBody {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncodedData(from: formBody)
        }

        DanbooruDiagnostics.network.info("Request start method=\(method, privacy: .public) path=\(path, privacy: .public) url=\(url.absoluteString, privacy: .private(mask: .hash))")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                DanbooruDiagnostics.network.error("Request invalid response path=\(path, privacy: .public)")
                throw DanbooruAPIError.invalidResponse
            }

            DanbooruDiagnostics.network.info("Request finish method=\(method, privacy: .public) path=\(path, privacy: .public) status=\(httpResponse.statusCode, privacy: .public) bytes=\(data.count, privacy: .public) elapsed=\(Date().timeIntervalSince(startedAt), privacy: .public)")

            switch httpResponse.statusCode {
            case 200 ... 299:
                return data
            case 401, 403:
                throw DanbooruAPIError.unauthorized
            case 404:
                throw DanbooruAPIError.notFound
            case 421:
                throw DanbooruAPIError.throttled
            case 500, 503:
                throw DanbooruAPIError.serverError
            default:
                let message = (try? decoder.decode(DanbooruSuccessEnvelope.self, from: data).reason)
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                throw DanbooruAPIError.requestFailed(reason: message)
            }
        } catch {
            DanbooruDiagnostics.network.error("Request failed method=\(method, privacy: .public) path=\(path, privacy: .public) elapsed=\(Date().timeIntervalSince(startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private static func formEncodedData(from values: [String: String]) -> Data {
        let encoded = values
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }

    private static func percentEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
