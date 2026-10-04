// Lumeo — Sources/Features/Chats/ChatView.swift
// Чаты: только Personal 1-1 и Group (Squad). Текст/фото/видео/GIF/voice,
// реакции (6 базовых + расширяемые), reply/forward/pin/edit/delete/search,
// typing (WS), read receipts (1 галка — доставлено, 2 — прочитано,
// в группе — «Кто посмотрел»), E2EE badge («🔒 E2EE»).
// E2EE: в сеть уходит ciphertext, см. Services/E2EEngine.swift.

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - ChatThread (preview-модель списка)

struct ChatThread: Identifiable, Hashable {
    var id: UUID
    var title: String
    var kind: ChatKind
    var lastMessage: String
    var unread: Int
    var isPinned: Bool
    var isMuted: Bool
    var lastDate: Date = .now
}

// MARK: - ChatListView

struct ChatListView: View {
    @Environment(ThemeManager.self) private var theme
    @State private var threads: [ChatThread] = [
        ChatThread(id: UUID(), title: "Neo", kind: .personal, lastMessage: "Го в 21:00?", unread: 2, isPinned: true, isMuted: false),
        ChatThread(id: UUID(), title: "Night Owls", kind: .squad, lastMessage: "Mira: собрались 4/5", unread: 5, isPinned: false, isMuted: false),
        ChatThread(id: UUID(), title: "Kate", kind: .personal, lastMessage: "✓✓ скинула скрин", unread: 0, isPinned: false, isMuted: true),
    ]
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(visible) { thread in
                NavigationLink {
                    ChatView(thread: thread)
                } label: {
                    ChatThreadRow(thread: thread)
                }
                .listRowBackground(theme.current.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        togglePin(thread)
                    } label: {
                        Label(String(localized: "chats.pin"), systemImage: "pin")
                    }
                    .tint(theme.current.secondary)
                    Button {
                        toggleMute(thread)
                    } label: {
                        Label(String(localized: "chats.mute"), systemImage: thread.isMuted ? "bell" : "bell.slash")
                    }
                    .tint(theme.current.warning)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        markRead(thread)
                    } label: {
                        Label(String(localized: "chats.read"), systemImage: "envelope.open")
                    }
                    .tint(theme.current.success)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "tab.chats"))
            .searchable(text: $query, prompt: String(localized: "chats.search"))
            .refreshable {
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }

    private var visible: [ChatThread] {
        let sorted = threads.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.lastDate > $1.lastDate
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.lastMessage.localizedCaseInsensitiveContains(query) }
    }

    private func togglePin(_ thread: ChatThread) {
        guard let i = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        Haptics.selection()
        threads[i].isPinned.toggle()
    }

    private func toggleMute(_ thread: ChatThread) {
        guard let i = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        Haptics.selection()
        threads[i].isMuted.toggle()
    }

    private func markRead(_ thread: ChatThread) {
        guard let i = threads.firstIndex(where: { $0.id == thread.id }) else { return }
        Haptics.selection()
        threads[i].unread = 0
    }
}

// MARK: - ChatThreadRow

