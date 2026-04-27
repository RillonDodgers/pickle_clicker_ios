import Combine
import Foundation
import OSLog

@MainActor
final class DanbooruForumViewModel: ObservableObject {
    @Published private(set) var topics: [DanbooruForumTopic] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var usernamesByID: [Int: String] = [:]
    private let userDirectory = DanbooruUserDirectory.shared
    private let readStateStore = DanbooruForumReadStateStore.shared

    func reload(using configuration: DanbooruClientConfiguration?) async {
        DanbooruDiagnostics.ui.info("Forum reload start")
        errorMessage = nil

        guard let configuration else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            let fetchedTopics = try await client.fetchForumTopics()
            let host = configuration.baseURL.absoluteString
            let login = configuration.login
            let visibleTopics = fetchedTopics.filter { !$0.isDeleted }
            var mappedTopics: [DanbooruForumTopic] = []
            for var topic in visibleTopics {
                topic.isRead = await readStateStore.isTopicRead(
                    topicID: topic.id,
                    host: host,
                    login: login,
                    apiIsRead: topic.isRead
                )
                mappedTopics.append(topic)
            }
            topics = Self.sortTopics(mappedTopics)
            usernamesByID = [:]

            for topic in topics {
                if let creatorID = topic.creatorID, usernamesByID[creatorID] == nil {
                    if let cachedName = await userDirectory.cachedUsername(host: configuration.baseURL.absoluteString, userID: creatorID) {
                        usernamesByID[creatorID] = cachedName
                    } else if let fetchedUser = try? await client.fetchUser(id: creatorID) {
                        usernamesByID[creatorID] = fetchedUser.name
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: creatorID, username: fetchedUser.name)
                    }
                }
            }

            DanbooruDiagnostics.ui.info("Forum reload success count=\(self.topics.count, privacy: .public)")
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.ui.info("Forum reload cancelled")
                errorMessage = nil
                return
            }
            DanbooruDiagnostics.ui.error("Forum reload failed error=\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func displayName(for userID: Int?) -> String {
        guard let userID else { return "Unknown" }
        return usernamesByID[userID] ?? "User #\(userID)"
    }

    func markTopicRead(_ topicID: Int, using configuration: DanbooruClientConfiguration?) async {
        guard let configuration else { return }
        await readStateStore.markTopicRead(
            topicID: topicID,
            host: configuration.baseURL.absoluteString,
            login: configuration.login
        )
        if let index = topics.firstIndex(where: { $0.id == topicID }) {
            topics[index].isRead = true
        }
    }

    static func sortTopics(_ topics: [DanbooruForumTopic]) -> [DanbooruForumTopic] {
        topics.sorted { lhs, rhs in
            if lhs.isSticky != rhs.isSticky {
                return lhs.isSticky && !rhs.isSticky
            }

            if lhs.isLocked != rhs.isLocked {
                return lhs.isLocked && !rhs.isLocked
            }

            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? .distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }
}
