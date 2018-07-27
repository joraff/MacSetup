//
//  LAITMacSetupHelper.swift
//  LAIT Mac Setup
//
//  Created by Joseph Rafferty on 7/26/18.
//  Copyright © 2018 Joseph Rafferty. All rights reserved.
//

import Foundation
import SystemConfiguration

class LAITMacSetupHelper: NSObject, LAITMacSetupHelperProtocol, NSXPCListenerDelegate {
    
    private var connections = [NSXPCConnection]()
    private var listener:NSXPCListener
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    private var caller: ProcessProtocol?
    
    override init(){
        self.listener = NSXPCListener(machServiceName:LAITMacSetupHelperConstants.machServiceName)
        super.init()
        self.listener.delegate = self
    }
    
    convenience init(caller: AnyObject?){
        self.init()
        self.caller = caller as? ProcessProtocol
    }
    
    /*
     Starts the helper tool
     */
    func run(){
        self.listener.resume()
        
        // Kepp the helper running until shouldQuit variable is set to true.
        // This variable is changed to true in the connection invalidation handler in the listener(_ listener:shoudlAcceptNewConnection:) funciton.
        while !shouldQuit {
            RunLoop.current.run(until: Date.init(timeIntervalSinceNow: shouldQuitCheckInterval))
        }
    }
    
    /*
     Called when the application connects to the helper
     */
    func listener(_ listener:NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool
    {
        
        // MARK: Here a check should be added to verify the application that is calling the helper
        // For example, checking that the codesigning is equal on the calling binary as this helper.
        
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProcessProtocol.self)
        newConnection.exportedInterface = NSXPCInterface(with: LAITMacSetupHelperProtocol.self)
        newConnection.exportedObject = self;
        newConnection.invalidationHandler = (() -> Void)? {
            if let indexValue = self.connections.index(of: newConnection) {
                self.connections.remove(at: indexValue)
            }
            
            if self.connections.count == 0 {
                self.shouldQuit = true
            }
        }
        self.connections.append(newConnection)
        newConnection.resume()
        return true
    }
    
