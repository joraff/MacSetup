//
//  LAITHelperProtocol.swift
//  LAIT Mac Setup
//
//  Created by Joseph Rafferty on 7/26/18.
//  Copyright © 2018 Joseph Rafferty. All rights reserved.
//

import Foundation

struct LAITMacSetupHelperConstants {
    static let machServiceName = "edu.tamu.liberalarts.LAITMacSetupHelper"
}

// Protocol to list all functions the main application can call in the helper
@objc(LAITMacSetupHelperProtocol)
protocol LAITMacSetupHelperProtocol {
    func getVersion(reply: (String) -> Void)
    func renameComputer(computerName: String, authData: NSData?, reply: @escaping (Bool) -> Void)
    func adLeave(username: String, password: String, authData: NSData?, reply: @escaping (NSNumber) -> Void)
    func adJoin(domain: String, username: String, password: String, computername: String, authData: NSData?, reply: @escaping (NSNumber) -> Void)
    func adConfigure(groups: String, authData: NSData?, reply: @escaping (NSNumber) -> Void)
//    func runCommandLs(path: String, authData: NSData?, reply: @escaping (NSNumber) -> Void)
}
