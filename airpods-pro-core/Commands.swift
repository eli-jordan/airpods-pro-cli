
import ArgumentParser
import Foundation
import IOBluetooth

/**
 * Represents the connection state of a AirPod Pro device
 */
enum ConnectionState: String, CaseIterable {
   case Connected
   case Disconnected
}

/**
 * Represents the current mode of an AirPod Pro device.
 *
 * IOBluetoothDevice uses a UInt8 to represent the three modes, so there are also conversions
 * to / from this representation.
 */
enum ListeningMode: String, CaseIterable, ExpressibleByArgument {
   case Off
   case NoiseCancellation
   case Transparency

   // Convert this listening mode into the UInt8 representation
   func codeValue() -> UInt8 {
      switch self {
         case .Off: return 1
         case .NoiseCancellation: return 2
         case .Transparency: return 3
      }
   }

   // Convert the provided UInt8 representation into the the ListeningMode representation
   static func fromCode(_ code: UInt8) -> ListeningMode? {
      ListeningMode.allCases.filter { $0.codeValue() == code }.first
   }
}

/**
 * Represents the current state of a paired airpod device
 */
struct AirPodProDevice {
   let underlying: IOBluetoothDevice
   let name: String
   let mode: ListeningMode
   let state: ConnectionState
   
   // Create a new AirPodProDevice instance based on the provided IOBlueToothDevice
   static func from(_ device: IOBluetoothDevice) -> AirPodProDevice {
      let state = device.isConnected() ? ConnectionState.Connected : ConnectionState.Disconnected
      return AirPodProDevice(
         underlying: device,
         name: device.name,
         mode: ListeningMode.fromCode(device.listeningMode)!,
         state: state
      )
   }

   static func findAll() -> [AirPodProDevice] {
      IOBluetoothDevice.pairedDevices()?
         .compactMap { $0 as? IOBluetoothDevice }
         .filter { $0.isANCSupported() }
         .map { AirPodProDevice.from($0) } ?? []
   }
}

/**
 * Responsible for formatting the device list for output to the console.
 */
struct AirPodProDeviceList {
   
   // Format the list of devices as a textual table for output to the console
   static func formatAsText(_ devices: [AirPodProDevice]) -> String {
      let header = asTextRow(name: "Name", state: "Connection State", mode: "Listening Mode")
      let body = devices.map { asTextRow(device: $0) }.joined(separator: "\n")
      return header + "\n" + body
   }

   private static func asTextRow(device: AirPodProDevice) -> String {
      asTextRow(name: device.name, state: device.state.rawValue, mode: device.mode.rawValue)
   }

   private static func asTextRow(name: String, state: String, mode: String) -> String {
      let paddedDeviceName = name.padding(toLength: 30, withPad: " ", startingAt: 0)
      let paddedConnectionState = state.padding(toLength: 20, withPad: " ", startingAt: 0)
      let paddedListeningMode = mode.padding(toLength: 20, withPad: " ", startingAt: 0)

      return "\(paddedDeviceName) \(paddedConnectionState) \(paddedListeningMode)"
   }

   // Format the list of devices as a json array
   static func formatAsJson(_ devices: [AirPodProDevice]) -> String {
      let data = devices.map { asDictionary(device: $0) }
      // TODO: actual error handling
      return try! String(data: JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]), encoding: .utf8)!
   }

   private static func asDictionary(device: AirPodProDevice) -> [String: Any] {
      [
         "name": device.name,
         "connectionState": device.state.rawValue,
         "listeningMode": device.mode.rawValue
      ]
   }
}

/**
 * Handles the 'set-mode' command, which sets the listening mode for a named
 * AirPod Pro device.
 */
func runSetModeCommand(deviceName: String, mode: ListeningMode) {
   let device = AirPodProDevice.findAll().filter { $0.name == deviceName }.first
   if device == nil {
      print("There are no AirpodPro devices named \(deviceName) available")
   } else {
      turnOnBluetoothIfNeeded()
      let btDevice = device!.underlying
      if(device!.state == .Disconnected) {
         btDevice.openConnection()
      }
      btDevice.listeningMode = mode.codeValue()
   }
}

func turnOnBluetoothIfNeeded() {
    guard let bluetoothHost = IOBluetoothHostController.default(),
    bluetoothHost.powerState != kBluetoothHCIPowerStateON else { return }

    // Definitely not App Store safe
    if let iobluetoothClass = NSClassFromString("IOBluetoothPreferences") as? NSObject.Type {
        let obj = iobluetoothClass.init()
        let selector = NSSelectorFromString("setPoweredOn:")
        if (obj.responds(to: selector)) {
            obj.perform(selector, with: 1)
        }
    }

    var timeWaited : UInt32 = 0
    let interval : UInt32 = 200000 // in microseconds
    while (bluetoothHost.powerState != kBluetoothHCIPowerStateON) {
        usleep(interval)
        timeWaited += interval
        if (timeWaited > 5000000) {
            exit(-2)
        }
    }
}

/**
 * Handles the 'list' command, which lists all paired AirPod Pro devices.
 */
func runListCommand(format: OutputFormat) {
   let devices = AirPodProDevice.findAll()
   if devices.isEmpty {
      print("There are no AirpodPro devices available")
   } else {
      switch format {
         case .Text: print(AirPodProDeviceList.formatAsText(devices))
         case .Json: print(AirPodProDeviceList.formatAsJson(devices))
      }
   }
}

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
   case Text
   case Json
}

/**
 * Defines the CLI, and delegates command execution to the above handlers.
 */
public struct AirpodsProCommandParser: ParsableCommand {
   public init() { }
   public static let configuration = CommandConfiguration(
      commandName: "airpods-pro",
      abstract: "Control available AirPod Pro devices",
      subcommands: [List.self, SetMode.self]
   )

   struct List: ParsableCommand {
      static let configuration = CommandConfiguration(
         abstract: "List available AirPod Pro devices"
      )

      @Option(help: "The format of the generated results. Options are 'Text' and 'Json'")
      var format: OutputFormat = OutputFormat.Text

      func run() {
         runListCommand(format: format)
      }
   }

   struct SetMode: ParsableCommand {
      static let configuration = CommandConfiguration(
         abstract: "Set the listening mode of a specified AirPod Pro device"
      )

      @Argument(help: "The name of the device")
      var name: String
      
      @Option(help: "The listening mode to set. Options are 'Off', 'NoiseCancellation' and 'Transparency'")
      var mode: ListeningMode

      func run() {
         runSetModeCommand(deviceName: name, mode: mode)
      }
   }
}

