import Cocoa
import Carbon

// MARK: - Clipboard History

class ClipboardHistory {
    static let maxItems = 5
    private(set) var items: [String] = []
    private var lastChangeCount: Int
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MrClips")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        lastChangeCount = NSPasteboard.general.changeCount
        load()
    }

    func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard let text = pb.string(forType: .string), !text.isEmpty else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > Self.maxItems { items.removeLast(items.count - Self.maxItems) }
        save()
    }

    func select(_ index: Int) {
        guard index < items.count else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(items[index], forType: .string)
        lastChangeCount = pb.changeCount
    }

    func clear() {
        for i in items.indices {
            items[i] = String(repeating: "\0", count: items[i].utf8.count)
        }
        items.removeAll()
        if FileManager.default.fileExists(atPath: fileURL.path),
           let h = try? FileHandle(forWritingTo: fileURL) {
            let n = h.seekToEndOfFile()
            h.seek(toFileOffset: 0)
            h.write(Data(repeating: 0, count: Int(n)))
            h.synchronizeFile()
            h.closeFile()
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return }
        items = Array(arr.prefix(Self.maxItems))
    }
}

// MARK: - Global Hotkey Callback (C-compatible)

func onHotKey(_: EventHandlerCallRef?, _: EventRef?, _ ctx: UnsafeMutableRawPointer?) -> OSStatus {
    guard let ctx = ctx else { return OSStatus(eventNotHandledErr) }
    let del = Unmanaged<AppDelegate>.fromOpaque(ctx).takeUnretainedValue()
    DispatchQueue.main.async { del.togglePanel() }
    return noErr
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let history = ClipboardHistory()
    var panel: NSPanel!
    var stack: NSStackView!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_: Notification) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.history.poll()
        }
        buildPanel()
        buildStatusItem()
        installHotKey()

        // Hide panel when app loses focus
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.panel.orderOut(nil)
        }
    }

    // MARK: Panel

    func buildPanel() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear

        let bg = NSVisualEffectView()
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.layer?.masksToBounds = true
        panel.contentView = bg

        stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bg.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }
        refreshPanel()
        let mouse = NSEvent.mouseLocation
        // Position centered horizontally on cursor, dropping down below it
        let origin = NSPoint(
            x: mouse.x - panel.frame.width / 2,
            y: mouse.y - panel.frame.height
        )
        panel.setFrameOrigin(clampToScreen(origin))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Keep the panel fully on-screen.
    func clampToScreen(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main?.visibleFrame else { return origin }
        var p = origin
        p.x = max(screen.minX, min(p.x, screen.maxX - panel.frame.width))
        p.y = max(screen.minY, min(p.y, screen.maxY - panel.frame.height))
        return p
    }

    func refreshPanel() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let items = history.items
        if items.isEmpty {
            let lbl = NSTextField(labelWithString: "(empty)")
            lbl.textColor = .secondaryLabelColor
            lbl.alignment = .center
            stack.addArrangedSubview(lbl)
        } else {
            for (i, item) in items.enumerated() {
                let preview = item.replacingOccurrences(of: "\n", with: " ")
                let short = String(preview.prefix(50)) + (preview.count > 50 ? "..." : "")
                let btn = makeButton("\(i + 1). \(short)", action: #selector(pick(_:)))
                btn.tag = i
                stack.addArrangedSubview(btn)
                btn.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true
            }
        }

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)
        sep.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16).isActive = true

        let clr = makeButton("Clear", action: #selector(clearAll))
        clr.contentTintColor = .systemRed
        stack.addArrangedSubview(clr)

        let fit = stack.fittingSize
        panel.setContentSize(NSSize(width: max(280, fit.width + 16), height: fit.height))
    }

    func makeButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.isBordered = false
        b.alignment = .left
        b.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    @objc func pick(_ sender: NSButton) {
        history.select(sender.tag)
        panel.orderOut(nil)
    }

    @objc func clearAll() {
        history.clear()
        panel.orderOut(nil)
    }

    // MARK: Status Bar

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "MrClips"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Show History  \u{2303}\u{2325}V",
            action: #selector(togglePanel),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit MrClips",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // MARK: Global Hotkey (Ctrl+Option+V via Carbon)

    func installHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            onHotKey,
            1,
            &eventType,
            selfPtr,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D52434C), id: 1) // "MRCL"
        var ref: EventHotKeyRef?
        // V = keycode 9, controlKey | optionKey
        let status = RegisterEventHotKey(
            9,
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if status != noErr {
            NSLog("MrClips: failed to register hotkey (status %d)", status)
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