    /*
     Return bundle version for this helper
     */
    func getVersion(reply: (String) -> Void) {
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)
    }
    
    /*
     Functions to run from the main app
     */
    
    func renameComputer(computerName: String, authData: NSData?, reply: @escaping(Bool) -> Void) {
        NSLog("in XPC renameComputer")
        var scprefs: SCPreferences
        
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication.  Will be nill if we're not being called from helper service
        if authData != nil {
            if !LAITMacSetupHelperAuthorization().checkAuthorization(authData: authData, command: NSStringFromSelector(#selector(LAITMacSetupHelperProtocol.renameComputer(computerName:authData:reply:)))) {
                return reply(false)
            }
        
            let authRef = LAITMacSetupHelperAuthorization().authDataToAuthRef(authData: authData)
            guard let p = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! CFString, nil, authRef) else {
                self.sendError("unable to connect to system preferences store")
                reply(false)
                return
            }
            scprefs = p
        } else {
            guard let p = SCPreferencesCreate(kCFAllocatorDefault, Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! CFString, nil) else {
                self.sendError("unable to connect to system preferences store")
                reply(false)
                return
            }
            scprefs = p
        }
        
        SCPreferencesLock(scprefs, true)
        
        let systemDitionary = NSMutableDictionary()
        let networkDictionary = NSMutableDictionary()
        
        systemDitionary["ComputerName"]    = computerName
        systemDitionary["HostName"]        = computerName
        networkDictionary["LocalHostName"] = computerName
        
        guard SCPreferencesPathSetValue(scprefs, "/System/System" as CFString, systemDitionary),
            SCPreferencesPathSetValue(scprefs, "/System/Network/HostNames" as CFString, systemDitionary)
            else {
                let s = "unable to set system preferences values"
                self.sendError(s)
                reply(false)
                return
        }
        
        guard SCPreferencesCommitChanges(scprefs), SCPreferencesApplyChanges(scprefs) else {
            self.sendError("unable commit or apply system config preferences")
            reply(false)
            return
        }
        
        SCPreferencesUnlock(scprefs)
        
        reply(true)
    }
    
    func adLeave(username: String, password: String, authData: NSData?, reply: @escaping(NSNumber) -> Void) {
        NSLog("in XPC adLeave")
        let command = "/usr/sbin/dsconfigad"
        let arguments = ["-remove", "-username", username, "-password", password, "-force"]
       
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication. Will be nill if we're not being called from helper service
        if authData != nil {
            if !LAITMacSetupHelperAuthorization().checkAuthorization(authData: authData, command: NSStringFromSelector(#selector(LAITMacSetupHelperProtocol.adLeave(username:password:authData:reply:)))) {
                return reply(-1)
            }
        }
        
        runTask(command: command, arguments: arguments, reply:reply)
    }
    
    func adJoin(domain: String, username: String, password: String, computername: String, authData: NSData?, reply: @escaping(NSNumber) ->  Void) {
        NSLog("in XPC adJoin")
        let command = "/usr/sbin/dsconfigad"
        let arguments = ["-add", domain, "-username", username, "-password", password, "-computer", computername, "-force"]
            
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication.  Will be nill if we're not being called from helper service
        if authData != nil {
            if !LAITMacSetupHelperAuthorization().checkAuthorization(authData: authData, command: NSStringFromSelector(#selector(LAITMacSetupHelperProtocol.adJoin(domain:username:password:computername:authData:reply:)))) {
                return reply(-1)
            }
        }
        
        runTask(command: command, arguments: arguments, reply:reply)
    }
    
    func adConfigure(groups: String, authData: NSData?, reply: @escaping(NSNumber) ->  Void) {
        NSLog("in XPC adConfig")
        let command = "/usr/sbin/dsconfigad"
        let arguments = ["-groups", groups]
        
        // Check the passed authorization, if the user need to authenticate to use this command the user might be prompted depending on the settings and/or cached authentication.  Will be nill if we're not being called from helper service
        if authData != nil {
            if !LAITMacSetupHelperAuthorization().checkAuthorization(authData: authData, command: NSStringFromSelector(#selector(LAITMacSetupHelperProtocol.adConfigure(groups:authData:reply:)))) {
                return reply(-1)
            }
        }
        
        runTask(command: command, arguments: arguments, reply:reply)
    }

    /*
     Not really used in this test app, but there might be reasons to support multiple simultaneous connections.
     */
    private func connection() -> NSXPCConnection?
    {
        //
        if !self.connections.isEmpty {
            return self.connections.last!
        } else {
            return nil
        }
        
    }
    
    
    /*
     General private function to run an external command
     */
    private func runTask(command: String, arguments: Array<String>, reply:@escaping ((NSNumber) -> Void)) -> Void
    {
        let task:Process = Process()
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        task.launchPath = command
        task.arguments = arguments
        
        task.terminationHandler = { task in
            NSLog("Process terminated. Reading pipes")
            let outPipe = task.standardOutput as! Pipe
            let errPipe = task.standardError as! Pipe
            
            var data = outPipe.fileHandleForReading.readDataToEndOfFile()
            
            NSLog("Out pipe")
            if let stdOut = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                self.sendOutput(stdOut as String)
            }
            
            data = errPipe.fileHandleForReading.readDataToEndOfFile()
            
            NSLog("Err pipe")
            if let stdErr = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                self.sendError(stdErr as String)
            }
            
            reply(NSNumber(value: task.terminationStatus))
        }
        
        try? task.run()
    }
    
    private func sendOutput(_ s: String) {
        if let remoteObject = self.connection()?.remoteObjectProxy as? ProcessProtocol {
            remoteObject.outputBuffer(s)
        } else {
            self.caller?.outputBuffer(s)
        }
    }
    
    private func sendError(_ s: String) {
        if let remoteObject = self.connection()?.remoteObjectProxy as? ProcessProtocol {
            remoteObject.errorBuffer(s)
        } else {
            self.caller?.errorBuffer(s)
        }
    }
}