struct ChatThreadRow: View {
    @Environment(ThemeManager.self) private var theme
    var thread: ChatThread

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.current.surfaceSecondary)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: thread.kind == .squad ? "person.3.fill" : "person.fill")
                        .foregroundStyle(theme.current.textSecondary)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(thread.title)
                        .font(.headline)
                        .foregroundStyle(theme.current.text)
                    if thread.isPinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(theme.current.secondary)
                            .accessibilityLabel(String(localized: "chats.pin"))
                    }
                    if thread.isMuted {
                        Image(systemName: "bell.slash").font(.caption2).foregroundStyle(theme.current.textSecondary)
                            .accessibilityLabel(String(localized: "chats.mute"))
                    }
                }
                Text(thread.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(thread.lastDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(theme.current.textSecondary)
                if thread.unread > 0 {
                    Text("\(thread.unread)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(thread.isMuted ? Color.gray : theme.current.primary, in: .circle)
                        .accessibilityLabel("\(thread.unread)")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(thread.lastMessage)")
    }
}

// MARK: - ChatView

struct ChatView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(WebSocketService.self) private var socket
    var thread: ChatThread
    @State private var messages: [ChatMessage] = ChatView.previewMessages
    @State private var draft = ""
    @State private var threadQuery = ""
    @State private var activeSession: GameSession?
    @State private var typingNames: [String] = ["Mira"]
    @State private var replyTo: ChatMessage?
    @State private var editing: ChatMessage?
    @State private var editText = ""
    @State private var pinnedIDs: Set<UUID> = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var forwardMessage: ChatMessage?
    @State private var deleteCandidate: ChatMessage?
    @State private var showReactionsFor: ChatMessage?
    @State private var customReactions: [String] = ["🎉", "😂", "😮"]

    var body: some View {
        VStack(spacing: 0) {
            E2EEBadge()
            if let pinned = pinnedMessage {
                PinnedBanner(text: pinned.text ?? String(localized: "chats.attachment")) {
                    pinnedIDs.remove(pinned.id)
                }
            }
            // Баннер активной Session в чате (x/y игроков, Войти/Выйти, таймер).
            if let session = activeSession {
                SessionBanner(session: session, isJoined: true, onJoin: {}, onLeave: { activeSession = nil })
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sections, id: \.day) { section in
                            DateSeparator(day: section.day)
                            ForEach(section.items) { message in
                                if !message.isDeleted || true {
                                    MessageBubble(
                                        message: message,
                                        isMine: message.senderID == PreviewData.me.id,
                                        threadKind: thread.kind,
                                        onReply: { replyTo = message },
                                        onForward: { forwardMessage = message },
                                        onPin: { togglePin(message) },
                                        onEdit: { editing = message; editText = message.text ?? "" },
                                        onDelete: { deleteCandidate = message },
                                        onReact: { emoji in toggleReaction(emoji, on: message) },
                                        onMoreReactions: { showReactionsFor = message }
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        if !typingNames.isEmpty {
                            TypingIndicator(names: typingNames)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = filteredMessages.last {
                        withAnimation(theme.animation()) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            ComposerView(
                draft: $draft,
                replyTo: $replyTo,
                pickerItems: $pickerItems,
                onSend: sendText,
                onSendVoice: sendVoice,
                onAttach: handlePickedItems
            )
        }
        .background(theme.current.background)
        .navigationTitle(thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $threadQuery, prompt: String(localized: "chats.search.thread"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    activeSession = PreviewData.session
                } label: {
                    Image(systemName: "gamecontroller")
                }
                .tint(theme.current.primary)
                .accessibilityLabel(String(localized: "session.create"))
            }
        }
        .onChange(of: pickerItems) { _, _ in
            handlePickedItems()
        }
        .onChange(of: socket.lastEvent) { _, event in
            handleSocket(event)
        }
        .onChange(of: draft) { _, new in
            // Typing-индикатор (WS): дебаунс 1.5с.
            Task {
                await socket.sendTyping(chatID: thread.id, isTyping: !new.isEmpty)
                try? await Task.sleep(for: .seconds(1.5))
                if draft == new {
                    await socket.sendTyping(chatID: thread.id, isTyping: false)
                }
            }
        }
        .alert(String(localized: "chats.edit"), isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField(String(localized: "chats.message"), text: $editText)
            Button(String(localized: "common.save")) { applyEdit() }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(String(localized: "chats.delete.confirm"), isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
            Button(String(localized: "chats.delete"), role: .destructive) { applyDelete() }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
        .sheet(item: $forwardMessage) { message in
            ForwardSheet(message: message) { _ in
                Haptics.success()
            }
        }
        .sheet(item: $showReactionsFor) { message in
            ReactionPickerSheet(custom: $customReactions) { emoji in
                toggleReaction(emoji, on: message)
            }
        }
    }

    // MARK: Sections (даты)

    private struct DaySection {
        var day: Date
        var items: [ChatMessage]
    }

    private var filteredMessages: [ChatMessage] {
        guard !threadQuery.isEmpty else { return messages }
        return messages.filter { $0.text?.localizedCaseInsensitiveContains(threadQuery) ?? false }
    }

    private var sections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredMessages) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted().map { day in
            DaySection(day: day, items: (grouped[day] ?? []).sorted { $0.createdAt < $1.createdAt })
        }
    }

    private var pinnedMessage: ChatMessage? {
        messages.first(where: { pinnedIDs.contains($0.id) })
    }

    // MARK: Mutations

    private func sendText() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Haptics.messageSent()
        let message = ChatMessage(
            id: UUID(), chatID: thread.id, senderID: PreviewData.me.id,
            text: text, attachment: nil, replyToID: replyTo?.id,
            createdAt: .now, editedAt: nil, isDeleted: false, readByIDs: [], reactions: [:]
        )
        messages.append(message)
        draft = ""
        replyTo = nil
        // TODO(e2ee): encryptText → MessageMetadata → APIClient.sendCiphertext + socket.send.
    }

    private func sendVoice(duration: Double, waveform: [Float]) {
        Haptics.messageSent()
        let attachment = ChatAttachment(id: UUID(), kind: .voice, remoteURL: nil, durationSeconds: duration, sizeBytes: Int(duration * 4000), waveform: waveform)
        messages.append(ChatMessage(id: UUID(), chatID: thread.id, senderID: PreviewData.me.id, text: nil, attachment: attachment, replyToID: nil, createdAt: .now, editedAt: nil, isDeleted: false, readByIDs: [], reactions: [:]))
    }

    private func handlePickedItems() {
        guard !pickerItems.isEmpty else { return }
        let items = pickerItems
        pickerItems = []
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let kind: AttachmentKind = item.supportedContentTypes.first?.preferredFilenameExtension == "gif" ? .gif : .photo
                do {
                    try MediaCache.validate(sizeBytes: data.count, kind: kind)
                } catch {
                    Haptics.error()
                    continue
                }
                Haptics.messageSent()
                let attachment = ChatAttachment(id: UUID(), kind: kind, remoteURL: nil, durationSeconds: nil, sizeBytes: data.count, waveform: nil)
                messages.append(ChatMessage(id: UUID(), chatID: thread.id, senderID: PreviewData.me.id, text: nil, attachment: attachment, replyToID: nil, createdAt: .now, editedAt: nil, isDeleted: false, readByIDs: [], reactions: [:]))
            }
        }
    }

    private func togglePin(_ message: ChatMessage) {
        Haptics.selection()
        if pinnedIDs.contains(message.id) { pinnedIDs.remove(message.id) } else { pinnedIDs.insert(message.id) }
    }

    private func applyEdit() {
        guard let editing, !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let i = messages.firstIndex(where: { $0.id == editing.id }) else { editing = nil; return }
        Haptics.selection()
        messages[i].text = editText
        messages[i].editedAt = .now
        // TODO(e2ee): re-encrypt + PATCH через APIClient.editMessage.
        editing = nil
    }

    private func applyDelete() {
        guard let candidate = deleteCandidate,
              let i = messages.firstIndex(where: { $0.id == candidate.id }) else { return }
        Haptics.warning()
        messages[i].isDeleted = true
        messages[i].text = nil
        // TODO(backend): DELETE через APIClient.deleteMessage.
        deleteCandidate = nil
    }

    private func toggleReaction(_ emoji: String, on message: ChatMessage) {
        guard let i = messages.firstIndex(where: { $0.id == message.id }) else { return }
        Haptics.light()
        var list = messages[i].reactions[emoji] ?? []
        if list.contains(PreviewData.me.id) {
            list.removeAll(where: { $0 == PreviewData.me.id })
        } else {
            list.append(PreviewData.me.id)
        }
        if list.isEmpty {
            messages[i].reactions.removeValue(forKey: emoji)
        } else {
            messages[i].reactions[emoji] = list
        }
    }

    private func handleSocket(_ event: WSEvent?) {
        guard let event else { return }
        switch event {
        case .typing(let chatID, _, let name, let isTyping) where chatID == thread.id:
            if isTyping, !typingNames.contains(name) {
                typingNames.append(name)
            } else if !isTyping {
                typingNames.removeAll(where: { $0 == name })
            }
        case .readReceipt(let chatID, let messageID, let readerID) where chatID == thread.id:
            if let i = messages.firstIndex(where: { $0.id == messageID }), !messages[i].readByIDs.contains(readerID) {
                messages[i].readByIDs.append(readerID)
            }
        default:
            break
        }
    }

    // MARK: Preview messages

    static var previewMessages: [ChatMessage] {
        let me = PreviewData.me.id
        let other = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        return [
            ChatMessage(id: UUID(), chatID: UUID(), senderID: other, text: "Собираемся в 21:00?", attachment: nil, replyToID: nil, createdAt: .now.addingTimeInterval(-3600), editedAt: nil, isDeleted: false, readByIDs: [me, other], reactions: ["🔥": [me]]),
            ChatMessage(id: UUID(), chatID: UUID(), senderID: me, text: "Да, я буду", attachment: nil, replyToID: nil, createdAt: .now.addingTimeInterval(-3540), editedAt: nil, isDeleted: false, readByIDs: [other], reactions: [:]),
            ChatMessage(id: UUID(), chatID: UUID(), senderID: other, text: nil, attachment: ChatAttachment(id: UUID(), kind: .voice, remoteURL: nil, durationSeconds: 12, sizeBytes: 48000, waveform: [0.2, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7]), replyToID: nil, createdAt: .now.addingTimeInterval(-120), editedAt: nil, isDeleted: false, readByIDs: [], reactions: [:]),
        ]
    }
}

// MARK: - E2EEBadge

/// Бейдж шифрования: «🔒 E2EE» при подключённом провайдере, иначе dev-метка.
struct E2EEBadge: View {
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(E2EEngine.isAvailable ? "🔒 E2EE" : "🔓 dev")
                .font(.caption.bold())
                .foregroundStyle(E2EEngine.isAvailable ? theme.current.success : theme.current.warning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.current.surface, in: .capsule)
        .padding(.top, 6)
        .accessibilityLabel(E2EEngine.isAvailable ? String(localized: "chats.e2ee.on") : String(localized: "chats.e2ee.off"))
    }
}

// MARK: - PinnedBanner

struct PinnedBanner: View {
    @Environment(ThemeManager.self) private var theme
    var text: String
    var onUnpin: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.fill").font(.caption).foregroundStyle(theme.current.secondary)
            Text(text).font(.caption).foregroundStyle(theme.current.text).lineLimit(1)
            Spacer()
            Button(action: onUnpin) { Image(systemName: "xmark").font(.caption) }
                .foregroundStyle(theme.current.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.current.surfaceSecondary, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}

// MARK: - DateSeparator

struct DateSeparator: View {
    @Environment(ThemeManager.self) private var theme
    var day: Date

    var body: some View {
        Text(day, style: .date)
            .font(.caption2)
            .foregroundStyle(theme.current.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(theme.current.surface, in: .capsule)
    }
}

// MARK: - MessageBubble

/// Пузырь: текст / voice с waveform / реакции / reply / read receipts / «Кто посмотрел».
struct MessageBubble: View {
    @Environment(ThemeManager.self) private var theme
    var message: ChatMessage
    var isMine: Bool
    var threadKind: ChatKind = .personal
    var onReply: () -> Void = {}
    var onForward: () -> Void = {}
    var onPin: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}
    var onReact: (String) -> Void = { _ in }
    var onMoreReactions: () -> Void = {}

    @State private var speed: Double = 1

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if message.isDeleted {
                    Text(String(localized: "chats.deleted"))
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(theme.current.textSecondary)
                        .padding(10)
                        .background(theme.current.surface, in: .rect(cornerRadius: 16))
                } else {
                    if message.replyToID != nil {
                        Text(String(localized: "chats.reply.quoted"))
                            .font(.caption)
                            .foregroundStyle(theme.current.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.current.surfaceSecondary, in: .rect(cornerRadius: 8))
                    }
                    if let text = message.text {
                        Text(text)
                            .padding(10)
                            .background(isMine ? theme.current.primary : theme.current.surface, in: .rect(cornerRadius: 16))
                            .foregroundStyle(isMine ? .white : theme.current.text)
                            .contextMenu { messageMenu }
                    }
                    if let attachment = message.attachment {
                        switch attachment.kind {
                        case .voice:
                            VoiceMessageView(attachment: attachment, isMine: isMine)
                                .contextMenu { messageMenu }
                        case .photo, .video, .gif:
                            MediaPlaceholderView(attachment: attachment, isMine: isMine)
                                .contextMenu { messageMenu }
                        }
                    }
                    // Реакции: 6 базовых + расширяемые (словарь emoji → userIDs).
                    if !message.reactions.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(message.reactions.keys.sorted()), id: \.self) { key in
                                Button {
                                    onReact(key)
                                } label: {
                                    Text("\(key) \(message.reactions[key]?.count ?? 0)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(theme.current.surfaceSecondary, in: .capsule)
                                }
                            }
                            Button(action: onMoreReactions) {
                                Image(systemName: "plus.circle").font(.caption)
                                    .foregroundStyle(theme.current.secondary)
                            }
                            .accessibilityLabel(String(localized: "chats.react.more"))
                        }
                    }
                    HStack(spacing: 4) {
                        Text(message.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(theme.current.textSecondary)
                        if message.editedAt != nil {
                            Text("· \(String(localized: "chats.edited"))")
                                .font(.caption2)
                                .foregroundStyle(theme.current.textSecondary)
                        }
                        // Read receipts: 1 галка — доставлено, 2 — прочитано.
                        if isMine {
                            Text(receiptText)
                                .font(.caption2)
                                .foregroundStyle(message.readByIDs.isEmpty ? theme.current.textSecondary : theme.current.secondary)
                                .accessibilityLabel(message.readByIDs.isEmpty ? String(localized: "chats.delivered") : String(localized: "chats.read"))
                        }
                    }
                    // «Кто посмотрел» — в групповом чате.
                    if threadKind == .squad, !message.readByIDs.isEmpty, !isMine {
                        Text("\(String(localized: "chats.viewedBy")): \(message.readByIDs.count)")
                            .font(.caption2)
                            .foregroundStyle(theme.current.textSecondary)
                    }
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.text ?? String(localized: "chats.attachment"))
    }

    private var receiptText: String {
        guard isMine else { return "" }
        return message.readByIDs.isEmpty ? "✓" : "✓✓"
    }

    private var messageMenu: some View {
        Group {
            ForEach(ReactionKind.allCases, id: \.rawValue) { kind in
                Button { onReact(kind.rawValue) } label: { Text(kind.rawValue) }
            }
            Button(action: onMoreReactions) { Label(String(localized: "chats.react.more"), systemImage: "plus") }
            Button(action: onReply) { Label(String(localized: "chats.reply"), systemImage: "arrowshape.turn.up.left") }
            Button(action: onForward) { Label(String(localized: "chats.forward"), systemImage: "arrowshape.turn.up.right") }
            Button(action: onPin) { Label(String(localized: "chats.pin"), systemImage: "pin") }
            if isMine {
                Button(action: onEdit) { Label(String(localized: "chats.edit"), systemImage: "pencil") }
                Button(role: .destructive, action: onDelete) { Label(String(localized: "chats.delete"), systemImage: "trash") }
            }
        }
    }
}

// MARK: - MediaPlaceholderView

/// Фото/видео/GIF превью (заглушка: thumbnail через MediaCache, полноэкранно — Фаза B).
struct MediaPlaceholderView: View {
    @Environment(ThemeManager.self) private var theme
    var attachment: ChatAttachment
    var isMine: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill((isMine ? theme.current.primary.opacity(0.85) : theme.current.surfaceSecondary))
            .frame(width: 200, height: 140)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: attachment.kind == .video ? "play.circle.fill" : attachment.kind == .gif ? "photo.stack.fill" : "photo.fill")
                        .font(.title)
                        .foregroundStyle(isMine ? .white : theme.current.secondary)
                    Text(attachment.kind.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(isMine ? .white.opacity(0.9) : theme.current.textSecondary)
                }
            }
            .accessibilityLabel("\(String(localized: "chats.attachment")): \(attachment.kind.rawValue)")
    }
}

