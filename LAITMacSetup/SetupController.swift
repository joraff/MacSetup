//
//  SetupController.swift
//  LAITMacSetup
//
//  Created by Joseph Rafferty on 7/27/18.
//  Copyright © 2018 Joseph Rafferty. All rights reserved.
//

import Foundation
import SystemConfiguration
import ServiceManagement
import os.log

let setupLog = OSLog(subsystem: Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String, category: "Setup")

class SetupController: NSObject, ProcessProtocol {
    var xpcHelperConnection: NSXPCConnection?
    var cachedHelperAuthData: NSData?
    var xpcService: LAITMacSetupHelperProtocol?
    var xpcOutputBuffer: String?
    var xpcErrorBuffer: String?
    var setupHelper: LAITMacSetupHelper?
    let nc = NotificationCenter.default
    
    override init() {
        super.init()
        
        if amIRoot() {
            os_log("We're root, skip the separate helper app", log: setupLog, type: .default)
            setupHelper = LAITMacSetupHelper(caller: self)
        } else {
            shouldInstallHelper(callback: { installed in
                if !installed {
                    self.installHelper()
                    self.xpcHelperConnection = nil  //  Nulls the connection to force a reconnection
                }
            })
            
            os_log("Checking for cached authdata", log: setupLog, type: .default)
            if self.cachedHelperAuthData == nil {
                self.cachedHelperAuthData = LAITMacSetupHelperAuthorization().authorizeHelper()
            }
            
            self.xpcService = self.helperConnection()?.remoteObjectProxyWithErrorHandler() { error -> Void in
                os_log("XPCService error: %{public}@", log: setupLog, type: .default, error.localizedDescription)
            } as? LAITMacSetupHelperProtocol
        }
        
        nc.addObserver(forName: .renameComputer,  object: nil, queue: nil, using: renameComputer)
        nc.addObserver(forName: .leaveDomain,     object: nil, queue: nil, using: leaveDomain)
        nc.addObserver(forName: .joinDomain,      object: nil, queue: nil, using: joinDomain)
        nc.addObserver(forName: .configureDomain, object: nil, queue: nil, using: configureDomain)
    }
    
    func amIRoot() -> Bool {
        if let user = ProcessInfo().environment["USER"] {
            return user == "root"
        }
        return false
    }
    
    func renameComputer(_ notification: Notification) {
        os_log("invoking rename computer task", log: setupLog, type: .default)
        
        guard let userInfo = notification.userInfo,
            let computerName = userInfo["computerName"] as? String else {
                os_log("missing data passed to task", log: setupLog, type: .default)
                nc.post(name: .renameComputerFailed, object: nil, userInfo: ["error": "Internal error: Unable to determine computer name"])
                return
        }
        os_log("Renaming to: %{public}@", log: setupLog, type: .default, computerName)
        
        let callback:(Bool) -> Void = { exitStatus in
            os_log("Returned from xpc rename computer. Exit status: %{public}@, output: %{public}@, error: %{public}@", log: setupLog, type: .default, exitStatus.description, self.xpcOutputBuffer ?? "empty", self.xpcErrorBuffer ?? "empty")
            if exitStatus {
                // leave task success
                os_log("Posting renamedComputer", log: setupLog, type: .default)
                self.nc.post( name: .renamedComputer, object: nil)
            } else {
                os_log("Posting renameComputerFailed", log: setupLog, type: .default)
                self.nc.post(name: .renameComputerFailed, object: nil, userInfo: ["error": self.xpcErrorBuffer ?? "Unknown error"])
                self.xpcErrorBuffer = ""
            }
        }
        
        if amIRoot() {
            setupHelper?.renameComputer(computerName: computerName, authData: nil, reply: callback)
        } else {
            xpcService?.renameComputer(computerName: computerName, authData: self.cachedHelperAuthData, reply: callback)
            os_log("invoked rename computer task", log: setupLog, type: .default)
        }
        
    }
    
