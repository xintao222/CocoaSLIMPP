//
//  SLIMPPMessage.swift
//  CocoaSLIMPP
//
//  Created by 李方朔 on 14/8/3.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

struct SLIMPPMessage {

    var type: String = "chat"
    
    var from: String
    
    var to: String
    
    var nick: String
    
    var body: String

}