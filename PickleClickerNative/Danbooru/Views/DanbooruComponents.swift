import Foundation
import OSLog
import SwiftUI
import UIKit

enum DanbooruProfileTarget: Hashable {
    case currentUser
    case user(id: Int, name: String?)

    var title: String {
        switch self {
        case .currentUser:
            return "Profile"
        case let .user(_, name):
            return name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : "Profile"
        }
    }

    var userID: Int? {
        switch self {
        case .currentUser:
            return nil
        case let .user(id, _):
            return id
        }
    }
}

enum DanbooruNavigationRoute: Hashable, Identifiable {
    case profile(DanbooruProfileTarget)
    case post(Int)
    case feed(String)

    var id: String {
        switch self {
        case let .profile(target):
            switch target {
            case .currentUser:
                return "profile:current"
            case let .user(id, name):
                return "profile:\(id):\(name ?? "")"
            }
        case let .post(postID):
            return "post:\(postID)"
        case let .feed(query):
            return "feed:\(query)"
        }
    }
}

@ViewBuilder
func DanbooruNavigationDestination(route: DanbooruNavigationRoute) -> some View {
    switch route {
    case let .profile(target):
        DanbooruProfileView(target: target)
    case let .post(postID):
        DanbooruPostDetailView(postID: postID)
    case let .feed(query):
        DanbooruFeedView(initialQuery: query)
    }
}

struct DanbooruScreenContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        NativeAppScreenContainer(title: title, currentApp: .danbooru) {
            content
        }
    }
}

struct DanbooruConfigurationRequiredView: View {
    let action: () -> Void

    var body: some View {
        NativeConfigurationRequiredView(
            title: "Danbooru Settings Needed",
            systemImage: "gearshape.2",
            description: "Add your Danbooru URL, login, and API key in Settings before loading this tab.",
            actionTitle: "Open Settings",
            action: action
        )
    }
}

struct DanbooruProtectedScreen<LoadingContent: View, Content: View>: View {
    let title: String
    let tab: DanbooruAppModel.Tab
    var requiresSelectedTabMatch: Bool = true
    let taskIdentity: String
    let onLoad: @MainActor () async -> Void
    @ViewBuilder let loadingContent: () -> LoadingContent
    @ViewBuilder let content: () -> Content

    @EnvironmentObject private var appModel: DanbooruAppModel

    var body: some View {
        DanbooruScreenContainer(title: title) {
            screenBody
        }
        .task(id: effectiveTaskIdentity) {
            await loadContentIfNeeded()
        }
    }

    @ViewBuilder
    private var screenBody: some View {
        if appModel.configuration == nil {
            DanbooruConfigurationRequiredView(action: openSettings)
        } else if appModel.validationStatus == .validating {
            loadingContent()
        } else if !appModel.canLoadProtectedContent {
            DanbooruConfigurationRequiredView(action: openSettings)
        } else {
            content()
        }
    }

    private func openSettings() {
        appModel.switchToSettings()
    }

    private var effectiveTaskIdentity: String {
        "\(taskIdentity)|\(validationIdentity)"
    }

    private var validationIdentity: String {
        switch appModel.validationStatus {
        case .unknown:
            return "unknown"
        case .validating:
            return "validating"
        case .valid:
            return "valid"
        case let .invalid(message):
            return "invalid:\(message)"
        }
    }

    private func loadContentIfNeeded() async {
        guard appModel.canLoadProtectedContent else {
            DanbooruDiagnostics.state.info(
                "ProtectedScreen skip load title=\(title, privacy: .public) reason=protected-content-unavailable validation=\(validationIdentity, privacy: .public)"
            )
            return
        }
        guard !requiresSelectedTabMatch || appModel.selectedTab == tab else {
            DanbooruDiagnostics.state.info(
                "ProtectedScreen skip load title=\(title, privacy: .public) reason=inactive-tab selected=\(String(describing: appModel.selectedTab), privacy: .public)"
            )
            return
        }
        DanbooruDiagnostics.state.info(
            "ProtectedScreen load title=\(title, privacy: .public) identity=\(effectiveTaskIdentity, privacy: .public)"
        )
        await onLoad()
    }
}

typealias DanbooruErrorBanner = NativeErrorBanner
typealias DanbooruCompactSectionHeader = NativeCompactSectionHeader
typealias DanbooruEdgeDivider = NativeEdgeDivider
typealias DanbooruEdgeRow<Content: View> = NativeEdgeRow<Content>
typealias DanbooruSkeletonBlock = NativeSkeletonBlock

