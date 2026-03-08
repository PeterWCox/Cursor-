import SwiftUI
import AppKit

final class PasteAwareTextView: NSTextView {
    var onPasteImage: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandV = modifiers.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "v"

        if isCommandV {
            let pasteboard = NSPasteboard.general
            if onPasteImage != nil, SubmittableTextEditor.imageFromPasteboard(pasteboard) != nil {
                onPasteImage?()
                return true
            }
            if let string = pasteboard.string(forType: .string), !string.isEmpty {
                insertText(string, replacementRange: selectedRange())
                return true
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        if onPasteImage != nil, SubmittableTextEditor.imageFromPasteboard(.general) != nil {
            onPasteImage?()
            return
        }
        super.paste(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        if onPasteImage != nil, SubmittableTextEditor.imageFromPasteboard(.general) != nil {
            onPasteImage?()
            return
        }
        super.pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        if onPasteImage != nil, SubmittableTextEditor.imageFromPasteboard(.general) != nil {
            onPasteImage?()
            return
        }
        super.pasteAsRichText(sender)
    }
}

struct SubmittableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isDisabled: Bool
    var onSubmit: () -> Void
    var onPasteImage: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.onPasteImage = onPasteImage
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = !isDisabled
        (textView as? PasteAwareTextView)?.onPasteImage = onPasteImage
    }

    /// Extracts an image from the pasteboard using multiple methods (NSImage, file URL, raw PNG/TIFF).
    static func imageFromPasteboard(_ pasteboard: NSPasteboard) -> NSImage? {
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            return image
        }
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            return image
        }
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SubmittableTextEditor
        weak var textView: NSTextView?

        init(_ parent: SubmittableTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            }
            return false
        }
    }
}

private let availableModels: [(id: String, label: String)] = [
    ("composer-1.5", "Composer 1.5"),
    ("composer-1", "Composer 1"),
    ("auto", "Auto"),
    ("opus-4.6-thinking", "Claude 4.6 Opus (Thinking)"),
    ("sonnet-4.6-thinking", "Claude 4.6 Sonnet (Thinking)"),
    ("sonnet-4.6", "Claude 4.6 Sonnet"),
    ("gpt-5.4-high", "GPT-5.4 High"),
    ("gpt-5.4-medium", "GPT-5.4"),
    ("gemini-3.1-pro", "Gemini 3.1 Pro"),
]

struct PopoutView: View {
    @EnvironmentObject var appState: AppState
    var dismiss: () -> Void = {}
    @AppStorage("workspacePath") private var workspacePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @AppStorage("selectedModel") private var selectedModel: String = "composer-1.5"
    @State private var prompt = ""
    @State private var output = ""
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var hasAttachedScreenshot = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    SubmittableTextEditor(text: $prompt, isDisabled: isRunning, onSubmit: sendPrompt, onPasteImage: pasteScreenshot)
                        .frame(height: 72)
                    Button {
                        pasteScreenshot()
                    } label: {
                        Image(systemName: hasAttachedScreenshot ? "photo.fill" : "photo.badge.plus")
                            .symbolRenderingMode(hasAttachedScreenshot ? .multicolor : .monochrome)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(hasAttachedScreenshot ? .accentColor : .secondary)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .help("Paste screenshot (⌘V or ⌘⇧V)")
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .onChange(of: prompt) { _, newValue in
                    hasAttachedScreenshot = newValue.contains("[Screenshot attached:")
                }
                
                if hasAttachedScreenshot {
                    let imageURL = URL(fileURLWithPath: workspacePath).appendingPathComponent(".cursor", isDirectory: true).appendingPathComponent("pasted-screenshot.png")
                    if let nsImage = NSImage(contentsOf: imageURL) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 660)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                            Button {
                                deleteScreenshot()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 6) {
                    Button(action: { appState.changeWorkspace() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(appState.workspaceDisplayName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.accessoryBar)
                    
                    Menu {
                        ForEach(availableModels, id: \.id) { model in
                            Button {
                                selectedModel = model.id
                            } label: {
                                if model.id == selectedModel {
                                    Label(model.label, systemImage: "checkmark")
                                } else {
                                    Text(model.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(selectedModelLabel)
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                    
                    Button(action: sendPrompt) {
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 50)
                        } else {
                            Label("Send", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
                }
            }
            .padding(12)
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "Response will appear here..." : output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(output.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                        .id("outputEnd")
                }
                .frame(maxHeight: .infinity)
                .onChange(of: output) { _, _ in
                    withAnimation {
                        proxy.scrollTo("outputEnd", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button {
                    (NSApp.delegate as? AppDelegate)?.showSettingsWindow(nil)
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 800)
        .overlay(alignment: .topTrailing) {
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
    
    private var selectedModelLabel: String {
        availableModels.first { $0.id == selectedModel }?.label ?? selectedModel
    }
    
    private func deleteScreenshot() {
        let reference = "\n\n[Screenshot attached: .cursor/pasted-screenshot.png]"
        prompt = prompt.replacingOccurrences(of: reference, with: "")
        hasAttachedScreenshot = false
        let imageURL = URL(fileURLWithPath: workspacePath).appendingPathComponent(".cursor", isDirectory: true).appendingPathComponent("pasted-screenshot.png")
        try? FileManager.default.removeItem(at: imageURL)
    }
    
    private func pasteScreenshot() {
        let pasteboard = NSPasteboard.general
        guard let image = SubmittableTextEditor.imageFromPasteboard(pasteboard) else {
            return
        }
        
        let cursorDir = URL(fileURLWithPath: workspacePath).appendingPathComponent(".cursor", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: cursorDir, withIntermediateDirectories: true)
        } catch {
            return
        }
        
        let destURL = cursorDir.appendingPathComponent("pasted-screenshot.png")
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        do {
            try pngData.write(to: destURL)
            let reference = "\n\n[Screenshot attached: .cursor/pasted-screenshot.png]"
            if !prompt.contains(reference) {
                prompt += reference
            }
            hasAttachedScreenshot = true
        } catch {
            return
        }
    }
    
    private func sendPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        errorMessage = nil
        output = ""
        isRunning = true
        
        Task {
            do {
                let stream = try AgentRunner.stream(prompt: trimmed, workspacePath: workspacePath, model: selectedModel)
                prompt = ""
                hasAttachedScreenshot = false
                for try await chunk in stream {
                    output += chunk
                }
                isRunning = false
            } catch let error as AgentRunnerError {
                errorMessage = error.userMessage
                isRunning = false
            } catch {
                errorMessage = error.localizedDescription
                isRunning = false
            }
        }
    }
}

