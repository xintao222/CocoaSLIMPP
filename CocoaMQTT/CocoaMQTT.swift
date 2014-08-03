//
//  CocoaMQTT.swift
//  CocoaMQTT
//
//  Created by Feng Lee<feng.lee@nextalk.im> on 14/7/28.
//  Copyright (c) 2014年 slimpp.io. All rights reserved.
//

import Foundation

/**
 * MQTT Delegate
 **/
protocol CocoaMQTTDelegate {
    
    /**
     * MQTT connected with server
     */
    func mqtt(mqtt: CocoaMQTT, didConnect host: String, port: Int)
    
    func mqtt(mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    
    func mqtt(mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16)
    
    func mqtt(mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 )
    
    func mqtt(mqtt: CocoaMQTT, didSubscribeTopic topic: String)
    
    func mqtt(mqtt: CocoaMQTT, didUnsubscribeTopic topic: String)
    
    func mqttDidPing(mqtt: CocoaMQTT)
    
    func mqttDidReceivePong(mqtt: CocoaMQTT)
    
    func mqttDidDisconnect(mqtt: CocoaMQTT, withError err: NSError)

}

/**
 * Blueprint of the mqtt client
 **/
protocol CocoaMQTTClient {
    
    var host: String { get set }
    
    var port: UInt16 { get set }
    
    var clientId: String { get }
    
    var username: String? {get set}
    
    var password: String? {get set}
    
    var cleansess: Bool {get set}
    
    var keepAlive: UInt16 {get set}
    
    var willMessage: CocoaMQTTWill? {get set}
    
    func connect() -> Bool
    
    func publish(topic: String, withString string: String, qos: CocoaMQTTQOS) -> UInt16
    
    func publish(message: CocoaMQTTMessage) -> UInt16
    
    func subscribe(topic: String, qos: CocoaMQTTQOS) -> UInt16
    
    func unsubscribe(topic: String) -> UInt16
    
    func ping()
    
    func disconnect()
    
}


/**
 * QOS
 */
enum CocoaMQTTQOS: UInt8 {

    case QOS0 = 0

    case QOS1

    case QOS2
}

/**
 * Connection State
 **/
enum CocoaMQTTConnState: UInt8 {
    
    case INIT = 0
    
    case CONNECTING
    
    case CONNECTED
    
    case DISCONNECTED
}


/**
 * Conn Ack
 **/
enum CocoaMQTTConnAck: UInt8 {
    
    case ACCEPT  = 0
    
    case PROTO_VER
    
    case INVALID_ID
    
    case SERVER
    
    case CREDENTIALS
    
    case AUTH
    
}

/**
 * asyncsocket read tag
 **/
enum CocoaMQTTReadTag: Int {
    
    case TAG_HEADER = 0
    
    case TAG_LENGTH
    
    case TAG_PAYLOAD
    
}

/**
 * Main CocoaMQTT Class
 *
 * Notice: GCDAsyncSocket need delegate to extend NSObject
 **/
class CocoaMQTT: NSObject, CocoaMQTTClient, GCDAsyncSocketDelegate, CocoaMQTTReaderDelegate {
    
    //client variables
    
    var host = "localhost"
    
    var port: UInt16 = 1883
    
    var clientId: String
    
    var username: String?
    
    var password: String?
    
    var cleansess: Bool = true
    
    //keep alive
    
    var keepAlive: UInt16 = 0
    
    var aliveTimer: MSWeakTimer?
    
    //will message
    var willMessage: CocoaMQTTWill?

    //delegate
    
    var delegate: CocoaMQTTDelegate?

    //socket and connection 
    
    var connState = CocoaMQTTConnState.INIT

    var socket: GCDAsyncSocket?

    var reader: CocoaMQTTReader?

    //global message id
    var gmid: UInt16 = 1
    
    //subscribed topics
    var subtopics = Dictionary<UInt16, String>()
    
    //published messages
    var messages = Dictionary<UInt16, CocoaMQTTMessage>()
    