struct DanbooruPostCardSkeleton: View {
    var body: some View {
        DanbooruEdgeRow(compactVerticalPadding: 12) {
            HStack(alignment: .top, spacing: 12) {
                DanbooruSkeletonBlock(width: 72, height: 72, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 7) {
                    DanbooruSkeletonBlock(width: nil, height: 16)
                    DanbooruSkeletonBlock(width: 170, height: 16)
                    DanbooruSkeletonBlock(width: 132, height: 12)
                    DanbooruSkeletonBlock(width: 180, height: 11)
                }

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    DanbooruSkeletonBlock(width: 24, height: 24, cornerRadius: 12)
                    DanbooruSkeletonBlock(width: 24, height: 24, cornerRadius: 12)
                    DanbooruSkeletonBlock(width: 24, height: 24, cornerRadius: 12)
                }
            }
        }
    }
}

typealias DanbooruSectionCardSkeleton = NativeSectionCardSkeleton

struct DanbooruInboxRowSkeleton: View {
    var body: some View {
        DanbooruEdgeRow {
            VStack(alignment: .leading, spacing: 6) {
                DanbooruSkeletonBlock(width: 180, height: 16)
                DanbooruSkeletonBlock(width: 120, height: 12)
                DanbooruSkeletonBlock(width: nil, height: 12)
            }
        }
    }
}

struct DanbooruCommentSkeleton: View {
    var body: some View {
        DanbooruEdgeRow(compactVerticalPadding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DanbooruSkeletonBlock(width: 120, height: 14)
                    Spacer()
                    DanbooruSkeletonBlock(width: 80, height: 11)
                }
                DanbooruSkeletonBlock(width: nil, height: 14)
                DanbooruSkeletonBlock(width: 220, height: 14)
            }
        }
    }
}

enum DanbooruDTextAction: Hashable {
    case user(id: Int, name: String?)
    case userName(String)
    case tag(String)
    case wiki(String)
    case post(Int)
    case topic(Int, page: Int?)
    case forumPost(Int)
    case comment(Int)
    case web(String)
}

enum DanbooruDTextTokenKind: String {
    case user
    case userName
    case tag
    case wiki
    case post
    case topic
    case forumPost
    case comment
    case web
}

enum DanbooruDTextStyle: String, Hashable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case spoiler
}

indirect enum DanbooruDTextInlineNode: Equatable {
    case text(String)
    case lineBreak
    case styled(Set<DanbooruDTextStyle>, [DanbooruDTextInlineNode])
    case code(String)
    case link([DanbooruDTextInlineNode], DanbooruDTextAction)
}

struct DanbooruDTextListItem: Equatable {
    let level: Int
    let content: [DanbooruDTextInlineNode]
}

indirect enum DanbooruDTextBlock: Equatable {
    case paragraph([DanbooruDTextInlineNode])
    case quote([DanbooruDTextBlock])
    case spoiler([DanbooruDTextBlock])
    case expand(title: String?, [DanbooruDTextBlock])
    case heading(level: Int, anchor: String?, [DanbooruDTextInlineNode])
    case unorderedList([DanbooruDTextListItem])
    case horizontalRule
    case codeBlock(String)
}

