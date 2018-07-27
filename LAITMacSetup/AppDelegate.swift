//
//  AppDelegate.swift
//  LAIT Mac Setup
//
//  Created by Joseph Rafferty on 7/24/18.
//  Copyright © 2018 Joseph Rafferty. All rights reserved.
//

import Cocoa
import SystemConfiguration
import os.log
import IOKit

let appLog = OSLog(subsystem: Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String, category: "App")

extension Notification.Name {
    static let renameComputer = Notification.Name("rename-computer")
    static let renamedComputer = Notification.Name("renamed-computer")
    static let renameComputerFailed = Notification.Name("rename-computer-failed")
    static let leaveDomain = Notification.Name("leave-domain")
    static let leftDomain = Notification.Name("left-domain")
    static let leaveDomainFailed = Notification.Name("leave-domain-failed")
    static let joinDomain = Notification.Name("join-domain")
    static let joinedDomain = Notification.Name("joined-domain")
    static let joinDomainFailed = Notification.Name("join-domain-failed")
    static let configureDomain = Notification.Name("configure-domain")
    static let configuredDomain = Notification.Name("configured-domain")
    static let configureDomainFailed = Notification.Name("configure-domain-failed")
    static let setupComplete = Notification.Name("setup-complete")
    static let setupFailed = Notification.Name("setup-failed")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var setupController: SetupController?
    
    @IBOutlet weak var window: NSWindow!
    var backgroundWindow: NSWindow!
    var effectWindow: NSWindow!
    
    var computedName = ""
    let defaults = UserDefaults.standard
    let nc = NotificationCenter.default
    
    let deploymentTypes = ["A Person", "A Computer Lab", "A Shared Workspace", "Other"]
    
    @IBOutlet weak var menu: NSMenu!
    
    @IBOutlet weak var serialNumber: NSTextField!
    @IBOutlet weak var assetNumber: NSTextField!
    @IBOutlet weak var computerDescription: NSTextField!
    @IBOutlet weak var deploymentType: NSPopUpButton!
    @IBOutlet weak var department: NSTextField!
    @IBOutlet weak var firstName: NSTextField!
    @IBOutlet weak var lastName: NSTextField!
    @IBOutlet weak var room: NSTextField!
    @IBOutlet weak var building: NSTextField!
    @IBOutlet weak var labIdentifier: NSTextField!
    @IBOutlet weak var labComputerNumber: NSTextField!
    @IBOutlet weak var sharedPurpose: NSTextField!
    @IBOutlet weak var computerName: NSTextField!
    @IBOutlet weak var overrideName: NSButton!
    
    @IBOutlet weak var adUserName: NSTextField!
    @IBOutlet weak var adPassword: NSSecureTextField!
    
    @IBOutlet weak var personDetailsView: NSView!
    @IBOutlet weak var labDetailsView: NSView!
    @IBOutlet weak var sharedDetailsView: NSView!
    
    @IBOutlet weak var computerNameValidationMsg: NSTextField!
    @IBOutlet weak var setupStatusMsg: NSTextView!
    @IBOutlet weak var setupStatusSpinner: NSProgressIndicator!
    
    @IBOutlet weak var saveButton: NSButton!
    
