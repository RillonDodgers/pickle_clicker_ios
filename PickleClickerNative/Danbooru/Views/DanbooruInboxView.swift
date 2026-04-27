import SwiftUI

struct DanbooruInboxView: View {
    @EnvironmentObject private var appModel: DanbooruAppModel
    @StateObject private var viewModel = DanbooruInboxViewModel()
    @State private var replyThread: DanbooruDmailThread?
    @State private var selectedRoute: DanbooruNavigationRoute?

    var body: some View {
        DanbooruProtectedScreen(
            title: "Inbox",
            tab: .inbox,
            taskIdentity: "\(appModel.reloadToken)|\(appModel.selectedTab)",
            onLoad: loadInbox
        ) {
            loadingContent
        } content: {
            content
        }
    }

    private var loadingContent: some View {
        List {
            ForEach(0 ..< 8, id: \.self) { _ in
                DanbooruInboxRowSkeleton()
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.black)
            }
        }
        .listStyle(.plain)
    }

    private var content: some View {
        List {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ForEach(0 ..< 8, id: \.self) { _ in
                    DanbooruInboxRowSkeleton()
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.black)
                }
            } else {
                ForEach(viewModel.threads) { thread in
                    NavigationLink {
                        DanbooruDmailThreadView(
                            thread: thread,
                            viewModel: viewModel,
                            configuration: appModel.configuration,
                            canReply: viewModel.replyTarget(for: thread) != nil,
                            onReply: { replyThread = thread },
                            onOpenRoute: { selectedRoute = $0 }
                        )
                    } label: {
                        DanbooruEdgeRow {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(thread.displaySubject)
                                    .font(.system(size: 17, weight: .semibold, design: .default))
                                participantRow(for: thread)
                                if let body = thread.latestMessage.body, !body.isEmpty {
                                    Text(body)
                                        .font(.system(size: 13, weight: .regular, design: .default))
                                        .lineLimit(2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.black)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(item: $selectedRoute) { route in
            DanbooruNavigationDestination(route: route)
        }
        .overlay {
            if !viewModel.isLoading && viewModel.threads.isEmpty {
                ContentUnavailableView(
                    "No DMail",
                    systemImage: "tray",
                    description: Text("Your inbox is empty.")
                )
            }
        }
        .refreshable {
            await viewModel.reload(using: appModel.configuration)
        }
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                DanbooruErrorBanner(message: errorMessage)
            }
        }
        .sheet(item: $replyThread) { thread in
            DanbooruDmailReplySheet(thread: thread, viewModel: viewModel, configuration: appModel.configuration)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func loadInbox() async {
        await viewModel.reload(using: appModel.configuration)
    }

    @ViewBuilder
    private func participantRow(for thread: DanbooruDmailThread) -> some View {
        if viewModel.participants(for: thread).isEmpty {
            Text(viewModel.participantSummary(for: thread))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.participants(for: thread), id: \.id) { participant in
                        DanbooruUserLink(
                            userID: participant.id,
                            username: participant.name
                        ) { target in
                            selectedRoute = .profile(target)
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DanbooruDmailThreadView: View {
    let thread: DanbooruDmailThread
    @ObservedObject var viewModel: DanbooruInboxViewModel
    let configuration: DanbooruClientConfiguration?
    let canReply: Bool
    let onReply: () -> Void
    let onOpenRoute: (DanbooruNavigationRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DanbooruCompactSectionHeader(title: thread.displaySubject)

                ForEach(thread.messages) { message in
                    DanbooruEdgeRow(compactVerticalPadding: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle")
                                DanbooruUserLink(
                                    userID: message.fromID,
                                    username: viewModel.displayName(
                                        for: message.fromID,
                                        fallback: message.fromName,
                                        placeholder: "Unknown"
                                    )
                                ) { target in
                                    onOpenRoute(.profile(target))
                                }
                                if let createdAt = message.createdAt {
                                    Label(createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                            if let body = message.body, !body.isEmpty {
                                DanbooruDTextView(
                                    text: body,
                                    uiFont: .systemFont(ofSize: 15),
                                    foregroundColor: .white,
                                    baseURL: configuration?.baseURL
                                ) { action in
                                    let result = DanbooruActionRouter.routingResult(for: action, baseURL: configuration?.baseURL)
                                    if let route = result.route {
                                        onOpenRoute(route)
                                    }
                                }
                            } else {
                                Text("No message body.")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canReply {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reply", action: onReply)
                }
            }
        }
    }
}

private struct DanbooruDmailReplySheet: View {
    let thread: DanbooruDmailThread
    @ObservedObject var viewModel: DanbooruInboxViewModel
    let configuration: DanbooruClientConfiguration?

    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var includeQuote = true

    private var replyTarget: DanbooruDmailReplyTarget? {
        viewModel.replyTarget(for: thread)
    }

    private var canSend: Bool {
        !viewModel.isSendingReply && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && replyTarget != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let replyTarget {
                        VStack(alignment: .leading, spacing: 0) {
                            DanbooruEdgeRow(compactVerticalPadding: 12) {
                                HStack {
                                    NativePill(
                                        title: replyTarget.recipientName ?? "User #\(replyTarget.recipientID ?? 0)",
                                        fill: NativeAppTheme.chrome.opacity(0.42),
                                        foreground: .white
                                    )
                                    Spacer()
                                    Text(replyTarget.subject)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(NativeAppTheme.secondaryText)
                                }
                            }

                            DanbooruEdgeRow(compactVerticalPadding: 12) {
                                Toggle("Include quoted message", isOn: $includeQuote)
                                    .font(.system(size: 14, weight: .medium))
                                    .tint(.orange)
                            }

                            DanbooruEdgeRow(compactVerticalPadding: 12) {
                                TextEditor(text: $bodyText)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 2)
                                    .overlay(alignment: .topLeading) {
                                        if bodyText.isEmpty {
                                            Text("Write your reply")
                                                .font(.system(size: 15))
                                                .foregroundStyle(NativeAppTheme.tertiaryText)
                                                .padding(.top, 8)
                                                .allowsHitTesting(false)
                                        }
                                    }
                            }

                            if includeQuote {
                                DanbooruEdgeRow(compactVerticalPadding: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Quoted message")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(NativeAppTheme.secondaryText)
                                        DanbooruDTextView(
                                            text: replyTarget.quotedBody,
                                            uiFont: .systemFont(ofSize: 14),
                                            foregroundColor: .secondaryLabel,
                                            baseURL: configuration?.baseURL,
                                            onAction: { _ in }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                    } else {
                        ContentUnavailableView(
                            "Reply Unavailable",
                            systemImage: "arrowshape.turn.up.left",
                            description: Text("This conversation doesn't have a valid recipient.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(NativeAppTheme.background)
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            let didSend = await viewModel.sendReply(
                                body: bodyText,
                                in: thread,
                                includeQuote: includeQuote,
                                using: configuration
                            )
                            if didSend {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSend)
                }
            }
        }
        .presentationBackground(NativeAppTheme.background)
    }
}
