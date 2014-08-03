//
//  main.swift
//  CocoaSLIMPP
//
//  Created by Feng Lee<feng.lee@nextalk.im> on 14/8/3.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

let slimpp = SLIMPP.sharedInstance

slimpp.apiURL = "http://localhost/app/public/"
slimpp.hello()
slimpp.roster.getBuddy("uid1")
slimpp.roster.getRoom("uid1")
slimpp.chatManager.openChat("uid1")
slimpp.login("test", password: "public")
dispatch_main()