    func leaveDomain(_ notification: Notification) {
        os_log("invoking ad leave task", log: setupLog, type: .default)
        
        guard let userInfo = notification.userInfo,
            let username  = userInfo["username"] as? String,
            let password  = userInfo["password"] as? String else {
                os_log("missing data passed to leaveDomain", log: setupLog, type: .default)
                nc.post(name: .renameComputerFailed, object: nil, userInfo: ["error": "Internal error: Unable to determine AD Credentials"])
                return
        }
    
        os_log("leaving domain with username and password: %{public}@, <redacted>", log: setupLog, type: .default, username)
        
        let callback: (NSNumber) -> Void = { exitStatus in
            os_log("Returned from xpc adLeave. Exit status: %{public}@, output: %{public}@, error: %{public}@", log: setupLog, type: .default, exitStatus, self.xpcOutputBuffer ?? "empty", self.xpcErrorBuffer ?? "empty")
            if exitStatus == 0 {
                // leave task success
                os_log("Posting LeaveDomainSuccess", log: setupLog, type: .default)
                self.nc.post( name: .leftDomain, object: nil)
            } else if
                (self.xpcErrorBuffer?.range(of: "This computer is not Bound to Active Directory") != nil) ||
                    (self.xpcErrorBuffer?.range(of: "Container does not exist") != nil) {
                // Acceptable error messages
                // leave task success
                os_log("Posting LeaveDomainSuccess", log: setupLog, type: .default)
                self.nc.post(name: .leftDomain, object: nil)
            } else {
                os_log("Posting LeaveDomainFailure", log: setupLog, type: .default)
                self.nc.post(name: .leaveDomainFailed, object: nil, userInfo: ["error": self.xpcErrorBuffer ?? "Unknown error"])
                self.xpcErrorBuffer = ""
            }
        }
        
        if amIRoot() {
            setupHelper?.adLeave(username: username, password: password, authData: nil, reply: callback)
        } else {
            xpcService?.adLeave(username: username, password: password, authData: self.cachedHelperAuthData, reply: callback)
        }
        os_log("invoked ad leave task", log: setupLog, type: .default)
    }
    
    func joinDomain(_ notification: Notification) {
        os_log("invoking ad join task", log: setupLog, type: .default)
        
        guard let userInfo = notification.userInfo,
            let domain       = userInfo["domain"] as? String,
            let username     = userInfo["username"] as? String,
            let password     = userInfo["password"] as? String,
            let computerName = userInfo["computerName"] as? String else {
                os_log("missing data passed to joinDomain", log: setupLog, type: .default)
                nc.post(name: .renameComputerFailed, object: nil, userInfo: ["error": "Internal error: Missing required information to join domain"])
                return
        }
        
        os_log("joining %{public}@ as %{public}@ with username and password: %{public}@, <redacted>", log: setupLog, type: .default, domain, computerName, username)
        
        let callback: (NSNumber) -> Void = { exitStatus in
            os_log("Returned from xpc adJoin. Exit status: %{public}@, output: %{public}@, error: %{public}@", log: setupLog, type: .default, exitStatus, self.xpcOutputBuffer ?? "empty", self.xpcErrorBuffer ?? "empty")
            if exitStatus == 0 {
                // leave task success
                os_log("Posting JoinDomainSuccess", log: setupLog, type: .default)
                self.nc.post(name: .joinedDomain, object: nil)
            } else {
                os_log("Posting JoinDomainFailure", log: setupLog, type: .default)
                self.nc.post(name: .joinDomainFailed, object: nil, userInfo: ["error": self.xpcErrorBuffer ?? "Unknown error"])
                self.xpcErrorBuffer = ""
            }
        }
        
        if amIRoot() {
            setupHelper?.adJoin(domain: domain, username: username, password: password, computername: computerName, authData: nil, reply: callback)
        } else {
            xpcService?.adJoin(domain: domain, username: username, password: password, computername: computerName, authData: self.cachedHelperAuthData, reply: callback)
        }
        
        os_log("invoked ad join task", log: setupLog, type: .default)
    }
    
