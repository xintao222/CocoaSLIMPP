//
//  SLIMPPRoster.swift
//  CocoaSLIMPP
//
//  Created by 李方朔 on 14/8/3.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

/**
 * Roster Delegate
 */
protocol SLIMPPRosterDelegate {

}


/**
 * SLIMPP Roster Item
 **/
class SLIMPPRosterItem: NSObject {
    
    let id: String
    
    var nick: String
    
    init(id: String, nick: String) {
        self.id = id
        self.nick = nick
    }

}

/**
 * SLIMPP Buddy Item
 **/
class SLIMPPBuddy: SLIMPPRosterItem {
    
    var presence: String = "online"
    
    var group: String = "friend"
    
    var show: String = "available"
    
    var status: String = ""
    
    var avatar: String?
    
    var url: String?
    
    init(id: String, nick: String) {
        super.init(id: id, nick: nick)
    }
    
}



/**
 * SLIMPP Room Object
 **/
class SLIMPPRoom: SLIMPPRosterItem {

    //Home page of room
    var url: String?
    
    //Avatar of Room
    var avatar: String?
    
    //Room status
    var status: String?
    
    var blocked: Bool = false
    
    init(id: String, nick: String) {
        super.init(id: id, nick: nick)
    }

}



/**
 * SLIMPP Roster
 **/
class SLIMPPRoster {

    var buddies: Dictionary<String, SLIMPPBuddy>
    
    var rooms: Dictionary<String, SLIMPPRoom>
    
    init() {
        buddies = Dictionary<String, SLIMPPBuddy>()
        rooms = Dictionary<String, SLIMPPRoom>()
    }

    func getBuddy(id: String) -> SLIMPPBuddy? {
        println("get buddy: \(id)")
        return nil
    }
    

    func getRoom(id: String) -> SLIMPPRoom? {
        println("rooms...")
        return nil
    }
    
    func getMembers(roomId: String) -> [String] {
        return []
    }
    
}