// MARK: - VoiceMessageView

/// Voice: play, waveform (Canvas), длительность, скорость 1x/1.5x/2x.
struct VoiceMessageView: View {
    @Environment(ThemeManager.self) private var theme
    var attachment: ChatAttachment
    var isMine: Bool
    @State private var speed: Double = 1
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.selection()
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(isMine ? .white : theme.current.primary)
            }
            .accessibilityLabel(isPlaying ? String(localized: "voice.pause") : String(localized: "voice.play"))
            // Waveform через Canvas (амплитуды 0...1).
            Canvas { context, size in
                let bars = attachment.waveform ?? Array(repeating: 0.4, count: 16)
                let gap: CGFloat = 2
                let width = (size.width - CGFloat(bars.count - 1) * gap) / CGFloat(bars.count)
                for (i, amp) in bars.enumerated() {
                    let height = max(4, CGFloat(amp) * size.height)
                    let rect = CGRect(x: CGFloat(i) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color((isMine ? Color.white : theme.current.secondary).opacity(0.85)))
                }
            }
            .frame(width: 110, height: 32)
            .accessibilityHidden(true)
            Text("0:\(String(format: "%02d", Int(attachment.durationSeconds ?? 0)))")
                .font(.caption)
                .foregroundStyle(isMine ? .white : theme.current.textSecondary)
            Button {
                Haptics.selection()
                speed = speed == 1 ? 1.5 : speed == 1.5 ? 2 : 1
            } label: {
                Text("\(speed, specifier: "%g")x")
                    .font(.caption.bold())
                    .foregroundStyle(isMine ? .white : theme.current.secondary)
            }
            .accessibilityLabel("\(String(localized: "voice.speed")): \(speed, specifier: "%g")x")
        }
        .padding(10)
        .background(isMine ? theme.current.primary : theme.current.surface, in: .rect(cornerRadius: 16))
    }
}