    init(clientId: String, host: String = "localhost", port: UInt16 = 1883) {
        self.clientId = clientId
        self.host = host
        self.port = port
    }
    
    //API Functions
    
    func connect() -> Bool {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        reader = CocoaMQTTReader(socket: socket!, delegate: self)
        var err: NSError?
        if !socket!.connectToHost(self.host, onPort: self.port, error: &err) {
            NSLog("CocoaMQTT: socket connect error: \(err?.description)")
            return false
        }
        connState = CocoaMQTTConnState.CONNECTING
        return true
    }
    
    func publish(topic: String, withString string: String, qos: CocoaMQTTQOS = .QOS1) -> UInt16 {
        var data = [Byte](string.utf8)
        let message = CocoaMQTTMessage(topic: topic, string: string, qos: qos)
        return publish(message)
    }
    
    func publish(message: CocoaMQTTMessage) -> UInt16 {
        let msgId : UInt16 = _nextMessageId()
        let frame = CocoaMQTTFramePublish(msgid: msgId, topic: message.topic, payload: message.payload)
        frame.qos = message.qos.toRaw()
        frame.retain = message.retain
        frame.dup = message.dup
        send(frame, tag: Int(msgId))
        if message.qos != CocoaMQTTQOS.QOS0 {
            messages[msgId] = message //cache
        } else {
            delegate?.mqtt(self, didPublishMessage: message, id: msgId)
        }
        return msgId
    }
    
    func subscribe(topic: String, qos: CocoaMQTTQOS = .QOS1) -> UInt16 {
        let msgId = _nextMessageId()
        let frame = CocoaMQTTFrameSubscribe(msgid: msgId, topic: topic, reqos: qos.toRaw())
        send(frame, tag: Int(msgId))
        subtopics[msgId] = topic //cache?
        return msgId
    }

    func unsubscribe(topic: String) -> UInt16 {
        let msgId = _nextMessageId()
        let frame = CocoaMQTTFrameUnsubscribe(msgid: msgId, topic: topic)
        subtopics[msgId] = topic //cache
        send(frame, tag: Int(msgId))
        return msgId
    }
    
    func ping() {
        send(CocoaMQTTFrame(type: CocoaMQTTFrameType.PINGREQ), tag: -0xC0)
        self.delegate?.mqttDidPing(self)
    }
    
    func disconnect() {
        send(CocoaMQTTFrame(type: CocoaMQTTFrameType.DISCONNECT), tag: -0xE0)
        socket!.disconnect()
    }
    
    func send(frame: CocoaMQTTFrame, tag: Int = 0) {
        let data = frame.data()
        socket!.writeData(NSData(bytes: data, length: data.count), withTimeout: -1, tag: tag)
    }
    
    //AsyncSocket Delegate
    func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        NSLog("CocoaMQTT: connected to \(host) : \(port)")
        connState = CocoaMQTTConnState.CONNECTED
        let frame = CocoaMQTTFrameConnect(client: self)
        send(frame)
        reader!.start()
        delegate?.mqtt(self, didConnect: host, port: Int(port))
    }