enum DanbooruDTextParser {
    static func parse(_ text: String) -> [DanbooruDTextBlock] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        return parseBlocks(lines, startIndex: 0, terminator: nil).blocks
    }

    private struct BlockParseResult {
        let blocks: [DanbooruDTextBlock]
        let nextIndex: Int
        let foundTerminator: Bool
    }

    private static func parseBlocks(_ lines: [String], startIndex: Int, terminator: String?) -> BlockParseResult {
        var blocks: [DanbooruDTextBlock] = []
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if let terminator, trimmed == terminator {
                return BlockParseResult(blocks: blocks, nextIndex: index + 1, foundTerminator: true)
            }

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed == "[quote]" {
                let nested = parseBlocks(lines, startIndex: index + 1, terminator: "[/quote]")
                if nested.foundTerminator {
                    blocks.append(.quote(nested.blocks))
                    index = nested.nextIndex
                    continue
                }
            }

            if trimmed == "[spoiler]" {
                let nested = parseBlocks(lines, startIndex: index + 1, terminator: "[/spoiler]")
                if nested.foundTerminator {
                    blocks.append(.spoiler(nested.blocks))
                    index = nested.nextIndex
                    continue
                }
            }

            if let expandTitle = parseExpandTitle(trimmed) {
                let nested = parseBlocks(lines, startIndex: index + 1, terminator: "[/expand]")
                if nested.foundTerminator {
                    blocks.append(.expand(title: expandTitle, nested.blocks))
                    index = nested.nextIndex
                    continue
                }
            }

            if trimmed == "[hr]" {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            if trimmed == "[code]" || trimmed == "[nodtext]" {
                let closeTag = trimmed == "[code]" ? "[/code]" : "[/nodtext]"
                var buffer: [String] = []
                var closeIndex = index + 1
                while closeIndex < lines.count, lines[closeIndex].trimmingCharacters(in: .whitespaces) != closeTag {
                    buffer.append(lines[closeIndex])
                    closeIndex += 1
                }
                if closeIndex < lines.count {
                    blocks.append(.codeBlock(buffer.joined(separator: "\n")))
                    index = closeIndex + 1
                    continue
                }
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(.heading(level: heading.level, anchor: heading.anchor, parseInline(heading.text)))
                index += 1
                continue
            }

            if let listResult = parseList(lines, startIndex: index) {
                blocks.append(.unorderedList(listResult.items))
                index = listResult.nextIndex
                continue
            }

            let paragraph = parseParagraph(lines, startIndex: index, terminator: terminator)
            blocks.append(.paragraph(parseInline(paragraph.text)))
            index = paragraph.nextIndex
        }

        return BlockParseResult(blocks: blocks, nextIndex: index, foundTerminator: false)
    }

    private static func parseExpandTitle(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("[expand"), trimmed.hasSuffix("]") else { return nil }
        if trimmed == "[expand]" {
            return nil
        }
        guard trimmed.hasPrefix("[expand=") else { return nil }
        return String(trimmed.dropFirst(8).dropLast())
    }

    private static func parseHeading(_ trimmed: String) -> (level: Int, anchor: String?, text: String)? {
        let pattern = #"^h([456])(?:#([^.]+))?\.\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: nsRange),
              let levelRange = Range(match.range(at: 1), in: trimmed),
              let textRange = Range(match.range(at: 3), in: trimmed),
              let level = Int(trimmed[levelRange]) else {
            return nil
        }
        let anchor: String?
        if let range = Range(match.range(at: 2), in: trimmed) {
            anchor = String(trimmed[range])
        } else {
            anchor = nil
        }
        return (level, anchor, String(trimmed[textRange]))
    }

    private struct ListParseResult {
        let items: [DanbooruDTextListItem]
        let nextIndex: Int
    }

    private static func parseList(_ lines: [String], startIndex: Int) -> ListParseResult? {
        var items: [DanbooruDTextListItem] = []
        var index = startIndex

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { break }

            var level = 0
            for character in trimmed {
                guard character == "*" else { break }
                level += 1
            }

            guard level > 0 else { break }
            let remainder = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
            items.append(DanbooruDTextListItem(level: level, content: parseInline(remainder)))
            index += 1
        }

        return items.isEmpty ? nil : ListParseResult(items: items, nextIndex: index)
    }

    private static func parseParagraph(_ lines: [String], startIndex: Int, terminator: String?) -> (text: String, nextIndex: Int) {
        var buffer: [String] = []
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == terminator || trimmed == "[quote]" || trimmed == "[spoiler]" || trimmed == "[hr]" {
                break
            }
            if parseExpandTitle(trimmed) != nil || parseHeading(trimmed) != nil || parseList(lines, startIndex: index) != nil {
                if buffer.isEmpty {
                    buffer.append(lines[index])
                    index += 1
                }
                break
            }
            buffer.append(lines[index])
            index += 1
        }

        return (buffer.joined(separator: "\n"), index)
    }

    static func parseInline(_ text: String) -> [DanbooruDTextInlineNode] {
        parseInlineSegment(text, closingTag: nil).nodes
    }

    private struct InlineParseResult {
        let nodes: [DanbooruDTextInlineNode]
        let consumed: String.Index
        let foundClosing: Bool
    }

    private static func parseInlineSegment(_ text: String, closingTag: String?) -> InlineParseResult {
        var nodes: [DanbooruDTextInlineNode] = []
        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            nodes.append(contentsOf: tokenizePlainText(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < text.endIndex {
            if let closingTag, text[index...].hasPrefix(closingTag) {
                flushBuffer()
                return InlineParseResult(nodes: nodes, consumed: text.index(index, offsetBy: closingTag.count), foundClosing: true)
            }

            if text[index...].hasPrefix("[br]") {
                flushBuffer()
                nodes.append(.lineBreak)
                index = text.index(index, offsetBy: 4)
                continue
            }

            if let tag = parseInlineTag(in: text[index...]) {
                flushBuffer()
                let contentStart = text.index(index, offsetBy: tag.open.count)
                let nested = parseInlineSegment(String(text[contentStart...]), closingTag: tag.close)
                if nested.foundClosing {
                    switch tag.kind {
                    case .code:
                        nodes.append(.code(serializeInline(nested.nodes)))
                    case .styled(let styles):
                        nodes.append(.styled(styles, nested.nodes))
                    }
                    index = text.index(contentStart, offsetBy: text[contentStart...].distance(from: text[contentStart...].startIndex, to: nested.consumed))
                    continue
                } else {
                    buffer.append(tag.open)
                    buffer.append(serializeInline(nested.nodes))
                    break
                }
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flushBuffer()
        return InlineParseResult(nodes: nodes, consumed: text.endIndex, foundClosing: false)
    }

    private enum InlineTagKind {
        case styled(Set<DanbooruDTextStyle>)
        case code
    }

    private struct InlineTag {
        let open: String
        let close: String
        let kind: InlineTagKind
    }

    private static func parseInlineTag(in text: Substring) -> InlineTag? {
        let tags: [InlineTag] = [
            InlineTag(open: "[b]", close: "[/b]", kind: .styled([.bold])),
            InlineTag(open: "[i]", close: "[/i]", kind: .styled([.italic])),
            InlineTag(open: "[u]", close: "[/u]", kind: .styled([.underline])),
            InlineTag(open: "[s]", close: "[/s]", kind: .styled([.strikethrough])),
            InlineTag(open: "[spoiler]", close: "[/spoiler]", kind: .styled([.spoiler])),
            InlineTag(open: "[code]", close: "[/code]", kind: .code),
            InlineTag(open: "[nodtext]", close: "[/nodtext]", kind: .code)
        ]

        return tags.first(where: { text.hasPrefix($0.open) })
    }

    private static func tokenizePlainText(_ text: String) -> [DanbooruDTextInlineNode] {
        guard !text.isEmpty else { return [] }
        let tokenizers: [DanbooruInlineTokenizer] = [
            DanbooruQuotedLinkTokenizer(),
            DanbooruMarkdownLinkTokenizer(),
            DanbooruReverseMarkdownLinkTokenizer(),
            DanbooruWikiLinkTokenizer(),
            DanbooruTagLinkTokenizer(),
            DanbooruIDLinkTokenizer(),
            DanbooruMentionTokenizer(),
            DanbooruURLTokenizer()
        ]

        var result: [DanbooruDTextInlineNode] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            let slice = String(text[cursor...])
            let matches = tokenizers.compactMap { $0.firstMatch(in: slice) }
            guard let best = matches.min(by: { lhs, rhs in
                if lhs.range.lowerBound == rhs.range.lowerBound {
                    return lhs.range.count > rhs.range.count
                }
                return lhs.range.lowerBound < rhs.range.lowerBound
            }) else {
                result.append(.text(slice))
                break
            }

            if best.range.lowerBound > 0 {
                let prefixEnd = slice.index(slice.startIndex, offsetBy: best.range.lowerBound)
                result.append(.text(String(slice[..<prefixEnd])))
            }

            result.append(best.node)
            cursor = text.index(cursor, offsetBy: best.range.upperBound)
        }

        return result
    }

    private static func serializeInline(_ nodes: [DanbooruDTextInlineNode]) -> String {
        nodes.map { node in
            switch node {
            case let .text(text):
                return text
            case .lineBreak:
                return "[br]"
            case let .styled(_, children):
                return serializeInline(children)
            case let .code(text):
                return text
            case let .link(children, _):
                return serializeInline(children)
            }
        }
        .joined()
    }
}

private struct DanbooruInlineTokenMatch {
    let range: Range<Int>
    let node: DanbooruDTextInlineNode
}

private protocol DanbooruInlineTokenizer {
    func firstMatch(in text: String) -> DanbooruInlineTokenMatch?
}

private protocol DanbooruRegexTokenizer: DanbooruInlineTokenizer {
    var regex: NSRegularExpression { get }
    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode?
}

private extension DanbooruRegexTokenizer {
    func firstMatch(in text: String) -> DanbooruInlineTokenMatch? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text),
              let node = makeNode(from: match, text: text) else {
            return nil
        }
        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
        return DanbooruInlineTokenMatch(range: lowerBound..<upperBound, node: node)
    }
}