// MARK: - VoiceMessagePlaceholder (legacy alias)

/// Voice-заглушка: play, waveform, скорость. Реальная запись — AVFoundation, Фаза B.
struct VoiceMessagePlaceholder: View {
    var attachment: ChatAttachment
    var isMine: Bool

    var body: some View {
        VoiceMessageView(attachment: attachment, isMine: isMine)
    }
}

// MARK: - ComposerView

/// Композер: текст + фото/видео/GIF (PhotosUI) + voice-кнопка
/// (зажал — запись, отпустил — отправить, вверх — lock, влево — cancel).
struct ComposerView: View {
    @Environment(ThemeManager.self) private var theme
    @Binding var draft: String
    @Binding var replyTo: ChatMessage?
    @Binding var pickerItems: [PhotosPickerItem]
    var onSend: () -> Void
    var onSendVoice: (Double, [Float]) -> Void
    var onAttach: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            if let reply = replyTo {
                HStack {
                    Text("\(String(localized: "chats.reply")): \(reply.text ?? String(localized: "chats.attachment"))")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button { replyTo = nil } label: { Image(systemName: "xmark").font(.caption) }
                        .foregroundStyle(theme.current.textSecondary)
                }
                .padding(.horizontal)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.current.secondary)
                }
                .accessibilityLabel(String(localized: "chats.attach"))
                TextField(String(localized: "chats.message"), text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VoiceRecordButton(onSend: onSendVoice)
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.current.primary)
                    }
                    .accessibilityLabel(String(localized: "chats.send"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(theme.current.surface)
        }
    }
}