    func configureDomain( _ notification: Notification) {
        os_log("invoking configure domain task", log: setupLog, type: .default)
        
        guard let userInfo = notification.userInfo,
            let groups       = userInfo["groups"] as? String else {
                os_log("missing data passed to ", log: setupLog, type: .default)
                nc.post(name: .renameComputerFailed, object: nil, userInfo: ["error": "Internal error: Missing required information to configure domain"])
                return
        }
        
        os_log("configuring domain with groups: %{public}@", log: setupLog, type: .default, groups)
        
        let callback: (NSNumber) -> Void = { exitStatus in
            os_log("Returned from xpc adConfigure. Exit status: %{public}@, output: %{public}@, error: %{public}@", log: setupLog, type: .default, exitStatus, self.xpcOutputBuffer ?? "empty", self.xpcErrorBuffer ?? "empty")
            if exitStatus == 0 {
                // leave task success
                os_log("Posting ConfiguredDomain", log: setupLog, type: .default)
                self.nc.post(name: .configuredDomain, object: nil)
            } else {
                os_log("Posting COnfigureDomainFailure", log: setupLog, type: .default)
                self.nc.post(name: .configureDomainFailed, object: nil, userInfo: ["error": self.xpcErrorBuffer ?? "Unknown error"])
                self.xpcErrorBuffer = ""
            }
        }
        
        if amIRoot() {
            setupHelper?.adConfigure(groups: groups, authData: nil, reply: callback)
        } else {
            xpcService?.adConfigure(groups: groups, authData: self.cachedHelperAuthData, reply: callback)
        }
        os_log("invoked cocnfigure domain task", log: setupLog, type: .default)
    }
    
    func helperConnection() -> NSXPCConnection? {
        if (self.xpcHelperConnection == nil){
            self.xpcHelperConnection = NSXPCConnection(machServiceName:LAITMacSetupHelperConstants.machServiceName, options:NSXPCConnection.Options.privileged)
            self.xpcHelperConnection!.exportedObject = self
            self.xpcHelperConnection!.exportedInterface = NSXPCInterface(with:ProcessProtocol.self)
            self.xpcHelperConnection!.remoteObjectInterface = NSXPCInterface(with:LAITMacSetupHelperProtocol.self)
            self.xpcHelperConnection!.invalidationHandler = {
                self.xpcHelperConnection?.invalidationHandler = nil
                OperationQueue.main.addOperation(){
                    self.xpcHelperConnection = nil
                    os_log("XPC Connection Invalidated\n", log: setupLog, type: .default)
                }
            }
            self.xpcHelperConnection?.resume()
        }
        return self.xpcHelperConnection
    }
    
    /*
     Process Protocol Functions
     */
    
    func outputBuffer(_ str: String) -> Void {
        self.xpcOutputBuffer = str
        //        logStatus("xpc: " + str)
    }
    
    func errorBuffer(_ str: String) -> Void {
        self.xpcErrorBuffer = str
        //        logError("xpc: " + str)
    }
    
    /*
     Helper process function
    */
    
    func shouldInstallHelper(callback: @escaping (Bool) -> Void){
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(LAITMacSetupHelperConstants.machServiceName)")
        os_log("helperURL = %{public}@", log: setupLog, type: .default, helperURL.description)
        let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL?)
        if helperBundleInfo != nil, let helperInfo = helperBundleInfo as? [String: AnyObject] {
            let helperVersion = helperInfo["CFBundleVersion"] as! String
        
            os_log("Helper: Bundle Version => %{public}@", log: setupLog, type: .default, helperVersion)
        
            let helper = self.helperConnection()?.remoteObjectProxyWithErrorHandler({
                _ in callback(false)
            }) as! LAITMacSetupHelperProtocol
            
            helper.getVersion(reply: {
                installedVersion in
                os_log("Helper: Installed Version => %{public}@", log: setupLog, type: .default, installedVersion)
                callback(helperVersion == installedVersion)
            })
        } else {
            callback(false)
        }
    }
    
    // Uses SMJobBless to install or update the helper tool
    func installHelper(){
        
        var authRef:AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value:UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights:AuthorizationRights = AuthorizationRights(count: 1, items:&authItem)
        let authFlags: AuthorizationFlags = [ [], .extendRights, .interactionAllowed, .preAuthorize ]
        
        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)
        if (status != errAuthorizationSuccess){
            let error = NSError(domain:NSOSStatusErrorDomain, code:Int(status), userInfo:nil)
            os_log("Authorization error: %{public}@", log: setupLog, type: .default, error)
        } else {
            var cfError: Unmanaged<CFError>? = nil
            if !SMJobBless(kSMDomainSystemLaunchd, LAITMacSetupHelperConstants.machServiceName as CFString, authRef, &cfError) {
                let blessError = cfError!.takeRetainedValue() as Error
                os_log("Bless Error: %{public}@", log: setupLog, type: .default, blessError as! String)
            } else {
                os_log("%{public}@ installed successfully", log: setupLog, type: .default, LAITMacSetupHelperConstants.machServiceName)
            }
        }
    }
}
