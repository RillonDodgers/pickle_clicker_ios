import Combine
import Foundation
import OSLog

struct DanbooruDmailThread: Identifiable, Equatable {
    let normalizedSubject: String
    let participantIDs: [Int]
    let messages: [DanbooruDmail]

    var id: String {
        "\(normalizedSubject)|\(participantIDs.map(String.init).joined(separator: ","))"
    }

    var latestMessage: DanbooruDmail {
        messages.max(by: { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }) ?? messages[0]
    }

    var displaySubject: String {
        let title = latestMessage.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Untitled DMail" : title
    }
}

struct DanbooruDmailReplyTarget: Equatable {
    let recipientID: Int?
    let recipientName: String?
    let subject: String
    let quotedBody: String
}

@MainActor
final class DanbooruInboxViewModel: ObservableObject {
    @Published private(set) var messages: [DanbooruDmail] = []
    @Published private(set) var threads: [DanbooruDmailThread] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSendingReply = false
    @Published var errorMessage: String?
    @Published private(set) var usernamesByID: [Int: String] = [:]
    private let userDirectory = DanbooruUserDirectory.shared
    private var currentUserID: Int?

    func reload(using configuration: DanbooruClientConfiguration?) async {
        DanbooruDiagnostics.ui.info("Inbox reload start")
        errorMessage = nil

        guard let configuration else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            let fetchedMessages = try await client.fetchDmails()
            let sortedMessages = fetchedMessages.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            messages = sortedMessages
            threads = buildThreads(from: sortedMessages)
            usernamesByID = [:]
            currentUserID = sortedMessages.first?.ownerID

            for message in messages {
                if let fromID = message.fromID, usernamesByID[fromID] == nil {
                    if let fromName = message.fromName, !fromName.isEmpty {
                        usernamesByID[fromID] = fromName
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: fromID, username: fromName)
                    } else if let cachedName = await userDirectory.cachedUsername(host: configuration.baseURL.absoluteString, userID: fromID) {
                        usernamesByID[fromID] = cachedName
                    } else if let fetchedUser = try? await client.fetchUser(id: fromID) {
                        usernamesByID[fromID] = fetchedUser.name
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: fromID, username: fetchedUser.name)
                    }
                }