// MARK: - VoiceRecordButton

/// Voice-кнопка: зажал — запись, отпустил — отправить, свайп вверх — lock, влево — cancel.
/// Stub-запись: таймер + синтетическая waveform; реальный AVAudioRecorder — Фаза B.
struct VoiceRecordButton: View {
    @Environment(ThemeManager.self) private var theme
    var onSend: (Double, [Float]) -> Void
    @State private var isRecording = false
    @State private var isLocked = false
    @State private var duration: Double = 0
    @State private var amplitudes: [Float] = []
    @State private var dragOffset: CGSize = .zero
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            if isRecording || isLocked {
                recordingBar
            }
            Image(systemName: (isRecording || isLocked) ? "stop.circle.fill" : "mic.fill")
                .font(.title2)
                .foregroundStyle((isRecording || isLocked) ? theme.current.danger : theme.current.primary)
                .gesture(recordGesture)
                .accessibilityLabel(String(localized: "voice.record"))
                .accessibilityHint(String(localized: "voice.record.hint"))
        }
    }

    private var recordingBar: some View {
        HStack(spacing: 8) {
            Circle().fill(theme.current.danger).frame(width: 8, height: 8)
            Text(formatted(duration))
                .font(.caption)
                .foregroundStyle(theme.current.text)
            Canvas { context, size in
                let gap: CGFloat = 2
                let width = (size.width - CGFloat(max(amplitudes.count - 1, 0)) * gap) / CGFloat(max(amplitudes.count, 1))
                for (i, amp) in amplitudes.enumerated() {
                    let height = max(3, CGFloat(amp) * size.height)
                    let rect = CGRect(x: CGFloat(i) * (width + gap), y: (size.height - height) / 2, width: width, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(theme.current.danger.opacity(0.9)))
                }
            }
            .frame(width: 90, height: 24)
            if isLocked {
                Button {
                    finish(send: true)
                } label: { Image(systemName: "arrow.up.circle.fill") }
                    .foregroundStyle(theme.current.primary)
                    .accessibilityLabel(String(localized: "chats.send"))
                Button {
                    finish(send: false)
                } label: { Image(systemName: "trash") }
                    .foregroundStyle(theme.current.danger)
                    .accessibilityLabel(String(localized: "chats.delete"))
            } else {
                Text(dragOffset.height < -50 ? "🔒" : dragOffset.width < -60 ? "✕" : "← · ↑")
                    .font(.caption)
                    .foregroundStyle(theme.current.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.current.surfaceSecondary, in: .capsule)
        .offset(x: -140)
    }

    private var recordGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if !isRecording && !isLocked {
                        start()
                    }
                    if let drag {
                        dragOffset = drag.translation
                        if drag.translation.height < -60 {
                            isLocked = true
                            Haptics.medium()
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag):
                    if isLocked {
                        dragOffset = .zero
                        return
                    }
                    if let drag, drag.translation.width < -60 {
                        finish(send: false) // влево — cancel
                    } else {
                        finish(send: true) // отпустил — отправить
                    }
                default:
                    if !isLocked { finish(send: false) }
                }
            }
    }

    private func start() {
        Haptics.voiceStart()
        isRecording = true
        duration = 0
        amplitudes = []
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            duration += 0.15
            amplitudes.append(Float.random(in: 0.15...0.95))
            if amplitudes.count > 40 { amplitudes.removeFirst() }
        }
    }

    private func finish(send: Bool) {
        timer?.invalidate()
        timer = nil
        Haptics.voiceStop()
        let result = (duration, amplitudes)
        isRecording = false
        isLocked = false
        dragOffset = .zero
        if send, result.0 >= 0.5 {
            onSend(result.0, result.1)
        }
    }

    private func formatted(_ seconds: Double) -> String {
        "0:\(String(format: "%02d", Int(seconds)))"
    }
}