private struct DanbooruQuotedLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #""([^"]+)":\[([^\]]+)\]"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let labelRange = Range(match.range(at: 1), in: text),
              let targetRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        return .link([.text(String(text[labelRange]))], .web(String(text[targetRange])))
    }
}

private struct DanbooruMarkdownLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\((https?://[^\s)]+)\)"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let labelRange = Range(match.range(at: 1), in: text),
              let targetRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        return .link([.text(String(text[labelRange]))], .web(String(text[targetRange])))
    }
}

private struct DanbooruReverseMarkdownLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"\[(https?://[^\]]+)\]\(([^)]+)\)"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let targetRange = Range(match.range(at: 1), in: text),
              let labelRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        return .link([.text(String(text[labelRange]))], .web(String(text[targetRange])))
    }
}

private struct DanbooruWikiLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"\[\[([^\]|]+)(?:\|([^\]]*))?\]\]"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let titleRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let title = String(text[titleRange])
        let label: String
        if let aliasRange = Range(match.range(at: 2), in: text) {
            let alias = String(text[aliasRange])
            if alias.isEmpty {
                label = title.replacingOccurrences(of: #"\s+\([^)]*\)$"#, with: "", options: .regularExpression)
            } else {
                label = alias
            }
        } else {
            label = title
        }
        return .link([.text(label)], .wiki(title))
    }
}

