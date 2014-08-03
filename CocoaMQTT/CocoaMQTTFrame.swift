//
//  CocoaMQTTFrame.swift
//  CocoaMQTT
//
//  Created by Feng Lee<feng.lee@nextalk.im> on 14/7/28.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

/**
 * Encode and Decode big-endian UInt16
**/
extension UInt16 {

    //Most Significant Byte (MSB)
    var highByte: UInt8 { return UInt8( (self & 0xFF00) >> 8) }
    
    //Least Significant Byte (LSB)
    var lowByte: UInt8 { return UInt8(self & 0x00FF) }
    
    var hlBytes: [Byte] { return [highByte, lowByte] }

}

/**
 * String with two bytes length
**/
extension String {
    
    //ok?
    var bytesWithLength: [Byte] { return UInt16(countElements(utf8)).hlBytes + utf8 }
    
}

/**
 * Bool to bit
**/
extension Bool {
    
    var bit: UInt8 { return self ? 1 : 0}
    
    init(bit: UInt8) {
        self = (bit == 0) ? false : true
    }
    
}

/**
 * read bit
**/
extension UInt8 {
    
    func bitAt(offset:UInt8) -> UInt8 {
        return (self >> offset) & 0x01
    }
    
}

/**
 * MQTT Frame Type
**/
enum CocoaMQTTFrameType: UInt8 {
    
    case RESERVED = 0x00
    
    case CONNECT = 0x10
    
    case CONNACK = 0x20
    
    case PUBLISH = 0x30
    
    case PUBACK = 0x40
    
    case PUBREC = 0x50
    
    case PUBREL = 0x60
    
    case PUBCOMP = 0x70
    
    case SUBSCRIBE = 0x80
    
    case SUBACK = 0x90
    
    case UNSUBSCRIBE = 0xA0
    
    case UNSUBACK = 0xB0
    
    case PINGREQ = 0xC0
    
    case PINGRESP = 0xD0
    
    case DISCONNECT = 0xE0
    
}


/**
 * MQTT Frame
**/
class CocoaMQTTFrame {
    
    let PROTOCOL_MAJOR = UInt8(3)
    
    let PROTOCOL_MINOR = UInt8(1)
    
    let PROTOCOL_VERSION: String  = "MQTT/3.1"
    
    let PROTOCOL_MAGIC: String = "MQIsdp"
    
    /**
     * |--------------------------------------
     * | 7 6 5 4 |     3    |  2 1  | 0      |
     * |  Type   | DUP flag |  QoS  | RETAIN |
     * |--------------------------------------
    **/
    var header: UInt8 = 0
    
    var qos: UInt8 {
    
    //#define GETQOS(HDR)			((HDR & 0x06) >> 1)
    get { return (header & 0x06) >> 1 }
    
    //#define SETQOS(HDR, Q)		(HDR | ((Q) << 1))
    set { header |= (newValue << 1) }
    
    }
    
    var dup: Bool {
    
    get { return ((header & 0x08) >> 3) == 0 ? false : true }
    
    set { header |= (newValue.bit << 3) }
    
    }
    
    var retain: Bool {
    
    get { return (header & 0x01) == 0 ? false : true }
    
    set { header |= newValue.bit }
    
    }

    /*
     * Variable Header
     */
    var variableHeader: [Byte] = []
    
    /*
     * Playload
     */
    var payload: [Byte] = []
    
    /*
     * Type
     */
    var type: UInt8 { return  UInt8(header & 0xF0) }

    /**
     * |----------------------------------------------------------------------------------
     * |     7    |    6     |      5     |  4   3  |     2    |       1      |     0    |
     * | username | password | willretain | willqos | willflag | cleansession | reserved |
     * |----------------------------------------------------------------------------------
    **/
    var flags: UInt8 = 0

    var flagUsername: Bool {
        //#define FLAG_USERNAME(F, U)		(F | ((U) << 7))
        get { return Bool(bit: (flags >> 7) & 0x01) }
    
        set { flags |= (newValue.bit << 7) }
    
    }
    
    var flagPasswd: Bool {
        //#define FLAG_PASSWD(F, P)		(F | ((P) << 6))
        get { return Bool(bit:(flags >> 6) & 0x01) }
    
        set { flags |= (newValue.bit << 6) }
    
    }
    
    var flagWillRetain: Bool {
        //#define FLAG_WILLRETAIN(F, R) 	(F | ((R) << 5))
        get { return Bool(bit: (flags >> 5) & 0x01) }
        set { flags |= (newValue.bit << 5) }
    }

    var flagWillQOS: UInt8 {
        //#define FLAG_WILLQOS(F, Q)		(F | ((Q) << 3))
        get { return (flags >> 3) & 0x03 }
        set { flags |= (newValue << 3) }
    }
    
    var flagWill: Bool {
        //#define FLAG_WILL(F, W)			(F | ((W) << 2))
        get { return Bool(bit:(flags >> 2) & 0x01) }
        set { flags |= ((newValue.bit) << 2) }
    }