// MARK: - TypingIndicator

struct TypingIndicator: View {
    @Environment(ThemeManager.self) private var theme
    var names: [String]

    var body: some View {
        HStack {
            Text("\(names.joined(separator: ", ")) \(String(localized: "chats.typing"))…")
                .font(.caption)
                .foregroundStyle(theme.current.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.current.surface, in: .capsule)
            Spacer()
        }
        .accessibilityLabel("\(names.joined(separator: ", ")) \(String(localized: "chats.typing"))")
    }
}

// MARK: - ForwardSheet

/// Пересылка сообщения: выбор треда (stub-список превью).
struct ForwardSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    var message: ChatMessage
    var onForward: (ChatThread) -> Void

    private let threads = [
        ChatThread(id: UUID(), title: "Neo", kind: .personal, lastMessage: "", unread: 0, isPinned: false, isMuted: false),
        ChatThread(id: UUID(), title: "Night Owls", kind: .squad, lastMessage: "", unread: 0, isPinned: false, isMuted: false),
    ]

    var body: some View {
        NavigationStack {
            List(threads) { thread in
                Button {
                    onForward(thread)
                    dismiss()
                } label: {
                    Text(thread.title).foregroundStyle(theme.current.text)
                }
                .listRowBackground(theme.current.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.current.background)
            .navigationTitle(String(localized: "chats.forward"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
            }
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
    }
}

// MARK: - ReactionPickerSheet

/// Расширенные реакции: 6 базовых + кастомные + добавление своей.
struct ReactionPickerSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Binding var custom: [String]
    var onPick: (String) -> Void
    @State private var newEmoji = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(ReactionKind.allCases, id: \.rawValue) { kind in
                        Button {
                            onPick(kind.rawValue)
                            dismiss()
                        } label: {
                            Text(kind.rawValue).font(.largeTitle)
                        }
                    }
                    ForEach(custom, id: \.self) { emoji in
                        Button {
                            onPick(emoji)
                            dismiss()
                        } label: {
                            Text(emoji).font(.largeTitle)
                        }
                    }
                }
                HStack {
                    TextField("😀", text: $newEmoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Button(String(localized: "chats.react.add")) {
                        let emoji = newEmoji.trimmingCharacters(in: .whitespaces)
                        guard !emoji.isEmpty, !custom.contains(emoji) else { return }
                        custom.append(emoji)
                        newEmoji = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.current.primary)
                }
                Spacer()
            }
            .padding()
            .background(theme.current.background)
            .navigationTitle(String(localized: "chats.react.more"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
        .tint(theme.current.primary)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        ChatView(thread: ChatThread(id: UUID(), title: "Night Owls", kind: .squad, lastMessage: "", unread: 0, isPinned: false, isMuted: false))
    }
    .environment(ThemeManager())
    .environment(WebSocketService())
    .preferredColorScheme(.dark)
}

#Preview("List") {
    ChatListView()
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}