    func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        NSLog("CocoaMQTT: Socket write message with tag: \(tag)")
    }
    
    func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        let etag : CocoaMQTTReadTag = CocoaMQTTReadTag.fromRaw(tag)!
        var bytes = [Byte]([0])
        switch etag {
        case CocoaMQTTReadTag.TAG_HEADER:
            data.getBytes(&bytes, length: 1)
            reader!.headerReady(bytes[0])
        case CocoaMQTTReadTag.TAG_LENGTH:
            data.getBytes(&bytes, length: 1)
            reader!.lengthReady(bytes[0])
        case CocoaMQTTReadTag.TAG_PAYLOAD:
            reader!.payloadReady(data)
        default:
            assert(false)
        }
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        connState = CocoaMQTTConnState.DISCONNECTED
        delegate?.mqttDidDisconnect(self, withError: err)
    }
    
    //CocoaMQTTReader Delegate
    
    func didReceiveConnAck(reader: CocoaMQTTReader, connack: UInt8) {
        connState = CocoaMQTTConnState.CONNECTED
        NSLog("CocoaMQTT: CONNACK Received: \(connack)")
        
        //keep alive
        if keepAlive > 0 {
            aliveTimer = MSWeakTimer.scheduledTimerWithTimeInterval(
                NSTimeInterval(keepAlive),
                target: self,
                selector: "_aliveTimerFired",
                userInfo: nil,
                repeats: true,
                dispatchQueue: dispatch_get_main_queue())
        }
        let ack = CocoaMQTTConnAck.fromRaw(connack)!
        delegate?.mqtt(self, didConnectAck: ack)
    }

    func _aliveTimerFired() {
        if connState == CocoaMQTTConnState.CONNECTED {
            ping()
        } else {
            aliveTimer?.invalidate()
        }
    }
    
    func didReceivePublish(reader: CocoaMQTTReader, message: CocoaMQTTMessage, id: UInt16) {
        NSLog("CocoaMQTT: PUBLISH Received from \(message.topic)")
        delegate?.mqtt(self, didReceiveMessage: message, id: id)
        if message.qos == CocoaMQTTQOS.QOS1 {
            _puback(CocoaMQTTFrameType.PUBACK, msgid: id)
        } else if message.qos == CocoaMQTTQOS.QOS2 {
            _puback(CocoaMQTTFrameType.PUBREC, msgid: id)
        }
    }

    func _puback(type: CocoaMQTTFrameType, msgid: UInt16) {
        var descr: String?
        switch type {
        case .PUBACK: descr = "PUBACK"
        case .PUBREC: descr = "PUBREC"
        case .PUBREL: descr = "PUBREL"
        case .PUBCOMP: descr = "PUBCOMP"
        default: assert(false)
        }
        if descr? { NSLog("CocoaMQTT: Send \(descr!), msgid: \(msgid)") }
        send(CocoaMQTTFramePubAck(type: type, msgid: msgid))
    }

    func didReceivePubAck(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT: PUBACK Received: \(msgid)")
        if let message = messages[msgid]? {
            messages.removeValueForKey(msgid)
            delegate?.mqtt(self, didPublishMessage: message, id: msgid)
        }
    }
    
    func didReceivePubRec(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT: PUBREC Received: \(msgid)")
        _puback(CocoaMQTTFrameType.PUBREL, msgid: msgid)
    }
    
    func didReceivePubRel(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT: PUBREL Received: \(msgid)")
        if let message = messages[msgid]? {
            messages.removeValueForKey(msgid)
            delegate?.mqtt(self, didPublishMessage: message, id: msgid)
        }
        _puback(CocoaMQTTFrameType.PUBCOMP, msgid: msgid)
    }
    
    func didReceivePubComp(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT: PUBCOMP Received: \(msgid)")
    }
    
    func didReceiveSubAck(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT: SUBACK Received: \(msgid)")
        if let topic = subtopics.removeValueForKey(msgid) {
            delegate?.mqtt(self, didSubscribeTopic: topic)
        }
    }
    
    func didReceiveUnsubAck(reader: CocoaMQTTReader, msgid: UInt16) {
        NSLog("CocoaMQTT:UNSUBACK Received: \(msgid)")
        if let topic = subtopics.removeValueForKey(msgid) {
            delegate?.mqtt(self, didUnsubscribeTopic: topic)
        }
    }
    
    func didReceivePong(reader: CocoaMQTTReader) {
        NSLog("CocoaMQTT:PONG Received")
        delegate?.mqttDidReceivePong(self)
    }
    
    func _nextMessageId() -> UInt16 {
        var id = self.gmid++
        if(id >= UInt16.max) { gmid = 1 }
        return id
    }
    
}

/**
 * MQTT Reader Delegate
 **/
protocol CocoaMQTTReaderDelegate {
    
