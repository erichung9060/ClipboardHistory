import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private struct Keys {
        static let displayingNumber = "displayingNumber"
        static let rememberingNumber = "rememberingNumber"
    }

    var displayingNumber: Int {
        get {
            return UserDefaults.standard.object(forKey: Keys.displayingNumber) as? Int ?? 100
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.displayingNumber)
        }
    }
    
    var rememberingNumber: Int {
        get {
            return UserDefaults.standard.object(forKey: Keys.rememberingNumber) as? Int ?? 1000
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.rememberingNumber)
        }
    }
    
    let recordInterval = 0.5
    let menuItemMaxWidth = 300.0
    
    var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var searchField = NSTextField()
    var statusMenu = NSMenu()

    var clipboardHistory: [String] = []
    
    var lastChangeCount: Int = NSPasteboard.general.changeCount

    var timer: Timer?
    lazy var preferencesWindowController: NSWindowController? = {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateController(withIdentifier: "PreferencesWindowController") as? NSWindowController
    }()
    
    let fileManager = FileManager.default
    var historyFileURL: URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.copyboard"
        let appFolderURL = appSupportURL.appendingPathComponent(bundleID)
        return appFolderURL.appendingPathComponent("clipboard_history.txt")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Edit menu programmatically to avoid storyboard inconsistencies
        setupEditMenu()
        
        createApplicationSupportDirectory()
        loadHistory()
        
        // set menu button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
            button.action = #selector(showMenu)
            button.target = self
        }
        
        // set search field
        searchField.frame = NSRect(x: 10, y: 0, width: 330 - 2 * 10, height: 27)
        searchField.placeholderString = "Search history..."
        searchField.target = self
        searchField.delegate = self
        searchField.bezelStyle = .roundedBezel
        searchField.isBordered = true
        searchField.isBezeled = true
        
        // add search field into Menu
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 330, height: 27))
        containerView.addSubview(searchField)
        let searchMenuItem = NSMenuItem()
        searchMenuItem.view = containerView
        
        statusMenu.addItem(searchMenuItem)
        statusMenu.addItem(NSMenuItem.separator())
        
        startMonitoringClipboard()
    }
    
    func setupEditMenu() {
        // Create Edit menu
        let editMenu = NSMenu(title: "Edit")
        
        // Add Cut
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(cutItem)
        
        // Add Copy
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(copyItem)
        
        // Add Paste
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(pasteItem)
        
        // Add Select All
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(selectAllItem)
        
        // Add separator
        editMenu.addItem(NSMenuItem.separator())
        
        // Add Close Window
        let closeItem = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        editMenu.addItem(closeItem)
        
        // Create Edit menu item and add it to main menu
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        
        // Add to main menu
        if let mainMenu = NSApp.mainMenu {
            mainMenu.addItem(editMenuItem)
        }
    }
    
    func createApplicationSupportDirectory() {
        let fileURL = historyFileURL
        let directoryURL = fileURL.deletingLastPathComponent()
        
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            print("Error creating directory: \(error)")
        }
    }
    
    func loadHistory() {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            clipboardHistory = []
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            if let history = try JSONSerialization.jsonObject(with: data) as? [String] {
                clipboardHistory = history
            }
        } catch {
            print("Error loading history: \(error)")
            clipboardHistory = []
        }
    }
    
    func saveHistory() {
        do {
            let data = try JSONSerialization.data(withJSONObject: clipboardHistory)
            try data.write(to: historyFileURL)
        } catch {
            print("Error saving history: \(error)")
        }
    }
    
    func updateMenu(searchString: String) {
        while statusMenu.items.count > 2 {
            statusMenu.removeItem(at: 2)
        }

        var displayingHistory: [String] = []
        if searchString != "" {
            displayingHistory = clipboardHistory.filter { $0.lowercased().contains(searchString.lowercased()) }
        }else{
            displayingHistory = Array(clipboardHistory.prefix(displayingNumber))
        }
        
        for item in displayingHistory {
            let truncatedText = truncateString(input: item)
            
            let menuItem = NSMenuItem(title: truncatedText, action: #selector(copyToClipboard(_:)), keyEquivalent: "")
            menuItem.representedObject = item
            statusMenu.addItem(menuItem)
        }
        
        if displayingHistory.count != 0 { 
            statusMenu.addItem(NSMenuItem.separator()) 
        }
        statusMenu.addItem(NSMenuItem(title: "Clear All", action: #selector(clearClipboardHistory), keyEquivalent: "c"))
        statusMenu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    

    func truncateString(input: String) -> String {
        let safeInput = input.map { String($0) }.prefix(100).joined()
        
        let font = NSFont.systemFont(ofSize: 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        var truncatedString = ""
        var currentWidth: CGFloat = 0
        let ellipsisWidth = (" ..." as NSString).size(withAttributes: attributes).width

        for character in safeInput {
            let charStr = String(character) as NSString
            let charWidth = charStr.size(withAttributes: attributes).width

            if currentWidth + charWidth + ellipsisWidth > menuItemMaxWidth {
                truncatedString += " ..."
                break
            }

            if character == "\n" || character == "\r" || character == "\t" {
                truncatedString.append(" ")
                currentWidth += (" " as NSString).size(withAttributes: attributes).width
            } else {
                truncatedString.append(character)
                currentWidth += charWidth
            }
        }

        return truncatedString
    }
    
    @objc func pasteBoardMonitor() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount

            guard let copiedString = pasteboard.string(forType: .string) else { return }
            clipboardHistory.insert(copiedString, at: 0)
            checkClipBoardMaximum()
            
            saveHistory()
        }
    }
    
    func updateRememberingNumber(){
        checkClipBoardMaximum()
        saveHistory()
    }

    func checkClipBoardMaximum(){
        let excessDetails = clipboardHistory.count - rememberingNumber
        if excessDetails > 0 {
            clipboardHistory.removeLast(excessDetails)
        }
    }
    
    @objc func copyToClipboard(_ sender: NSMenuItem) {
        guard let itemToCopy = sender.representedObject as? String else { return }
        
        clipboardHistory.removeAll { $0 == itemToCopy }
        clipboardHistory.insert(itemToCopy, at: 0)
        
        lastChangeCount += 1
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(itemToCopy, forType: .string)
        
        saveHistory()
    }
    
    @objc func clearClipboardHistory() {
        clipboardHistory.removeAll()
        saveHistory()
    }
    
    @objc func showPreferences() {
        preferencesWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showMenu() {
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            searchField.stringValue = ""
            updateMenu(searchString: "")
            
            statusItem.menu = statusMenu
            button.performClick(nil)
            statusItem.menu = nil

            while statusMenu.items.count > 2 {
                statusMenu.removeItem(at: 2)
            }
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        updateMenu(searchString: searchField.stringValue)
    }
    
    func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(timeInterval: recordInterval, target: self, selector: #selector(pasteBoardMonitor), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        timer?.invalidate()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
}
