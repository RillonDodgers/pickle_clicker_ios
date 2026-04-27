import Foundation

enum FourChanAPIError: LocalizedError {
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "4chan returned data the app couldn't understand."
        case let .requestFailed(reason):
            return reason
        }
    }
}

actor FourChanRateLimiter {
    private var lastRequestDate: Date?

    func waitIfNeeded() async {
        guard let lastRequestDate else {
            self.lastRequestDate = Date()
            return
        }

        let elapsed = Date().timeIntervalSince(lastRequestDate)
        if elapsed < 1 {
            let remaining = UInt64((1 - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remaining)
        }
        self.lastRequestDate = Date()
    }
}

final class FourChanAPIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let rateLimiter = FourChanRateLimiter()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchBoards() async throws -> [FourChanBoard] {
        let response: FourChanBoardsResponse = try await performRequest(path: "/boards.json")
        return response.boards.sorted { $0.board < $1.board }
    }

    func fetchCatalog(boardID: String) async throws -> [FourChanPost] {
        let pages: [FourChanCatalogPage] = try await performRequest(path: "/\(boardID)/catalog.json")
        return pages.flatMap(\.threads)
    }

    func fetchThread(boardID: String, threadID: Int) async throws -> [FourChanPost] {
        let response: FourChanThreadResponse = try await performRequest(path: "/\(boardID)/thread/\(threadID).json")
        return response.posts
    }

    private func performRequest<T: Decodable>(path: String) async throws -> T {
        await rateLimiter.waitIfNeeded()

        guard let url = URL(string: "https://a.4cdn.org\(path)") else {
            throw FourChanAPIError.requestFailed("That 4chan request URL was invalid.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("PickleClickerNative/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FourChanAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw FourChanAPIError.requestFailed("4chan returned HTTP \(httpResponse.statusCode).")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FourChanAPIError.invalidResponse
        }
    }
}
