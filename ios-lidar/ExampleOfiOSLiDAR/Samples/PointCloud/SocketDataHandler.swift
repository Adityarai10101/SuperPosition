//
//  SocketDataHandler.swift
//  ExampleOfiOSLiDAR
//
//  Created by Shrey Joshi on 1/28/23.
//


import Foundation
import Metal
import MetalKit

final class SwiftWebSocketClient: NSObject {
        
    static let shared = SwiftWebSocketClient()
    var webSocket: URLSessionWebSocketTask?
    
    var opened = false
    
    private var urlString = "wss://superposition.herokuapp.com"
    
    private override init() {
        // no-op
    }
    
    func subscribeToService() {
        print("subscribing to service")
        if !opened {
            print("not opened yet, subscribing")
            openWebSocket()
        }
    }
    
    private func openWebSocket() {
        print("openwebsocket")
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let webSocket = session.webSocketTask(with: request)
            self.webSocket = webSocket
            self.opened = true
            self.webSocket?.resume()
            print("Websocket opened")
        } else {
            print("Websocket not able to be opened, setting to nil")
            webSocket = nil
        }
    }

    
    func sendData(_ data: Data) {
        if opened {
            webSocket?.send(.data(data)) { error in
                if let error = error {
                    print("Error sending data over WebSocket: \(error)")
                }
            }
        } else {
            print("WebSocket is not open, cannot send data.")
        }
    }

    
//    func sendData(_ data: Data) {
//        if let webSocket = webSocket, webSocket.state == .running {
//            webSocket.send(.data(data)) { error in
//                if let error = error {
//                    print("Error sending data over WebSocket: \(error)")
//                }
//            }
//        } else {
//            print("WebSocket is not open, cannot send data.")
//        }
//    }

}

extension SwiftWebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
    }

    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.webSocket = nil
        self.opened = false
    }
}

