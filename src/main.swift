//
//  main.swift
//  airpod-mode-switcher
//
//  Created by Elias Jordan on 4/8/20.
//  Copyright © 2020 Elias Jordan. All rights reserved.
//

import Foundation
import IOBluetooth
import ArgumentParser


enum ConnectionState: String, CaseIterable {
    case Connected = "Connected"
    case Disconnected = "Disconnected"
}

enum ListeningMode: String, CaseIterable, ExpressibleByArgument {
    case Off = "Off"
    case NoiseCancellation = "NoiseCancellation"
    case Transparency = "Transparency"
}

extension ListeningMode {
    
    static func fromString(_ mode: String) -> ListeningMode? {
        ListeningMode.allCases.filter { $0.rawValue == mode }.first
    }
    
    static func fromCode(_ code: UInt8) -> ListeningMode? {
        ListeningMode.allCases.filter { $0.codeValue() == code }.first
    }
    
    func codeValue() -> UInt8 {
        switch self {
            case .NoiseCancellation: return 2
            case .Off: return 1
            case .Transparency: return 3
        }
    }
}

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case Text = "Text"
    case Json = "Json"
}

func listAirpodProDevices() -> [IOBluetoothDevice] {
    return IOBluetoothDevice.pairedDevices()?
        .compactMap { $0 as? IOBluetoothDevice }
        .filter { $0.isANCSupported() } ?? []
}


struct CommandParser: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "airpods-pro",
        abstract: "Control available Airpod Pro devices",
        subcommands: [List.self, SetMode.self]
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available Airpod Pro devices"
        )
        
        @Option(help: "The format of the generated results")
        var format: OutputFormat = OutputFormat.Text
        

        func run() {
            let devices = listAirpodProDevices()
            if devices.isEmpty {
                print("There are no airpods-pro devices available")
            } else {
                if(format == .Text) {
                    print(formatRow("Name", "Connection State", "Listening Mode"))
                    devices.forEach { device in
                        let deviceName = device.name!
                        let isConnected = (device.isConnected() ? ConnectionState.Connected : ConnectionState.Disconnected).rawValue
                        let listeningMode = ListeningMode.fromCode(device.listeningMode)!.rawValue
                        
                        print(formatRow(deviceName, isConnected, listeningMode))
                    }
                } else {
                    
                    func toItem(_ device: IOBluetoothDevice) -> Dictionary<String, String> {
                        let deviceName = device.name!
                        let isConnected = (device.isConnected() ? ConnectionState.Connected : ConnectionState.Disconnected).rawValue
                        let listeningMode = ListeningMode.fromCode(device.listeningMode)!.rawValue
                        let item: Dictionary<String, String> = [
                            "name": deviceName,
                            "connectionState": isConnected,
                            "listeningMode": listeningMode
                        ]
                        return item
                    }
                    
                    let data = devices.map { toItem($0) }
                    print(try! String(data: JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]), encoding: .utf8)!)
                }
                
            }
        }
        
        private func formatRow(_ deviceName: String, _ connectionState: String, _ listeningMode: String) -> String {
            let paddedDeviceName = deviceName.padding(toLength: 30, withPad: " ", startingAt: 0)
            let paddedConnectionState = connectionState.padding(toLength: 20, withPad: " ", startingAt: 0)
            let paddedListeningMode = listeningMode.padding(toLength: 20, withPad: " ", startingAt: 0)
            
            return "\(paddedDeviceName) \(paddedConnectionState) \(paddedListeningMode)"
        }
    }
    
    struct SetMode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set the listening mode of a specified AirPods Pro device"
        )
        
        @Argument(help: "The name of the device")
        var name: String
        
        @Option(help: "The listening mode to set")
        var mode: ListeningMode
 
        func run() {
            let device = listAirpodProDevices().filter { $0.name == name }.first
            if device == nil {
                print("There are no Airpod Pro devices named \(name) available")
            } else {
                device!.listeningMode = mode.codeValue()
            }
        }
    }
}

CommandParser.main()