private struct DanbooruTagLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"\{\{([^}|]+)(?:\|([^}]+))?\}\}"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let queryRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let query = String(text[queryRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let label: String
        if let labelRange = Range(match.range(at: 2), in: text) {
            label = String(text[labelRange])
        } else {
            label = query
        }
        return .link([.text(label)], .tag(query))
    }
}

private struct DanbooruMentionTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])@([A-Za-z0-9_]+)"#)

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let range = Range(match.range(at: 1), in: text) else { return nil }
        let username = String(text[range])
        return .link([.text("@\(username)")], .userName(username))
    }
}

private struct DanbooruIDLinkTokenizer: DanbooruRegexTokenizer {
    let regex = try! NSRegularExpression(pattern: #"\b(post|topic|forum|comment|user)\s+#(\d+)(?:/p(\d+))?\b"#, options: [.caseInsensitive])

    func makeNode(from match: NSTextCheckingResult, text: String) -> DanbooruDTextInlineNode? {
        guard let kindRange = Range(match.range(at: 1), in: text),
              let idRange = Range(match.range(at: 2), in: text),
              let fullRange = Range(match.range, in: text),
              let numericID = Int(text[idRange]) else {
            return nil
        }

        let kind = String(text[kindRange]).lowercased()
        let label = String(text[fullRange])
        switch kind {
        case "post":
            return .link([.text(label)], .post(numericID))
        case "topic":
            let page: Int?
            if let pageRange = Range(match.range(at: 3), in: text) {
                page = Int(text[pageRange])
            } else {
                page = nil
            }
            return .link([.text(label)], .topic(numericID, page: page))
        case "forum":
            return .link([.text(label)], .forumPost(numericID))
        case "comment":
            return .link([.text(label)], .comment(numericID))
        case "user":
            return .link([.text(label)], .user(id: numericID, name: nil))
        default:
            return nil
        }
    }
}

private struct DanbooruURLTokenizer: DanbooruInlineTokenizer {
    private let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    func firstMatch(in text: String) -> DanbooruInlineTokenMatch? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        let urlString = String(text[range])
        let lowerBound = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: range.upperBound)
        return DanbooruInlineTokenMatch(
            range: lowerBound..<upperBound,
            node: .link([.text(urlString)], .web(urlString))
        )
    }
}

private enum DanbooruDTextLinkCodec {
    static let scheme = "pickle-danbooru"

    static func encode(_ action: DanbooruDTextAction) -> URL? {
        var components = URLComponents()
        components.scheme = scheme

        switch action {
        case let .user(id, name):
            components.host = DanbooruDTextTokenKind.user.rawValue
            components.queryItems = [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "name", value: name)
            ]
        case let .userName(name):
            components.host = DanbooruDTextTokenKind.userName.rawValue
            components.queryItems = [URLQueryItem(name: "name", value: name)]
        case let .tag(query):
            components.host = DanbooruDTextTokenKind.tag.rawValue
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case let .wiki(title):
            components.host = DanbooruDTextTokenKind.wiki.rawValue
            components.queryItems = [URLQueryItem(name: "title", value: title)]
        case let .post(id):
            components.host = DanbooruDTextTokenKind.post.rawValue
            components.queryItems = [URLQueryItem(name: "id", value: String(id))]
        case let .topic(id, page):
            components.host = DanbooruDTextTokenKind.topic.rawValue
            components.queryItems = [
                URLQueryItem(name: "id", value: String(id)),
                URLQueryItem(name: "page", value: page.map(String.init))
            ]
        case let .forumPost(id):
            components.host = DanbooruDTextTokenKind.forumPost.rawValue
            components.queryItems = [URLQueryItem(name: "id", value: String(id))]
        case let .comment(id):
            components.host = DanbooruDTextTokenKind.comment.rawValue
            components.queryItems = [URLQueryItem(name: "id", value: String(id))]
        case let .web(target):
            components.host = DanbooruDTextTokenKind.web.rawValue
            components.queryItems = [URLQueryItem(name: "url", value: target)]
        }

