// SideQuest Arcade — a floating CrazyGames screen that sits on top of World of Warcraft (or anything else).
// It is a separate always-on-top window, so nothing touches the WoW client. Global hotkeys swap the
// keyboard between the game and WoW without alt-tabbing.
import AppKit
import Carbon.HIToolbox
import WebKit

struct Game { let name: String; let slug: String }

// Curated for a side screen: short sessions, playable small, embeddable on CrazyGames.
// Any other CrazyGames game works through Browse; its page is turned into the game-only view.
let GAMES: [Game] = [
    Game(name: "Lumen", slug: "lumen-vne"),            // ours (Shadow Games): first in the list, first launch
    Game(name: "Smash Karts", slug: "smash-karts"),
    Game(name: "Crazy Roll 3D", slug: "crazy-roll-3d"),
    Game(name: "Ragdoll Archers", slug: "ragdoll-archers"),
    Game(name: "Paper.io 2", slug: "paper-io-2"),
    Game(name: "Helix Jump", slug: "helix-jump"),
    Game(name: "Basketball Stars", slug: "basketball-stars"),
    Game(name: "8 Ball Billiards", slug: "8-ball-billiards-classic"),
    Game(name: "Classic Solitaire", slug: "classic-solitaire"),
]
let HOME = "https://www.crazygames.com/"
let BAR: CGFloat = 30
let SIZES: [CGFloat] = [360, 480, 640, 800]      // window widths; height follows 16:9 + bar
let VIOLET = NSColor(red: 0.486, green: 0.361, blue: 1.0, alpha: 1)

let THEATER = """
(() => {
  const css = `html.sq, html.sq body { overflow: hidden !important; background: #000 !important; }
  html.sq #game-iframe { position: fixed !important; left: 0 !important; top: 0 !important;
    width: 100vw !important; height: 100vh !important; max-width: none !important; max-height: none !important;
    margin: 0 !important; border: 0 !important; transform: none !important; background: #000 !important;
    z-index: 2147483000 !important; }`;
  const fix = () => {
    const f = document.getElementById('game-iframe');
    const root = document.documentElement;
    if (!f) { root.classList.remove('sq'); return; }
    if (!document.getElementById('sq-style')) {
      const s = document.createElement('style'); s.id = 'sq-style'; s.textContent = css;
      (document.head || root).appendChild(s);
    }
    root.classList.add('sq');
    // position:fixed is trapped by any ancestor with a transform/filter/contain; release them.
    for (let p = f.parentElement; p && p !== document.body; p = p.parentElement) {
      const cs = getComputedStyle(p);
      if (cs.transform !== 'none' || cs.filter !== 'none' || cs.contain !== 'none' || cs.containerType !== 'normal')
        p.style.cssText += ';transform:none!important;filter:none!important;contain:none!important;container-type:normal!important';
    }
  };
  setInterval(fix, 500);
  document.addEventListener('DOMContentLoaded', fix);
})();
"""

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class Bar: NSView {
    var playing = false { didSet { needsDisplay = true } }
    override var mouseDownCanMoveWindow: Bool { true }
    override func draw(_ r: NSRect) {
        NSColor(red: 0.035, green: 0.035, blue: 0.043, alpha: 1).setFill()
        bounds.fill()
        (playing ? VIOLET : NSColor(white: 0.25, alpha: 1)).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 2).fill()
    }
}

var appRef: App?

