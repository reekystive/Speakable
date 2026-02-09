import SwiftUI

// MARK: - Speak Text Editor (NSTextView wrapper)

struct SpeakTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var textHeight: CGFloat
  let onSubmit: () -> Void

  private let horizontalInset: CGFloat = 16
  private let topInset: CGFloat = 16
  private let bottomInset: CGFloat = 54

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    scrollView.automaticallyAdjustsContentInsets = false

    let textView = SubmitTextView()
    textView.delegate = context.coordinator
    textView.onSubmit = onSubmit
    textView.isRichText = false
    textView.font = .systemFont(ofSize: 14)
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: horizontalInset, height: topInset)
    textView.textContainer?.lineFragmentPadding = 0
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.autoresizingMask = [.width]

    scrollView.documentView = textView
    context.coordinator.textView = textView
    context.coordinator.horizontalInset = horizontalInset

    // Focus on appear
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      textView.window?.makeFirstResponder(textView)
    }

    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }

    if textView.string != text {
      textView.string = text
      context.coordinator.updateHeight()
    }
  }

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: SpeakTextEditor
    weak var textView: NSTextView?
    var horizontalInset: CGFloat = 16

    init(_ parent: SpeakTextEditor) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
      updateHeight()
    }

    func updateHeight() {
      guard let textView else { return }
      textView.layoutManager?.ensureLayout(for: textView.textContainer!)
      let height = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 20
      let newTextHeight = max(height, 20)

      // Update binding for SwiftUI state
      parent.textHeight = newTextHeight

      // Synchronously resize the window in the same frame as the text layout
      // change, preventing any one-frame jitter from SwiftUI's async state pipeline.
      SpeakWindow.updateFrame(forTextHeight: newTextHeight)
    }
  }
}

// MARK: - Submit Text View (handles Enter key)

final class SubmitTextView: NSTextView {
  var onSubmit: (() -> Void)?

  // Only claim hits inside the actual text content area;
  // padding (textContainerInset) falls through to the window
  // background, enabling drag via isMovableByWindowBackground.
  override func hitTest(_ point: NSPoint) -> NSView? {
    let local = convert(point, from: superview)
    let inset = textContainerInset
    let textRect = NSRect(
      x: inset.width,
      y: inset.height,
      width: bounds.width - inset.width * 2,
      height: bounds.height - inset.height
    )
    guard textRect.contains(local) else { return nil }
    return super.hitTest(point)
  }

  override func keyDown(with event: NSEvent) {
    // Enter key without Shift = submit
    if event.keyCode == 36, !event.modifierFlags.contains(.shift) {
      onSubmit?()
      return
    }
    super.keyDown(with: event)
  }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .popover

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
  }
}

// MARK: - Toolbar Popover Button

struct ToolbarPopoverButton<Content: View>: View {
  let icon: String
  let label: String
  @ViewBuilder let content: () -> Content

  @State private var showPopover = false

  var body: some View {
    Button {
      showPopover.toggle()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 12))
        Text(label)
          .font(.system(size: 12))
      }
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showPopover) {
      content()
    }
  }
}

// MARK: - Standard Close Button

/// Wraps the native macOS traffic-light close button via
/// `NSWindow.standardWindowButton(.closeButton, for: .titled)`.
struct StandardCloseButton: NSViewRepresentable {
  let onClose: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onClose: onClose)
  }

  func makeNSView(context: Context) -> NSView {
    guard let button = NSWindow.standardWindowButton(.closeButton, for: .titled) else {
      return NSView()
    }
    button.target = context.coordinator
    button.action = #selector(Coordinator.performClose)
    return button
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  class Coordinator: NSObject {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
      self.onClose = onClose
    }

    @objc func performClose() {
      onClose()
    }
  }
}

#Preview("StandardCloseButton") {
  StandardCloseButton(onClose: {})
    .frame(width: 14, height: 14)
    .padding()
}