        return components.url
    }

    static func decode(_ url: URL) -> DanbooruDTextAction? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return nil
        }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        switch host {
        case DanbooruDTextTokenKind.user.rawValue:
            guard let id = query["id"] ?? nil, let parsedID = Int(id) else { return nil }
            return .user(id: parsedID, name: query["name"] ?? nil)
        case DanbooruDTextTokenKind.userName.rawValue:
            guard let name = query["name"] ?? nil else { return nil }
            return .userName(name)
        case DanbooruDTextTokenKind.tag.rawValue:
            guard let q = query["q"] ?? nil else { return nil }
            return .tag(q)
        case DanbooruDTextTokenKind.wiki.rawValue:
            guard let title = query["title"] ?? nil else { return nil }
            return .wiki(title)
        case DanbooruDTextTokenKind.post.rawValue:
            guard let id = query["id"] ?? nil, let parsedID = Int(id) else { return nil }
            return .post(parsedID)
        case DanbooruDTextTokenKind.topic.rawValue:
            guard let id = query["id"] ?? nil, let parsedID = Int(id) else { return nil }
            let page = (query["page"] ?? nil).flatMap { Int($0) }
            return .topic(parsedID, page: page)
        case DanbooruDTextTokenKind.forumPost.rawValue:
            guard let id = query["id"] ?? nil, let parsedID = Int(id) else { return nil }
            return .forumPost(parsedID)
        case DanbooruDTextTokenKind.comment.rawValue:
            guard let id = query["id"] ?? nil, let parsedID = Int(id) else { return nil }
            return .comment(parsedID)
        case DanbooruDTextTokenKind.web.rawValue:
            guard let target = query["url"] ?? nil else { return nil }
            return .web(target)
        default:
            return nil
        }
    }
}

struct DanbooruActionRoutingResult {
    var route: DanbooruNavigationRoute?
    var url: URL?
}

enum DanbooruActionRouter {
    static func routingResult(for action: DanbooruDTextAction, baseURL: URL?) -> DanbooruActionRoutingResult {
        switch action {
        case let .user(id, name):
            return DanbooruActionRoutingResult(route: .profile(.user(id: id, name: name)), url: nil)
        case let .userName(name):
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: "/users", queryItems: [URLQueryItem(name: "search[name]", value: name)], baseURL: baseURL))
        case let .tag(query):
            return DanbooruActionRoutingResult(route: .feed(query), url: nil)
        case let .wiki(title):
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: "/wiki_pages/\(title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title)", baseURL: baseURL))
        case let .post(postID):
            return DanbooruActionRoutingResult(route: .post(postID), url: nil)
        case let .topic(topicID, page):
            let path = page.map { "/forum_topics/\(topicID)?page=\($0)" } ?? "/forum_topics/\(topicID)"
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: path, baseURL: baseURL))
        case let .forumPost(postID):
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: "/forum_posts/\(postID)", baseURL: baseURL))
        case let .comment(commentID):
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: "/comments/\(commentID)", baseURL: baseURL))
        case let .web(target):
            if let absolute = URL(string: target), absolute.scheme != nil {
                return DanbooruActionRoutingResult(url: absolute)
            }
            return DanbooruActionRoutingResult(url: buildRelativeURL(path: target, baseURL: baseURL))
        }
    }

    private static func buildRelativeURL(path: String, queryItems: [URLQueryItem] = [], baseURL: URL?) -> URL? {
        guard let baseURL else { return URL(string: path) }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        if path.contains("?"), let url = URL(string: path, relativeTo: baseURL) {
            return url.absoluteURL
        }
        components?.path = path.hasPrefix("/") ? path : "/\(path)"
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url
    }
}

struct DanbooruUserLink: View {
    let userID: Int?
    let username: String
    var accentColor: Color = NativeAppTheme.tint
    let onOpenProfile: (DanbooruProfileTarget) -> Void

    var body: some View {
        if let userID {
            Button {
                onOpenProfile(.user(id: userID, name: username))
            } label: {
                Text(username)
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        } else {
            Text(username)
        }
    }
}

struct DanbooruDTextView: View {
    let text: String
    var uiFont: UIFont = .preferredFont(forTextStyle: .body)
    var foregroundColor: UIColor = .label
    var baseURL: URL?
    let onAction: (DanbooruDTextAction) -> Void