@MainActor
final class App: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    var panel: Panel!
    var web: WKWebView!
    var bar: Bar!
    var picker: NSPopUpButton!
    var hint: NSTextField!
    var muteBtn: NSButton!
    var status: NSStatusItem!
    var lastApp: NSRunningApplication?
    var hotkeys: [EventHotKeyRef?] = []
    let d = UserDefaults.standard

    var muted: Bool { get { d.bool(forKey: "muted") } set { d.set(newValue, forKey: "muted") } }
    var sizeIndex: Int { get { d.object(forKey: "size") as? Int ?? 1 } set { d.set(newValue, forKey: "size") } }
    var side: String { get { d.string(forKey: "side") ?? "right" } set { d.set(newValue, forKey: "side") } }
    var opacity: Double { get { d.object(forKey: "opacity") as? Double ?? 1 } set { d.set(newValue, forKey: "opacity") } }

    func applicationDidFinishLaunching(_ n: Notification) {
        appRef = self
        if let f = NSWorkspace.shared.frontmostApplication, f != .current { lastApp = f }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            guard let a = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  a != .current else { return }
            MainActor.assumeIsolated { self?.lastApp = a }
        }

        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                      styleMask: [.titled, .resizable, .fullSizeContentView, .closable],
                      backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(b)?.isHidden = true }
        panel.isFloatingPanel = true             // (this resets the level, so it goes first)
        panel.level = .statusBar                 // above a windowed-fullscreen game
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.backgroundColor = .black
        panel.minSize = NSSize(width: 280, height: 200)
        panel.alphaValue = opacity
        panel.delegate = self

        let cfg = WKWebViewConfiguration()
        cfg.mediaTypesRequiringUserActionForPlayback = []
        // Theater mode: on a CrazyGames game page, the game's own iframe is blown up to fill the window and
        // the site around it (header, sidebars, ads column, footer) is covered. The game keeps running inside
        // crazygames.com, so its SDK, saves and login behave exactly as on the site.
        cfg.userContentController.addUserScript(WKUserScript(source: THEATER, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        cfg.applicationNameForUserAgent = "Version/18.0 Safari/605.1.15"
        cfg.preferences.isElementFullscreenEnabled = false
        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.underPageBackgroundColor = .black
        // The web view sits below our bar, so it must not inset itself for the (invisible) titlebar.
        let noInsets = NSSelectorFromString("_setAutomaticallyAdjustsContentInsets:")
        if web.responds(to: noInsets) {
            typealias SetBool = @convention(c) (AnyObject, Selector, Bool) -> Void
            unsafeBitCast(web.method(for: noInsets), to: SetBool.self)(web, noInsets, false)
        }

        let root = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
        web.frame = NSRect(x: 0, y: 0, width: 480, height: 300 - BAR)
        web.autoresizingMask = [.width, .height]
        root.addSubview(web)
        buildBar(in: root)
        panel.contentView = root

        if !panel.setFrameUsingName("SideQuestPanel") { dock(side) }
        panel.setFrameAutosaveName("SideQuestPanel")
        panel.orderFrontRegardless()

        buildStatusMenu()
        registerHotkeys()
        applyMute()
        refreshFocusUI()

        // First launch goes straight into a game; afterwards, back to whatever was playing.
        let last = d.string(forKey: "lastURL")
        if let last, let u = URL(string: last) { web.load(URLRequest(url: u)) } else { play(GAMES[0].slug) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }

    // MARK: bar

    func button(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!, target: self, action: action)
        b.isBordered = false
        b.contentTintColor = NSColor(white: 0.85, alpha: 1)
        b.toolTip = tip
        b.imageScaling = .scaleProportionallyDown
        return b
    }

    func buildBar(in root: NSView) {
        bar = Bar(frame: NSRect(x: 0, y: root.bounds.height - BAR, width: root.bounds.width, height: BAR))
        bar.autoresizingMask = [.width, .minYMargin]
        root.addSubview(bar)

        picker = NSPopUpButton(frame: NSRect(x: 6, y: 4, width: 150, height: 22), pullsDown: true)
        picker.controlSize = .small
        picker.font = .systemFont(ofSize: 11, weight: .semibold)
        picker.isBordered = false
        picker.contentTintColor = .white
        picker.addItem(withTitle: "Games")
        for (i, g) in GAMES.enumerated() {
            picker.addItem(withTitle: g.name)
            picker.lastItem?.tag = i
            picker.lastItem?.action = #selector(pickGame(_:))
            picker.lastItem?.target = self
        }
        picker.menu?.addItem(.separator())
        picker.addItem(withTitle: "Browse all CrazyGames…")
        picker.lastItem?.action = #selector(browse)
        picker.lastItem?.target = self
        bar.addSubview(picker)

        var x: CGFloat = 158
        for (sym, tip, sel) in [("house", "Browse CrazyGames", #selector(browse)),
                                ("arrow.clockwise", "Reload (⌃⌥R)", #selector(reload))] {
            let b = button(sym, tip, sel)
            b.frame = NSRect(x: x, y: 6, width: 18, height: 18)
            bar.addSubview(b)
            x += 24
        }

        hint = NSTextField(labelWithString: "")
        hint.font = .systemFont(ofSize: 10, weight: .medium)
        hint.textColor = NSColor(white: 0.6, alpha: 1)
        hint.lineBreakMode = .byTruncatingTail
        hint.frame = NSRect(x: x + 4, y: 8, width: root.bounds.width - x - 4 - 130, height: 14)
        hint.autoresizingMask = [.width]
        bar.addSubview(hint)

        var rx = root.bounds.width - 6
        let right: [(String, String, Selector)] = [
            ("xmark", "Hide (⌃⌥G)", #selector(toggleShown)),
            ("arrow.up.left.and.arrow.down.right", "Size (⌃⌥= / ⌃⌥-)", #selector(cycleSize)),
            ("sidebar.right", "Dock right (⌃⌥→)", #selector(dockRight)),
            ("sidebar.left", "Dock left (⌃⌥←)", #selector(dockLeft)),
            ("speaker.wave.2.fill", "Mute (⌃⌥M)", #selector(toggleMute)),
        ]
        for (sym, tip, sel) in right {
            rx -= 22
            let b = button(sym, tip, sel)
            b.frame = NSRect(x: rx, y: 6, width: 18, height: 18)
            b.autoresizingMask = [.minXMargin]
            bar.addSubview(b)
            if sel == #selector(toggleMute) { muteBtn = b }
        }
    }

    // MARK: games & navigation

    func load(_ s: String) {
        guard let u = URL(string: s) else { return }
        web.load(URLRequest(url: u))
    }

    func play(_ slug: String) { load("https://www.crazygames.com/game/\(slug)") }

    @objc func pickGame(_ item: NSMenuItem) { play(GAMES[item.tag].slug); grabFocus() }
    @objc func browse() { load(HOME); grabFocus() }
    @objc func reload() { web.reload() }

    static func slug(from u: URL) -> String? {
        guard u.host?.hasSuffix("crazygames.com") == true else { return nil }
        let parts = u.path.split(separator: "/")
        guard parts.count >= 2, parts[0] == "game" || parts[0] == "embed" else { return nil }
        return String(parts[1])
    }

    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        if let u = w.url?.absoluteString { d.set(u, forKey: "lastURL") }
        refreshFocusUI()
    }

    // Popups (ads, "open on CrazyGames", login) go to the real browser rather than replacing the game.
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction,
                 windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url {
            if let s = App.slug(from: u) { play(s) } else { NSWorkspace.shared.open(u) }
        }
        return nil
    }

    // MARK: focus — the keyboard goes to the game or to WoW, never both

    var playing: Bool { NSApp.isActive && panel.isKeyWindow }

    func grabFocus() {
        if !panel.isVisible { panel.orderFrontRegardless() }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(web)
        // Many games only listen for keys once their canvas has focus.
        web.evaluateJavaScript("(document.querySelector('iframe,canvas')||document.body).focus&&(document.querySelector('iframe,canvas')||document.body).focus()")
    }

    func giveBack() {
        if let a = lastApp, !a.isTerminated { a.activate() } else { NSApp.hide(nil); panel.orderFrontRegardless() }
    }

    @objc func swapFocus() { playing ? giveBack() : grabFocus() }

    func refreshFocusUI() {
        let on = playing
        bar?.playing = on
        let other = lastApp?.localizedName ?? "your game"
        hint?.stringValue = on ? "PLAYING · ⌃⌥Space → \(other)" : "⌃⌥Space or click to play"
        hint?.textColor = on ? VIOLET.blended(withFraction: 0.35, of: .white) : NSColor(white: 0.55, alpha: 1)
    }

    func windowDidBecomeKey(_ n: Notification) { refreshFocusUI() }
    func windowDidResignKey(_ n: Notification) { refreshFocusUI() }
    func applicationDidBecomeActive(_ n: Notification) { refreshFocusUI() }
    func applicationDidResignActive(_ n: Notification) { refreshFocusUI() }
    func windowShouldClose(_ s: NSWindow) -> Bool { toggleShown(); return false }

    // MARK: layout

    func dock(_ where_: String) {
        side = where_
        let screen = panel.screen ?? NSScreen.main!
        let v = screen.visibleFrame
        let w = min(SIZES[sizeIndex], v.width * 0.6)
        let h = min(w * 9 / 16 + BAR, v.height - 24)
        let x = where_ == "left" ? v.minX + 12 : v.maxX - w - 12
        // Sit a little above centre: WoW's action bars and chat live along the bottom.
        let y = v.minY + (v.height - h) * 0.6
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: true)
    }

    @objc func dockLeft() { dock("left") }
    @objc func dockRight() { dock("right") }
    @objc func cycleSize() { sizeIndex = (sizeIndex + 1) % SIZES.count; dock(side) }
    func resize(_ step: Int) { sizeIndex = max(0, min(SIZES.count - 1, sizeIndex + step)); dock(side) }

    @objc func toggleShown() {
        if panel.isVisible {
            let wasPlaying = playing
            panel.orderOut(nil)
            web.evaluateJavaScript("document.querySelectorAll('video,audio').forEach(m=>m.pause())")
            if wasPlaying { giveBack() }
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc func setOpacity(_ item: NSMenuItem) {
        opacity = Double(item.tag) / 100
        panel.alphaValue = opacity
        rebuildStatusMenu()
    }

    // MARK: sound

    @objc func toggleMute() { muted.toggle(); applyMute(); rebuildStatusMenu() }

    func applyMute() {
        // WKWebView's page-mute switch covers WebAudio inside the game's iframe, which JS cannot reach.
        let sel = NSSelectorFromString("_setPageMuted:")
        if web.responds(to: sel) {
            typealias Fn = @convention(c) (AnyObject, Selector, UInt) -> Void
            unsafeBitCast(web.method(for: sel), to: Fn.self)(web, sel, muted ? 1 : 0)
        }
        muteBtn?.image = NSImage(systemSymbolName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill", accessibilityDescription: "Mute")
        muteBtn?.contentTintColor = muted ? NSColor.systemOrange : NSColor(white: 0.85, alpha: 1)
    }

    // MARK: hotkeys (Carbon: system-wide, no Accessibility permission needed)

    func registerHotkeys() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
            var hk = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            MainActor.assumeIsolated { appRef?.hotkey(id) }
            return noErr
        }, 1, &spec, nil, nil)

        let mods = UInt32(controlKey | optionKey)
        var keys: [(Int, UInt32)] = [
            (kVK_Space, 1), (kVK_ANSI_G, 2), (kVK_LeftArrow, 3), (kVK_RightArrow, 4),
            (kVK_ANSI_M, 5), (kVK_ANSI_R, 6), (kVK_ANSI_Equal, 7), (kVK_ANSI_Minus, 8), (kVK_ANSI_B, 9),
        ]
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (i, k) in digits.prefix(GAMES.count).enumerated() { keys.append((k, UInt32(100 + i))) }
        for (code, id) in keys {
            var ref: EventHotKeyRef?
            let st = RegisterEventHotKey(UInt32(code), mods, EventHotKeyID(signature: OSType(0x5351_4B59), id: id),
                                         GetApplicationEventTarget(), 0, &ref)
            if st != noErr { NSLog("SideQuest: hotkey \(id) taken (\(st))") }
            hotkeys.append(ref)
        }
    }

    func hotkey(_ id: UInt32) {
        switch id {
        case 1: swapFocus()
        case 2: toggleShown()
        case 3: dockLeft()
        case 4: dockRight()
        case 5: toggleMute()
        case 6: reload()
        case 7: resize(1)
        case 8: resize(-1)
        case 9: browse()
        case 100..<200: play(GAMES[Int(id) - 100].slug); grabFocus()
        default: break
        }
    }

    // MARK: menu bar

    func buildStatusMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "SideQuest")
        icon?.isTemplate = true
        status.button?.image = icon
        rebuildStatusMenu()
    }

    func rebuildStatusMenu() {
        let m = NSMenu()
        func add(_ t: String, _ s: Selector?, _ key: String = "", tag: Int = 0, on: Bool = false) {
            let i = NSMenuItem(title: t, action: s, keyEquivalent: "")
            i.target = self
            i.tag = tag
            i.state = on ? .on : .off
            if !key.isEmpty { i.title = "\(t)\t\(key)" }
            if s == nil { i.isEnabled = false }
            m.addItem(i)
        }
        add("Play / Back to game", #selector(swapFocus), "⌃⌥Space")
        add(panel.isVisible ? "Hide screen" : "Show screen", #selector(toggleShown), "⌃⌥G")
        m.addItem(.separator())
        for (i, g) in GAMES.enumerated() { add(g.name, #selector(pickGame(_:)), "⌃⌥\(i + 1)", tag: i) }
        add("Browse all CrazyGames…", #selector(browse), "⌃⌥B")
        m.addItem(.separator())
        add("Dock left", #selector(dockLeft), "⌃⌥←", on: side == "left")
        add("Dock right", #selector(dockRight), "⌃⌥→", on: side == "right")
        add("Bigger / smaller", #selector(cycleSize), "⌃⌥= / -")
        add("Mute", #selector(toggleMute), "⌃⌥M", on: muted)
        let op = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for p in [100, 90, 75, 60, 45] {
            let i = NSMenuItem(title: "\(p)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            i.target = self; i.tag = p; i.state = Int((opacity * 100).rounded()) == p ? .on : .off
            sub.addItem(i)
        }
        op.submenu = sub
        m.addItem(op)
        m.addItem(.separator())
        add("Quit SideQuest", #selector(quit))
        status.menu = m
    }

    @objc func quit() { NSApp.terminate(nil) }

    // Debug: `open -g sidequest://snap` writes the window (bar + game) to ~/Library/Caches/SideQuest-snap.png.
    func snap(peek: Bool = false) {
        if peek {   // hide whatever covers the centre (e.g. a consent dialog) just for this snapshot
            web.evaluateJavaScript("(()=>{let e=document.elementFromPoint(innerWidth/2,innerHeight/2);while(e&&e.parentElement&&e.parentElement!==document.body)e=e.parentElement;if(e&&e.id!=='game-iframe'&&!e.querySelector('#game-iframe')){e.style.visibility='hidden';setTimeout(()=>e.style.visibility='',1500)}})()") { _, _ in
                MainActor.assumeIsolated { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.snap() } }
            }
            return
        }
        guard bar != nil, web != nil, let rep = bar.bitmapImageRepForCachingDisplay(in: bar.bounds) else { return }
        bar.cacheDisplay(in: bar.bounds, to: rep)
        web.evaluateJavaScript("JSON.stringify([innerWidth,innerHeight,document.documentElement.scrollHeight,scrollY,getComputedStyle(document.body).backgroundColor])") { r, _ in
            try? "web=\(self.web.frame) js=\(r ?? "nil")".write(toFile: NSHomeDirectory() + "/Library/Caches/SideQuest-snap.txt", atomically: true, encoding: .utf8)
        }
        web.takeSnapshot(with: nil) { img, _ in
            MainActor.assumeIsolated {
                guard let img else { return }
                let w = self.web.bounds.width, h = self.web.bounds.height + BAR
                let out = NSImage(size: NSSize(width: w, height: h))
                out.lockFocus()
                img.draw(in: NSRect(x: 0, y: 0, width: w, height: h - BAR))
                rep.draw(in: NSRect(x: 0, y: h - BAR, width: w, height: BAR))
                out.unlockFocus()
                if let t = out.tiffRepresentation, let b = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) {
                    let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SideQuest-snap.png")
                    try? b.write(to: url)
                }
            }
        }
    }

    // sidequest://play/<slug>, sidequest://toggle, sidequest://swap
    func application(_ application: NSApplication, open urls: [URL]) {
        guard panel != nil else { return }      // URL arrived before launch finished
        for u in urls where u.scheme == "sidequest" {
            switch u.host {
            case "play": if let s = u.pathComponents.dropFirst().first { play(s) }
            case "toggle": toggleShown()
            case "swap": swapFocus()
            case "snap": snap(peek: u.path == "/peek")
            default: break
            }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = App()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
