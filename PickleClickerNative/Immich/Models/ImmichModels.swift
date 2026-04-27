import Foundation

struct ImmichSettings: Equatable {
    var baseURLString = ""
    var apiKey = ""

    var configuration: ImmichClientConfiguration? {
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty else { return nil }
        guard var baseURL = URL(string: trimmedURL) else { return nil }

        if !baseURL.path.hasSuffix("/api") {
            baseURL = baseURL.appendingPathComponent("api")
        }

        return ImmichClientConfiguration(baseURL: baseURL, apiKey: trimmedKey)
    }
}

struct ImmichClientConfiguration: Equatable {
    let baseURL: URL
    let apiKey: String
}

struct ImmichUser: Decodable, Hashable {
    let id: String
    let email: String
    let name: String
}

struct ImmichSearchResponse: Decodable {
    let assets: ImmichSearchAssetResponse
}

struct ImmichSearchAssetResponse: Decodable {
    let count: Int
    let items: [ImmichAsset]
    let nextPage: String?
    let total: Int
}

struct ImmichAsset: Decodable, Hashable, Identifiable {
    let id: String
    let createdAt: String
    let fileCreatedAt: String
    let isFavorite: Bool
    let localDateTime: String
    let originalFileName: String
    let originalMimeType: String?
    let type: ImmichAssetType

    var isVideo: Bool { type == .video }
}

enum ImmichAssetType: String, Decodable, Hashable {
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case other = "OTHER"
}

struct ImmichAlbumSummary: Decodable, Hashable, Identifiable {
    let id: String
    let albumName: String
    let albumThumbnailAssetId: String?
    let assetCount: Int
}

struct ImmichTagSummary: Decodable, Hashable, Identifiable {
    let id: String
    let name: String?
    let value: String?

    var displayName: String {
        let resolved = value ?? name ?? ""
        return resolved.isEmpty ? "Untitled Tag" : resolved
    }
}

struct ImmichTagCount: Hashable, Identifiable {
    let tag: ImmichTagSummary
    let assetCount: Int

    var id: String { tag.id }
}
