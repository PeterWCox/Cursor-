import SwiftUI
import AppKit

// MARK: - Full-screen modal to preview screenshot(s) at larger size
// Pair with ScreenshotThumbnailView: parent shows this modal when user taps a thumbnail (same pattern
// in PopoutView, TasksListView for existing tasks and new/edit task draft screenshots).
// Multiple images are shown side by side; optional onDeleteScreenshotAtIndex adds an X on each image to delete.

struct ScreenshotPreviewModal: View {
    /// Multiple saved screenshots (e.g. task with several screenshots). Shown side by side.
    var imageURLs: [URL]? = nil
    /// Initial index when showing imageURLs. Ignored when imageURLs is nil or empty.
    var initialIndex: Int = 0
    /// Single saved screenshot (file URL). Used when previewing one image from PopoutView/conversation.
    var imageURL: URL? = nil
    /// In-memory image (e.g. new or edit task draft). When set, shown instead of loading from URL(s).
    var image: NSImage? = nil
    @Binding var isPresented: Bool
    /// When non-nil, an X is shown in the top-right of each image to delete that screenshot (by index).
    var onDeleteScreenshotAtIndex: ((Int) -> Void)? = nil

    @State private var escapeMonitor: Any? = nil

    private var urls: [URL] {
        if let imageURLs, !imageURLs.isEmpty { return imageURLs }
        if let url = imageURL { return [url] }
        return []
    }

    private var hasMultiple: Bool { urls.count > 1 }

    /// Single in-memory image (draft) or single URL: show one image.
    private var singleDisplayImage: NSImage? {
        if let image { return image }
        guard let url = urls.first else { return nil }
        return ImageAssetCache.shared.screenshot(for: url)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }

                if hasMultiple {
                    // Side-by-side images, each with optional delete X in top-right
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: CursorTheme.spaceL) {
                            ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                                CachedPreviewImageView(url: url) { nsImage in
                                    screenshotImageCell(nsImage: nsImage, index: index)
                                }
                            }
                        }
                        .padding(.horizontal, CursorTheme.spaceL)
                    }
                    .frame(maxWidth: 900, maxHeight: 700)
                } else if let nsImage = singleDisplayImage {
                    // Single image (URL or in-memory draft)
                    screenshotImageCell(nsImage: nsImage, index: 0)
                }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            guard escapeMonitor == nil else { return }
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event } // 53 = Escape
                Task { @MainActor in isPresented = false }
                return nil
            }
        }
        .onDisappear {
            if let monitor = escapeMonitor {
                NSEvent.removeMonitor(monitor)
                escapeMonitor = nil
            }
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    @ViewBuilder
    private func screenshotImageCell(nsImage: NSImage, index: Int) -> some View {
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: hasMultiple ? 440 : 900, maxHeight: hasMultiple ? 500 : 700)
            .fixedSize(horizontal: true, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: CursorTheme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CursorTheme.radiusCard, style: .continuous)
                    .stroke(CursorTheme.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if onDeleteScreenshotAtIndex != nil {
                    Button {
                        onDeleteScreenshotAtIndex?(index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: CursorTheme.fontIconList))
                            .foregroundStyle(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .padding(CursorTheme.spaceS)
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
    }
}

private struct CachedPreviewImageView<Content: View>: View {
    let url: URL
    let content: (NSImage) -> Content

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                content(image)
            }
        }
        .task(id: url.path) {
            image = ImageAssetCache.shared.screenshot(for: url)
        }
    }
}