                if let toID = message.toID, usernamesByID[toID] == nil {
                    if let toName = message.toName, !toName.isEmpty {
                        usernamesByID[toID] = toName
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: toID, username: toName)
                    } else if let cachedName = await userDirectory.cachedUsername(host: configuration.baseURL.absoluteString, userID: toID) {
                        usernamesByID[toID] = cachedName
                    } else if let fetchedUser = try? await client.fetchUser(id: toID) {
                        usernamesByID[toID] = fetchedUser.name
                        await userDirectory.storeUsername(host: configuration.baseURL.absoluteString, userID: toID, username: fetchedUser.name)
                    }
                }
            }
            DanbooruDiagnostics.ui.info("Inbox reload success count=\(self.messages.count, privacy: .public) threads=\(self.threads.count, privacy: .public)")
        } catch {
            if isAsyncCancellationError(error) {
                DanbooruDiagnostics.ui.info("Inbox reload cancelled")
                errorMessage = nil
                return
            }
            DanbooruDiagnostics.ui.error("Inbox reload failed error=\(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func displayName(for userID: Int?, fallback: String?, placeholder: String) -> String {
        if let userID, let cachedName = usernamesByID[userID] {
            return cachedName
        }

        if let fallback, !fallback.isEmpty {
            return fallback
        }

        return placeholder
    }

    func participantSummary(for thread: DanbooruDmailThread) -> String {
        let names = thread.participantIDs.map { displayName(for: $0, fallback: nil, placeholder: "User #\($0)") }
        return names.isEmpty ? "Unknown participants" : names.joined(separator: ", ")
    }

    func participants(for thread: DanbooruDmailThread) -> [(id: Int, name: String)] {
        thread.participantIDs.map { id in
            (id, displayName(for: id, fallback: nil, placeholder: "User #\(id)"))
        }
    }

    func isThreadUnread(_ thread: DanbooruDmailThread) -> Bool {
        thread.messages.contains { ($0.isRead ?? true) == false }
    }

    func replyTarget(for thread: DanbooruDmailThread) -> DanbooruDmailReplyTarget? {
        let replyRecipientID = thread.participantIDs.first(where: { $0 != currentUserID })
        let replyRecipientName = displayName(
            for: replyRecipientID,
            fallback: latestReplySource(for: thread)?.fromName ?? thread.latestMessage.toName,
            placeholder: "Unknown"
        )
        let recipientName = replyRecipientName == "Unknown" ? nil : replyRecipientName

        guard replyRecipientID != nil || recipientName != nil else {
            return nil
        }

        let sourceMessage = latestReplySource(for: thread) ?? thread.latestMessage
        return DanbooruDmailReplyTarget(
            recipientID: replyRecipientID,
            recipientName: recipientName,
            subject: replySubject(for: sourceMessage.title),
            quotedBody: quotedBody(for: sourceMessage)
        )
    }

    func sendReply(
        body: String,
        in thread: DanbooruDmailThread,
        includeQuote: Bool,
        using configuration: DanbooruClientConfiguration?
    ) async -> Bool {
        errorMessage = nil

        guard let configuration else {
            errorMessage = DanbooruAPIError.invalidConfiguration.localizedDescription
            return false
        }

        guard let replyTarget = replyTarget(for: thread) else {
            errorMessage = "This conversation doesn't have a valid reply target."
            return false
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            errorMessage = "Write a reply before sending."
            return false
        }

        isSendingReply = true
        defer { isSendingReply = false }

        do {
            let client = DanbooruAPIClient(configuration: configuration)
            let messageBody = includeQuote
                ? "\(trimmedBody)\n\n\(replyTarget.quotedBody)"
                : trimmedBody
            _ = try await client.createDmail(
                DanbooruDmailComposeRequest(
                    toID: replyTarget.recipientID,
                    toName: replyTarget.recipientName,
                    title: replyTarget.subject,
                    body: messageBody
                )
            )
            await reload(using: configuration)
            return true
        } catch {
            if isAsyncCancellationError(error) {
                return false
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func buildThreads(from messages: [DanbooruDmail]) -> [DanbooruDmailThread] {
        let grouped = Dictionary(grouping: messages) { message in
            let normalizedSubject = Self.normalizedSubject(from: message.title)
            let participantIDs = Set([message.fromID, message.toID].compactMap { $0 }).sorted()
            return "\(normalizedSubject)|\(participantIDs.map(String.init).joined(separator: ","))"
        }

        return grouped.values
            .map { groupedMessages in
                let sortedMessages = groupedMessages.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                let participantIDs = Set(sortedMessages.flatMap { [$0.fromID, $0.toID] }.compactMap { $0 }).sorted()
                return DanbooruDmailThread(
                    normalizedSubject: Self.normalizedSubject(from: sortedMessages.last?.title),
                    participantIDs: participantIDs,
                    messages: sortedMessages
                )
            }
            .sorted { lhs, rhs in
                (lhs.latestMessage.createdAt ?? .distantPast) > (rhs.latestMessage.createdAt ?? .distantPast)
            }
    }

    private static func normalizedSubject(from title: String?) -> String {
        var subject = (title ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while subject.lowercased().hasPrefix("re:") {
            subject = String(subject.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return subject.lowercased()
    }

    private func latestReplySource(for thread: DanbooruDmailThread) -> DanbooruDmail? {
        thread.messages
            .reversed()
            .first(where: { $0.fromID != currentUserID })
    }

    private func replySubject(for title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Re:" }
        return trimmed.lowercased().hasPrefix("re:") ? trimmed : "Re: \(trimmed)"
    }

    private func quotedBody(for message: DanbooruDmail) -> String {
        let speaker = displayName(
            for: message.fromID,
            fallback: message.fromName,
            placeholder: "Unknown"
        )
        let body = (message.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if body.isEmpty {
            return "[quote]\n\(speaker) said:\n[/quote]"
        }

        return "[quote]\n\(speaker) said:\n\n\(body)\n[/quote]"
    }
}
