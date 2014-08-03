//
//  SLIMPPChatManager.swift
//  CocoaSLIMPP
//
//  Created by 李方朔 on 14/8/3.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

protocol SLIMPPChatDelegate {

    func messageReceived(message: SLIMPPMessage)

}

class SLIMPPChatManager {
    
    var delegates: Dictionary<String, SLIMPPChatDelegate>

    init() { delegates =  Dictionary<String, SLIMPPChatDelegate>() }

    func addDelegate(id: String, delegate: SLIMPPChatDelegate) {
        delegates[id] = delegate
    }
    
    func removeDelegate(id: String) {
        delegates.removeValueForKey(id)
    }
    
    func openChat(to: String) {
        println("Open Chat to: \(to)")
    }
    
}