    @Environment(\.openURL) private var openURL

    private var blocks: [DanbooruDTextBlock] {
        let parsed = DanbooruDTextParser.parse(text)
        return parsed.isEmpty ? [.paragraph([.text(text)])] : parsed
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard let action = DanbooruDTextLinkCodec.decode(url) else {
                    return .systemAction
                }

                let result = DanbooruActionRouter.routingResult(for: action, baseURL: baseURL)
                if let route = result.route {
                    onAction(actionForRoute(route))
                    return .handled
                }
                if let resolvedURL = result.url {
                    openURL(resolvedURL)
                    return .handled
                }
                return .discarded
            })
    }

    private var content: AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { entry in
                    renderBlock(entry.element, depth: 0)
                }
            }
        )
    }

    private func renderBlock(_ block: DanbooruDTextBlock, depth: Int) -> AnyView {
        switch block {
        case let .paragraph(inlines):
            if !renderAttributedString(inlines).characters.isEmpty {
                return AnyView(
                    Text(renderAttributedString(inlines))
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
            }
            return AnyView(EmptyView())
        case let .quote(children):
            return AnyView(
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.opacity(max(0.28, 0.65 - (Double(depth) * 0.12))))
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(children.enumerated()), id: \.offset) { entry in
                            renderBlock(entry.element, depth: depth + 1)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(max(0.03, 0.06 - (Double(depth) * 0.01))))
            )
        case let .spoiler(children):
            return AnyView(
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(children.enumerated()), id: \.offset) { entry in
                            renderBlock(entry.element, depth: depth + 1)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Spoiler")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: foregroundColor))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
            )
        case let .expand(title, children):
            return AnyView(
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(children.enumerated()), id: \.offset) { entry in
                            renderBlock(entry.element, depth: depth + 1)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(title?.isEmpty == false ? title! : "Expand")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(uiColor: foregroundColor))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NativeAppTheme.secondaryBackground)
                )
            )
        case let .heading(level, _, inlines):
            return AnyView(
                Text(renderAttributedString(inlines))
                    .font(.system(size: headingSize(for: level), weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            )
        case let .unorderedList(items):
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(Color(uiColor: foregroundColor))
                            Text(renderAttributedString(entry.element.content))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.leading, CGFloat(max(0, entry.element.level - 1)) * 18)
                    }
                }
            )
        case .horizontalRule:
            return AnyView(
                Rectangle()
                    .fill(NativeAppTheme.divider)
                    .frame(height: 1)
            )
        case let .codeBlock(text):
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(text)
                        .font(.system(size: uiFont.pointSize, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                )
            )
        }
    }

    private func renderAttributedString(_ inlines: [DanbooruDTextInlineNode], inheritedStyles: Set<DanbooruDTextStyle> = []) -> AttributedString {
        let mutable = NSMutableAttributedString()

        for inline in inlines {
            switch inline {
            case let .text(text):
                mutable.append(NSAttributedString(
                    string: text,
                    attributes: textAttributes(for: inheritedStyles, link: nil)
                ))
            case .lineBreak:
                mutable.append(NSAttributedString(string: "\n", attributes: textAttributes(for: inheritedStyles, link: nil)))
            case let .styled(styles, children):
                mutable.append(nsAttributedString(from: children, inheritedStyles: inheritedStyles.union(styles), link: nil))
            case let .code(text):
                mutable.append(NSAttributedString(
                    string: text,
                    attributes: codeAttributes(for: inheritedStyles)
                ))
            case let .link(children, action):
                mutable.append(nsAttributedString(from: children, inheritedStyles: inheritedStyles, link: DanbooruDTextLinkCodec.encode(action)))
            }
        }

        return (try? AttributedString(mutable, including: \.uiKit)) ?? AttributedString(String(mutable.string))
    }

    private func nsAttributedString(from inlines: [DanbooruDTextInlineNode], inheritedStyles: Set<DanbooruDTextStyle>, link: URL?) -> NSAttributedString {
        let mutable = NSMutableAttributedString()
        for inline in inlines {
            switch inline {
            case let .text(text):
                mutable.append(NSAttributedString(string: text, attributes: textAttributes(for: inheritedStyles, link: link)))
            case .lineBreak:
                mutable.append(NSAttributedString(string: "\n", attributes: textAttributes(for: inheritedStyles, link: link)))
            case let .styled(styles, children):
                mutable.append(nsAttributedString(from: children, inheritedStyles: inheritedStyles.union(styles), link: link))
            case let .code(text):
                var attributes = codeAttributes(for: inheritedStyles)
                if let link {
                    attributes[.link] = link
                    attributes[.foregroundColor] = UIColor.systemTeal
                }
                mutable.append(NSAttributedString(string: text, attributes: attributes))
            case let .link(children, nestedAction):
                mutable.append(nsAttributedString(from: children, inheritedStyles: inheritedStyles, link: DanbooruDTextLinkCodec.encode(nestedAction)))
            }
        }
        return mutable
    }

    private func textAttributes(for styles: Set<DanbooruDTextStyle>, link: URL?) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedUIFont(for: styles),
            .foregroundColor: styles.contains(.spoiler) ? UIColor.clear : foregroundColor
        ]

        if styles.contains(.underline) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if styles.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if styles.contains(.spoiler) {
            attributes[.backgroundColor] = UIColor.darkGray
        }
        if let link {
            attributes[.link] = link
            attributes[.foregroundColor] = UIColor.systemTeal
            if attributes[.underlineStyle] == nil {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
        }
        return attributes
    }

    private func codeAttributes(for styles: Set<DanbooruDTextStyle>) -> [NSAttributedString.Key: Any] {
        var attributes = textAttributes(for: styles, link: nil)
        attributes[.font] = UIFont.monospacedSystemFont(ofSize: uiFont.pointSize * 0.94, weight: .regular)
        attributes[.backgroundColor] = UIColor.black.withAlphaComponent(0.25)
        return attributes
    }

    private func resolvedUIFont(for styles: Set<DanbooruDTextStyle>) -> UIFont {
        if styles.contains(.bold), styles.contains(.italic) {
            return UIFont.systemFont(ofSize: uiFont.pointSize, weight: .semibold).withTraits([.traitItalic])
        }
        if styles.contains(.bold) {
            return UIFont.systemFont(ofSize: uiFont.pointSize, weight: .semibold)
        }
        if styles.contains(.italic) {
            return uiFont.withTraits([.traitItalic])
        }
        return uiFont
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 4:
            return uiFont.pointSize + 5
        case 5:
            return uiFont.pointSize + 3
        default:
            return uiFont.pointSize + 1
        }
    }

    private func actionForRoute(_ route: DanbooruNavigationRoute) -> DanbooruDTextAction {
        switch route {
        case let .profile(target):
            switch target {
            case .currentUser:
                return .web("/profile")
            case let .user(id, name):
                return .user(id: id, name: name)
            }
        case let .post(postID):
            return .post(postID)
        case let .feed(query):
            return .tag(query)
        }
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits.union(fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

struct DanbooruPostCard: View {
    let post: DanbooruPostCardState
    let configuration: DanbooruClientConfiguration?
    let onUpvote: (() -> Void)?
    let onDownvote: (() -> Void)?
    let onFavorite: (() -> Void)?

    var body: some View {
        DanbooruEdgeRow(compactVerticalPadding: 10) {
            HStack(alignment: .top, spacing: 12) {
                DanbooruAuthenticatedImage(
                    url: post.imageURL,
                    configuration: configuration,
                    contentMode: .fill,
                    maxPixelSize: 256
                ) {
                    ZStack {
                        Rectangle()
                            .fill(Color(.secondarySystemFill))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if post.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .shadow(radius: 6)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(post.primaryText)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)

                    Text(post.secondaryText)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label("\(post.score)", systemImage: "arrow.up")
                        Label("\(post.favoriteCount)", systemImage: "heart")
                        if let createdAt = post.createdAt {
                            Text(createdAt.formatted(.relative(presentation: .named)))
                        }
                        if let rating = post.rating {
                            Text(rating.uppercased())
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if showsActionButtons {
                    VStack(spacing: 8) {
                        if let onUpvote {
                            voteButton(
                                systemName: post.voteDirection == .up ? "arrow.up.circle.fill" : "arrow.up.circle",
                                tint: post.voteDirection == .up ? .orange : .secondary,
                                action: onUpvote
                            )
                        }

                        if let onFavorite {
                            voteButton(
                                systemName: post.isFavorited ? "heart.fill" : "heart",
                                tint: post.isFavorited ? .pink : .secondary,
                                action: onFavorite
                            )
                        }

                        if let onDownvote {
                            voteButton(
                                systemName: post.voteDirection == .down ? "arrow.down.circle.fill" : "arrow.down.circle",
                                tint: post.voteDirection == .down ? .blue : .secondary,
                                action: onDownvote
                            )
                        }
                    }
                }
            }
        }
    }

    private var showsActionButtons: Bool {
        onUpvote != nil || onDownvote != nil || onFavorite != nil
    }

    private func voteButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}
