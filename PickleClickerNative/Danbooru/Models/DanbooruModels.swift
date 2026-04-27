import Foundation

enum DanbooruCommentSortOrder: String, CaseIterable, Equatable {
    case oldestFirst
    case newestFirst

    var title: String {
        switch self {
        case .oldestFirst:
            return "Oldest First"
        case .newestFirst:
            return "Newest First"
        }
    }
}

enum DanbooruVoteDirection: Int, Codable {
    case down = -1
    case neutral = 0
    case up = 1

    init(rawVoteValue: Int?) {
        switch rawVoteValue {
        case let value? where value > 0:
            self = .up
        case let value? where value < 0:
            self = .down
        default:
            self = .neutral
        }
    }

    var apiValue: String {
        switch self {
        case .up:
            return "1"
        case .down:
            return "-1"
        case .neutral:
            return "1"
        }
    }
}

struct DanbooruClientConfiguration: Equatable {
    let baseURL: URL
    let login: String
    let apiKey: String
    let atfAntiBotCookie: String
}

struct DanbooruPost: Identifiable, Decodable, Equatable {
    let id: Int
    let createdAt: Date?
    let uploaderID: Int?
    let isPending: Bool?
    let score: Int?
    let upScore: Int?
    let downScore: Int?
    let favCount: Int?
    let isFavorited: Bool?
    let myVote: Int?
    let fileExtension: String?
    let previewFileURL: URL?
    let largeFileURL: URL?
    let fileURL: URL?
    let tagString: String?
    let tagStringGeneral: String?
    let tagStringArtist: String?
    let tagStringCharacter: String?
    let artistCommentaryTitle: String?
    let artistCommentaryDescription: String?
    let rating: String?
    let imageWidth: Int?
    let imageHeight: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case uploaderID = "uploader_id"
        case isPending = "is_pending"
        case score
        case upScore = "up_score"
        case downScore = "down_score"
        case favCount = "fav_count"
        case isFavorited = "is_favorited"
        case myVote = "my_vote"
        case fileExtension = "file_ext"
        case previewFileURL = "preview_file_url"
        case largeFileURL = "large_file_url"
        case fileURL = "file_url"
        case tagString = "tag_string"
        case tagStringGeneral = "tag_string_general"
        case tagStringArtist = "tag_string_artist"
        case tagStringCharacter = "tag_string_character"
        case artistCommentaryTitle = "artist_commentary_title"
        case artistCommentaryDescription = "artist_commentary_desc"
        case rating
        case imageWidth = "image_width"
        case imageHeight = "image_height"
    }

    var thumbnailURL: URL? {
        previewFileURL ?? largeFileURL
    }

    var isVideo: Bool {
        let ext = (fileExtension ?? fileURL?.pathExtension ?? largeFileURL?.pathExtension ?? "").lowercased()
        return ext == "mp4" || ext == "webm" || ext == "mov"
    }

    var primaryText: String {
        let commentary = artistCommentaryDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !commentary.isEmpty {
            return commentary
        }

        let title = artistCommentaryTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return title
        }

        let tagSummary = tagStringGeneral?
            .split(separator: " ")
            .prefix(10)
            .joined(separator: " ") ?? ""
        return tagSummary.isEmpty ? "No artist commentary yet." : tagSummary
    }

    var secondaryText: String {
        let artistTags = tagStringArtist?.replacingOccurrences(of: " ", with: ", ") ?? ""
        if !artistTags.isEmpty {
            return artistTags
        }

        return tagStringGeneral?
            .split(separator: " ")
            .prefix(6)
            .joined(separator: " ") ?? "Untitled post"
    }
}

struct DanbooruComment: Identifiable, Decodable, Equatable {
    let id: Int
    let body: String?
    let creatorName: String?
    let creatorID: Int?
    let createdAt: Date?
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case creatorName = "creator_name"
        case creatorID = "creator_id"
        case createdAt = "created_at"
        case score
    }
}

struct DanbooruFavoriteRecord: Identifiable, Decodable, Equatable {
    let id: Int
    let userID: Int?
    let postID: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case postID = "post_id"
    }
}