    func didReceiveConnAck(reader: CocoaMQTTReader, connack: UInt8)
    
    func didReceivePublish(reader: CocoaMQTTReader, message: CocoaMQTTMessage, id: UInt16)

    func didReceivePubAck(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceivePubRec(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceivePubRel(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceivePubComp(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceiveSubAck(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceiveUnsubAck(reader: CocoaMQTTReader, msgid: UInt16)
    
    func didReceivePong(reader: CocoaMQTTReader)

}

class CocoaMQTTReader {

    var socket: GCDAsyncSocket

    var header: UInt8 = 0

    var data: [Byte] = []

    var length: UInt = 0

    var multiply: Int = 1

    var delegate: CocoaMQTTReaderDelegate

    var timeout: Int = 30000

    init(socket: GCDAsyncSocket, delegate: CocoaMQTTReaderDelegate) {
        self.socket = socket
        self.delegate = delegate
    }

    func start() { readHeader() }
    
    func readHeader() {
        _reset(); socket.readDataToLength(1, withTimeout: -1, tag: CocoaMQTTReadTag.TAG_HEADER.toRaw())
    }

    func headerReady(header: UInt8) {
        NSLog("header ready: \(header) ")
        self.header = header
        readLength()
    }
    
    func readLength() {
        socket.readDataToLength(1, withTimeout: NSTimeInterval(timeout), tag: CocoaMQTTReadTag.TAG_LENGTH.toRaw())
    }

    func lengthReady(byte: UInt8) {
         length += Int(byte & 127) * multiply
         if (byte & 0x80) == 0 { //done
            if length == 0 {
                frameReady()
            } else {
                readPayload()
            }
         } else { //more
            multiply *= 128
            readLength()
        }
    }

    func readPayload() {
        socket.readDataToLength(length, withTimeout: NSTimeInterval(timeout), tag: CocoaMQTTReadTag.TAG_PAYLOAD.toRaw())
    }

    func payloadReady(data: NSData) {
        self.data = [Byte](count: data.length, repeatedValue: 0)
        data.getBytes(&(self.data), length: data.length)
        frameReady()
    }

    func frameReady() {
        //handle frame
        let frameType = CocoaMQTTFrameType.fromRaw(UInt8(header & 0xF0))!
        switch frameType {
        case .CONNACK:
           delegate.didReceiveConnAck(self, connack: data[1])
        case .PUBLISH:
            let (msgId, message) = unpackPublish()
            delegate.didReceivePublish(self, message: message, id: msgId)
        case .PUBACK:
            delegate.didReceivePubAck(self, msgid: _msgid(data))
        case .PUBREC:
            delegate.didReceivePubRec(self, msgid: _msgid(data))
        case .PUBREL:
            delegate.didReceivePubRel(self, msgid: _msgid(data))
        case .PUBCOMP:
            delegate.didReceivePubComp(self, msgid: _msgid(data))
        case .SUBACK:
            delegate.didReceiveSubAck(self, msgid: _msgid(data))
        case .UNSUBACK:
            delegate.didReceiveUnsubAck(self, msgid: _msgid(data))
        case .PINGRESP:
            delegate.didReceivePong(self)
        default:
            assert(false)
        }
        readHeader()
    }
    
    func unpackPublish() -> (UInt16, CocoaMQTTMessage) {
        let frame = CocoaMQTTFramePublish(header: header, data: data)
        frame.unpack()
        let msgId = frame.msgid!
        let qos = CocoaMQTTQOS.fromRaw(frame.qos)!
        let message = CocoaMQTTMessage(topic: frame.topic!, payload: frame.payload, qos: qos, retain: frame.retain, dup: frame.dup)
        return (msgId, message)
    }

    func _msgid(bytes: [Byte]) -> UInt16 {
        if bytes.count < 2 { return 0 }
        return UInt16(bytes[0]) << 8 + UInt16(bytes[1])
    }
    
    func _reset() {
        length = 0; multiply = 1; header = 0; data = []
    }
    
}


