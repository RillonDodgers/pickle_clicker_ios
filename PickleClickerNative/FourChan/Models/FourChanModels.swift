import Foundation

struct FourChanBoardsResponse: Decodable {
    let boards: [FourChanBoard]
}

struct FourChanBoard: Decodable, Hashable, Identifiable {
    let board: String
    let title: String
    let metaDescription: String?
    let wsBoard: Int?
    let pages: Int?
    let maxFilesize: Int?
    let cooldowns: FourChanBoardCooldowns?

    enum CodingKeys: String, CodingKey {
        case board
        case title
        case metaDescription = "meta_description"
        case wsBoard = "ws_board"
        case pages
        case maxFilesize = "max_filesize"
        case cooldowns
    }

    var id: String { board }
    var isWorksafe: Bool { (wsBoard ?? 0) == 1 }
    var displayPath: String { "/\(board)/" }
    var summary: String {
        if let metaDescription, !metaDescription.isEmpty {
            return metaDescription.removingHTMLTags()
        }
        return "\(pages ?? 0) pages"
    }
}

struct FourChanBoardCooldowns: Decodable, Hashable {
    let threads: Int?
    let replies: Int?
    let images: Int?
}

struct FourChanCatalogPage: Decodable {
    let page: Int
    let threads: [FourChanPost]
}

struct FourChanThreadResponse: Decodable {
    let posts: [FourChanPost]
}

struct FourChanPost: Decodable, Hashable, Identifiable {
    let no: Int
    let resto: Int
    let sticky: Int?
    let closed: Int?
    let now: String?
    let time: Int?
    let name: String?
    let trip: String?
    let idCode: String?
    let country: String?
    let countryName: String?
    let sub: String?
    let com: String?
    let tim: Int64?
    let filename: String?
    let ext: String?
    let fsize: Int?
    let w: Int?
    let h: Int?
    let tnW: Int?
    let tnH: Int?
    let filedeleted: Int?
    let spoiler: Int?
    let replies: Int?
    let images: Int?
    let bumplimit: Int?
    let imagelimit: Int?
    let semanticUrl: String?
    let uniqueIps: Int?
    let archived: Int?
    let archivedOn: Int?

    enum CodingKeys: String, CodingKey {
        case no
        case resto
        case sticky
        case closed
        case now
        case time
        case name
        case trip
        case country
        case countryName = "country_name"
        case sub
        case com
        case tim
        case filename
        case ext
        case fsize
        case w
        case h
        case tnW = "tn_w"
        case tnH = "tn_h"
        case filedeleted
        case spoiler
        case replies
        case images
        case bumplimit
        case imagelimit
        case semanticUrl = "semantic_url"
        case uniqueIps = "unique_ips"
        case archived
        case archivedOn = "archived_on"
        case idCode = "id"
    }

    var id: Int { no }
    var threadID: Int { resto == 0 ? no : resto }
    var authorLine: String {
        var parts = [name?.isEmpty == false ? name : "Anonymous"].compactMap { $0 }
        if let trip, !trip.isEmpty {
            parts.append(trip)
        }
        if let idCode, !idCode.isEmpty {
            parts.append("ID \(idCode)")
        }
        if let countryName, !countryName.isEmpty {
            parts.append(countryName)
        }
        return parts.joined(separator: " • ")
    }

    var titleText: String {
        if let sub, !sub.isEmpty {
            return sub.removingHTMLTags()
        }
        if let plainComment, !plainComment.isEmpty {
            return plainComment
        }
        return "Thread #\(threadID)"
    }

    var plainComment: String? {
        guard let com, !com.isEmpty else { return nil }
        return com.removingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func thumbnailRequest(boardID: String) -> SharedRemoteMediaRequest? {
        guard let tim else { return nil }
        guard let url = URL(string: "https://i.4cdn.org/\(boardID)/\(tim)s.jpg") else { return nil }
        return SharedRemoteMediaRequest(namespace: "fourchan", url: url)
    }

    func mediaRequest(boardID: String) -> SharedRemoteMediaRequest? {
        guard let tim, let ext else { return nil }
        guard let url = URL(string: "https://i.4cdn.org/\(boardID)/\(tim)\(ext)") else { return nil }
        return SharedRemoteMediaRequest(namespace: "fourchan", url: url)
    }

    var isVideoAttachment: Bool {
        ext == ".webm"
    }

    var suggestedFilename: String {
        if let filename, let ext {
            return "\(filename)\(ext)"
        }
        return "4chan-\(boardSafeIdentifier)-\(no)\(ext ?? ".bin")"
    }

    private var boardSafeIdentifier: String {
        "\(threadID)"
    }
}