    var flagCleanSess: Bool {
        //#define FLAG_CLEANSESS(F, C)	(F | ((C) << 1))
        get { return Bool(bit: (flags >> 1) & 0x01) }
        set { flags |= ((newValue.bit) << 1) }
    }
    
    init(header: UInt8) {
        self.header = header
    }
    
    init(type: CocoaMQTTFrameType, payload: [Byte] = []) {
        self.header = type.toRaw()
        self.payload = payload
    }
    
    func data() -> [Byte] {
        self.pack()
        return [Byte]([header]) + encodeLength() + variableHeader + payload
    }
    
    func encodeLength() -> [Byte] {
        var bytes: [Byte] = []
        var digit: UInt8 = 0
        var len: UInt32 = UInt32(variableHeader.count+payload.count)
        do {
            digit = UInt8(len % 128)
            len = len / 128
            // if there are more digits to encode, set the top bit of this digit
            if ( len > 0 ) { digit = digit | 0x80 }
            bytes.append(digit)
        } while ( len > 0 )
        return bytes
    }
    
    func pack() { return; } //do nothing

    
}

/**
 * MQTT CONNECT Frame
 **/
class CocoaMQTTFrameConnect: CocoaMQTTFrame {

    var client: CocoaMQTTClient
    
    init(client: CocoaMQTT) {
        self.client = client
        super.init(type: CocoaMQTTFrameType.CONNECT)
    }
    
    override func pack() {
        
        variableHeader += PROTOCOL_MAGIC.bytesWithLength
        variableHeader += PROTOCOL_MAJOR
        payload += client.clientId.bytesWithLength
        
        if let will = client.willMessage {
            flagWill = true
            flagWillQOS = will.qos.toRaw()
            flagWillRetain = will.retain
            payload += will.topic.bytesWithLength
            payload += will.payload
        }
        if let username = client.username {
            flagUsername = true
            payload += username.bytesWithLength
        }
        if let password = client.password {
            flagPasswd = true
            payload += password.bytesWithLength
        }
        
        flagCleanSess = true
        variableHeader += flags
        variableHeader += client.keepAlive.hlBytes
    }
    
}

/**
 * MQTT PUBLISH Frame
 **/
class CocoaMQTTFramePublish : CocoaMQTTFrame {
    
    var msgid: UInt16?

    var topic: String?
    
    var data: [Byte]?

    init(msgid: UInt16, topic: String, payload: [Byte]) {
        super.init(type: CocoaMQTTFrameType.PUBLISH, payload: payload)
        self.msgid = msgid
        self.topic = topic
        self.qos = 1
    }
    
    init(header: UInt8, data: [Byte]) {
        super.init(header: header)
        self.data = data
    }
    
    func unpack() {
        var msb = data![0], lsb = data![1]
        var len = UInt16(msb) << 8 + UInt16(lsb)
        var pos : Int = 2 + Int(len)
    
        topic = String.stringWithBytes(
            [Byte](data![2...(pos-1)]),
            length: Int(len),
            encoding: NSUTF8StringEncoding)!

        //msgid
        msb = data![pos]; lsb = data![pos+1]
        msgid = UInt16(msb) << 8 + UInt16(lsb)
        pos += 2
        
        
        //payload
        var end = data!.count - 1
        
        payload = [Byte](data![pos...end])
    }

    override func pack() {
        variableHeader += topic!.bytesWithLength
        variableHeader += msgid!.hlBytes
    }
    
}

/**
 * MQTT PUBACK Frame
 **/
class CocoaMQTTFramePubAck : CocoaMQTTFrame {

    var msgid: UInt16?
    
    init(type: CocoaMQTTFrameType, msgid: UInt16) {
        super.init(type: type)
        self.msgid = msgid
    }
    
    override func pack() {
        variableHeader += msgid!.hlBytes
    }
    
}

/**
 * MQTT SUBSCRIBE Frame
 **/
class CocoaMQTTFrameSubscribe: CocoaMQTTFrame {

    var msgid: UInt16?
    
    var topic: String?
    
    var reqos: UInt8 = CocoaMQTTQOS.QOS0.toRaw()
    
    init(msgid: UInt16, topic: String, reqos: UInt8) {
        super.init(type: CocoaMQTTFrameType.SUBSCRIBE)
        self.msgid = msgid
        self.topic = topic
        self.reqos = reqos
        self.qos = CocoaMQTTQOS.QOS1.toRaw()
    }

    override func pack() {
        variableHeader += msgid!.hlBytes
        payload += topic!.bytesWithLength
        payload += reqos
    }
    
}

/**
 * MQTT UNSUBSCRIBE Frame
 **/
class CocoaMQTTFrameUnsubscribe: CocoaMQTTFrame {
 
    var msgid: UInt16?
    
    var topic: String?
    
    init(msgid: UInt16, topic: String) {
        super.init(type: CocoaMQTTFrameType.UNSUBSCRIBE)
        self.msgid = msgid
        self.topic = topic
        qos = CocoaMQTTQOS.QOS1.toRaw()
    }
    
    override func pack() {
        variableHeader += msgid!.hlBytes
        payload += topic!.bytesWithLength
    }

}



