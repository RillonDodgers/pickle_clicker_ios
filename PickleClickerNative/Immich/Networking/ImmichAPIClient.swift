import Foundation
import UniformTypeIdentifiers
import UIKit

enum ImmichAPIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Enter a valid Immich URL and API key first."
        case .invalidResponse:
            return "Immich returned data the app couldn't understand."
        case let .requestFailed(reason):
            return reason
        }
    }
}

final class ImmichAPIClient {
    private let configuration: ImmichClientConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(configuration: ImmichClientConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func fetchCurrentUser() async throws -> ImmichUser {
        try await performRequest(path: "/users/me")
    }

    func searchAssets(
        page: Int,
        pageSize: Int = 60,
        albumIDs: [String] = [],
        tagIDs: [String] = []
    ) async throws -> ImmichSearchAssetResponse {
        var body: [String: Any] = [
            "order": "desc",
            "page": page,
            "size": pageSize,
            "withExif": false,
            "withPeople": false,
            "withStacked": true
        ]
        if !albumIDs.isEmpty {
            body["albumIds"] = albumIDs
        }
        if !tagIDs.isEmpty {
            body["tagIds"] = tagIDs
        }

        let response: ImmichSearchResponse = try await performRequest(
            path: "/search/metadata",
            method: "POST",
            body: body
        )
        return response.assets
    }

    func fetchAlbums() async throws -> [ImmichAlbumSummary] {
        try await performRequest(path: "/albums")
    }

    func fetchTags() async throws -> [ImmichTagSummary] {
        try await performRequest(path: "/tags")
    }

    func thumbnailRequest(for asset: ImmichAsset, size: String = "thumbnail") -> SharedRemoteMediaRequest {
        thumbnailRequest(forAssetID: asset.id, size: size)
    }

    func thumbnailRequest(forAssetID assetID: String, size: String = "thumbnail") -> SharedRemoteMediaRequest {
        let url = configuration.baseURL
            .appendingPathComponent("assets")
            .appendingPathComponent(assetID)
            .appendingPathComponent("thumbnail")
            .appending(queryItems: [URLQueryItem(name: "size", value: size)])
        return SharedRemoteMediaRequest(
            namespace: "immich",
            url: url,
            headers: headers,
            cacheIdentity: "\(configuration.baseURL.absoluteString)|\(assetID)|thumbnail|\(size)"
        )
    }

    func originalRequest(for asset: ImmichAsset) -> SharedRemoteMediaRequest {
        let url = configuration.baseURL
            .appendingPathComponent("assets")
            .appendingPathComponent(asset.id)
            .appendingPathComponent("original")
        return SharedRemoteMediaRequest(
            namespace: "immich",
            url: url,
            headers: headers,
            cacheIdentity: "\(configuration.baseURL.absoluteString)|\(asset.id)|original"
        )
    }

    func videoPlaybackRequest(for asset: ImmichAsset) -> SharedRemoteMediaRequest {
        let url = configuration.baseURL
            .appendingPathComponent("assets")
            .appendingPathComponent(asset.id)
            .appendingPathComponent("video")
            .appendingPathComponent("playback")
        return SharedRemoteMediaRequest(
            namespace: "immich",
            url: url,
            headers: headers,
            cacheIdentity: "\(configuration.baseURL.absoluteString)|\(asset.id)|video"
        )
    }

    func uploadRemoteMedia(
        _ request: SharedRemoteMediaRequest,
        suggestedFilename: String,
        albumName: String? = nil,
        additionalAlbumNames: [String] = [],
        tagNames: [String] = [],
        sourceDescription: String? = nil
    ) async throws -> String {
        var remoteRequest = URLRequest(url: request.url)
        remoteRequest.timeoutInterval = 60
        remoteRequest.cachePolicy = .reloadIgnoringLocalCacheData
        request.headers.forEach { header, value in
            remoteRequest.setValue(value, forHTTPHeaderField: header)
        }

        let (data, response) = try await session.data(for: remoteRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            let sourceName = sourceDescription ?? request.namespace
            throw ImmichAPIError.requestFailed("Failed to download media from \(sourceName).")
        }

        let mimeType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? mimeType(for: suggestedFilename)
        let now = ISO8601DateFormatter().string(from: Date())
        let deviceAssetID = UUID().uuidString
        let boundary = "Boundary-\(UUID().uuidString)"

        var uploadRequest = URLRequest(url: configuration.baseURL.appendingPathComponent("assets"))
        uploadRequest.httpMethod = "POST"
        uploadRequest.timeoutInterval = 120
        uploadRequest.cachePolicy = .reloadIgnoringLocalCacheData
        uploadRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        uploadRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        uploadRequest.httpBody = multipartBody(
            boundary: boundary,
            data: data,
            mimeType: mimeType,
            filename: suggestedFilename,
            deviceAssetID: deviceAssetID,
            now: now
        )

        let (uploadData, uploadResponse) = try await session.data(for: uploadRequest)
        guard let uploadHTTPResponse = uploadResponse as? HTTPURLResponse else {
            throw ImmichAPIError.invalidResponse
        }
        guard (200 ... 299).contains(uploadHTTPResponse.statusCode) else {
            throw ImmichAPIError.requestFailed("Immich upload returned HTTP \(uploadHTTPResponse.statusCode).")
        }

        let responseDTO: ImmichUploadResponse
        do {
            responseDTO = try decoder.decode(ImmichUploadResponse.self, from: uploadData)
        } catch {
            throw ImmichAPIError.invalidResponse
        }

        let normalizedAlbumNames = normalizedAlbumNames(primaryAlbumName: albumName, additionalAlbumNames: additionalAlbumNames)
        for normalizedAlbumName in normalizedAlbumNames {
            let albumID = try await ensureAlbum(named: normalizedAlbumName)
            try await addAssets([responseDTO.id], toAlbumID: albumID)
        }

        let normalizedTagNames = normalizedTags(tagNames)
        if !normalizedTagNames.isEmpty {
            let tags = try await upsertTags(named: normalizedTagNames)
            try await addTags(tags.map(\.id), toAssets: [responseDTO.id])
        }

        return responseDTO.id
    }

    private func ensureAlbum(named name: String) async throws -> String {
        if let existingAlbum = try await fetchAlbums().first(where: { $0.albumName.caseInsensitiveCompare(name) == .orderedSame }) {
            return existingAlbum.id
        }

        let payload: [String: Any] = ["albumName": name]
        let album: ImmichAlbumSummary = try await performRequest(path: "/albums", method: "POST", body: payload)
        return album.id
    }

    private func addAssets(_ assetIDs: [String], toAlbumID albumID: String) async throws {
        let payload: [String: Any] = ["ids": assetIDs]
        try await performVoidJSONRequestWithFallback(
            path: "/albums/\(albumID)/assets",
            methods: ["PUT", "POST"],
            body: payload
        )
    }

    private func upsertTags(named names: [String]) async throws -> [ImmichTagSummary] {
        let payload: [String: Any] = ["tags": names]
        return try await performRequestWithFallback(
            path: "/tags",
            methods: ["PUT", "POST"],
            body: payload
        )
    }

    private func addTags(_ tagIDs: [String], toAssets assetIDs: [String]) async throws {
        let payload: [String: Any] = [
            "assetIds": assetIDs,
            "tagIds": tagIDs
        ]
        try await performVoidJSONRequestWithFallback(
            path: "/tags/assets",
            methods: ["PUT", "POST"],
            body: payload
        )
    }

    private var headers: [String: String] {
        [
            "Accept": "application/json",
            "x-api-key": configuration.apiKey
        ]
    }

    private func multipartBody(
        boundary: String,
        data: Data,
        mimeType: String,
        filename: String,
        deviceAssetID: String,
        now: String
    ) -> Data {
        var body = Data()
        body.appendFormField(named: "deviceAssetId", value: deviceAssetID, boundary: boundary)
        body.appendFormField(named: "deviceId", value: UIDevice.current.identifierForVendor?.uuidString ?? "pickle-clicker-ios", boundary: boundary)
        body.appendFormField(named: "fileCreatedAt", value: now, boundary: boundary)
        body.appendFormField(named: "fileModifiedAt", value: now, boundary: boundary)
        body.appendFormField(named: "filename", value: filename, boundary: boundary)
        body.appendFormField(named: "metadata", value: "[]", boundary: boundary)
        body.appendFileField(named: "assetData", filename: filename, mimeType: mimeType, data: data, boundary: boundary)
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for filename: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension
        if let type = UTType(filenameExtension: ext), let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    private func normalizedAlbumName(_ albumName: String?) -> String? {
        guard let albumName else { return nil }
        let normalized = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedAlbumNames(primaryAlbumName: String?, additionalAlbumNames: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        if let primaryAlbumName = normalizedAlbumName(primaryAlbumName) {
            let lookupKey = primaryAlbumName.lowercased()
            if seen.insert(lookupKey).inserted {
                result.append(primaryAlbumName)
            }
        }

        for albumName in additionalAlbumNames {
            guard let normalizedAlbumName = normalizedAlbumName(albumName) else { continue }
            let lookupKey = normalizedAlbumName.lowercased()
            guard seen.insert(lookupKey).inserted else { continue }
            result.append(normalizedAlbumName)
        }

        return result
    }

    private func normalizedTags(_ tagNames: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for tagName in tagNames {
            let normalized = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let lookupKey = normalized.lowercased()
            guard seen.insert(lookupKey).inserted else { continue }
            result.append(normalized)
        }

        return result
    }

    private func performRequestWithFallback<T: Decodable>(
        path: String,
        methods: [String],
        body: [String: Any]
    ) async throws -> T {
        var lastError: Error?

        for method in methods {
            do {
                return try await performRequest(path: path, method: method, body: body)
            } catch {
                if shouldRetryWithAlternateMethod(error) {
                    lastError = error
                    continue
                }
                throw error
            }
        }

        throw lastError ?? ImmichAPIError.invalidResponse
    }

    private func performVoidJSONRequestWithFallback(
        path: String,
        methods: [String],
        body: [String: Any]
    ) async throws {
        var lastError: Error?

        for method in methods {
            do {
                _ = try await performRawJSONRequest(path: path, method: method, body: body)
                return
            } catch {
                if shouldRetryWithAlternateMethod(error) {
                    lastError = error
                    continue
                }
                throw error
            }
        }

        throw lastError ?? ImmichAPIError.invalidResponse
    }

    private func performRawJSONRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        headers.forEach { header, value in
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImmichAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ImmichAPIError.requestFailed("Immich returned HTTP \(httpResponse.statusCode).")
        }

        return data
    }

    private func shouldRetryWithAlternateMethod(_ error: Error) -> Bool {
        guard case let ImmichAPIError.requestFailed(reason) = error else { return false }
        return reason.contains("HTTP 404") || reason.contains("HTTP 405")
    }

    private func performRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        headers.forEach { header, value in
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImmichAPIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ImmichAPIError.requestFailed("Immich returned HTTP \(httpResponse.statusCode).")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ImmichAPIError.invalidResponse
        }
    }
}

private struct ImmichUploadResponse: Decodable {
    let id: String
    let status: String
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = queryItems
        return components.url ?? self
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendFormField(named name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFileField(named name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }
}
