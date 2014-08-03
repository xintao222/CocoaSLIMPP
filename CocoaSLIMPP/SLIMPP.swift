//
//  SLIMPP.swift
//  CocoaSLIMPP
//
//  Created by 李方朔 on 14/8/3.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

/**
 * SLIMPP Delegate
 */
protocol SLIMPPDelegate {

    func slimpp(slimpp: SLIMPP, DidLogin: Bool, error: String?)
    
    func slimppDidOnline(slimpp: SLIMPP, json: NSDictionary)
    
    func slimpp(slimpp: SLIMPP, didSendMessage: SLIMPPMessage)
    
    func slimpp(slimpp: SLIMPP, didReceiveMessage: SLIMPPMessage)
    
    func slimpp(slimpp: SLIMPP, didSendPresence: SLIMPPPresence)
    
    func slimpp(slimpp: SLIMPP, didReceivePresence: SLIMPPPresence)
    
    func slimppDidOffline(slimpp: SLIMPP)
    
}

/**
 * SLIMPP Main Class
 **/
class SLIMPP {
    
    /**
     * Shared Instance
     */
    class var sharedInstance: SLIMPP {
        
        struct Static {
            static let instance : SLIMPP = SLIMPP()
        }
            
        return Static.instance
    
    }

    //delegate
    var delegate: SLIMPPDelegate?

    
    //model layer
    let roster: SLIMPPRoster
    
    let chatManager: SLIMPPChatManager
    
    let historyManager: SLIMPPHistoryManager
    
    //connection layer
    var apiURL: String?
    
    var ticket: String = ""
    
    var connection = NSDictionary()
    
    //mqtt
    var mqttClient: CocoaMQTT?
    
    init() {
        roster = SLIMPPRoster()
        chatManager = SLIMPPChatManager()
        historyManager = SLIMPPHistoryManager()
    }
    
    func hello() {
        println("Hello, CocoaSLIMPP!")
    }

    func login(username: String, password: String) {
    
        let url = apiURL! + "login?client=ios"
        let params = ["username": username, "password": password]
        let httpManager = AFHTTPRequestOperationManager()
        httpManager.POST(url,
            parameters: params,
            success: { (operation: AFHTTPRequestOperation!,
                responseObject: AnyObject!) in
                println("JSON: " + responseObject.description!)
                if let json = responseObject as? NSDictionary {
                    if json["status"]? as NSString == "ok" {
                        self.delegate?.slimpp(self, DidLogin: true, error: "OK")
                    }
                }
            },
            failure: { (operation: AFHTTPRequestOperation!,
                error: NSError!) in
                println("Error: " + error.localizedDescription)
                self.delegate?.slimpp(self, DidLogin: false, error: error.localizedDescription)
            })

    }
    
    
    func online() {
        
        let params = ["show": "available"]
        let httpManager = AFHTTPRequestOperationManager()
        httpManager.POST(_urlFor("online"),
            parameters: params,
            success: {(operation: AFHTTPRequestOperation!,
                responseObject: AnyObject!) in
                println("JSON: " + responseObject.description!)
                self._setup(responseObject as NSDictionary)
                self.delegate?.slimppDidOnline(self, json: responseObject as NSDictionary)
                self.startPolling()
            },
            failure: {(operation: AFHTTPRequestOperation!,
                error: NSError!) in
                println("Error: " + error.localizedDescription)
            })

    
    }
    
    func _setup(data: NSDictionary) {
        connection = data["connection"] as NSDictionary
        ticket = connection["ticket"] as String
        println("ticket: " + ticket)
    }
    
    func sendMessage(message: SLIMPPMessage) {
        let url = _urlFor("message")
        println(url)
        
        var params = Dictionary<String,String>()
        params["ticket"] = ticket
        params["from"] = "test"
        params["nick"] = "test"
        params["style"] = ""
        params["offline"] = "false"
        
        let httpManager = AFHTTPRequestOperationManager()
        httpManager.POST(url,
            parameters: params,
            success: {(operation: AFHTTPRequestOperation!,
                responseObject: AnyObject!) in
                println("JSON: " + responseObject.description!)
                
                //self.delegate?.slimppMessageSent(self, message: message)
            },
            failure:{(operation: AFHTTPRequestOperation!,
                error: NSError!) in
                println("Error: " + error.localizedDescription)
                
            })
    }
    
    func sendPresence(presence: SLIMPPPresence) {
        let url = _urlFor("presence")
        println(url)
        
        var params = Dictionary<String,String>()
        params["ticket"] = ticket
        params["show"] = "away"
        
        let httpManager = AFHTTPRequestOperationManager()
        httpManager.POST(url,
            parameters: params,
            success: {(operation: AFHTTPRequestOperation!,
                responseObject: AnyObject!) in
                println("JSON: " + responseObject.description!)
                
                //self.delegate?.slimppPresenceSent(self, presence:presence)
            },
            failure:{(operation: AFHTTPRequestOperation!,
                error: NSError!) in
                println("Error: " + error.localizedDescription)
            })
   
    }

    
    func offline() {
    
    }
    
    
    func startPolling() {
        let domain = connection["domain"] as String
        let server = connection["jsonpd"] as String
        let params = ["domain": domain, "ticket": ticket]
        let httpManager = AFHTTPRequestOperationManager()
        httpManager.GET(server,
            parameters: params,
            success: {(operation: AFHTTPRequestOperation!,
                responseObject: AnyObject!) in
                println("Packets Received: " + responseObject.description!)
                self.receivedData(responseObject as NSDictionary)
                //self.delegate?.slimppReceivedData(self, data: responseObject as NSDictionary)
                self.startPolling();
            },
            failure: {(operation: AFHTTPRequestOperation!,
                error: NSError!) in
                println("Error: " + error.localizedDescription)
            })
        
    }
    
    func receivedData(data: NSDictionary) {
        if data["messages"] {
            let messages = data["messages"] as NSArray
            for msg in messages {
                let from = msg["from"] as String
                let body = msg["body"] as String
                //let to = msg["to"] as String
                //chatManager.delegates[from]?.messageReceived(from, message: body)
            }
        }
    }
    
    func _urlFor(api: String) -> String {
        return apiURL! + "slimpp.php/v1/" + api
    }

}
