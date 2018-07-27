//
//  ProcessProtocol.swift
//  LAIT Mac Setup
//
//  Created by Joseph Rafferty on 7/26/18.
//  Copyright © 2018 Joseph Rafferty. All rights reserved.
//

import Foundation

// Protocol to list all functions the helper can call in the main application
@objc(ProcessProtocol)
protocol ProcessProtocol {
    func outputBuffer(_: String) -> Void
    func errorBuffer(_: String) -> Void
}