    @objc dynamic var inputsEnabled: Bool = true
//    
//    private let aduser = "mac join"
//    private let adpass = "Beeswing turnip glycolic boric scalar avouch1"
    
    
    func applicationWillFinishLaunching(_ aNotification: Notification) {
        deploymentType.addItems(withTitles: deploymentTypes)
        populateDetailsView()
        
        NSMenu.setMenuBarVisible(false)
        window.canBecomeVisibleWithoutLogin = true
        window.level = .screenSaver + 1
        window.orderFrontRegardless()
        window.isOpaque = false
        window.titlebarAppearsTransparent = true
        window.hasShadow = false
        
        window.title = ""
        
        if let screenSize = window.screen?.frame.size {
            window.setFrameOrigin(NSPoint(x: (screenSize.width-window.frame.size.width)/2, y: (screenSize.height-window.frame.size.height)/2))
        }
        
        serialNumber.stringValue = getSerialNumber()
        loadDefaults()
        setupController = SetupController()
        
        for screen in NSScreen.screens {
            let view = NSView()
            view.wantsLayer = true
            
            backgroundWindow = NSWindow(contentRect: screen.frame,
                                        styleMask: .fullSizeContentView,
                                        backing: .buffered,
                                        defer: true)
            
            backgroundWindow.backgroundColor = window.backgroundColor
            backgroundWindow.contentView = view
            backgroundWindow.level = window.level - 1
            backgroundWindow.makeKeyAndOrderFront(self)
            backgroundWindow.canBecomeVisibleWithoutLogin = true
            
            //            let effectView = NSVisualEffectView()
            //            effectView.wantsLayer = true
            //            effectView.blendingMode = .behindWindow
            //            effectView.frame = screen.frame
            //
            //            effectWindow = NSWindow(contentRect: screen.frame,
            //                                    styleMask: .fullSizeContentView,
            //                                    backing: .buffered,
            //                                    defer: true)
            //
            //            effectWindow.contentView = effectView
            //            effectWindow.alphaValue = 0.8
            //            effectWindow.level = window.level - 1
            //            effectWindow.orderFrontRegardless()
            //            effectWindow.canBecomeVisibleWithoutLogin = true
        }
        
        
        
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.makeKeyAndOrderFront(nil)
        assetNumber.becomeFirstResponder()
        // Something at the loginwindow context steals keyboard focus after launch. Wait and steal it back
       
        
        nc.addObserver(forName: .renamedComputer,      object: nil, queue: nil, using: renamedComputer)
        nc.addObserver(forName: .renameComputerFailed, object: nil, queue: nil, using: renameComputerFailed)
        nc.addObserver(forName: .leftDomain,           object: nil, queue: nil, using: leftDomain)
        nc.addObserver(forName: .leaveDomainFailed,    object: nil, queue: nil, using: leaveDomainFailed)
        nc.addObserver(forName: .joinedDomain,         object: nil, queue: nil, using: joinedDomain)
        nc.addObserver(forName: .joinDomainFailed,     object: nil, queue: nil, using: joinDomainFailed)
        nc.addObserver(forName: .configuredDomain,     object: nil, queue: nil, using: configuredDomain)
        nc.addObserver(forName: .configureDomainFailed,object: nil, queue: nil, using: configureDomainFailed)
        nc.addObserver(forName: .setupComplete,        object: nil, queue: nil, using: setupComplete)
        nc.addObserver(forName: .setupFailed,          object: nil, queue: nil, using: setupFailed)
        
        if !hasConsoleUser() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.window.makeKeyAndOrderFront(nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        generateComputerName()
    }
    
    @IBAction func deploymentTypeDidChange(_ sender: Any?) {
        os_log("popup did change", log: appLog, type: .default)
        populateDetailsView()
    }
    
    func loadDefaults() {
        if let val = defaults.string(forKey: "assetNumber") {
            assetNumber.stringValue = val
        }
        
        if let val = defaults.string(forKey: "department") {
            department.stringValue = val
        }
        
        if let val = defaults.string(forKey: "computerDescription") {
            computerDescription.stringValue = val
        }
        
        if let val = defaults.string(forKey: "building") {
            building.stringValue = val
        }
        
        if let val = defaults.string(forKey: "room") {
            room.stringValue = val
        }
        
        if let val = defaults.string(forKey: "deploymentType") {
            deploymentType.selectItem(withTitle: val)
        }
        
        if let val = defaults.string(forKey: "firstName") {
            firstName.stringValue = val
        }
        
        if let val = defaults.string(forKey: "lastName") {
            lastName.stringValue = val
        }
        
        if let val = defaults.string(forKey: "labIdentifier") {
            labIdentifier.stringValue = val
        }
        
        if let val = defaults.string(forKey: "labComputerNumber") {
            labComputerNumber.stringValue = val
        }
        
        if let val = defaults.string(forKey: "sharedPurpose") {
            sharedPurpose.stringValue = val
        }
        
        if let val = defaults.string(forKey: "computerName") {
            computerName.stringValue = val
        }
        
        if defaults.bool(forKey: "overrideName") {
            overrideName.state = .on
        }
    }
    
    func saveDefaults() {
        defaults.set(assetNumber.stringValue, forKey: "assetNumber")
        defaults.set(department.stringValue, forKey: "department")
        defaults.set(computerDescription.stringValue, forKey: "computerDescription")
        defaults.set(building.stringValue, forKey: "building")
        defaults.set(room.stringValue, forKey: "room")
        defaults.set(deploymentType.selectedItem?.title, forKey: "deploymentType")
        defaults.set(firstName.stringValue, forKey: "firstName")
        defaults.set(lastName.stringValue, forKey: "lastName")
        defaults.set(labIdentifier.stringValue, forKey: "labIdentifier")
        defaults.set(labComputerNumber.stringValue, forKey: "labComputerNumber")
        defaults.set(sharedPurpose.stringValue, forKey: "sharedPurpose")
        defaults.set(computerName.stringValue, forKey: "computerName")
        defaults.set(overrideName.state, forKey: "overrideName")
    }
    
    func populateDetailsView() {
        personDetailsView.isHidden = true
        labDetailsView.isHidden = true
        sharedDetailsView.isHidden = true
        overrideName.state = .off
        let val = deploymentType.titleOfSelectedItem
        switch val {
        case "A Person":
            personDetailsView.isHidden = false
            break
        case "A Computer Lab":
            labDetailsView.isHidden = false
            break
        case "A Shared Workspace":
            sharedDetailsView.isHidden = false
            break
        case "Other":
            overrideName.state = .on
            overrideComputerNameStateDidChange(nil)
            break
        default:
            break
        }
        
    }
    
    @IBAction func overrideComputerNameStateDidChange(_ sender: Any?) {
        computerName.isEnabled = (overrideName.state == NSControl.StateValue.on) ? true : false
    }
    
    @objc func computerNameFieldEnabled() -> Bool {
        return self.inputsEnabled && (self.overrideName.state == .on)
    }
    
    @IBAction func setupComputerButtonClicked(_ sender: NSButton) {
        os_log("Saving defaults", log: appLog, type: .default)
        saveDefaults()
        inputsEnabled = false
        
        DispatchQueue.main.async {
            self.setupStatusMsg.string = ""
            self.logStatus("Starting Setup:\n\n")
            self.setupStatusMsg.superview?.superview?.isHidden = false // First parent view is clip, second is scroll view
            self.setupStatusSpinner.startAnimation(self)
            self.setupStatusSpinner.isHidden = false
            self.logStatus("Renaming computer... ")
        }
        
        // Kick things off with rename computer
        nc.post(name: .renameComputer, object: nil, userInfo: ["computerName": computerName.stringValue])
    }
    
    func renamedComputer(_ notification: Notification) {
        self.logStatus("""
        Done.
        Leaving any currently joined domain...
        """)
        DispatchQueue.main.async {
            self.nc.post(name: .leaveDomain, object: nil, userInfo: ["username": self.adUserName.stringValue, "password": self.adPassword.stringValue])
        }
    }
    
    func renameComputerFailed(_ notification: Notification) {
        let error = notification.userInfo?["error"] as? String
        self.logError("""
        Failed! Error:
        \(error ?? "Unable to rename computer")
        """)
        self.nc.post(name: .setupFailed, object: nil)
    }
    
    func leftDomain(_ notification: Notification) {
        os_log("ad leave task succeeded", log: appLog, type: .default)
        self.logStatus("""
        Done.
        Joining domain...
        """)
        DispatchQueue.main.async {
            self.nc.post(name: .joinDomain, object: nil, userInfo: ["domain": "cla.tamu.edu", "username": self.adUserName.stringValue, "password": self.adPassword.stringValue, "computerName": self.computerName.stringValue])
        }
        
    }
    
    func leaveDomainFailed(_ notification: Notification) {
        let error = notification.userInfo?["error"] as? String
        self.logError("""
        Failed! Error:
        \(error ?? "Unable to leave domain")
        """)
        nc.post(name: .setupFailed, object: nil)
    }
    
    func joinedDomain(_ notification: Notification) {
        os_log("ad join task succeeded", log: appLog, type: .default)
        self.logStatus("""
        Done.
        Configuring domain settings...
        """)
        nc.post(name: .configureDomain, object: nil, userInfo: ["groups": "CLA\\Domain Admins,CLA\\LAIT-Tier 2"])
    }
    
    func joinDomainFailed(_ notification: Notification) {
        let error = notification.userInfo?["error"] as? String
        self.logError("""
        Failed! Error:
        \(error ?? "Unable to join domain")
        """)
        nc.post(name: .setupFailed, object: nil)
    }
    
    func configuredDomain(_ notification: Notification) {
        os_log("ad configure task succeeded", log: appLog, type: .default)
        self.logStatus("""
        Done.
        """)
        nc.post(name: .setupComplete, object: nil)
    }
    
    func configureDomainFailed(_ notification: Notification) {
        let error = notification.userInfo?["error"] as? String
        self.logError("""
        Failed! Error:
        \(error ?? "Unable to configure domain")
        """)
        nc.post(name: .setupFailed, object: nil)
    }
    
    func setupComplete(_ notification: Notification) {
        DispatchQueue.main.async {
            self.logStatus("\n\n--------\n\nSetup Process Complete")
            self.setupStatusSpinner.stopAnimation(self)
            self.setupStatusSpinner.isHidden = true
            self.inputsEnabled = true
            self.saveButton.title = "Quit"
            self.saveButton.action = #selector(AppDelegate.exitNow)
        }
    }
    
    func setupFailed(_ notification: Notification) {
        DispatchQueue.main.async {
            self.setupStatusSpinner.stopAnimation(self)
            self.setupStatusSpinner.isHidden = true
            self.inputsEnabled = true
        }
    }
    
    func generateComputerName() {
        if overrideName.state == .off {
            switch deploymentType.titleOfSelectedItem {
            case "A Person":
                computedName = "\(department.stringValue.prefix(4))\(firstName.stringValue.prefix(1))\(lastName.stringValue.prefix(6))\(assetNumber.stringValue.suffix(4))"
                break
            case "A Computer Lab":
                computedName = "\(department.stringValue.prefix(4))\(labIdentifier.stringValue.prefix(9))\(labComputerNumber.stringValue.prefix(2))"
                break
            case "A Shared Workspace":
                computedName = "\(department.stringValue.prefix(4))\(sharedPurpose.stringValue.prefix(7))\(assetNumber.stringValue.suffix(4))"
                break
            case "Other":
                computedName = "\(department.stringValue.prefix(4))-\(assetNumber.stringValue.suffix(11))"
            default:
                break
            }
//            os_log("computer name = %{public}@", log: appLog, type: .default, computedName)
            computerName.stringValue = computedName
        }
        let _ = validateComputerName()
    }
    
    func validateComputerName() -> Bool {
        if computerName.stringValue.range(of: "[^a-zA-Z0-9._-]", options: .regularExpression) != nil {
            computerNameValidationMsg.stringValue = "Computer name may only contain letters, numbers, or special characters from: '- _ .'"
            saveButton.isEnabled = false
            return false
        }
        
        if computerName.stringValue.count > 15 {
            computerNameValidationMsg.stringValue = "Computer name is too long"
            saveButton.isEnabled = false
            return false
        }
        
        if computerName.stringValue.count == 0 {
            // No error message necessary, just disable button
            saveButton.isEnabled = false
            return false
        }
        
        // Passed validations
        computerNameValidationMsg.stringValue = ""
        saveButton.isEnabled = true
        return true
    }
    
    func hasConsoleUser() -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        
        if SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) != nil {
            return true
        } else {
            return false
        }
    }
    
    @IBAction func exitNow(_ sender: AnyObject?) {
        NSApp.terminate(self)
    }
    
    func getSerialNumber() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)
        let serial = serialNumberAsCFString?.takeRetainedValue() as! String
        IOObjectRelease(platformExpert)
        
        return serial
    }
    
    func logStatus(_ str: String?) {
        if (str != nil) && !str!.isEmpty {
            DispatchQueue.main.async {
                self.setupStatusMsg.string = self.setupStatusMsg.string + str!
                self.setupStatusMsg.scrollToEndOfDocument(self)
            }
        }
    }
    
    func logError(_ str: String?) {
        if (str != nil) && !str!.isEmpty {
            DispatchQueue.main.async {
                let attributedString = NSMutableAttributedString(string: str!, attributes: [.foregroundColor: NSColor.red])
                self.setupStatusMsg.textStorage?.append(attributedString)
                self.setupStatusMsg.scrollToEndOfDocument(self)
            }
        }
    }
}
