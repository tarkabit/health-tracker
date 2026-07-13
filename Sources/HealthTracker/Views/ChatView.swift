import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Conversational logging surface. Talk naturally ("ran an easy 5k this morning, felt good"
/// or "how have my headaches been this month?"); the assistant records against the right
/// habit or answers from your data.
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var showImporter = false
    @State private var dropTargeted = false

    private let examples = [
        "Easy 5k run this morning, legs felt good",
        "Headache around 3pm, took 1 tablet",
        "Clean breakfast and lunch, had protein and water",
        "How do my runs this week compare to last week?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !vm.isAvailable { setupBanner }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.messages.isEmpty { emptyState }
                        ForEach(vm.messages) { msg in
                            MessageRow(message: msg) { vm.undo(msg) }
                                .id(msg.id)
                        }
                        if vm.isWorking {
                            ThinkingRow().id("__working__")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: vm.messages.count) { scrollToEnd(proxy) }
                .onChange(of: vm.isWorking) { scrollToEnd(proxy) }
                .overlay { if dropTargeted { dropHighlight } }
                .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted, perform: handleDrop)
            }

            Divider()
            inputBar
        }
        .navigationTitle("Assistant")
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { urls.forEach { vm.attach(contentsOf: $0) } }
        }
    }

    // MARK: Input

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !vm.pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.pendingImages, id: \.self) { url in
                            PendingThumb(url: url) { vm.removePending(url) }
                        }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button { showImporter = true } label: {
                    Image(systemName: "paperclip").font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Attach a screenshot")
                .disabled(vm.isWorking)

                Button { _ = vm.attachFromClipboard() } label: {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Paste image from clipboard")
                .disabled(vm.isWorking)

                TextField("Tell me what happened, attach a run screenshot, or ask about your data…",
                          text: $vm.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .focused($inputFocused)
                    .onSubmit(submit)
                    .disabled(vm.isWorking)

                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? Color.accentColor : .secondary)
                .disabled(!canSend)
                .help("Send")
            }
        }
        .padding(12)
    }

    private var canSend: Bool {
        guard !vm.isWorking else { return false }
        return !vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.pendingImages.isEmpty
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
            .background(Color.accentColor.opacity(0.06))
            .padding(8)
            .allowsHitTesting(false)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, isImageURL(url) else { return }
                    Task { @MainActor in vm.attach(contentsOf: url) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    Task { @MainActor in vm.attach(data: data) }
                }
            }
        }
        return handled
    }

    private func isImageURL(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .image) ?? false
    }

    private func submit() {
        guard canSend else { return }
        Task { await vm.send() }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text("Log by chatting")
                    .font(.title3.weight(.semibold))
            }
            Text("Describe what happened and I'll record it against the right habit. Ask a question and I'll answer from your data.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examples, id: \.self) { ex in
                    Button {
                        vm.input = ex
                        inputFocused = true
                    } label: {
                        Text(ex)
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: 520, alignment: .leading)
    }

    // MARK: Setup banner (claude not found)

    private var setupBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Code not found")
                    .font(.callout.weight(.semibold))
                Text("Install Claude Code and sign in once with your subscription (`claude` in Terminal). The assistant uses your plan — no API key needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if vm.isWorking {
                proxy.scrollTo("__working__", anchor: .bottom)
            } else if let last = vm.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: ChatViewModel.Message
    let onUndo: () -> Void

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 6) {
                    if !message.images.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(message.images, id: \.self) { SentThumb(url: $0) }
                        }
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Color.accentColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                    }
                }
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: message.isError ? "exclamationmark.bubble" : "sparkles")
                    .foregroundStyle(message.isError ? .orange : Color.accentColor)
                    .frame(width: 18)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 8) {
                    Group {
                        if message.isError {
                            Text(message.text).foregroundStyle(.secondary)
                        } else {
                            MarkdownView(text: message.text).textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                    if !message.changes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(message.changes) { change in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("\(change.habitName): \(change.summary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if message.undoSnapshot != nil {
                                Button("Undo", role: .destructive, action: onUndo)
                                    .controlSize(.small)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Thinking indicator

private struct ThinkingRow: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(.secondary)
                        .opacity(pulse ? 0.3 : 1)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: pulse)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 40)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Thumbnails

/// A staged attachment shown above the input, with a remove button.
private struct PendingThumb: View {
    let url: URL
    let onRemove: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThumbImage(url: url, side: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(2)
        }
    }
}

/// An image thumbnail inside a sent user message.
private struct SentThumb: View {
    let url: URL
    var body: some View {
        ThumbImage(url: url, side: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ThumbImage: View {
    let url: URL
    let side: CGFloat
    var body: some View {
        if let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: side, height: side)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }
}