struct DanbooruDmail: Identifiable, Decodable, Equatable {
    let id: Int
    let ownerID: Int?
    let title: String?
    let body: String?
    let isRead: Bool?
    let fromName: String?
    let fromID: Int?
    let toName: String?
    let toID: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case title
        case body
        case isRead = "is_read"
        case fromName = "from_name"
        case fromID = "from_id"
        case toName = "to_name"
        case toID = "to_id"
        case createdAt = "created_at"
    }
}

struct DanbooruUser: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let level: Int?
    let createdAt: Date?
    let postUploadCount: Int?
    let noteCount: Int?
    let favoriteCount: Int?
    let levelString: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case level
        case createdAt = "created_at"
        case postUploadCount = "post_upload_count"
        case noteCount = "note_count"
        case favoriteCount = "favorite_count"
        case levelString = "level_string"
    }
}

struct DanbooruForumTopic: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let creatorID: Int?
    let updaterID: Int?
    let title: String
    let responseCount: Int
    let isSticky: Bool
    let isLocked: Bool
    var isRead: Bool?
    let isDeleted: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let categoryID: Int?
    let minLevel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case creatorID = "creator_id"
        case updaterID = "updater_id"
        case title
        case responseCount = "response_count"
        case isSticky = "is_sticky"
        case isLocked = "is_locked"
        case isRead = "is_read"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case categoryID = "category_id"
        case minLevel = "min_level"
    }
}

struct DanbooruForumPost: Identifiable, Decodable, Equatable {
    let id: Int
    let topicID: Int
    let creatorID: Int?
    let updaterID: Int?
    let body: String
    let isDeleted: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case topicID = "topic_id"
        case creatorID = "creator_id"
        case updaterID = "updater_id"
        case body
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DanbooruPostCardState: Identifiable, Equatable {
    let id: Int
    let imageURL: URL?
    let fullImageURL: URL?
    let isVideo: Bool
    let tagNames: [String]
    let allTagNames: [String]
    let uploaderID: Int?
    let primaryText: String
    let secondaryText: String
    let characterAlbumNames: [String]
    let createdAt: Date?
    let rating: String?
    let imageWidth: Int?
    let imageHeight: Int?
    var score: Int
    var favoriteCount: Int
    var isFavorited: Bool
    var voteDirection: DanbooruVoteDirection

    init(post: DanbooruPost) {
        id = post.id
        imageURL = post.thumbnailURL
        fullImageURL = post.fileURL ?? post.largeFileURL ?? post.previewFileURL
        isVideo = post.isVideo
        tagNames = post.tagStringGeneral?
            .split(separator: " ")
            .map(String.init) ?? []
        allTagNames = post.tagString?
            .split(separator: " ")
            .map(String.init) ?? []
        characterAlbumNames = post.tagStringCharacter?
            .split(separator: " ")
            .map(String.init) ?? []
        uploaderID = post.uploaderID
        primaryText = post.primaryText
        secondaryText = post.secondaryText
        createdAt = post.createdAt
        rating = post.rating
        imageWidth = post.imageWidth
        imageHeight = post.imageHeight
        score = post.score ?? ((post.upScore ?? 0) - (post.downScore ?? 0))
        favoriteCount = post.favCount ?? 0
        isFavorited = post.isFavorited ?? false
        voteDirection = DanbooruVoteDirection(rawVoteValue: post.myVote)
    }

    mutating func applyVote(_ newVote: DanbooruVoteDirection) {
        let previousVote = voteDirection
        voteDirection = newVote
        score += newVote.rawValue - previousVote.rawValue
    }

    mutating func applyFavorite(_ favorited: Bool) {
        guard isFavorited != favorited else { return }
        isFavorited = favorited
        favoriteCount += favorited ? 1 : -1
        favoriteCount = max(0, favoriteCount)
    }

    mutating func applyPersistedInteraction(_ snapshot: DanbooruPostInteractionSnapshot) {
        score = snapshot.score
        favoriteCount = snapshot.favoriteCount
        isFavorited = snapshot.isFavorited
        voteDirection = DanbooruVoteDirection(rawValue: snapshot.voteDirectionRawValue) ?? .neutral
    }
}
